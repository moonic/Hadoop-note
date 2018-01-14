# Unmanaged AM工作原理介绍 

1. 在YARN中，一个ApplicationMaster需要占用一个container，该container可能位于任意一个NodeManager上，这给ApplicationMaster测试带来很大麻烦，为了解决该问题，YARN引入了一种新的ApplicationMaster—Unmanaged AM（具体参考：MAPREDUCE-4427），这种AM运行在客户端，不再由ResourceManager启动和销毁。用户只需稍微修改一下客户端即可将分布式环境下的AM运行在客户端的一个单独进程中。


2.    Unmanaged AM工作原理
Unmanaged AM运行步骤如下：
步骤1 通过RPC函数ClientRMProtocol.getNewApplication()获取一个ApplicationId.
步骤2 创建一个ApplicationSubmissionContext对象，填充各个字段，并通过调用函数ApplicationSubmissionContext.setUnmanagedAM(true)启用Unmanaged AM。
步骤3 通过RPC函数ClientRMProtocol.submitApplication()将application提交到ResourceManage上，并监控application运行状态，直到其状态变为YarnApplicationState.ACCEPTED。
步骤4 在客户端中的一个独立线程中启动ApplicationMaster，然后等待ApplicationMaster运行结束，接着再等待ResourceManage报告application运行结束。
YARN在
hadoop-yarn-project/hadoop-yarn/hadoop-yarn-applications/hadoop-yarn-applications-unmanaged-am-launcher目录中提供了一个应用实例（最新版本中有该实例，较早版本没有）