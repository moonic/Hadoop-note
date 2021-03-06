# MRv2 ResourceManager  Framework

* ResourceManager相当于整个系统的master，主要功能是启动application的ApplicationMaster和分配系统资源。
* ResourceManager的核心代码在java包org.apache.hadoop.yarn.server.resourcemanager中的ResourceManager类中
  * 主要涉及到三种对象：事件处理器，RPC服务和普通服务，其中事件处理器实现EventHandler接口，并被注册到统一的事件调度器AsyncDispatcher中，由该调度器进行统一管理和调度：
……
private EventHandler<SchedulerEvent>schedulerDispatcher; //实际上是AsyncDispatcher
……
this.rmDispatcher.register(RMAppEventType.class,
new ApplicationEventDispatcher(this.rmContext));
……

* Register函数有两个参数，第一个是事件类型，另一个是事件处理器。
  * 每种事件对应一种事件处理器，一旦该事件发生，事件调度器会直接交由其对应的事件处理器处理，而事件处理器实际上是一个状态机，
  * 事件会使一个对象从一种状态变为另一种状态，并触发相应的行为；
  * RPC服务主要功能是创建一个RPC server，供远程客户端调用提供的服务（接口）。 
  * 实现时，会继承AbstractService抽象类，实现某个RPC协议，并调用YarnRPC中的getServer接口创建一个server以供客户端RPC调用。主要涉及四个RPC服务
  * ApplicationMasterService（实现AMRMProtocol协议）
  * ResourceTrackerService（实现ResourceTracker协
  * ClientRMService（实现ClientRMProtocol协议）
  * AdminService（实现RMAdminProtocol服务）
  * 普通服务继承AbstractService抽象类，一般为一个后台线程或者普通对象。RPC服务和普通服务会被组装到组合服务对象CompositeService中，以便统一进行管理（启动、停止等）。

* 四种actor
  * 每个代表一个actor，对应一个状态机。
  * RMApp：application的状态信息，
  * 由org.apache.hadoop.yarn.server.resourcemanager.rmapp/RMAppImpl.java实现。
RMAppAttempt：运行application的一次尝试（每个application从1开始逐步尝试运行，如果失败，则继续尝试运行，直到成功或者到达某个尝试上限，如果成果，则该application运行成功。一个RMApp可能对一个多个RMAppAttempt）
* org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt/
RMAppAttemptImpl.java实现
  * RMContainer：各个container的状态信息，由org.apache.hadoop.yarn.server.resourcemanager.rmcontainer/RMContainerImpl.java实现。
  * RMNode：YARN集群中每个节点的状态信息，由org.apache.hadoop.yarn.server.resourcemanager.rmnode/RMNodeImpl.java

* PRC服务
  * ClientRMService：实现ClientRMProtocal协议，负责与client交互，接收来自client端的请求并作出响应。
  * ApplicationMasterService：实现了AMRMProtocol通信协议，负责与ApplicationMaster交互，接收来自ApplicationMaster的请求并作出相应。
  * ResourceTrackerService：实现了ResourceTracker协议，主要负责管理各个NodeManager，如新NodeManager注册，死NodeManager的剔除，会调  用NMLivelinessMonitor的一些接口。
  * AdminService：实现RMAdminProtocol协议，主要负责整个系统权限管理，如哪些client可以修改系统中队列名称，给某些队列增加资源等。

* 其他类
  * ApplicationMasterLauncher：创建ApplicationMaster
  * NMLivelinessMonitor：监控各个Nodemanager是否存活，默认情况下，如果某个NodeManage在10min内卫汇报心跳，则认为该节点出现故障。
  * RMAppManager：application管理者，client端提交的作业会最终提交给该类。
  * ResourceScheduler：非常核心的组件，application调度器，当某个节点出现空闲资源使，采用某种策略从application队列中选择某个application使用这些空闲资源。当前有两种调度器： FIFO（First In First Out，默认调度器）和CapacityScheduelr（与Hadoop MapReduce中的Capacity Scheduler思想相同）。
* ApplicationACLsManager：Application权限管理
  * 对于某个application，哪些用户可以查看运行状态，哪些可以修改运行时属性，如优先级等。
NodesListManager：node列表管理，可以动态往集群中添加节点或者减少节点。
 
