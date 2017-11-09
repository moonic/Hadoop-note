# MapReduce Framework 2
> 随着集群规模和负载增加，MapReduce JobTracker在内存消耗，线程模型和扩展性/可靠性/性能方面暴露出了缺点，为此需要对它进行大整修。
需求

* 当我们对Hadoop MapReduce框架进行改进时，需要时刻谨记的一个重要原则是用户的需求。近几年来，从Hadoop用户那里总结出MapReduce框架当前最紧迫的需求有：
  1. 可靠性（Reliability）– JobTracker不可靠
  2.可用性（Availability）– JobTracker可用性有问题
  3. 扩展性（Scalibility）-拥有10000个节点和200，000个核的集群
  4. 向后兼容性（Backward Compatibility）：确保用户的MapReduce作业可无需修改即可运行
  5. 演化（Evolution）：让用户能够控制软件栈的升级，尤其是与Hive，HBase等的兼容。
  6. 可预测的延迟：这是用户非常关心的。小作业应该尽可能快得被调度，而当前基于TaskTracker->JobTracker ping（heartbeat）的通信方式代价和延迟过大，比较好的方式是JobTracker->TaskTracker ping, 这样JobTracker可以主动扫描有作业运行的TaskTracker（调用RPC）（见MAPREDUCE-279）。
  7.集群资源利用率。 Map slot和reduce slot不能共享，且reduce 依赖于map结果，造成reduce task在shuffle阶段资源利用率很低，出现“slot hoarding”现象。

* 次重要的需求有：
  1.支持除MapReduce之外的计算框架，如DAG，迭代计算等。
  2.  支持受限的，短时间的服务(for example ????)
面对以上这些需求，我们有必要重新设计整个MapReduce数据计算架构。大家已达成共识：当前的MapReduce架构不能够满足我们上面的需求，而双层调度器（Two level Scheduler）将可解决该问题。

* 下一代MapReduce（MRv2/YARN）
  * MRv2最基本的设计思想是将JobTracker的两个主要功能，即资源管理和作业调度/监控分成两个独立的进程。在该解决方案中包含两个组件：全局的ResourceManager（RM）和与每个应用相关的ApplicationMaster（AM）。
   * 这里的“应用”指一个单独的MapReduce作业或者DAG作业。RM和与NodeManager（NM，每个节点一个）共同组成整个数据计算框架。RM是系统中将资源分配给各个应用的最终决策者。AM实际上是一个具体的框架库，它的任务是【与RM协商获取应用所需资源】和【与NM合作，以完成执行和监控task的任务】。

* RM有两个组件组成：
  * 调度器（Scheduler）
  * 应用管理器（ApplicationsManager，ASM）
    * 调度器根据容量，队列等限制条件（如每个队列分配一定的资源，最多执行一定数量的作业等），将系统中的资源分配给各个正在运行的应用。这里的调度器是一个“纯调度器”，因为它不再负责监控或者跟踪应用的执行状态等，此外，他也不负责重新启动因应用执行失败或者硬件故障而产生的失败任务。调度器仅根据各个应用的资源需求进行调度，这是通过抽象概念“资源容器”完成的，资源容器（Resource Container）将内存，CPU，磁盘，网络等资源封装在一起，从而限定每个任务使用的资源量。（注：Hadoop-0.23.0【资料一， 资料二】中的Container采用了“监控linux进程”来限制每个任务的资源，即：有个监控线程周期性地从linux虚拟文件系统/proc/中读取相应进程树使用的资源总量，一旦检测到超出限制，则直接kill该task，今后的版本想严格限制内存，CPU，网络，磁盘等资源，也许会采用cgroups，关于cgroups，可参考：【cgroups.txt】，【cgroup及资源管理】，cgroups在淘宝，百度等公司已经开始使用。）。
    * 调度器是可插拔的组件，主要负责将集群中得资源分配给多个队列和应用。YARN自带了多个资源调度器，如Capacity Scheduler和Fair Scheduler等。
  * ASM主要负责接收作业，协商获取第一个容器用于执行AM和提供重启失败AM container的服务。
  * NM是每个节点上的框架代理，主要负责启动应用所需的容器，监控资源（内存，CPU，磁盘，网络等）的使用情况并将之汇报给调度器。
  * AM主要负责同调度器协商以获取合适的容器，并跟踪这些容器的状态和监控其进度。

* YARN v1.0
该部分描述了第一版YARN的实现方案。
需求
完成上一节提到的几个最紧迫的需求，其中可扩展性的目标是适用于约6K节点数量的集群。

* Resource Manager
  * 资源模型
    * 在YARN 1.0中，调度器仅考虑了内存资源。 每个节点由多个固定内存大小（512MB或者1GB）的容器组成。AM可以申请该内存整数倍大小的容器。
    YARN最终会提供一个更加通用的资源模型，但在Yarn V1中，仅提供了一个相当直接的模型：
    “资源模型完全是基于内存的，且每个节点由若干个离散的内存块（chunk of memory）组成”。
  * 与Hadoop MapReduce不同，MRv2并没有人为的将集群资源分成map slot和reduce slot。MRv2中的每个内存块是可互换的，这就提高了集群利用率—当前Hadoop MapReduce的一个最大问题是由于缺乏资源互换，作业会在reduce slot上存在瓶颈。（“互换”的意思是资源是对等的，所有资源形成一个资源池，任务可以从资源池中申请任意的资源，这就提高了资源利用率）

* 对上一端进一步解释：
   * 在当前Hadoop MapReduce中，集群资源会被切分成map slot和reduce slot。在每个TaskTracker上，管理员可配置若干个map slot和reduce slot，slot可看做是令牌，map task拿到一个map slot后才可以运行（对于reduce task类似）。而管理员一般只根据CPU个数配置slot个数时，如果CPU个数为12，则可配置8个map slot，4个reduce slot。这会导致两个问题：（1）实际的计算资源不仅仅是CPU，还有内存，磁盘和网络等，这些均需要考虑，只考虑某一种资源势必会造成机器拥塞，这在共享集群环境下表现尤为显著；（2）MapReduce计算流程是两阶段的，而这两个阶段存在依赖性：reduce task不会进入sort和reduce阶段，直到全部map task计算完成，而实际计算时，map task完成一定的比例，便会启动reduce task，此时启动的reduce task全部处于shuffle阶段，经常会走走停停，导致该map slot资源利用率非常低。
  * 在Yarn中，任何一个应用可申请任何内存大小合理（合理是指内存大小必须是memory chunck的整数倍）的容器，也可以申请各种类型的容器。
资源协商
  * 每个AM使用资源描述来申请一系列容器，其中可能包括一些特殊需求的机器。它也可以申请同一个机器上的多个容器。所有的资源请求是受应用程序容量，队列容量等限制的。
  * AM负责计算应用程序所需的资源量，比如MapReduce的input-splits，并把他们转化成调度器可以理解的协议。当前调度器可理解的协议是<priority, (hos,rack,*), memory, #containers>。
以MapReduce为例，MapReduce AM分析input-splis，并将之转化成以host为key的转置表发送给RM。下图为一个典型的AM资源请求：

调度器会尽量匹配该表中的资源；如果某个特定机器上的资源是不可用的，调度器会提供同一个机架或者不同机架上的等量资源代替之。有些情况下，由于整个集群非常忙碌，AM获取的资源可能不是最合适的，此时它可以拒绝这些资源并请求重新分配。

* 调度
  * 调度器收集所有正在运行的应用程序的资源请求并构建一个全局规划进行资源分配。调度器会根据应用程序相关的约束（如合适的机器）和全局约束（如队列资源总量，用户可提交作业总数等）分配资源。
  * 调度器使用与容量调度类似的概念，采用容量保证作为基本的策略在多个应用程序间分配资源。
  * 调度器的调度策略如下：
    * 选择系统中“服务最低”的队列（如何定义服务最低？可以是资源利用量最低的队列，即：已使用的资源与总共可用资源比值最小）
从该队列中选择优先级最高的作业
尽量满足该作业的资源请求
调度器API
Yarn 调度器与AM之间仅有一个API：
Response allocate (List<ResourceRequest> ask, List<Container> release)
AM使用一个ResourceRequest列表请求特定资源，并同时可要求释放一些调度器已经分配的容器。
Response包含三方面内容：新分配的容器列表，自从上次AM与RM交互以来已经计算完成的容器的状态（包含该容器中运行task的详细信息），当前集群中剩余资源量。 AM收集完成容器的信息并对失败的任务作出反应。资源剩余量可用于AM调整接下来的资源请求，如MapReduce AM可使用该信息以合理调度maps和reduces从而防止产生死锁。（何以“死锁”？在MapReduce框架中，如果将所有资源分配给了map task，则可能会造成reduce  task饥饿，需要合理调整map资源和reduce 资源的比例）
资源监控
调度器周期性地收到NM所在节点的资源变化信息，同时，调度器会将已使用完的容器分配重新分给合适的AM。
AM的生命周期
ASM负责管理系统中所有应用程序的AM，正如上一节所述，ASM负责启动AM，监控AM的运行状态，在AM失败时对其进行重启等。
为了完成该功能，ASM主要有以下几个组件：
（1） SchedulerNegotiator：与调度器协商容器资源，并返回给AM
（2）AMContainerManager：告知NM，启动或者停止某个AM的容器
（3）  AMMonitor：查看AM是否活着，并在必要的时候重启AM
【NodeManager】
每个节点上装有一个NM，主要的职责有：
（1）为应用程序启动容器，同时确保申请的容器使用的资源不会超过节点上的总资源。
（2）为task构建容器环境，包括二进制可执行文件，jars等
（3）为所在的节点提供了一个管理本地存储资源的简单服务，应用程序可以继续使用本地存储资源即使他没有从RM那申请。比如：MapReduce可以使用该服务程序存储map task的中间输出结果。
【ApplicationMaster】
每个应用程序均会有一个AM，主要职责有：
（1）  与调度器协商资源
（2）  与NM合作，在合适的容器中运行对应的task，并监控这些task执行
（3） 如果container出现故障，AM会重新向调度器申请资源
（4）  计算应用程序所需的资源量，并转化成调度器可识别的格式（协议）
（5）  AM出现故障后，ASM会重启它，而由AM自己从之前保存的应用程序执行状态中恢复应用程序。
注：在MapReduce中，由于AM会定时的保存job的运行时状态，因此，当AM重启时可以恢复对应的job，按照粒度有三种策略：
<1>整个作业重新计算
<2> 保存已经完成的map task和reduce task，只重新计算未完成的task
<3> 保存task的进度，从task断点处开始计算，如：某个task完成了20%，则AM重启后，让该task从20%处开始计算。
这个本人之前也在现有的Hadoop版本山调研过，第三种方案基本不可能实现，因为作业执行时，有时会保存几个全局变量，如全局counter，自定义的变量，这些东西由用用户的程序控制，框架很难获取到他们的值并物化到磁盘上以便恢复。当前MapReduce AM按照第二种方案实现了，但是文档说将来会考虑实现第三种方案，个人觉得可能性不大。
