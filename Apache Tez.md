Tez（Hortonworks介绍：这里，源代码下载：这里，今天刚刚发布的源代码）是Apache最新开源的支持DAG作业的计算框架，它直接源于MapReduce框架，核心思想是将Map和Reduce两个操作进一步拆分，即Map被拆分成Input、Processor、Sort、Merge和Output， Reduce被拆分成Input、Shuffle、Sort、Merge、Processor和Output等，这样，这些分解后的元操作可以任意灵活组合，产生新的操作，这些操作经过一些控制程序组装后，可形成一个大的DAG作业。总结起来，Tez有以下特点：
（1）Apache二级开源项目（源代码今天发布的）
（2）运行在YARN之上
（3） 适用于DAG（有向图）应用（同Impala、Dremel和Drill一样，可用于替换Hive/Pig等）
其中，第三点需要做一些简单的说明，Apache当前有顶级项目Oozie用于DAG作业设计，但Oozie是比较高层（作业层面）的，它只是提供了一种多类型作业（比如MR程序、Hive、Pig等）依赖关系表达方式，并按照这种依赖关系提交这些作业，而Tez则不同，它在更底层提供了DAG编程接口，用户编写程序时直接采用这些接口进行程序设计，这种更底层的编程方式会带来更高的效率，举例如下：
（1）传统的MR（包括Hive，Pig和直接编写MR程序）。假设有四个有依赖关系的MR作业（1个较为复杂的Hive SQL语句或者Pig脚本可能被翻译成4个有依赖关系的MR作业）或者用Oozie描述的4个有依赖关系的作业，运行过程如下（其中，绿色是Reduce Task，需要写HDFS）：

（2）采用Tez，则运行过程如下：

通过上面的例子可以看出，Tez可以将多个有依赖的作业转换为一个作业（这样只需写一次HDFS，且中间节点较少），从而大大提升DAG作业的性能。Tez已被Hortonworks用于Hive引擎的优化，经测试，性能提升约100倍（http://hortonworks.com/blog/100x-faster-hive/）。
【Tez实现】
Tez对外提供了6种可编程组件，分别是：
（1）Input：对输入数据源的抽象，它解析输入数据格式，并吐出一个个Key/value
（2）Output：对输出数据源的抽象，它将用户程序产生的Key/value写入文件系统
（3）Paritioner：对数据进行分片，类似于MR中的Partitioner
（4）Processor：对计算的抽象，它从一个Input中获取数据，经处理后，通过Output输出
（5）Task：对任务的抽象，每个Task由一个Input、Ouput和Processor组成
（6）Maser：管理各个Task的依赖关系，并按顺依赖关系执行他们
除了以上6种组件，Tez还提供了两种算子，分别是Sort（排序）和Shuffle（混洗），为了用户使用方便，它还提供了多种Input、Output、Task和Sort的实现，具体如下：
（1）Input实现：LocalMergedInput（文件本地合并后作为输入），ShuffledMergedInput（远程拷贝数据且合并后作为输入）
（2）Output实现：InMemorySortedOutput（内存排序后输出），LocalOnFileSorterOutput（本地磁盘排序后输出），OnFileSortedOutput（磁盘排序后输出）
（3） Task实现：RunTimeTask（非常简单的Task，基本没做什么事）
（4）Sort实现：DefaultSorter（本地数据排序），InMemoryShuffleSorter（远程拷贝数据并排序）
为了展示Tez的使用方法和验证Tez框架的可用性，Apache在YARN MRAppMaster基础上使用Tez编程接口重新设计了MapReduce框架，使之可运行在YARN中。为此，Tez提供了以下几个组件：
（1）Input：SimpleInput（直接使用MR InputFormat获取数据）
（2）Output：SimpleOutput（直接使用MR OutputFormat获取数据）
（3）Partition：MRPartitioner（直接使用MR Partitioner获取数据）
（4）Processor：MapProcessor（执行Map Task），ReduceProcessor（执行Reduce Task）
（5）Task：FinalTask，InitialTask，initialTaskWithInMemSort，InitialTaskWithLocalSort ，IntermediateTask，LocalFinalTask，MapOnlyTask，这几个Task的组成如下：
对于MapReduce作业而言，如果只有Map Task，则使用MapOnlyTask，否则，Map Task使用InitialTaskWithInMemSort而Reduce Task用FinalTask。当然，如果你想编写其他类型的作业，可使用以上任何几种Task进行组合，比如”InitialTaskWithInMemSort  –> FinalTask”是MapReduce作业，而”InitialTaskWithInMemSort –> IntermediateTask  –> FinalTask”是一种类似于“Map->Reduce->Reduce”的作业，但从目前Tez SVN代码看，这种类型的作业还无法调度执行（需要自己写）。
为了减少Tez开发工作量，并让Tez能够运行在YARN之上，Tez重用了大部分YARN 中MRAppMater的代码，包括客户端、资源申请、任务推测执行、任务启动等。
当前Tez设计还比较粗糙，尚未提供一个复杂的DAG作业设计实例（比如：Map->Reduce->Reduce），不过在Hortonworks官方博客可看到，Tez已经用到Hive引擎的优化中了，并产生了一个新的系统Stinger（http://hortonworks.com/blog/100x-faster-hive/），该系统最近也会开源。
另外，Hortonworks在3月20日发布的HDP 2.0 alpha 2 中已经增加了Apache Tez和利用Apache Tez优化的Hive，具体可参考：http://hortonworks.com/blog/hortonworks-data-platform-2-0-alpha-2-now-available-focus-on-apache-hive-performance-enhancements/（这里号称Hive优化了45X倍，使用说明见：这里）。
【(Tez+Hive)与Impala、Dremel和Drill的区别？】
(Tez+Hive)与Impala、Dremel和Drill均可用于解决Hive/Pig延迟大、性能低效的问题，Impala、Dremel和Drill的出发点是抛弃MapReduce计算框架，不再将SQL或者PIG语句翻译成MR程序，而是采用传统数据数据库的方式，直接从DataNode上存取数据，而(Tez+Hive)则不同，(Tez+Hive)仍采用MapReduce计算框架，但对DAG的作业依赖关系进行了裁剪，并将多个小作业合并成一个大作业，这样，不仅计算量减少，而且写HDFS次数也会大大减少。
想了解Apache Tez中的优化技术，参考我的这篇文章：《浅谈Apache Tez中的优化技术》，《Apache Tez最新进展》。
【总结】
Tez计算框架的引入，至少可以解决现有MR框架在迭代计算（如PageRank计算）和交互式计算方面（如Hive和Pig，当前Hortonworks已将Tez用到了Hive DAG优化中，性能有大约45X提升）的不足，此外，Tez是基于YARN的，可以与原有的MR共存，至此，YARN已经支持两种计算框架：Tez和MR，随着时间的推移，YARN上会出现越来越多的计算框架（具体见：这里），而YARN这种资源统一管理系统必将越来越成熟、稳定。
参考资料：
（1）Tez介绍：http://hortonworks.com/blog/introducing-tez-faster-hadoop-processing/
（2）SVN代码：https://svn.apache.org/repos/asf/incubator/tez/trunk/
（3）Tez Jira：https://issues.apache.org/jira/browse/TEZ
（4）Wiki：http://wiki.apache.org/incubator/TezProposal
（5）http://hortonworks.com/blog/100x-faster-hive/
（6）http://hortonworks.com/blog/hortonworks-data-platform-2-0-alpha-2-now-available-focus-on-apache-hive-performance-enhancements/
（7）http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.0.0.2/bk_installing_manually_book/content/rpm-chap-tez.html 
