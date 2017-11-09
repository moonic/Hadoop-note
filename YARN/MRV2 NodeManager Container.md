# MRV2 NodeManager Container

* NodeManager的一个最重要的功能是根据ApplicationMaster的要求启动container
   * 由于各个节点上的container由ResourceManager进行统一管理和分配的
   * 通常，ResourceManager将Container分配给ApplicationMaster，ApplicationMaster再进一步要求对应的NodeManager启动container。为防止ApplicationMaster未经授权随意要求NodeManager启动container，ResourceManager一般会为每个container分配一个令牌（ApplicationMaster无法伪造），而NodeManager启动任何container之前均会对令牌的合法性进行验证，一旦通过验证后，NodeManager才会按照一定的流程启动该container。本章将介绍

* NodeManager启动container的详细流程。
  * Application 用户提交的任何一个应用程序，在YARN中被称为Application。
  * Container 一个Application通常会被分解成多个任务并行执行，其中，每个任务要使用一定量的资源，这些资源被封装成container。详细说来，container不仅包含一个任务的资源说明，还包含很多其他信息，比如Container对应的节点、启动container所需的文件资源、环境变量和命令等信息。
  * 资源本地化 在container中启动任务之前，先要为任务准备好各种文件资源，这些文件资源通常在用户提交应用程序时已上传到HDFS上，而container启动之前，需要下载到本地工作录下，该过程称为资源本地化。


* 事件驱动与状态机
  * YARN中采用了事件驱动模型，YARN按照事件将各个对象组织起来，如果一个对象存在多种状态，则用一个状态机描述它的生命周期
  * 其中，状态机的状态变化是由事件驱动的，一个事件可以使对象从一个状态转移到另一个状态，同时触发一个行为，而该行为可能在此发出一个事件
  * 使得另外一些对象发生状态转移。
  * 如下如所示，一个时间可以使对象的一个状态转移到另一个状态，也可以转移到多个可能的状态中的一个，具体转移到哪个状态，由行为函数的返回值决定。

NodeManager中包含三个状态机，分别为对象LocalizedResources、Application（由ApplicationImpl实现）和Container（由ContainerImpl实现），具体如下（其中action未画出，这三个图来源为：MAPREDUCE-279）：



* Container启动过程分析
  * 从源代码级别分析container启动过程，具体如下图所示，读者可对照代码阅读以下流程图。
Container的启动开始于ApplicationMaster调用ContainerManager::startContainer()，而NodeManager中的ContainerManagerImpl收到该RPC请求后，经历的整个过程如下所示：