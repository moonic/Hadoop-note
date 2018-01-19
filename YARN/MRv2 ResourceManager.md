# MRv2 ResourceManager
> 在YARN中，资源调度器（ResourceScheduler）是一个非常核心的部件，它负责将各个节点上的资源封装成container，并按照一定的约束条件（按队列分配，每个队列有一定的资源分配上限等）分配给各个application。

* 分析基于hadoop-2.0.3-alpha）
  * YARN的资源管理器实际上是一个事件处理器，它需要处理来自外部的6种SchedulerEvent类型的事件，并根据事件的具体含义进行相应的处理。这6种事件含义如下：
  1.  NODE_REMOVED
    * 事件NODE_REMOVED表示集群中被移除一个计算节点（可能是节点故障或者管理员主动移除），资源调度器收到该事件时需要从可分配资源总量中移除相应的资源量。
    2. NODE_ADDED
      * 事件NODE_ADDED表示集群中增加了一个计算节点，资源调度器收到该事件时需要将新增的资源量添加到可分配资源总量中。
    3. APPLICATION_ADDED
      * 事件APPLICATION_ADDED 表示ResourceManager收到一个新的Application。通常而言，资源管理器需要为每个application维护一个独立的数据结构，以便于统一管理和资源分配。资源管理器需将该Application添加到相应的数据结构中。
    4. APPLICATION_REMOVED
      * 事件APPLICATION_REMOVED表示一个Application运行结束（可能成功或者失败），资源管理器需将该Application从相应的数据结构中清除。
    5. CONTAINER_EXPIRED
      * 当资源调度器将一个container分配给某个ApplicationMaster后，如果该ApplicationMaster在一定时间间隔内没有使用该container，则资源调度器会对该container进行再分配。
    6. NODE_UPDATE
      * NodeManager通过心跳机制向ResourceManager汇报各个container运行情况，会触发一个NODE_UDDATE事件，由于此时可能有新的container得到释放，因此该事件会触发资源分配，也就是说，该事件是6个事件中最重要的事件，它会触发资源调度器最核心的资源分配机制。

* 资源表示模型
  * 当前YARN支持内存和CPU两种资源类型的管理和分配。当NodeManager启动时，会向ResourceManager注册，而注册信息中会包含该节点可分配的CPU和内存总量，这两个值均可通过配置选项设置，具体如下：
  1. yarn.nodemanager.resource.memory-mb
    * 可分配的物理内存总量，默认是8*1024MB。
  2. yarn.nodemanager.vmem-pmem-ratio
  * 每单位的物理内存总量对应的虚拟内存量，默认是2.1，表示每使用1MB的物理内存，最多可以使用2.1MB的虚拟内存总量。
  3. yarn.nodemanager.resource.cpu-core（默认是8）可分配的CPU总个数，默认是8
  4. yarn.nodemanager.vcores-pcores-ratio
    * 为了更细粒度的划分CPU资源，YARN将每个物理CPU划分成若干个虚拟CPU，默认值为2。用户提交应用程序时，可以指定每个任务需要的虚拟CPU个数。在MRAppMaster中，每个Map Task和Reduce Task默认情况下需要的虚拟CPU个数为1，用户可分别通过mapreduce.map.cpu.vcores和mapreduce.reduce.cpu.vcores进行修改（对于内存资源，Map Task和Reduce Task默认情况下需要1024MB，用户可分别通过mapreduce.map.memory.mb和mapreduce.reduce.memory.mb修改）。
    * （在最新版本2.1.0-beta中，yarn.nodemanager.resource.cpu-core和yarn.nodemanager.vcores-pcores-ratio两个参数被遗弃，引入一个新参数yarn.nodemanager.resource.cpu-vcore，表示虚拟CPU个数，具体请阅读YARN-782）
YARN对内存资源和CPU资源采用了不同的资源隔离方案。对于内存资源，为了能够更灵活的控制内存使用量，YARN采用了进程监控的方案控制内存使用，即每个NodeManager会启动一个额外监控线程监控每个container内存资源使用量，一旦发现它超过约定的资源量，则会将其杀死。采用这种机制的另一个原因是Java中创建子进程采用了fork()+exec()的方案，子进程启动瞬间，它使用的内存量与父进程一致，从外面看来，一个进程使用内存量可能瞬间翻倍，然后又降下来，采用线程监控的方法可防止这种情况下导致swap操作。对于CPU资源，则采用了Cgroups进行资源隔离。具体可参考YARN-3。

* 资源分配模型
  * 在YARN中，用户以队列的形式组织，每个用户可属于一个或多个队列，且只能向这些队列中提交application。每个队列被划分了一定比例的资源。
YARN的资源分配过程是异步的
  * 也就是说，资源调度器将资源分配给一个application后，不会立刻push给对应的ApplicaitonMaster，而是暂时放到一个缓冲区中，等待ApplicationMaster通过周期性的RPC函数主动来取，也就是说，采用了pull-based模型，而不是push-based模型，这个与MRv1是一致的。

## NM管理 
NodeManager管理部分主要由三个服务构成，分别是NMLivelinessMonitor、NodesListManager和ResourceTrackerService，它们共同管理NodeManager的生存周期，接下来我们依次介绍这三个服务。
NMLivelinessMonitor
该服务周期性遍历所有NodeManager，如果一个NodeManager在一定时间（可通过参数yarn.nm.liveness-monitor.expiry-interval-ms配置，默认为10min）内未汇报心跳信息，则认为它死掉了，它上面所有正在运行的Container将被置为运行失败（RM不会重新执行这些Container，它只会通过心跳机制告诉对应的AM，由AM决定是否重新执行，如果需要，则AM重新向RM申请资源）。
NodesListManager
NodesListManager维护正常节点和异常节点列表，它管理exlude（类似于黑名单）和inlude（类似于白名单）节点列表，这两个列表所在的文件分别可通过yarn.resourcemanager.nodes.include-path和yarn.resourcemanager.nodes.exclude-path配置（每个节点host占一行），其中，exlude节点是排外节点，它们无法与RM取得连接（直接在RPC层抛出异常，导致NM死掉），默认情况下，这两个列表均为空，表示任何节点均可接入RM。最重要的一点是，这两个文件均可以动态加载。
ResourceTrackerService
ResourceTrackerService负责处理来自各个NodeManager的请求，主要包括两种请求：注册和心跳，其中，注册是NodeManager启动时发生的行为，请求包中包含节点ID，可用的资源上限等信息，而心跳是周期性 行为，包含各个Container运行状态，运行的Application列表、节点健康状况（可通过一个脚本设置），而ResourceTrackerService则为NM返回待释放的Container列表、Application列表等。
当一个NM启动时，他所做的第一件事是向RM注册，这是通过RPC函数ResourceTracker.registerNodeManager()实现的。
NM启动时候，它会周期性的通过RPC函数ResourceTracker. nodeHeartbeat ()汇报心跳，具体包含各个Container运行状态、运行的Application列表、节点健康状况等信息，而RM则位置返回需要释放的Container列表，Application列表等。

## RMNode 状态分析
> RMNode是ResourceManager中用于维护一个节点生命周期的数据结构，它的实现是RMNodeImpl，该类维护了一个节点状态机，记录了节点可能存在的各个状态以及导致状态间转换的事件，当某个事件发生时，RMNodeImpl会根据实际情况进行节点状态转移，同时触发一个行为。


如图所示，在RM看来，每个节点有6种基本状态（NodeState）和8种导致这6种状态之间发生转移的事件（RMNodeEventType），RMNodeImpl的作用是等待接收其他对象发出的RMNodeEventType类型的事件，然后根据当前状态和事件类型，将当前状态转移到另外一种状态，同时触发另外一种行为（实际上执行一个函数，该函数可能会再次发出一种其他类型的事件）。

* 基本状态
  1. NEW
    * 状态机初始状态，每个NodeManager对应一个状态机，而每个状态机的初始状态则为NEW。
  2. RUNNING
    * NodeManager启动后，会通过RPC函数ResourceTracker.registerNodeManager()向RM注册，此时NodeManager会进入RUNNING状态。
  3. DECOMMSIONED
    * 如果一个节点位于exlude list中，则对应的NodeManager将处于DECOMMSIONED状态，这样的NodeManager无法与RM取得连接。
  4. UNHEALTHY
    * 管理员可在每个NodeManager上配置一个健康状况监测脚本，NodeManager中有一个专门线程周期性执行该脚本，以判定NodeManager是否处于健康状态。NodeManager会通过心跳机制将脚本执行结果汇报给RM，如果NodeManager处于不健康状态下，则RM会将其状态置为UNHEALTHY。
  5. LOST
    * 如果一个NodeManager在一定时间间隔内未汇报心跳信息，则RM认为它死掉了，会将其置为LOST状态。
  6. REBOOTED
    * 如果RM发现NodeManager的心跳ID处于不连续状态，则会将其置为REBOOTED状态，已要求它重新启动。

* 基本事件
  1. STARTED
    * NodeManager启动后，会通过RPC函数ResourceTracker.registerNodeManager()向RM注册，此时会触发STARTED事件。
  2. STATUS_UPDATE
    * NM向RM汇报心跳信息时，会触发一个STATUS_UPDATE事件。
  3. DECOMMISSION
    * 当一个NodeManager被转入exlude list中时，会触发一个DECOMMISSION事件。
  4. EXPIRE 
    * 如果一个NodeManager在一定时间间隔内未汇报心跳，则会触发一个EXPIRE时间。
  5. REBOOTING
    * 当RM发现NodeManager的心跳ID处于不连续状态时，会触发一个REBOOTING事件。
  6. CLEANUP_APP
    * 当一个Application执行完成时（可能成功或则失败），会触发一个CLEANUP_APP事件，以清理Application。
  7. CLEANUP_CONTAINER
    * 当一个Container执行完成时（可能成功或则失败），会触发一个CLEANUP_ CONTAINER事件，以清理Container。
  8. RECONNECTED
    * 如果一个已经在RM上注册过的ApplicationMaster再次请求注册时，则RM会触发一个RECONNECTED，清理该ApplicationMaster后以要其它重新注册。
下图描述了以上各个事件的来源：


##   涉及到的状态机
  1. RMApp：每个application对应一个RMApp对象，保存该application的各种信息。
  2. RMAppAttempt：每个RMApp可能会对应多个RMAppAttempt对象，这取决于前面的RMAppAttempt是否执行成功，如果不成功，会启动另外一个，直到运行成功。RMAppAttempt对象称为“application执行尝试”，这RMApp与RMAppAttempt关系类似于MapReduce中的task与taskAttempt的关系。
  3. RMNode：保存各个节点的信息。
  4. RMContainer：保存各个container的信息。
##    事件调度器
1. AsyncDispatcher
中央事件调度器，各个状态机的事件调度器会在中央事件调度器中注册，注册方式信息包括：<事件，事件调度器>。该调度器维护了一个事件队列，它会不断扫描整个队列，取出一个事件，检查事件类型，并交给相应的事件调度器处理。

2. 各个子事件调度器
  * 事件类型	状态机	事件处理器
RMAppEvent	RMApp	ApplicationEventDispatcher
RMAppAttemptEvent	RMAppAttempt	ApplicationAttemptEventDispatcher
RMNodeEvent	RMNode	NodeEventDispatcher
SchedulerEvent	—	SchedulerEventDispatcher
AMLauncherEvent	—	ApplicationMasterLauncher

3.  ResourceManager中事件处理流
  1.Client通过RMClientProtocol协议向ResourceManager提交application。
* 代码所在目录：
hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient/src/main/java
* jar包：org.apache.hadoop.mapred

* 关键类与关键函数：YARNRunner.submitJob()
  1. ResourceManager端的ClientRMService服务接收到application，使得RMAppManager调用handle函数处理RMAppManagerSubmitEvent事件，处理逻辑如下：为该application创建RMAppImpl对象，保存其信息，接着产生RMAppEventType.START事件.
* 代码所在目录：
hadoop-mapreduce-project\hadoop-yarn\hadoop-yarn-server\hadoop-yarn-server-resourcemanager\src\main\java\org\apache\hadoop\yarn\server\resourcemanager
* jar包：org.apache.hadoop.yarn.server.resourcemanager
* 关键类与关键函数：ClientRMService.submitApplication()，RMAppManager.submitApplication()

* RMAppEventType.START事件传递给AsyncDispatcher，AsyncDispatcher查看相关数据结构，确定该事件由ApplicationEventDispatcher处理，该dispatcher将RMApp从RMAppState.NEW状态变为RMAppState.SUBMITTED状态，同时创建RMAppAttemptImpl对象，并触发RMAppAttemptEventType.START事件。
  * jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp
  * 关键类与关键函数：RMAppImpl.StartAppAttemptTransition
  * RMAppAttemptEventType.START事件传递给AsyncDispatcher，AsyncDispatcher查看相关数据结构，确定该事件由ApplicationAttemptEventDispatcher处理，该dispatcher将RMAppAttempt从RMAppAttemptState.NEW变为RMAppAttemptState.SUBMITTED状态。

* jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
*  关键类与关键函数：RMAppAttemptImpl.StateMachineFactory

### RMAppAttempt向ApplicationMasterService注册，它将之保存在responseMap中。
* jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
*  关键类与关键函数：RMAppAttemptImpl.AttemptStartedTransition

### RMAppAttempt触发AppAddedSchedulerEvent
1. jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
2.  关键类与关键函数：RMAppAttemptImpl.AttemptStartedTransition

##  ResourceScheduler
* （如FifoScheduler）捕获AppAddedSchedulerEvent事件，并创建SchedulerApp对象，使RMAppAttempt对像从RMAppAttemptState.SUBMITTED转化为RMAppAttemptState.SCHEDULED状态，同时产生RMAppAttemptEventType.APP_ACCEPTED事件。
*  jar包：org.apache.hadoop.yarn.server.resourcemanager.scheduler.fifo
*  关键类与关键函数：FifoScheduler.addApplication

* RMAppAttemptEventType.APP_ACCEPTED事件由ApplicationAttemptEventDispatcher捕获，并将RMAppAttempt从RMAppAttemptState.SUBMITTED转化为 RMAppAttemptState.SCHEDULED状态，并产生RMAppEventType.APP_ACCEPTED事件。
  *  jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
  * 关键类：RMAppAttemptImpl.ScheduleTransition
  * 调用ResourceScheduler的allocate函数，为ApplicationMaster申请一个container。
  * jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
  * 关键类：RMAppAttemptImpl.ScheduleTransition
  * 此刻，某个node（称为“AM-NODE”）正好通过heartbeat向ResourceManager.ResourceTrackerService汇报自己所在节点的资源使用情况。    
  * ResourceTrackerService.nodeHeartbeat收到heartbeat信息后，触发RMNodeStatusEvent(RMNodeEventType.STATUS_UPDATE)事件。
    * jar包：org.apache.hadoop.yarn.server.resourcemanager
    *  关键类：ResourceTrackerService.nodeHeartbeat
  * RMNodeStatusEvent被ResourceScheduler捕获，调用assginContainers为该application分配一个container（用对象RMContainer表示），分配之后，会触发一个RMContainerEventType.START事件。
  * RMContainerEventType.START事件被NodeEventDispatcher捕获，使得RMContainer对象从RMContainerState.NEW状态转变为RMContainerState.ALLOCATED状态，同时触发RMAppAttemptContainerAllocatedEvent（RMAppAttemptEventType.CONTAINER_ALLOCATED）事件.
    * jar包：org.apache.hadoop.yarn.server.resourcemanager.rmcontainer
    * 关键类：RMContainerImpl.ContainerStartedTransition
  * RMAppAttemptContainerAllocatedEvent事件被 ApplicationAttemptEventDispatcher捕获，并将RMAppAttempt对象从RMAppAttemptState.SCHEDULED状态转变为RMAppAttemptState.ALLOCATED状态，同时调用Scheduler的allocate函数申请一个container，并触发AMLauncherEventType.LAUNCH事件

* AMLauncherEventType.LAUNCH事件被ApplicationMasterLauncher捕获
  * 主要处理逻辑如下：创建一个AMLauncher对象，并添加到队列masterEvents中，等待处理；一旦被处理，会调用AMLauncher.launch()函数，该函数会调用ContainerManager.startContainer()函数创建container，同时触发RMAppAttemptEventType.LAUNCHED事件。
    * jar包：org.apache.hadoop.yarn.server.resourcemanager.amlauncher
    * 关键类：ApplicationMasterLauncher
  * RMAppAttemptEventType.LAUNCHED事件被ApplicationAttemptEventDispatcher捕获，并将RMAppAttempt对象从  RMAppAttemptState.ALLOCATED状态转变为RMAppAttemptState.LAUNCHED状态。
  * 将该application的RMAppAttempt对象注册到AMLivenessMonitor中，以便实时监控该application的存活状态。
  * AM-NODE节点为该Application创建ApplicationMaster，接下来ApplicationMaster会与ResourceManager协商资源并通知NodeManager创建Container。ApplicationMaster首先会向ApplicationMasterService注册。
  * ApplicationMasterService收到新的ApplicationMaster注册请求后，会触发RMAppAttemptRegistrationEvent（RMAppAttemptEventType.REGISTERED）事件。
  * RMAppAttemptRegistrationEvent事件被 ApplicationAttemptEventDispatcher捕获，并将RMAppAttempt对象从RMAppAttemptState.LAUNCHED状态转化为RMAppAttemptState.RUNNING状态，同时触发RMAppEventType.ATTEMPT_REGISTERED事件。
  * 至此，该application的ApplicationMaster创建与注册完毕，接下来ApplicationMaster会根据Application的资源需求向ResourceManager请求资源，同时监控各个子任务的执行情况。
 
4.    ResourceManager中事件处理流直观图
下图是从另一个方面对上图的重新绘制：


## RMAppAttempt 状态机分析
RMAppAttempt是ResourceManager中用于维护一个Application Attempt生命周期的数据结构，它的实现是RMAppAttemptImpl，该类维护了一个Application Attempt状态机，记录了一个Application Attempt可能存在的各个状态以及导致状态间转换的事件，当某个事件发生时，RMAppAttemptImpl会根据实际情况进行Application Attempt状态转移，同时触发一个行为。
需要说明的是，在YARN中，每个application用数据结构RMApp表示，每个application可能会尝试运行多次，则每次运行尝试的整个运行过程用数据结构RMAppAttempt表示，如果一次运行尝试运行失败，则RMApp会创建另外一个运行尝试，直到某次运行尝试运行成功或者达到运行尝试运行上限。

如图所示，在RM看来，每个Application Attempt有13种基本状态（RMAppAttemptState）和15种导致这13种状态之间发生转移的事件（RMAppAttemptEventType），RMAppAttemptImpl的作用是等待接收其他对象发出的RMAppAttemptEventType类型的事件，然后根据当前状态和事件类型，将当前状态转移到另外一种状态，同时触发另外一种行为（实际上执行一个函数，该函数可能会再次发出一种其他类型的事件）。下面具体进行介绍：
基本状态
（1） NEW
状态机初始状态，每个Application对应一个状态机，而每个状态机的初始状态为NEW。
（2）SUBMITTED
客户端通过RPC函数ClientRMProtocol.submitApplication向RM提交一个Application，通过合法性验证后，RM会将Application Attempt状态置为SUBMITTED。
（3）SCHEDULED
客户端提交Appliation后，ResourceManager通知ResouceScheduler，ResouceScheduler将之置为SCHEDULED状态，表示开始为该Application的ApplicationMaster分配资源。
（4）ALLOCATED_SAVING
ResouceScheduler将一个Container分配给该Application Attempt的ApplicationMaster（用于启动该ApplicationMaster），则该Application Attempt将被置为ALLOCATED_SAVING状态。
（5）ALLOCATED
ResourceManager将分配给ApplicationMaster的container信息保存到文件中，以便于失败后从磁盘上恢复，经持久化存储的Application Attempt状态为ALLOCATED。
（6） LAUNCHED
ResourceManager中的ApplicationMasterLauncher与对应的NodeManager通信，启动ApplicationMaster，此时Application Attempt将被置为LAUNCHED状态。
（7） RUNNING
RM创建的Application Attempt在对应的NodeManager上成功启动，并通过RPC函数AMRMProtocol.registeApplicationMaster()向ResourceManager注册，此时Application Attempt状态被置为RUNNING。
（8） FAILED
Application的ApplictionMaster运行失败，导致Application Attempt的状态被置为FAILED。
（9）KILLED
Application Attempt收到KILL事件，将被置为KILLED。
（10）FINISHING
Application Master通过RPC函数AMRMProtocol.finishApplicationMaster()通知RM，自己运行结束，此时Application处于FINISHING状态。
（11）FINISHED
NodeManager通过心跳汇报ApplicationMaster所在的Container运行结束，此时Application被置为FINISHED状态。
（12）LAUNCHED_UNMANAGED_SAVING
为了方便对ApplictionMaster进行测试和满足特殊情况下对权限的要求，ResourceManager允许用户直接将Application的ApplicationMaster启动在客户端中。
（13） RECOVERED
ApplicationAttempt从文件中恢复状态。
基本事件
RMAppAttempt中涉及到的15种事件类型来源如下图所示：
