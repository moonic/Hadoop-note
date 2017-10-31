# MRv2 Node Manager

* NodeManager（NM）是YARN中每个节点上的代理
  * 管理Hadoop集群中单个计算节点，包括与ResourceManger保持通信
  * 监督Container的生命周期管理
  * 监控每个Container的资源使用（内存、CPU等）情况，追踪节点健康状况
  * 管理日志和不同应用程序用到的附属服务（auxiliary service）。

### NodeStatusUpdater
 
* 当NM启动时，该组件向RM注册，并发送节点上可用资源
* 接下来，NM与RM通信，汇报各个Container的状态更新，包括节点上正运行的Container、已完成的Contaner等。
* 此外，RM可能向NodeStatusUpdater发信号，杀死处于运行中的Container。
> 注：NodeStatusUpdater是NM与RM通信的唯一通道，它实际上是RPC协议ResourceTracker的client，它周期性地调用RPC函数nodeHeartbeat()向RM汇报本节点上各种信息，包括资源使用情况，各个Container运行情况等。

### ContainerManager
* 它是NodeManager中核心组件，它由以下几个子组件构成
* 每个子组件负责一部分功能，以管理运行在该节点上的所有Container
* （注意，ContainerManager实际上是个接口，真正的实现是ContainerManagerImpl类）

1. RPC Server ContainerManager从各个Application Master上接收RPC请求以启动Container或者停止正在运行的Container。它与ContainerTokenSecretManager（下面将介绍）合作，以对所有请求进行合法性验证。所有作用在正运行Container的操作均会被写入audit-log，以便让安全工具进行后续处理。
注：这里的“RPC Server”实际上是RPC协议ContainerManager的server，AM可通过该协议通知某个节点启动或者释放container，ContainerManager定义了三个接口供AM使用：

StartContainerResponse startContainer(StartContainerRequest request); //启动container
StopContainerResponse stopContainer(StopContainerRequest request); //释放container
GetContainerStatusResponse getContainerStatus(GetContainerStatusRequest request);//获取container列表。

2. ResourceLocalizationService 负责（从HDFS上）安全地下载和组织Container需要的各种文件资源。它尽量将文件分摊到各个磁盘上。它会为下载的文件添加访问控制限制，并为之施加合适的（磁盘空间）使用上限。
注：该服务会采用多线程方式同时从HDFS上下载文件，并按照文件类型（public或者private文件）存放到不同目录下，并为目录设置严格的访问权限，同时，每个用户可使用的磁盘空间大小也可以设置。
3. ContainersLauncher 维护了一个线程池，随时准备并在必要时尽快启动Container，同时，当收到来自RM或者 ApplicationMaster的清理Container请求时，会清理对应的Container进程。
4. AuxServices NM提供了一个框架以通过配置附属服务扩展自己的功能，这允许每个节点定制一些特定框架可能需要的服务，当然，这些服务是与NM其他服务隔离开的（有自己的安全验证机制）。附属服务需要在NM启动之前配置好，且由对应应用程序的运行在本节点上的第一container触发启动。
5. ContainersMonitor 当一个Container启动之后，该组件便开始观察它在运行过程中的资源利用率。为了实现资源隔离和公平共享，RM为每个Container分配了一定量的资源。ContainersMonitor持续监控每个Container的利用率，一旦一个Container超出了它的允许使用份额，它将向Container发送信号将其杀掉，这可以避免失控的Container影响了同节点上其他正在运行的Container。（注意，ContainersMonitor实际上是个接口，真正的实现是ContainersMonitorImpl类）。
注：NM启动一个container后，ContainersMonitor会将该container进程对一个的pid添加到监控列表中，以监控以pid为根的整棵进程树的资源使用情况，它周期性地从/etc/proc中获取进程树使用的总资源，一旦发现超过了预期值，则会将其杀死。在最新版YARN中，已采用了Linux container对资源进行隔离。
6. LogHandler 一个可插拔组件，用户通过它可选择将Container日志写到本地磁盘上还是将其打包后上传到一个文件系统中。

### ContainerExecutor
与底层操作系统交互，安全存放Container需要的文件和目录，进而以一种安全的方式启动和清除Container对应的进程。
注：在最新版YARN中，已采用了Linux container对资源进行隔离

### NodeHealthCheckerService
提供以下功能：通过周期性地运行一个配置好的脚本检查节点的健康状况
它也会通过周期性地在磁盘上创建临时文件以监控磁盘健康状况
任何系统健康方面的改变均会通知NodeStatusUpdater（前面已经介绍过），它会进一步将信息传递给RM。


### Security
1. ApplicationACLsManager NM需要为所有面向用户的API提供安全检查，如在Web-UI上只能将container日志显示给授权用户。该组件为每个应用程序维护了一个ACL列表，一旦收到类似请求后会利用该列表对其进行验证。
2. ContainerTokenSecretManager 检查收到的各种访问请求的合法性，确保这些请求操作已被RM授权。

### WebServer
在给定时间点，展示该节点上所有应用程序和container列表，节点健康相关的信息和container产生的日志。

* 主要功能亮点
启动Container
为了能够启动Container，NM期望收到的Container定义了关于它运行时所需的详细信息，包括运行container的命令、环境变量、所需的资源列表和安全令牌等。
一旦收到container启动请求，如果YARN启用了安全机制，则NM首先验证请求合法性以对用户和正确的资源分配进行授权。之后，NM将按照以下步骤启动一个container：
1. 在本地拷贝一份运行Container所需的所有资源（通过Distributed Cache实现）。
2. 为container创建经隔离的工作目录，并在这些目录中准备好所有（文件）资源。
3. 运行命令启动container
  * 日志聚集
    * 与MRv1不同，NM不再截取日志并将日志留单个节点（TaskTracker）上，而是将日志上传到一个文件系统中
    * 比如HDFS，以此来解决日志管理问题。
    * 在某个NM上，所有属于同一个应用程序的container日志经聚集后被写到（可能经过压缩处理）一个FS上的日志文件中，用户可通过YARN命令行工具，WEB-UI或者直接通过FS访问这些日志。

* MapReduce shuffle如何利用NM的附属服务
  * 运行MapReduce程序所需的shuffle功能是通过附属服务实现的，该服务会启动一个Netty Server，它知道如何处理来自Reduce Task的MR相关的shuffle请求。
  * MR（MapReduce） AM（ApplicationMaster）为shuffle服务定义了服务ID，和可能需要的安全令牌，而NM向AM提供shuffle服务的运行端口号，并由AM传递给各个Reduce Task。

* 在YARN中，NodeManager主要用于管理抽象的container
  * 它只处理container相关的事情，而不必关心每个应用程序（如MapReduce Task）自身的状态管理
  * 不再有类似于map slot和reduce slot的slot概念，正是由于上述各个模块间清晰的责任分离，NM可以很容易的扩展，且它的代码也更容易维护。
