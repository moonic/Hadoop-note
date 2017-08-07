（1） 用户分组管理。用于按组为单位组织管理，某个用户只能向固定分组中提交作业，只能使用固定分组中配置的资源；同时可以限制每个用户提交的作业数，使用的资源量等
（2） 作业管理。包括作业提交权限控制，作业运行状态查看权限控制等。如：可限定可提交作业的用户；可限定可查看作业运行状态的用户；可限定普通用户只能修改自己作业的优先级，kill自己的作业；高级用户可以控制所有作业等。
想要支持权限管理需使用Fair Scheduler或者 Capacity Scheduler（作业管理需用到Hadoop的ACL(Access Control List)功能，启用该功能需选择一个支持多队列管理的调度器）
2.	基本术语
(1)  用户（User）：Hadoop使用Linux用户管理，Hadoop中的用户就是Linux中的用户
(2) 分组（group）：Hadoop使用Linux分组管理，Hadoop中的分组就是Linux中的分组
(3) 池（pool）：Hadoop Fair Scheduler中的概念，一个pool可以是一个user，一个group，或者一个queue。
(4) 队列（Queue）：队列是Hadoop提出的概念，一个Queue可以由任意几个Group和任意几个User组成。
3.	Hadoop中Fair Scheduler与Capacity Scheduler介绍
3.1	Fair Scheduler
Facebook开发的适合共享环境的调度器，支持多用户多分组管理，每个分组可以配置资源量，也可限制每个用户和每个分组中的并发运行作业数量；每个用户的作业有优先级，优先级越高分配的资源越多。
3.2	Capacity Scheduler
Yahoo开发的适合共享环境的调度器，支持多用户多队列管理，每个队列可以配置资源量，也可限制每个用户和每个队列的并发运行作业数量，也可限制每个作业使用的内存量；每个用户的作业有优先级，在单个队列中，作业按照先来先服务（实际上是先按照优先级，优先级相同的再按照作业提交时间）的原则进行调度。
3.3	Fair Scheduler vs Capacity Scheduler
（1）	相同点
[1] 均支持多用户多队列，即：适用于多用户共享集群的应用环境
[2] 单个队列均支持优先级和FIFO调度方式
[3] 均支持资源共享，即某个queue中的资源有剩余时，可共享给其他缺资源的queue
（2）	不同点
[1] 核心调度策略不同。 计算能力调度器的调度策略是，先选择资源利用率低的queue，然后在queue中同时考虑FIFO和memory constraint因素；而公平调度器仅考虑公平，而公平是通过作业缺额体现的，调度器每次选择缺额最大的job（queue的资源量，job优先级等仅用于计算作业缺额）。
[2] 内存约束。计算能力调度器调度job时会考虑作业的内存限制，为了满足某些特殊job的特殊内存需求，可能会为该job分配多个slot；而公平调度器对这种特殊的job无能为力，只能杀掉这种task。
（3）	功能上的不同
Fair Scheduler不允许配置每个user使用的slot数上限，但允许抢占资源 ；而Capacity scheduler允许配置每个user使用的slot数上限，但暂时不支持资源抢占 。
4.	用户分组管理
以Fair Scheduler（http://hadoop.apache.org/common/docs/r0.20.0/fair_scheduler.html ）为例,按以下步骤进行：
(1)	将Fair Scheduler的jar包拷贝到lib中
如：cp ${HADOOP_HOME}/contrib/fairscheduler/hadoop-fairscheduler-0.20.2+320.jar ${HADOOP_HOME}/lib/
(2)	配置Queue相关信息
具体参考：
http://hadoop.apache.org/common/docs/r0.20.2/cluster_setup.html#Configuring+the+Hadoop+Daemons
在mapred-site.xml中添加以下内容：
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
<property>
 
  <name>mapred.acls.enabled</name>
 
  <value>true</value>
 
</property>
 
<property>
 
  <name>mapred.queue.names</name>
 
  <value>my_group,default</value>
 
</property>
 
<property>
 
  <name>mapred.queue.my_queue.acl-submit-job</name>
 
  <value> my_group</value>
 
</property>
 
<property>
 
  <name>mapred.queue.default.acl-administer-jobs</name>
 
  <value></value>
 
</property>
 
<property>
 
  <name>mapred.queue.my_queue.acl-administer-jobs</name>
 
  <value></value>
 
</property>
说明：
【1】	属性mapred.queue.names是queue的所有名字，在这一名字中，必须有一个叫“default”的queue
【2】	每个queue均有一个属性mapred.queue.<queue-name>.acl-submit-job，用于指定哪些user或者group可以向该queue中提交作业
【3】	每个queue均有一个属性mapred.queue.<queue-name>.acl-administer-jobs，用于指定哪些user或者group可以管理该queue中的所有作业，即可以kill作业，查看task运行状态。一般而言，对于每个队列，该选项为空即可，表示每个user只能管理自己的作业。
【4】	每个queue拥有的资源量和其他信息均在另外一个配置文件中指定（对于公平调度器，可以在fair-scheduler.xml中指定）
【5】	mapred.queue.<queue-name>.acl-submit-job和mapred.queue.<queue-name>.acl-administer-jobs配置方法如下：
用户和用户组之间用空格分开，用户之间用“，”分割，用户组之间用“，”分割，如果queue的属性值中只有用户组，则前面保留一个空格。
(3)	配置fair scheduler相关信息
在mapred-site.xml中添加以下内容：

<property>
 
  <name>mapred.jobtracker.taskScheduler</name>
 
  <value>org.apache.hadoop.mapred.FairScheduler</value>
 
</property>
 
<property>
 
  <name>mapred.fairscheduler.poolnameproperty</name>
 
  <value>mapred.job.queue.name</value>
 
</property>
 
<property>
 
  <name>mapred.fairscheduler.allocation.file</name>
 
  <value>/home/XXX/hadoop/conf/fair-scheduler.xml</value>
 
</property>
说明：
mapred.fairscheduler.poolnameproperty有三个可用值：默认情况下是user.name，即每个用户独自一个pool；group.name，即一个linux group一个pool，mapred.job.queue.name，即一个queue一个pool，如果要支持“作业管理”，需使用最后一种配置。
(4)	创建文件fair-scheduler.xml，并添加以下内容：

31
32
33
<?xml version="1.0"?>
 
<allocations>
 
 <pool name="my_queue">
 
  <minMaps>10</minMaps>
 
  <minReduces>10</minReduces>
 
  <maxRunningJobs>10</maxRunningJobs>
 
  <minSharePreemptionTimeout>300</minSharePreemptionTimeout>
 
  <weight>2.0</weight>
 
</pool>
 
<user name="bob">
 
  <maxRunningJobs>5</maxRunningJobs>
 
</user>
 
<poolMaxJobsDefault>25</poolMaxJobsDefault>
 
<userMaxJobsDefault>2</userMaxJobsDefault>
 
<defaultMinSharePreemptionTimeout>600</defaultMinSharePreemptionTimeout>
 
<fairSharePreemptionTimeout>600</fairSharePreemptionTimeout>
 
</allocations>
说明：
【1】各个字段的含义
<pool></pool>之间配置的是每个pool的信息，主要如下：
(a) minMaps：该pool可使用的map slot数
(b) minReduces：该pool可使用的reduce slot数
(c) maxRunningJobs：该pool最大运行作业数
(d) minSharePreemptionTimeout：该pool抢占资源的时间间隔，即本属于自己的资源在改时间内拿不到便会抢占。
(e) Weight：pool的权重，该值越大，能够从共享区（有一些pool中的资源用不完，会共享给其他pool）中获取的资源越多。
<user></user>之间配置某个用户的约束：
maxRunningJobs：该用户可同时运行的作业数
<poolMaxJobsDefault></poolMaxJobsDefault>之间配置默认情况下每个pool最大运行作业数
<userMaxJobsDefault></userMaxJobsDefault>之间配置默认情况下每个user最大运行作业数
……
【2】 该配置文件中可动态修改无需重启Hadoop（修改后3s会被重新加载）
5.	作业管理
作业管理模块由Hadoop的ACL（http://hadoop.apache.org/common/docs/r0.20.2/service_level_auth.html ）完成。
(1)	在core-site.xmll中配置以下属性：

<property>
 
  <name>hadoop.security.authorization</name>
 
  <value>true</value>
 
</property>
(2)	配置${HADOOP_CONF_DIR}/hadoop-policy.xml
Hadoop有9个可配置的ACL属性，每个属性可指定拥有相应访问权限的用户或者用户组。这9个ACL属性如下：

这9个ACL的配置方法相同，具体如下：
每个ACL可配置多个用户，用户之间用“，”分割；可配置多个用户组，分组之间用“，”分割， 用户和分组之间用空格分割，如果只有分组，前面保留一个空格，如：
<property>
 
  <name>security.job.submission.protocol.acl</name>
 
  <value>alice,bob group1,group2</value>
 
</property>
说明： 用户alice和bob， 分组group1和group2可提交作业
又如：

<property>
 
  <name> security.client.protocol.acl </name>
 
  <value> group3</value>
 
</property>
说明：只有group3可访问HDFS

<property>
 
  <name>security.client.protocol.acl</name>
 
  <value>*</value>
 
</property>
说明：所有用户和分组均可访问HDFS
注意，默认情况下，这9个属性不对任何用户和分组开放。
该配置文件可使用以下命令动态加载：
(1)	更新namenode相关属性： bin/hadoop dfsadmin –refreshServiceAcl
(2)	更新jobtracker相关属性：bin/hadoop mradmin -refreshServiceAcl
6.	提交作业
用户提交作业时，需用mapred.job.queue.name属性告诉Hadoop你要将作业提交到哪个Queue中，具体如下：
（1）	如果你是用Java编写Hadoop作业，用-D mapred.job.queue.name指明提交到哪个queue，如：

$HADOOP_HOME/bin/hadoop jar wordcount.jar wordcount \
 
  -D mapred.map.tasks=1 \
 
  -D mapred.reduce.tasks=1 \
 
  -D mapred.job.queue.name= infrastructure \
 
  Input ouput
（2）	如果你使用Hadoop Pipes编写作业，用-D mapred.job.queue.name指明提交到哪个queue，如：

$HADOOP_HOME/bin/hadoop pipes \
 
  -D hadoop.pipes.executable=/examples/bin/wordcount \
 
  -D hadoop.pipes.java.recordreader=true \
 
  -D hadoop.pipes.java.recordwriter=true \
 
  -D mapred.job.queue.name= my_group \
 
  -input in-dir -output out-dir
（3）	如果你使用Hadoop Streaming编写作业，用-D mapred.job.queue.name指明提交到哪个queue，如：

$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/hadoop-streaming.jar \
 
  -input myInputDirs \
 
  -output myOutputDir \
 
  -mapper myPythonScript.py \
 
  -reducer /bin/wc \
 
  -D mapred.job.queue.name= my_group
