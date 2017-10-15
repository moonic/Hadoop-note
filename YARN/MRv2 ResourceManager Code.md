# MRv2 ResourceManager Code

##     涉及到的状态机
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

3.    ResourceManager中事件处理流
（1）Client通过RMClientProtocol协议向ResourceManager提交application。
<1> 代码所在目录：
hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient/src/main/java
<2> jar包：org.apache.hadoop.mapred
<3>关键类与关键函数：YARNRunner.submitJob()
（2） ResourceManager端的ClientRMService服务接收到application，使得RMAppManager调用handle函数处理RMAppManagerSubmitEvent事件，处理逻辑如下：为该application创建RMAppImpl对象，保存其信息，接着产生RMAppEventType.START事件.
<1> 代码所在目录：
hadoop-mapreduce-project\hadoop-yarn\hadoop-yarn-server\hadoop-yarn-server-resourcemanager\src\main\java\org\apache\hadoop\yarn\server\resourcemanager
<2> jar包：org.apache.hadoop.yarn.server.resourcemanager
<3>关键类与关键函数：ClientRMService.submitApplication()，RMAppManager.submitApplication()
(3) RMAppEventType.START事件传递给AsyncDispatcher，AsyncDispatcher查看相关数据结构，确定该事件由ApplicationEventDispatcher处理，该dispatcher将RMApp从RMAppState.NEW状态变为RMAppState.SUBMITTED状态，同时创建RMAppAttemptImpl对象，并触发RMAppAttemptEventType.START事件。
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp
<2> 关键类与关键函数：RMAppImpl.StartAppAttemptTransition
（4）RMAppAttemptEventType.START事件传递给AsyncDispatcher，AsyncDispatcher查看相关数据结构，确定该事件由ApplicationAttemptEventDispatcher处理，该dispatcher将RMAppAttempt从RMAppAttemptState.NEW变为RMAppAttemptState.SUBMITTED状态。
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
<2> 关键类与关键函数：RMAppAttemptImpl.StateMachineFactory
（5） RMAppAttempt向ApplicationMasterService注册，它将之保存在responseMap中。
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
<2> 关键类与关键函数：RMAppAttemptImpl.AttemptStartedTransition
（6）RMAppAttempt触发AppAddedSchedulerEvent
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
<2> 关键类与关键函数：RMAppAttemptImpl.AttemptStartedTransition
（7）ResourceScheduler（如FifoScheduler）捕获AppAddedSchedulerEvent事件，并创建SchedulerApp对象，使RMAppAttempt对像从RMAppAttemptState.SUBMITTED转化为RMAppAttemptState.SCHEDULED状态，同时产生RMAppAttemptEventType.APP_ACCEPTED事件。
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.scheduler.fifo
<2> 关键类与关键函数：FifoScheduler.addApplication
（8）RMAppAttemptEventType.APP_ACCEPTED事件由ApplicationAttemptEventDispatcher捕获，并将RMAppAttempt从RMAppAttemptState.SUBMITTED转化为 RMAppAttemptState.SCHEDULED状态，并产生RMAppEventType.APP_ACCEPTED事件。
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
<2> 关键类：RMAppAttemptImpl.ScheduleTransition
（9）调用ResourceScheduler的allocate函数，为ApplicationMaster申请一个container。
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt
<2> 关键类：RMAppAttemptImpl.ScheduleTransition
（10）此刻，某个node（称为“AM-NODE”）正好通过heartbeat向ResourceManager.ResourceTrackerService汇报自己所在节点的资源使用情况。
(11) ResourceTrackerService.nodeHeartbeat收到heartbeat信息后，触发RMNodeStatusEvent(RMNodeEventType.STATUS_UPDATE)事件。
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager
<2> 关键类：ResourceTrackerService.nodeHeartbeat
(12) RMNodeStatusEvent被ResourceScheduler捕获，调用assginContainers为该application分配一个container（用对象RMContainer表示），分配之后，会触发一个RMContainerEventType.START事件。
（13） RMContainerEventType.START事件被NodeEventDispatcher捕获，使得RMContainer对象从RMContainerState.NEW状态转变为RMContainerState.ALLOCATED状态，同时触发RMAppAttemptContainerAllocatedEvent（RMAppAttemptEventType.CONTAINER_ALLOCATED）事件.
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.rmcontainer
<2> 关键类：RMContainerImpl.ContainerStartedTransition
(14) RMAppAttemptContainerAllocatedEvent事件被 ApplicationAttemptEventDispatcher捕获，并将RMAppAttempt对象从RMAppAttemptState.SCHEDULED状态转变为RMAppAttemptState.ALLOCATED状态，同时调用Scheduler的allocate函数申请一个container，并触发AMLauncherEventType.LAUNCH事件
（15）AMLauncherEventType.LAUNCH事件被ApplicationMasterLauncher捕获，主要处理逻辑如下：创建一个AMLauncher对象，并添加到队列masterEvents中，等待处理；一旦被处理，会调用AMLauncher.launch()函数，该函数会调用ContainerManager.startContainer()函数创建container，同时触发RMAppAttemptEventType.LAUNCHED事件。
<1> jar包：org.apache.hadoop.yarn.server.resourcemanager.amlauncher
<2> 关键类：ApplicationMasterLauncher
（16） RMAppAttemptEventType.LAUNCHED事件被ApplicationAttemptEventDispatcher捕获，并将RMAppAttempt对象从RMAppAttemptState.ALLOCATED状态转变为RMAppAttemptState.LAUNCHED状态。
（17）将该application的RMAppAttempt对象注册到AMLivenessMonitor中，以便实时监控该application的存活状态。
（18）AM-NODE节点为该Application创建ApplicationMaster，接下来ApplicationMaster会与ResourceManager协商资源并通知NodeManager创建Container。ApplicationMaster首先会向ApplicationMasterService注册。
（19）ApplicationMasterService收到新的ApplicationMaster注册请求后，会触发RMAppAttemptRegistrationEvent（RMAppAttemptEventType.REGISTERED）事件。
（20）RMAppAttemptRegistrationEvent事件被 ApplicationAttemptEventDispatcher捕获，并将RMAppAttempt对象从RMAppAttemptState.LAUNCHED状态转化为RMAppAttemptState.RUNNING状态，同时触发RMAppEventType.ATTEMPT_REGISTERED事件。
（21）至此，该application的ApplicationMaster创建与注册完毕，接下来ApplicationMaster会根据Application的资源需求向ResourceManager请求资源，同时监控各个子任务的执行情况。
4.    ResourceManager中事件处理流直观图
下图是从另一个方面对上图的重新绘制：
