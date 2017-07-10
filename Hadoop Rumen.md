# Hadoop Rumen
>Hadoop MapReduce设计的日志解析和分析工具，它能够将JobHistory 日志解析成有意义的数据并格式化存储
Rumen可以单独使用，但通常作为其他组件，比如GridMix (v3) 和 Mumak的基础库。

### Hadoop Rumen设计动机

* 对于任何一个工作在Hadoop之上的外部工具，分析JobHistory日志都是必须的工作之一。
	* 基于这点考虑，Hadoop应内嵌一个JobHistory日志分析工具。
	* 统计分析MapReduce作业的各种属性，比如任务运行时间、任务失败率等，基准测试或者模拟器必备的功能，Hadoop Rumen可以为任务生成
	* Cumulative Distribution Functions (CDF)，这可以用于推断不完整的、失败的或者丢失的任务。


### Hadoop Rumen基本构成

* Hadoop Rumen已经内置在Apache Hadoop 1.0之上（包括0.21.x，0.22.x，CDH3）各个版本中，
	* 位于org.apache.hadoop.tools.rumen包中，通常被Hadoop打包成独立的jar包hadoop-tools-[VERSION].jar。Hadoop Rumen由两部分组成：
		1. Trace Builder
			* 将JobHistory日志解析成易读的格式，当前仅支持json格式。Trace Builder的输出被称为job trace（作业运行踪迹），我们通过job trace很容易模拟（还原）作业的整个运行过程。

	2. Folder
		* 将job trace按时间进行压缩或者扩张。
			* 为了方便其他组件，比如GridMix (v3) 和 Mumak，使用。Folder可以将作业运行过程进行等比例缩放，以便在更短的时间内模拟作业运行过程。


* 试用Hadoop Rumen
	* 两种方式运行Rumen
		* 一种是使用集成化（综合所有功能）的HadoopLogsAnalyzer类
			* 在很多Hadoop版本中，这个类已经过期，不推荐使用
		* 另一种是使用TraceBuilder和Folder类。它们的运行方式基本类似，下面以HadoopLogsAnalyzer类为例进行说明：


```xml
bin/hadoop org.apache.hadoop.tools.rumen.HadoopLogsAnalyzer -v1 -write-job-trace file:///tmp/job-trace.json -write-topology file:///tmp/topology.json file:///software/hadoop/logs/history/done/
其中，“-v1”表示采用version 1的JobHsitory格式，如果你的Hadoop版本是0.20.x系列，则需要加这个参数，“-write-job-trace”是输出的job trace存放位置，“-write-topology”是拓扑结构存放位置，Rumen能够通过分析JobHistory中所有文件得到Hadoop集群的拓扑结构。最后一项紧跟你的JobHistory 中done目录存放位置，一般在${HDOOP_LOG}/history/done中，如果在本地磁盘，则需在目录前加前缀file://，如果在HDFS上需在目录前加前缀“hdfs://”。
下面是截取的job-trace.json和topology.json文件内容：
【job-trace.json】
“priority” : “NORMAL”,
“jobID” : “job_201301061549_0003″,
“mapTasks” : [ {
"attempts" : [ {
"location" : null,
"hostName" : "HADOOP001",
"startTime" : 1357460454343,
"finishTime" : 1357460665299,
"result" : "KILLED",
"shuffleFinished" : -1,
"sortFinished" : -1,
"attemptID" : "attempt_201301061549_0003_m_000000_0",
"hdfsBytesRead" : -1,
"hdfsBytesWritten" : -1,
"fileBytesRead" : -1,
"fileBytesWritten" : -1,
"mapInputRecords" : -1,
"mapOutputBytes" : -1,
"mapOutputRecords" : -1,
"combineInputRecords" : -1,
"reduceInputGroups" : -1,
"reduceInputRecords" : -1,
"reduceShuffleBytes" : -1,
"reduceOutputRecords" : -1,
"spilledRecords" : -1,
"mapInputBytes" : -1
} ],
“preferredLocations” : [ ],
“startTime” : 1357460454686,
“finishTime” : -1,
“inputBytes” : -1,
“inputRecords” : -1,
“outputBytes” : -1,
“outputRecords” : -1,
“taskID” : “task_201301061549_0003_m_000000″,
“numberMaps” : -1,
“numberReduces” : -1,
“taskStatus” : null,
“taskType” : “MAP”
}, {
….
【topology.json】
{
“name” : “<root>”,
“children” : [ {
"name" : "default-rack",
"children" : [ {
"name" : " HADOOP001",
"children" : null
}, {
"name" : " HADOOP002",
"children" : null
}, {
"name" : HADOOP003",
"children" : null
}, {
"name" : " HADOOP004",
"children" : null
}, {
"name" : " HADOOP005",
"children" : null
}, {
"name" : " HADOOP006",
"children" : null
} ]
} ]
}

```xml
