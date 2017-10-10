# YARN/MRv2 Client
YARN/MRv2是一个资源统一管理系统，它上面可以运行各种计算框架，而所有计算框架的client端编写方法类似，本文拟以MapReduce计算框架的client端代码为例进行说明。
2.  两个相关协议
需要通过两个协议提交作业：
ClientProtocol：Hadoop中的JobClient通过该协议向JobTracker提交作业
ClientRMProtocol：Yarn中的client通过该协议向ResourceManager提交作业。
3. Client设计方法
为了使Hadoop MapReduce无缝迁移到Yarn中，需要在client端同时使用这两个协议，采用的方法是：
【继承+组合的设计模式】
设计新类YARNRunner，实现ClientProtocol接口，并将ClientRMProtocol对象作为内部成员。当用户提交作业时，会直接调用YARNRunner中的submitJob函数，在该函数内部，会接调用ClientRMProtocol的submitApplication函数，将作业提交到ResourceManager中。此处的submitApplication函数实际上是一个RPC函数，由ResourceManager实现。

我们看一下ClientRMProtocol接口中的所有方法：
1
2
3
public SubmitApplicationResponse submitApplication(
 
  SubmitApplicationRequest request) throws YarnRemoteException;
向ResourceManager提交新的application，client调用该函数时，需要在参数request中指定application所在队列，ApplicationMaster相关jar包及启动方法等信息。
1
2
3
public KillApplicationResponse forceKillApplication(
 
  KillApplicationRequest request) throws YarnRemoteException;
client要求ResourceManager杀死某个application。
1
2
3
public GetApplicationReportResponse getApplicationReport(
 
  GetApplicationReportRequest request) throws YarnRemoteException;
client通过该函数向ResourceManager查询某个application的信息，如id，user，time等信息。

4. 整个流程分析
Client首先通过ClientRMProtocal#getNewApplication获取一个新的“ApplicationId”，然后使用ClientRMProtocal#submitApplication提交一个application，当调用ClientRMProtocal#submitApplication时 ，需要向Resource Manager提供足够的信息以便启动第一个container（实际上就是Application Master）。Client需要提供足够的细节信息，如运行application需要的文件和jar包，执行这些jar包需要的命令，一些unix环境设置等。
这之后，Resource Manager会首先申请一个container，并在它里面启动ApplicationMaster，之后ApplicationMaster会通过AMRMProtocal和ContainerManager分别与Resource Manager和Node Manager通信进行资源申请和container启动。

具体细节：
（1） Client向Resource Manager发动一个连接，更具体 一些，实际上是向ResourceManager的ApplicationsManager发动一个连接。
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
YarnRPC rpc = YarnRPC.create(this.conf);
 
InetSocketAddress rmAddress =
 
  NetUtils.createSocketAddr(this.conf.get(
 
    YarnConfiguration.RM_ADDRESS,
 
    YarnConfiguration.DEFAULT_RM_ADDRESS),
 
    YarnConfiguration.DEFAULT_RM_PORT,
 
    YarnConfiguration.RM_ADDRESS);
 
LOG.info("Connecting to ResourceManager at " + rmAddress);
 
applicationsManager =
 
  (ClientRMProtocol) rpc.getProxy(ClientRMProtocol.class,
 
    rmAddress, this.conf);
（2） 一旦获取一个连接到ASM的handler，client要求ResourceManager分配一个新的ApplicationId。
1
2
3
4
5
6
7
SubmitApplicationRequest request = recordFactory.newRecordInstance(SubmitApplicationRequest.class);
 
request.setApplicationSubmissionContext(appContext);
 
applicationsManager.submitApplication(request);
 
LOG.info("Submitted application " + applicationId + " to ResourceManager");
（3） ASM返回的response中也包含cluster的信息，如该cluster中最少/最大可用资源量，这可以帮助我们合理的设置Application Master需要的资源量，关于更多细节，可查看GetNewApplicationResponse类。
Client最重要的任务是设置对象ApplicationSubmissionContext，它定义了ResourceManager启动ApplicationMaster所需的全部信息。Client需要在该context中设置一下信息：
[1] 队列，优先级信息：该application将要提交到哪个队列，以及它的优先级是多少。
[2] 用户：哪个用户提交的application，这主要用于权限管理。
[3] ContainerLaunchContext：启动并运行ApplicationMaster的那个container的相关信息，包括：本地资源（binaries，jars，files等），安全令牌（security tokens），环境变量设置（CLASSPATH等）和运行命令。
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53
54
55
56
57
58
59
60
61
62
63
64
65
66
67
68
69
70
71
72
73
74
75
76
77
78
79
80
81
82
83
84
85
86
87
88
89
90
91
92
93
94
95
96
97
98
99
100
101
102
103
104
105
106
107
108
109
110
111
112
113
114
115
116
117
118
119
120
121
122
123
124
125
126
127
128
129
130
131
132
133
134
135
136
137
138
139
140
141
142
143
144
145
146
147
148
149
150
151
152
153
// Create a new ApplicationSubmissionContext
 
ApplicationSubmissionContext appContext =
 
  Records.newRecord ( ApplicationSubmissionContext . class ) ;
 
// set the ApplicationId
 
appContext.setApplicationId ( appId ) ;
 
// set the application name
 
appContext.setApplicationName ( appName ) ;
 
// Create a new container launch context for the AM'scontainer
 
ContainerLaunchContext amContainer =
 
  Records.newRecord ( ContainerLaunchContext . class ) ;
 
// Define the local resources required
 
Map < String , LocalResource > localResources =
 
  new HashMap < String , LocalResource > ( ) ;
 
// Lets assume the jar we need for our ApplicationMaster is available in
 
// HDFS at a certain known path to us and we want to make it available to
 
// the ApplicationMaster in the launched container
 
Path jarPath ; // <- known path to jar file
 
FileStatus jarStatus = fs.getFileStatus ( jarPath ) ;
 
LocalResource amJarRsrc = Records.newRecord ( LocalResource . class ) ;
 
// Set the type of resource - file or archive
 
// archives are untarred at the destination by the framework
 
amJarRsrc.setType ( LocalResourceType.FILE ) ;
 
// Set visibility of the resource
 
// Setting to most private option i.e. this file will only
 
// be visible to this instance of the running application
 
amJarRsrc.setVisibility ( LocalResourceVisibility . APPLICATION ) ;
 
// Set the location of resource to be copied over into the
 
// working directory
 
amJarRsrc.setResource ( ConverterUtils . getYarnUrlFromPath ( jarPath ) ) ;
 
// Set timestamp and length of file so that the framework
 
// can do basic sanity checks for the local resource
 
// after it has been copied over to ensure it is the same
 
// resource the client intended to use with the application
 
amJarRsrc.setTimestamp ( jarStatus . getModificationTime ( ) ) ;
 
amJarRsrc.setSize ( jarStatus . getLen ( ) ) ;
 
// The framework will create a symlink called AppMaster.jar in the
 
// working directory that will be linked back to the actual file.
 
// The ApplicationMaster, if needs to reference the jar file, would
 
// need to use the symlink filename.
 
localResources.put ( "AppMaster.jar" , amJarRsrc ) ;
 
// Set the local resources into the launch context
 
amContainer.setLocalResources ( localResources ) ;
 
// Set up the environment needed for the launch context
 
Map < String , String > env = new HashMap < String , String > ( ) ;
 
// For example, we could setup the classpath needed.
 
// Assuming our classes or jars are available as local resources in the
 
// working directory from which the command will be run, we need toappend
 
// "." to the path.
 
// By default, all the hadoop specific classpaths will already be available
 
// in $CLASSPATH, so we should be careful not to overwrite it.
 
String classPathEnv = "$CLASSPATH:./*:" ;
 
env . put ( "CLASSPATH" , classPathEnv ) ;
 
amContainer . setEnvironment ( env ) ;
 
// Construct the command to be executed on the launched container
 
String command =
 
  "${JAVA_HOME}" + / bin / java " +
 
  " MyAppMaster" +
 
  " arg1 arg2 arg3" +
 
  " 1>" + ApplicationConstants . LOG_DIR_EXPANSION_VAR + "/stdout" +
 
  " 2>" + ApplicationConstants . LOG_DIR_EXPANSION_VAR + "/stderr" ;
 
List < String > commands = new ArrayList < String > ( ) ;
 
commands.add ( command ) ;
 
// add additional commands if needed
 
// Set the command array into the container spec
 
amContainer.setCommands ( commands ) ;
 
// Define the resource requirements for the container
 
// For now, YARN only supports memory so we set the memory
 
// requirements.
 
//If the process takes more than its allocated memory, it will
 
// be killed by the framework.
 
// Memory being requested for should be less than max capability
 
// of the cluster and all asks should be a multiple of the min capability.
 
Resource capability = Records . newRecord ( Resource . class ) ;
 
capability.setMemory ( amMemory ) ;
 
amContainer.setResource ( capability ) ;
 
// Set the container launch content into the ApplicationSubmissionContext
 
appContext.setAMContainerSpec ( amContainer ) ;
(4) 这之后client可以向ASM提交application：
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
// Create the request to send to the ApplicationsManager
 
SubmitApplicationRequest appRequest =
 
  Records.newRecord ( SubmitApplicationRequest . class ) ;
 
appRequest.setApplicationSubmissionContext ( appContext ) ;
 
// Submit the application to the ApplicationsManager
 
// Ignore the response as either a valid response object is returned on
 
//success or an exception thrown to denote the failure
 
applicationsManager. submitApplication ( appRequest ) ;
（4） 到此为止，ResourceManager应该已经接受该application，并根据资源需求分配一个container，最终在分配的container中启动ApplicationMaster。Client有多种方法跟踪实际任务的进度：可以使用ClientRMProtocal#getApplicationReport与ResourceManager通信以获取application执行当前情况报告。
1
2
3
4
5
6
7
8
9
10
11
GetApplicationReportRequest request = recordFactory
 
  .newRecordInstance(GetApplicationReportRequest.class);
 
request.setApplicationId(appId);
 
GetApplicationReportResponse response = applicationsManager
 
  .getApplicationReport(request);
 
ApplicationReport applicationReport = response.getApplicationReport();
从ResourceManager中获取的ApplicationReport包含以下内容：
[1] 一般的application信息，如：ApplicationId，application所在队列，application对应用户等
[2] ApplicationMaster信息：ApplicationMaster所在的host，接收用户请求的rpc port以及client与ApplicationMaster通信需要的token等。
[3] 追踪Application的相关信息：如果application支持进度追踪，可以设置一个tracking url，通过该url，client可以直接获取进度。
[4] ApplicationStatus：client通过ApplicationReport#getYarnApplicationState可从ResourceManager那获取application的当前状态，如果ApplicationState为FINISHED，client需要调用ApplicationReport#getFinalApplicationStatus检查application运行成功或者失败，如果运行失败，可调用ApplicationReport#getDiagnostics获取application失败的详细信息。
[5] 如果ApplicationMaster支持，client可直接通过host：rpcport向ApplicationMaster查询其执行进度。当然，也可以使用上面提到的tracking url。
