# YARN编程实例—distributedshell源
1. 概述
  * 本文介绍YARN自带的一个非常简单的应用程序编程实例—distributedshell，他可以看做YARN编程中的“hello world”，它的主要功能是并行执行用户提供的shell命令或者shell脚本。本文主要介绍distributedshell 的实现方法。
  * Distributedshell的源代码在文件夹
  * src\hadoop-yarn-project\hadoop-yarn\hadoop-yarn-applications\hadoop-yarn-applications-distributedshell下。
  * Distributedshell 的实现完全与文章“如何编写YARN应用程序”所描述的一般YARN应用程序的编写方法完全一致。


2. Distributedshell客户端源码分析
  * Distributedshell Client的入口main函数如下：
```java

public static void main(String[] args) {
…
Client client = new Client();
boolean doRun = client.init(args);
if (!doRun) {
System.exit(0);
}
result = client.run();
…
}
```

DistributedShell Client中最重要的是函数为run()，该函数实现过程如下：
1. 构造RPC句柄。
  * 利用Hadoop RPC接口创建一个可以直接与ResourceManager交互的RPC client句柄applicationsManager：
private void connectToASM() throws IOException {
YarnConfiguration yarnConf = new YarnConfiguration(conf);
InetSocketAddress rmAddress = yarnConf.getSocketAddr(
YarnConfiguration.RM_ADDRESS,
YarnConfiguration.DEFAULT_RM_ADDRESS,
YarnConfiguration.DEFAULT_RM_PORT);
LOG.info(“Connecting to ResourceManager at ” + rmAddress);
applicationsManager = ((ClientRMProtocol) rpc.getProxy(
ClientRMProtocol.class, rmAddress, conf));
}
2. 获取application id。
与ResourceManager通信，请求application id：
GetNewApplicationRequest request = Records.newRecord(GetNewApplicationRequest.class);
GetNewApplicationResponse response = applicationsManager.getNewApplication(request);
3. 构造ContainerLaunchContext。
构造一个用于运行ApplicationMaster的container，container相关信息被封装到ContainerLaunchContext对象中：
ContainerLaunchContext amContainer = Records.newRecord(ContainerLaunchContext.class);
//添加本地资源
//填充localResources
amContainer.setLocalResources(localResources);
//添加运行ApplicationMaster所需的环境变量
Map<String, String> env = new HashMap<String, String>();
//填充env
amContainer.setEnvironment(env);
//添加启动ApplicationMaster的命令
//填充commands;
amContainer.setCommands(commands);
//设置ApplicationMaster所需的资源
amContainer.setResource(capability);
4. 构造ApplicationSubmissionContext。
构造一个用于提交ApplicationMaster的ApplicationSubmissionContext：
ApplicationSubmissionContext appContext =
Records.newRecord(ApplicationSubmissionContext.class);
//设置application id，调用GetNewApplicationResponse#getApplicationId()
appContext.setApplicationId(appId);
//设置Application名称：“DistributedShell”
appContext.setApplicationName(appName);
//设置前面创建的container
appContext.setAMContainerSpec(amContainer);
//设置application的优先级，默认是0
pri.setPriority(amPriority);
//设置application的所在队列，默认是”"
appContext.setQueue(amQueue);
//设置application的所属用户，默认是”"
appContext.setUser(amUser);
5. 提交ApplicationMaster。
将ApplicationMaster提交到ResourceManager上，从而完成作业提交功能：
applicationsManager.submitApplication(appRequest);
6.  显示应用程序运行状态。
为了让用户知道应用程序进度，Client会每隔几秒在shell终端上打印一次应用程序运行状态：
while (true) {
Thread.sleep(1000);
GetApplicationReportRequest reportRequest =
Records.newRecord(GetApplicationReportRequest.class);
reportRequest.setApplicationId(appId);
GetApplicationReportResponse reportResponse =
applicationsManager.getApplicationReport(reportRequest);
ApplicationReport report = reportResponse.getApplicationReport();
//打印report内容
…
YarnApplicationState state = report.getYarnApplicationState();
FinalApplicationStatus dsStatus = report.getFinalApplicationStatus();
if (YarnApplicationState.FINISHED == state) {
if (FinalApplicationStatus.SUCCEEDED == dsStatus) {
return true;
} else {
return false;
}
} else if (YarnApplicationState.KILLED == state
|| YarnApplicationState.FAILED == state) {
return false;
}
}
3.    Distributedshell ApplicationMaster源码分析
Distributedshell ApplicationMaster的实现方法与“如何编写YARN应用程序”所描述的步骤完全一致，它的过程如下：

步骤1 ApplicationMaster由ResourceManager分配的一个container启用，之后，它与ResourceManager通信，注册自己，以告知自己所在的节点（host：port），trackingurl（客户端可通过该url直接查询AM运行状态）等。
RegisterApplicationMasterRequest appMasterRequest =
Records.newRecord(RegisterApplicationMasterRequest.class);
appMasterRequest.setApplicationAttemptId(appAttemptID);
appMasterRequest.setHost(appMasterHostname);
appMasterRequest.setRpcPort(appMasterRpcPort);
appMasterRequest.setTrackingUrl(appMasterTrackingUrl);
return resourceManager.registerApplicationMaster(appMasterRequest);
步骤2 ApplicationMaster周期性向ResourceManager发送心跳信息，以告知ResourceManager自己仍然活着，这是通过周期性调用AMRMProtocol#allocate实现的。
步骤3 为了完成计算任务，ApplicationMaster需向ResourceManage发送一个ResourceRequest描述对资源的需求，包括container个数、期望资源所在的节点、需要的CPU和内存等，而ResourceManager则为ApplicationMaster返回一个AllocateResponse结构以告知新分配到的container列表、运行完成的container列表和当前可用的资源量等信息。
while (numCompletedContainers.get() < numTotalContainers
&& !appDone) {
Thread.sleep(1000);
List<ResourceRequest> resourceReq = new ArrayList<ResourceRequest>();
if (askCount > 0) {
ResourceRequest containerAsk = setupContainerAskForRM(askCount);
resourceReq.add(containerAsk);
}
//如果resourceReq为null，则可看做心跳信息，否则就是申请资源
AMResponse amResp =sendContainerAskToRM(resourceReq);
}
步骤4 对于每个新分配到的container，ApplicationMaster将创建一个ContainerLaunchContext对象，该对象包含container id，启动container所需环境、启动container命令，然后与对应的节点通信，以启动container。
LaunchContainerRunnable runnableLaunchContainer =
new LaunchContainerRunnable(allocatedContainer);
//每个container由一个线程启动
Thread launchThread = new Thread(runnableLaunchContainer);
launchThreads.add(launchThread);
launchThread.start();
步骤5 ApplicationMaster通过AMRMProtocol#allocate获取各个container的运行状况，一旦发现某个container失败了，则会重新向ResourceManager发送资源请求，以重新运行失败的container。
步骤6 作业运行失败后，ApplicationMaster向ResourceManager发送FinishApplicationMasterRequest请求，以告知自己运行结束。
FinishApplicationMasterRequest finishReq =
Records.newRecord(FinishApplicationMasterRequest.class);
finishReq.setAppAttemptId(appAttemptID);
boolean isSuccess = true;
if (numFailedContainers.get() == 0) {
finishReq.setFinishApplicationStatus(FinalApplicationStatus.SUCCEEDED);
}
