# ClusterManager功能

* Corona中 ClusterManager负责整个集群的资源管理包括
  1. 维护各个节点的资源使用情况
  2. 将各个节点中的资源按照一定的约束分配（比如每个pool使用的资源不能超过其上线，任务分配时应考虑负载均衡等）给各个应用程序 ClusterManager是一个纯粹的资源管理器，它不再（向MRv1中的JobTracker那样）负责作业监控相关工作，如监控各个任务的运行状态，任务失败时重新启动等CoronaJobTracker完成 
 

* ClusterManager实现方法 
  * ClusterManager实际上由两部分组成：节点资源管理器和资源分配模型 节点资源管理器维护各个节点的资源变化，而资源分配模型由（经修改的）MRv1中的Fair Scheduler实现 
  * ClusterManager深度集成了Fair Scheduler，也就是说，调度器模块不再可插拔，它跟ClusterManager紧紧耦合在一起
ClusterManager需要与CoronaJobTracker和CoronaTaskTracker通信 通过thrift RPC实现的，具体涉及到的RPC协议，为了提高效率ClusterManager采用了非阻塞异步编程模型

*  ClusterManager架构
  * ClusterManager架构图如下所示
   
1. NodeManager
  * 负责管理各个节点上的资源使用情况，当前主要考虑内存、磁盘和CPU三种资源
  * CoronaTaskTracker通过thrift RPC汇报资源使用信息后，ClusterManager将交由NodeManager管理

2. SchedulerForType
  * 资源分配线程，每种资源（Corona中有三类资源：
    * MAP、REDUCE和JOBTRACKER，分别用于启动Map Task、Reduce Task和CoronaJobTracker）一个
    * 当出现空闲资源时，它从当前系统中选择出最合适的作业，并将资源分配它 
  * Corona已将Fair Scheduler深度集成到了ClusterManager中，相比于MRv1中的Fair Scheduler，它增加了group的概念，即不再只有平级pool的概念，而是引入了更高一层的pool组织方式—group，管理员可将整个集群资源划分成若干个group，并可进一步将一个group划分成若干个pool，一个配置实例corona.xml如下：

```XML
<?xml version=”1.0″?>
<configuration>  
<defaultSchedulingMode>FAIR</defaultSchedulingMode>
<nodeLocalityWaitMAP>0</nodeLocalityWaitMAP>
<rackLocalityWaitMAP>5000</rackLocalityWaitMAP>
<preemptedTaskMaxRunningTime>60000</preemptedTaskMaxRunningTime>
<shareStarvingRatio>0.9</shareStarvingRatio>
<starvingTimeForShare>60000</starvingTimeForShare>
<starvingTimeForMinimum>30000</starvingTimeForMinimum>
<grantsPerIteration>5000</grantsPerIteration>
<group name=”group_a”>
<minMAP>200</minMAP>
<minREDUCE>100</minREDUCE>
<maxMAP>200</maxMAP>
<maxREDUCE>200</maxREDUCE>
<pool name=”pool_sla”>
<minMAP>100</minMAP>
<minREDUCE>100</minREDUCE>
<maxMAP>200</maxMAP>
<maxREDUCE>200</maxREDUCE>
<weight>2.0</weight>
<schedulingMode>FIFO</schedulingMode>
</pool>
<pool name=”pool_nonsla”>
</pool>
</group>
<group name =”group_b”>
<maxMAP>200</maxMAP>
<maxREDUCE>200</maxREDUCE>
<weight>3.0</weight>
</group>
</configuration>

```

1. grantsPerIteration 该参数表示一次性分配的task数目上限，默认是5000
  * 如果你的集群足够小，那么，Corona可以一次性将集群中所有任务分配到各个节点上。MRv1中的资源分配是以TaskTracker为单位进行的，只有TaskTracker汇报心跳请求新任务时，调度器才会为该节点分配任务，而Corona则是采用了异步模型批量分配任务
  * 它将汇报心跳和分配任务分开，分别由不同的协议实现，当分配完一批任务后，它会通知一些线程，由这些线程进一步通知各个CoronaJobTracker，然后再由CoronaJobTracker与各个CoronaTaskTracker交互，进而启动任务。
  
2. schedulingMode 
  * 即pool内部采用的调度模式，Corona提供6种调度模式，分别是FAIR（Fair Scheduling）
  * FIFO（考虑优先级和达到时间）、DEADLINE（基于作业deadline，用户提交作业时可通过参数“mapred.job.deadline”为作业设置一个时间限制，调度器会优先调度deadline最小的作业）
  * FAIR_PREEMPT（-1*FAIR）、FIFO_PREEMPT（-1* FIFO）和DEADLINE_PREEMPT（-1* DEADLINE）

3. minMAP/minREDUCE/maxMAP/maxREDUCE group或者pool中至少保证的资源数目
  * （需要注意，由于group包含pool，因此，每个group的参数应不小于其内部各个pool对应参数之和）和最多可用的资源数目（注意，是数目，不是百分比！
  * 前面提到Corona是基于真实资源量进行调度的，在此应该配置内存、CPU等这种资源的使用限制才说的过去，为什么只配置一个数目呢？个人觉得，这是Corona与MRv1杂交的结果，Corona是在MRv1基础上实现的，它的资源分配模型掺有MRv1的特点，它并不能说是一个纯的，像YARN那样，基于真实资源量的调度模型。阅读其代码可发现，在pool或者group内部，一旦分配了一个新任务，则对应的资源使用量会加1，也就是说，这四个参数实际上是配置的Task数目限制！

4. SessionNotifierThread
  * 当SchedulerForType为某个作业分配资源后，并不会立即通知对应的CoronaJobTracker，而是随机交给线程池中的一个SessionNotifierThread线程，并由它通过thrift RPC通知对应的CoronaJobTracker。
