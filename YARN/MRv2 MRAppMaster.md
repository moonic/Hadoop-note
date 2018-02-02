# MRv2 MRAppMaster

1. 什么是MRAppMaster？
  * MRv1中，JobTracker存在诸多问题，包括存在单点故障，扩展受限等，为了解决这些问题，Apache对MRv1进行了改进，提出了YARN，YARN将JobTracker中的作业控制和资源管理两个功能分开，分别由两个不同的进程处理，进而解决了原有JobTracker存在的问题。经过架构调整之后 
  * YARN已经完全不同于MRv1，它已经变成了一个资源管理平台，或者说应用程序管理框架。运行于YARN之上的计算框架不只限于MapReduce一种，也可以是其他流行计算框架，比如流式计算、迭代式计算等类型的计算框架。
  * 为了将一个计算框架运行于YARN之上，用户需要开发一个组件—ApplicationMaster。作为一个开始，YARN首先支持的计算框架是MapReduce，YARN为用户实现好了MapReduce的ApplicationMaster，也就是本文要介绍了MRAppMaster。
  
2. 相比于JobTracker，MRAppMaster有什么不同？
  * 既然MRAppMaster是由JobTracker衍化而来的，那么是否将JobTracker的代码稍加修改，就变成了MRAppMaster呢，答案是否定的。事实上，YARN仅重用了MRv1中的少许代码，基本可看做重写了MRAppMaster。
  * YARN采用了新的软件设计思想，包括对象服务化、事件驱动的异步编程模型的。作为YARN的一部分，MRAppMaster的实现也采用了这些设计思想。

   
* MRAppMaster的实现细节。
  * 在正式介绍MRAppMaster之前，我们先回顾一下MRv1的实现。我们都知道，MRv1主要由两种服务组成，即：JobTracker和TaskTracker，而在YARN中，TaskTracker已经由NodeManager代替，因此，我们在此重点分析JobTracker。JobTracker包含资源管理和作业控制两个功能，在YARN中，作业管理由ResourceManager实现，因此，只剩下作业控制这一个功能（由MRAppMaster实现）。MRv1中每个作业由一个JobInProgress控制，每个任务由一个TaskInProgress控制，由于每个任务可能有多个运行实例，因此，TaskInProgress实际管理了多个运行实例Task Attempt，对于每个运行实例，可能运行了一个MapTask或者ReduceTask，另外，每个Map Task或者Reduce Task会通过RPC协议将状态汇报给TaskTracker，再由TaskTracker进一步汇报给JobTracker。
  * 在MRAppMaster中，它只负责管理一个作业，包括该作业的资源申请、作业运行过程监控和作业容错等。
  * MRAppMaster使用服务模型和事件驱动的异步编程模型对JobInProgress和TaskInProgress进行了重写（分别对应JobImpl和TaskImpl），并让Map     * Task和Reduce Task（Map Task和Reduce Task重用了MRv1中的代码）直接通过RPC将信息汇报给MRAppMaster。此外，为了能够运行于YARN之上，MRAppMaster还要与ResourceManager和NodeManager两个新的服务通信（用到两个新的RPC协议），以申请资源和启动任务，这些都使得MRAppMaster完全不同于JobTracker。
  * MRAppMaster是MapReduce的ApplicationMaster实现，它使得MapReduce计算框架可以运行于YARN之上。在YARN中，MRAppMaster负责管理MapReduce作业的生命周期，包括创建MapReduce作业，向ResourceManager申请资源，与NodeManage通信要求其启动Container，监控作业的运行状态，当任务失败时重新启动任务等。

* YARN使用了基于事件驱动的异步编程模型
  * 它通过事件将各个组件联系起来，并由一个中央事件调度器统一将各种事件分配给对应的事件处理器。
  * 在YARN中，每种组件是一种事件处理器，当MRAppMaster启动时，它们会以服务的形式注册到MRAppMaster的中央事件调度器上，并告诉调度器它们处理的事件类型，这样，当出现某一种事件时，MRAppMaster会查询<事件，事件处理器>表，并将该事件分配给对应的事件处理器。
  * 接下来，我们分别介绍MRAppMaster各种组件/服务的功能。
   
* ContainerAllocator
  * 与ResourceManager通信，为作业申请资源。作业的每个任务资源需求可描述为四元组<Priority, hostname，capability，containers>，分别表示作业优先级、期望资源所在的host，资源量（当前仅支持内存），
  * container数目。ContainerAllocator周期性通过RPC与ResourceManager通信，而ResourceManager会为之返回已经分配的container列表，完成的container列表等信息。

* ClientService
  * ClientService是一个接口，由MRClientService实现。MRClientService实现了MRClientProtocol协议，客户端可通过该协议获取作业的执行状态（而不必通过ResourceManager）和制作业（比如杀死作业等）。
* Job
  * 表示一个MapReduce作业，与MRv1的JobInProgress功能一样，负责监控作业的运行状态。它维护了一个作业状态机，以实现异步控制各种作业操作。
* Task
  * 表示一个MapReduce作业中的某个任务，与MRv1中的TaskInProgress功能类似，负责监控一个任务的运行状态。它为花了一个任务状态机，以实现异步控制各种任务操作。
* TaskAttempt
  * 表示一个任务运行实例，同MRv1中的概念一样。 
* TaskCleaner
  * 清理失败任务或者被杀死任务产生的结果，它维护了一个线程池，异步删除这些任务产生的结果。
* Speculator
  * 完成推测执行功能。当一个任务运行速度明显慢于其他任务时，Speculator会为该任务启动一个备份任务，让其同慢任务一同处理同一份数据，谁先计算完成则将谁的结果作为最终结果，另一个任务将被杀掉。该机制可有效防止“拖后腿”任务拖慢整个作业的执行进度。
* ContainerLauncher
  * 与NodeManager通信，要求其启动一个Container。当ResourceManager为作业分配资源后，ContainerLauncher会将资源信息封装成container，包括任务运行所需资源、任务运行命令、任务运行环境、任务依赖的外部文件等，然后与对应的节点通信，要求其启动container。
* TaskAttemptListener
  * 管理各个任务的心跳信息，如果一个任务一段时间内未汇报心跳，则认为它死掉了，会将其从系统中移除。同MRv1中的TaskTracker类似，它实现了TaskUmbilicalProtocol协议，任务会通过该协议汇报心跳，并询问是否能够提交最终结果。
* JobHistoryEventHandler
    * 对作业的各个事件记录日志，比如作业创建、作业开始运行、一个任务开始运行等，这些日志会被写到HDFS的某个目录下，这对于作业恢复非常有用。当MRAppMaster出现故障时，YARN会将其重新调度到另外一个节点上，为了避免重新计算，MRAppMaster首先会从HDFS上读取上次运行产生的运行日志，以恢复已经运行完成的任务，进而能够只运行尚未运行完成的任务。
    
# MRv2 MRAppMaster深入剖析—整体架构
MRAppMaster是MapReduce的ApplicationMaster实现，它使得MapReduce计算框架可以运行于YARN之上。在YARN中，MRAppMaster负责管理MapReduce作业的生命周期，包括创建MapReduce作业，向ResourceManager申请资源，与NodeManage通信要求其启动Container，监控作业的运行状态，当任务失败时重新启动任务等。

YARN使用了基于事件驱动的异步编程模型，它通过事件将各个组件联系起来，并由一个中央事件调度器统一将各种事件分配给对应的事件处理器。在YARN中，每种组件是一种事件处理器，当MRAppMaster启动时，它们会以服务的形式注册到MRAppMaster的中央事件调度器上，并告诉调度器它们处理的事件类型，这样，当出现某一种事件时，MRAppMaster会查询<事件，事件处理器>表，并将该事件分配给对应的事件处理器。
接下来，我们分别介绍MRAppMaster各种组件/服务的功能。
ContainerAllocator
与ResourceManager通信，为作业申请资源。作业的每个任务资源需求可描述为四元组<Priority, hostname，capability，containers>，分别表示作业优先级、期望资源所在的host，资源量（当前仅支持内存），container数目。ContainerAllocator周期性通过RPC与ResourceManager通信，而ResourceManager会为之返回已经分配的container列表，完成的container列表等信息。
ClientService
ClientService是一个接口，由MRClientService实现。MRClientService实现了MRClientProtocol协议，客户端可通过该协议获取作业的执行状态（而不必通过ResourceManager）和制作业（比如杀死作业等）。
Job
表示一个MapReduce作业，与MRv1的JobInProgress功能一样，负责监控作业的运行状态。它维护了一个作业状态机，以实现异步控制各种作业操作。
Task
表示一个MapReduce作业中的某个任务，与MRv1中的TaskInProgress功能类似，负责监控一个任务的运行状态。它为花了一个任务状态机，以实现异步控制各种任务操作。
TaskAttempt
表示一个任务运行实例，同MRv1中的概念一样。
TaskCleaner
清理失败任务或者被杀死任务产生的结果，它维护了一个线程池，异步删除这些任务产生的结果。
Speculator
完成推测执行功能。当一个任务运行速度明显慢于其他任务时，Speculator会为该任务启动一个备份任务，让其同慢任务一同处理同一份数据，谁先计算完成则将谁的结果作为最终结果，另一个任务将被杀掉。该机制可有效防止“拖后腿”任务拖慢整个作业的执行进度。
ContainerLauncher
与NodeManager通信，要求其启动一个Container。当ResourceManager为作业分配资源后，ContainerLauncher会将资源信息封装成container，包括任务运行所需资源、任务运行命令、任务运行环境、任务依赖的外部文件等，然后与对应的节点通信，要求其启动container。
TaskAttemptListener
管理各个任务的心跳信息，如果一个任务一段时间内未汇报心跳，则认为它死掉了，会将其从系统中移除。同MRv1中的TaskTracker类似，它实现了TaskUmbilicalProtocol协议，任务会通过该协议汇报心跳，并询问是否能够提交最终结果。
JobHistoryEventHandler
对作业的各个事件记录日志，比如作业创建、作业开始运行、一个任务开始运行等，这些日志会被写到HDFS的某个目录下，这对于作业恢复非常有用。当MRAppMaster出现故障时，YARN会将其重新调度到另外一个节点上，为了避免重新计算，MRAppMaster首先会从HDFS上读取上次运行产生的运行日志，以恢复已经运行完成的任务，进而能够只运行尚未运行完成的任务。
Recovery
当一个MRAppMaster故障后，它将被调度到另外一个节点上重新运行，为了避免重新计算，MRAppMaster首先会从HDFS上读取上次运行产生的运行日志，并恢复作业运行状态。


## MRv2 MRAppMaster深入剖析—作业生命周期
在正式讲解作业生命周期之前，先要了解MRAppMaster中作业表示方式，每个作业由若干干Map Task和Reduce Task组成，每个Task进一步由若干个TaskAttempt组成，Job、Task和TaskAttempt的生命周期均由一个状态机表示，具体可参考https://issues.apache.org/jira/browse/MAPREDUCE-279（附件中的图yarn-state-machine.job.png，yarn-state-machine.task.png和yarn-state-machine.task-attempt.png）

作业的创建入口在MRAppMaster类中，如下所示：
public class MRAppMaster extends CompositeService {
 
  public void start() {
 
    ...
 
    job = createJob(getConfig());//创建Job
 
    JobEvent initJobEvent = new JobEvent(job.getID(), JobEventType.JOB_INIT);
 
    jobEventDispatcher.handle(initJobEvent);//发送JOB_INI,创建MapTask,ReduceTask
 
    startJobs();//启动作业，这是后续一切动作的触发之源
 
    ...
 
  }
 
protected Job createJob(Configuration conf) {
 
  Job newJob =
 
    new JobImpl(jobId, appAttemptID, conf, dispatcher.getEventHandler(),
 
      taskAttemptListener, jobTokenSecretManager, fsTokens, clock,
 
      completedTasksFromPreviousRun, metrics, committer, newApiCommitter,
 
      currentUser.getUserName(), appSubmitTime, amInfos, context);
 
  ((RunningAppContext) context).jobs.put(newJob.getID(), newJob);
 
  dispatcher.register(JobFinishEvent.Type.class,
 
    createJobFinishEventHandler());
 
  return newJob;
 
  }
 
}
（1）作业/任务初始化
JobImpl会接收到.JOB_INIT事件，然后触发作业状态从NEW变为INITED，并触发函数InitTransition()，该函数会创建MapTask和
ReduceTask，代码如下：

public static class InitTransition
 
  implements MultipleArcTransition&lt;JobImpl, JobEvent, JobState&gt; {
 
  ...
 
  createMapTasks(job, inputLength, taskSplitMetaInfo);
 
  createReduceTasks(job);
 
  ...
 
}
其中，createMapTasks函数实现如下：

private void createMapTasks(JobImpl job, long inputLength,
 
  TaskSplitMetaInfo[] splits) {
 
  for (int i=0; i &amp;lt; job.numMapTasks; ++i) {
 
    TaskImpl task =
 
      new MapTaskImpl(job.jobId, i,
 
      job.eventHandler,
 
      job.remoteJobConfFile,
 
      job.conf, splits[i],
 
      job.taskAttemptListener,
 
job.committer, job.jobToken, job.fsTokens,
 
job.clock, job.completedTasksFromPreviousRun,
 
job.applicationAttemptId.getAttemptId(),
 
job.metrics, job.appContext);
 
job.addTask(task);
 
}
 
}
（2）作业启动
public class MRAppMaster extends CompositeService {
 
protected void startJobs() {
 
JobEvent startJobEvent = new JobEvent(job.getID(), JobEventType.JOB_START);
 
dispatcher.getEventHandler().handle(startJobEvent);
 
}
 
}
JobImpl会接收到.JOB_START事件，会触发作业状态从INITED变为RUNNING，并触发函数StartTransition()，进而触发Map Task和Reduce Task开始调度:
public static class StartTransition
 
implements SingleArcTransition&amp;lt;JobImpl, JobEvent&amp;gt; {
 
public void transition(JobImpl job, JobEvent event) {
 
job.scheduleTasks(job.mapTasks);
 
job.scheduleTasks(job.reduceTasks);
 
}
 
}
这之后，所有Map Task和Reduce Task各自负责各自的状态变化，ContainerAllocator模块会首先为Map Task申请资源，然后是Reduce Task，一旦一个Task获取到了资源，则会创建一个运行实例TaskAttempt，如果该实例运行成功，则Task运行成功，否则，Task还会启动下一个运行实例TaskAttempt，直到一个TaskAttempt运行成功或者达到尝试次数上限。当所有Task运行成功后，Job运行成功。一个运行成功的任务所经历的状态变化如下（不包含失败或者被杀死情况）：

* 本文分析只是起到抛砖引入的作用，读者如果感兴趣，可以自行更深入的研究以下内容：
（1）Job、Task和TaskAttempt状态机设计（分别在JobImpl、TaskImpl和TaskAttemptImpl中）
（2）在以下几种场景下，以上三个状态机的涉及到的变化：
1）  kill job
2）  kill task attempt
3）  fail task attempt
4）  container failed
5）  lose node
 
