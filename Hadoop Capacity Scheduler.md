# hadoop Capacity Scheduler

Capacity Scheduler支持以下特性
  1.	计算能力保证 :支持多个队列某个作业可被提交到某一个队列中。每个队列会配置一定比例的计算资源，所有提交到队列中的作业共享该队列中的资源
  2.	灵活性: 空闲资源会被分配给那些未达到资源使用上限的队列，当某个未达到资源的队列需要资源时，一旦出现空闲资源资源，便会分配给他们。
  3.  支持优先级: 队列支持作业优先级调度（默认是FIFO）
  4. 	多重租赁: 综合考虑多种约束防止单个作业、用户或者队列独占队列或者集群中的资源。
  5.	基于资源的调度 支持资源密集型作业，允许作业使用的资源量高于默认值，进而可容纳不同资源需求的作业仅支持内存资源的调度。
  
## 计算能力调度器算法分析 
* 涉及到的变量 
  * 在capacity中，存在三种粒度的对象，分别为：queue、job和task，它们均需要维护的一些信息：
    * queue维护的信息
@ queueName：queue的名称
@ ulMin：每个用户的可用的最少资源量（所有用户均相同），需用户在配置文件中指定
@ capacityPercent：计算资源比例，需用户在配置文件中指定
@ numJobsByUser：每个用户的作业量，用以跟踪每个用户提交的作业量，并进行数量的上限限制。

  * 该队列中map 或reduce task的属性：
@ capacity：实际的计算资源量，这个随着tasktracker中slot数目变化（用户可能在添加或减少机器节点）而动态变化，大小为：capacityPercent*mapClusterCapacity/100
@ numRunningTasks：正在running的task数目
@ numSlotsOccupied：正在running的task占用的slot总数，注意，在Capacity Scheduler中，running task与slot不一定是一一对应的，每个task可获取多个slot，这主要是因为该调度支持内存资源调度，某个task可能需要多个slot包含的内存量。
@ numSlotsOccupiedByUser：每个用户的作业占用slot总数，用以限制用户使用的资源量。

* job维护的信息
priority：作业优先级，分为五个等级，从大到小依次为：VERY_HIGH，HIGH，NORMAL，LOW，VERY_LOW;
numMapTasks/ numReduceTasks ：job的map/reduce task总数
runningMapTasks/ runningMapTasks：job正在运行的map/reduce task数
finishedMapTasks/finishedReduceTasks：job已完成的map/reduce task数
……
* 	task维护的信息
task开始运行时间，当前状态等

* 计算能力调度算法 
当某个tasktracker上出现空闲slot时，调度器依次选择一个queue、（选中的queue中的）job、（选中的job中的）task，并将该slot分配给该task。

* 选择queue、job和task所采用的策略：
  1. 	选择queue：将所有queue按照资源使用率（numSlotsOccupied/capacity）由小到大排序，依次进行处理，直到找到一个合适的job。
  2.	选择job：在当前queue中，所有作业按照作业提交时间和作业优先级进行排序（假设开启支持优先级调度功能，默认不支持，需要在配置文件中开启），调度依次考虑每个作业，选择符合两个条件的job：[1] 作业所在的用户未达到资源使用上限 [2] 该TaskTracker所在的节点剩余的内存足够该job的task使用。
  3.	选择task，同大部分调度器一样，考虑task的locality和资源使用情况。

```java
（即：调用JobInProgress中的obtainNewMapTask()/obtainNewReduceTask()方法）
综合上述，公平调度器的伪代码为：
// CapacityTaskScheduler:trackTracker出现空闲slot，为slot寻找合适的task
 
List<Task> assignTasks(TaskTrackerStatus taskTracker) {
 
  sortQueuesByResourcesUsesage(queues);
 
  for queue:queues {
 
    sortJobsByTimeAndPriority(queue);
 
    for job:queue.getJobs() {
 
      if(matchesMemoryRequirements(job，taskTracker)) {
 
        task = job. obtainNewTask();
 
        if(task != null) return task
 
      }
    }
 
  }
}

```

## 计算能力调度器源代码分析
计算能力调度器位于代码包的hadoop-0.20.2\src\contrib\capacity-scheduler目录下

* 源代码包组成（共5个java文件）
  * CapacitySchedulerConf.java：管理配置文件
  * CapacityTaskScheduler.java：调度器的核心代码
  * JobQueuesManager.java：管理作业队列
  * MemoryMatcher.java：用于判断job与内存容量是否匹配
  * JobInitializationPoller.java：作业初始化类，用户可同时启动多个线程，加快作业初始化速度。

* CapacityTaskScheduler分析
  * 只介绍调度器最核心的代码，即CapacityTaskScheduler.java文件中的代码。
  1.	几个基本的内类：
    *	TaskSchedulingInfo（TSI）：用以维护某种task(MAP或者REDUCE)的调度信息，包括numRunningTasks，numSlotsOccupied等
    *	QueueSchedulingInfo（QSI）：用以跟踪某个queue中的调度信息，包括capacityPercent，ulMin等
    *	TaskSchedulingMgr：调度的核心实现算法，这是一个抽象类，有两个派生类，分别为：MapSchedulingMgr和ReduceSchedulingMgr，用以实现map task和reduce task的调度策略
  2.	核心方法（按照执行顺序分析）：
    *	CapacityTaskScheduler.start()： 调度器初始化，包括加载配置文件，初始化各种对象和变量
    *	CapacityTaskScheduler. assignTasks ()：当有一个TaskTracker的HeartBeat到达JobTracker时，如果有空闲的slot，JobTracker会调用Capacity Scheduler中的assignTasks方法，该方法会为该TaskTracker需找若干个合适的task。在assignTasks方法中，会调TaskSchedulingMgr中的方法。
    * 提到TaskSchedulingMgr是一个抽象类，它实现了所有派生类必须使用的方法
    *	 TaskSchedulingMgr.assignTasks (taskTracker)：对外提供的最直接的调用函数，主要作用是为taskTracker选择一个合适的task，该函数会依次扫描系统中所有的queue（queue已经被排好序，排序类为TaskSchedulingMgr.QueueComparator），对于每个queue，调用getTaskFromQueue(taskTracker, qsi)。
    *	 TaskSchedulingMgr.getTaskFromQueue(taskTracker, qsi)：从队列qsi中选择一个符合条件的作业，这里的“条件”包括用户的资源量上限，taskTracker空闲内存等。
    
## 	计算能力调度器与公平调度器对比
1.	相同点
@ 均支持多用户多队列，即：适用于多用户共享集群的应用环境
@ 单个队列均支持优先级和FIFO调度方式
@ 均支持资源共享，即某个queue中的资源有剩余时，可共享给其他缺资源的queue
2. 不同点
@ 核心调度策略不同。 计算能力调度器的调度策略是，先选择资源利用率低的queue，然后在queue中同时考虑FIFO和memory constraint因素；
公平调度器仅考虑公平，而公平是通过作业缺额体现的，调度器每次选择缺额最大的job（queue的资源量，job优先级等仅用于计算作业缺额）。
@ 内存约束计算能力调度器调度job时会考虑作业的内存限制，为了满足某些特殊job的特殊内存需求，可能会为该job分配多个slot
公平调度器对这种特殊的job无能为力，只能杀掉这种task。
