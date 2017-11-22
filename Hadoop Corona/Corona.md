# Hadoop Corona
> Hadoop Corona是facebook开源的下一代MapReduce框架。其基本设计动机和Apache的YARN一致，在此不再重复，读者可参考我的这篇文章“下一代Apache Hadoop MapReduce框架的架构”。 

* 基本组件介绍
  1. Cluster Manager 类似于YARN中的Resource Manager，负责资源分配和调度。Cluster Manager掌握着各个节点的资源使用情况，并将资源分配给各个作业（默认调度器为Fair Scheduler）。同YARN中的Resource Manager一样，Resource Manager是一个高度抽象的资源统一分配与调度框架，它不仅可以为MapReduce，也可以为其他计算框架分配资源。
  2. Corona Job Tracker 类似于YARN中的Application Master，用于作业的监控和容错，它可以运行在两个模式下：1） 作为JobClient，用于提交作业和方便用户跟踪作业运行状态 2）   作为一个Task运行在某个TaskTracker上。与MRv1中的Job Tracker不同，每个Corona Job Tracker只负责监控一个作业。
  3. Corona Task Tracker 类似于YARN中的Node Manager，它的实现重用了MRv1中Task Tracker的很多代码，它通过心跳将节点资源使用情况汇报给Cluster Manager，同时会与Corona Job Tracker通信，以获取新任务和汇报任务运行状态。
  4. roxy Job Tracker 用于离线展示一个作业的历史运行信息，包括Counter、metrics、各个任务运行信息等。

* Hadoop Corona工作流程
  * 当用户提交一个作业后，Hadoop Corona分两个阶段运行该作业，首先由RemoteJTProxy向Cluster Manager申请资源，以启动一个Corona Job Tracker，然后Corona Job Tracker向Cluster Manager申请资源，运行该作业的任务。

* Corona Job Tracker介绍
  * Hadoop Corona的最大创新的之一是CoronaJobTracker的设计方法。CoronaJobTracker存在三种工作模式，分别是：
  1. InProgress 此时，CoronaJobTracker是一个客户端，用户可用于提交作业或者跟踪作业运行状态。
  2. Forwarding 此时，CoronaJobTracker是一个信息转发者，它只是将作业的信息转发给另外一个CoronaJobTracker。
  3.Standlone 最终的CoronaJobTracker，此时，CoronaJobTracker才执行类似于MRv1中的功能（但一个CoronaJobTracker只会管理一个作业），即完成资源申请和作业监控。

* 当用户在JobClient端提交作业时 如果设置了使用Hadoop Corona（如果没有设置，则提交到MRv1的JobTracker上）
  * 则会创建一个CoronaJobTracker，该CoronaJobTracker此时运行在InProgress模式下。
  * 之后，该CoronaJobTracker会判断用户是否设置了强制使用Standlone模式（可通过mapred.coronajobtracker.forceremote设置，默认是flase）或者该作业的Map Task数目是否超过1000个（可通过参数mapred.coronajobtracker.remote.threshold配置）
  * 如果是，则该CoronaJobTracker便会转为Forwarding模式，进而将作业提交到一个RemoteJTProxy上，具体后续过程见下一节分析；如果不是，则说明该作业是小作业，直接在该CoronaJobTracker上运行作业即可，这就降低了小作业延时，但可能会出现负载不均衡得问题（比如多个用户同时在一个JobClient上提交大量小作业）。

 
* 启动Corona Job Tracker过程分析
  * 为了与MRv1兼容，Hadoop Corona仍由JobClient提交作业，但里面的代码已经经过修改：
  * 如果采用Corona，则会创建一个CoronaJobTracker对象提交作业（CoronaJobTracker有可充当多个角色，其中一个角色是JobClient，即客户端），之后过程如下（注意，本节介绍的是CoronaJobTracker远程启动方式
  * 对于小作业，CoronaJobTracker直接在客户端启动，因此，这一节介绍的步骤会直接跳过）：
  1. JobClient与RemoteJTProxy通信，要求并等待其启动CoronaJobTracker。
  2. RemoteJTProxy收到请求后，向Cluster Manager申请资源。
  3. Cluster Manager中的Fair Scheduler调度器为其分配合适的资源，并push给RemoteJTProxy。
  4. RemoteJTProxy根据分配到的资源（在哪个TaskTracker上，可使用多少资源），与对应的CoronaTaskTracker通信，要求它启动CoronaJobTracker。
  5. CoronaTaskTracker成功启动CoronaJobTracker后，告诉RemoteJTProxy，然后就再由RemoteJTProxy告诉JobClient。
  6. CoronaJobTracker（即JobClient）得知CoronaJobTracker启动成功后，向RemoteJTProxy提交作业
  然后由RemoteJTProxy进一步将作业提交到刚刚启动的CoronaJobTracker上。至此，一个作业提交成功。

* 资源申请与任务启动过程分析
  * 首先需要注意的是，各个CoronaTaskTracker会通过心跳周期性的将本节点上资源使用情况汇报给Cluster Manager
  * ，Cluster Manager掌握着各个节点的资源使用情况。
  * ronaJobTracker负责为某个作业申请资源，并与CoronaTaskTracker通信，运行它的Task，总之

* CoronaJobTracker功能如下：
  1. 向Cluster Manager申请资源
  2.     释放资源与资源重用。 Cluster Manager中的调度器支持资源抢占，可随时命令某个CoronaJobTracker释放资源，另外，CoronaJobTracker可根据需要，自行决定资源是不是重用，即某个Task运行完后，可不必归还给Cluster Manager，可再给其他Task使用。
  3.     与CoronaTaskTracker通信，以启动任务。
  4.     任务推测执行，具体可参考“Hadoop中Speculative Task调度策略”。
  5.     任务容错。当任务执行失败后，向Cluster Manager重新申请资源，以重新运行该任务。
资源申请与任务启动过程如下图所示，已经非常清楚，在此不赘述。

 
*   Hadoop Corona实现
  * Hadoop Corona位于目录hadoop-20-yahoo\src\contrib\corona下，读者可直接从https://github.com/facebook/hadoop-20/tree/master/src/contrib/corona上下载。Hadoop Corona代码由两部分组成：
  1. org.apache.hadoop.corona        Hadoop Corona核心实现，用于资源分配和调度，与具体的分布式计算框架（如Storm、Spark等）无关。
  2.org.apache.hadoop.mapred      改造后的MRv1，使之能够运行在Hadoop Corona上。用户可仿照该实现，将其他计算框架移植到Hadoop Corona中。

* Hadoop Corona中CoronaJobTracker与ClusterManager的通信用到了thrift，它们既是thrift Client，也是Thrift Server
  1.CoronaJobTracker需与ClusterManager通信，以申请资源，此时ClusterManager是thrfit Server，具体见ClusterManager.thrift中的service ClusterManagerService定义。
  2.当ClusterManager中的调度器为CoronaJobTracker分配到资源后，采用push机制直接推送给CoronaJobTracker，此时CoronaJobTracker是thrift Server，具体见ClusterManager.thrift中的service SessionDriverService定义。
CoronaJobTracker与CoronaTaskTracker之间的通信机制与MRv1基本一致，在此不赘述。
  3. oop Corona重新实现了JobInProgress（CoronaJobInProgress）和TaskInProgress（CoronaTaskInProgress），但重用了MRv1的Task、MapTask和ReduceTask类。
