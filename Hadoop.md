# Hadoop
> 开源框架 编写运行分布式 应用处理的大规模数据
分布式技术是宽泛不断变化的领域 

* 发展史
	* Apache Lucene 子项目 全文本索引查询库 给一个文本集合
		* 根加方便的搜索 建立一个完整的web搜索引擎
	* Google 论文 GFS文件系统  MapReduce框架
		* 将Nutch 移植上去 提升了可扩展性 处理几亿个网页 运行在今节点集群上
	* 专业项目实行网络扩展需要的技术出来了hadoop
	

* 优点
	* 方便 
		* 部署在商用机器上的大型集群上 EC2 亚马逊的计算云
	* 健壮 
		* 致力于在商用硬件运行 容许大量类似故障
	* 可扩展 
		* 通过增加几区节点 线性扩展处理更大的数据集
	* 简单 
		* 运行用户快速编写高校并行的代码

* 存在的问题
	*  Namenode/jobtracker单点故障。
		* Hadoop采用的是master/slaves架构，该架构管理较简单，但存在致命的单点故障和空间容量不足等缺点严重影响了Hadoop的可扩展性。

	* HDFS小文件问题
		* HDFS中，任何block，文件或者目录在内存中均以对象的形式存储，每个对象约占150byte，如果有1000 0000个小文件，每个文件占用一个block，则				namenode需要2G空间
		* 如果存储1亿个文件，则namenode需要20G空间。这样namenode内存容量严重制约了集群的扩展。		

	* jobtracker同时进行监控和调度，负载过大。
		* 为了解决该问题，yahoo已经开始着手设计下一代Hadoop MapReduce将监控和调度分离，独立出一个专门的组件进行监控
		* jobtracker只负责总体调度，至于局部调度，交给作业所在的client。

	* 数据处理性能。 
		* 数据的处理性能能提高很大
			* Hadoop类似于数据库，可能需要专门的优化工程师根据实际的应用需要对Hadoop进行调优 Hadoop Performance Optimization” (HPO)


* 优化问题
	*  应用程序角度进行优化
		* mapreduce是迭代逐行解析数据文件的，如何迭代的情况下，编写高效率的应用程序
	* 对Hadoop参数进行调优
		* hadoop系统有190多个配置参数，怎样调整这些参数，使hadoop作业运行尽可能的快
	* 系统实现角度进行优化
		* 这种优化难度是最大，从hadoop实现机制角度，发现当前Hadoop设计和实现上的缺点，进行源码级地修改 虽难度大，但往往效果明显。
	* 以上三种思路出发点均是提高hadoop应用程序的效率
		* 实际上，随着社会的发展，绿色环保观念也越来越多地融入了企业 因而很多人开始研究Green Hadoop
		* 即怎样让Hadoop完成相应数据处理任务的同时，使用最少的能源

* 其他的分布式系统 展现Hadoop设计的理念
	* 比较SQL 数据库 和Hadoop
		* hadoop是数据处理框架 SQL是针对结构化程序设计的
		* hadoop 针对文本非结构化设计的
		* sqlゆHadiio互补 将hadoop作为执行引擎
			* 向外扩展代替向上扩展
				* 性能标准4倍的pc机器和 4台pc的集群
			* key-vaule
				* 灵活处理结构化少的数据类型
			* 函数编程代替申明查询
				* mapReduce 代替SQL
			* 批量处理代替在线处理
				* 为离线处理大规模数据分析而设计 不合适在线记录随机查写
* 摩尔定律 

* 理解MapReduce
	* 消息队里等数据处理模型 用于数据处理的方方面面 Unix pipes
	* 管道有助于原语言的重用 模块化简单连接可以使用
	* 数据处理模型 扩展到多个计算节点的数据 

* 扩展数据处理程序面对的挑战 
	* 文件存储在存储服务器上 瓶颈就是该服务器的带宽
	* 函数方法存储在内存中 处理大量 文档一个单词超过一台机器的容量
	* 将单词 存储散列表中 
	* 将数据分割在多台计算机上能独立运行

* 如何解决
	* 存储到多个计算机中
	* 编写基于磁盘的散列表  内存不受限制
	* 画风第一阶段的中间数据
	* 洗牌分区第二阶段合适的计算机上


```java

public class WordCount extends configured implements Tool{

	public static class MapClass extends MapReduceBase
		implements Mapper<LongWritable,Text,Text,IntWritable>{

			private final static IntWritable one = new IntWritable(1);
			private Text word = new Text();

			public void map(LongWritable key,Text value,
				OutputCollector<Text,IntWritable>output,
				Reporter reporter) throw IOExption{

				String line = value.toStirng();
				StringTokenizer itr = new StringTokenizer(line);
				while(itr.hasMoreTokens()){
					wori.set(itr.netToken());
					output.collect(word,one);
				}
			}
		}

		public static class Reduce extends MapReduceBase
		 implements Redicer<Text,IntWritable,Text,IntWritable>{

		 	public void reduce(LongWritable key,Text value,
				OutputCollector<Text,IntWritable>output,
				Reporter reporter) throw IOExption{

		 		int sum = 0;
		 		while (values.hasNext()){

		 			sum += values.next().get();
		 		}
		 		output.collect(key,new Intwritable(sum));
		 }
}


```

---

## Hadoop Model 


* Hadoop 构建模块
	* 全配置的集群运行Hadoop 不同服务器运行守护进程daemons 守护
		* NameNode 
			* 分布式计算你与分布式存储才去 主从 master slave结构
			* Hadoop文件系统HDFS NameNode 位于HDFS主端
			* 执行底层IO任务 NameNode追踪文件如何被分成文件块
			* 运行时消耗大量的IO资源 不会存储用户数据或者执行MapReduce
			NameNode 不会同时是TaskTracker
				* Hadoop 集群的单点失败热河其他的守护进程节点还是会平稳运行
		* DataNode
			* 集群上的从几点族村一个DataNode守护进程
			将HDFS数据库读取或者本地文件实际系统
			* NameNode 告诉客户端驻留在那个DataNode
			* 直接DataNode守护进程通信 处理对应的数据块对应的本地文件
				* 多个数据块用重复的存储在不同的副本上
				* DataNode向NameNode包括 个更新NameNode
		* Secondary NameNode
			* 检测HDFS 辅助时候进程 独占一台服务器
			* 该服务器不会运行其他的DataNode or TaskTracker 守护进程
			* SNN 快照有助于减少停机时候并降低数据丢失的风险
		* JobTracker 
			* 监视MapReduce作业的执行过程
			* JT守护进程 是应用程序和hadoop 之间的纽带
			* 不同任务分配的节点控制任务的运行
			* 一个几区只有一个守护进程 运行在服务器集群的主节点上
		* TaskTracker
			* 执 JobTracker 分配的单项任务 各个任务从节点的执行情况
			* 持续不断 JobTracker 通信 如果为收到默认为崩溃

## Hadoop 组件

* HDFS 文件系统为MapReduce 框架的分布式处理设计的
可以存放一个大的数据集合 存储为单个文件 大多数系统无力实现这一点
并不是天生的Unix系统
不只是 文件命令 ls cp 

* 基本文件命令
	* hadoop fs -cmd <args>
		* hadoop fs -linux命令

* Hadoop 文件系统命令与HDFS文件系统教会 可以和本地文件系统交互
	* URI 精确的映射指定文件或者目录位置 scheme协议
	* 来指定HDFS 文件或者本地文件系统 
		* 对于本地文件使用标准的Uninx命令 其他命令就会默认定向跳转

* 添加文件目录
	* hadoop文件起点是FileSystem 类 一个与文件系统交互抽象的类
	* 可以调用 factory 方法 来得到需要的Filesystem 实列
	* configuration 基于保留键配置的特殊类


* PutMerge applcation 
	* 用户定义参数设置本地目录HDFS目标文件
	* 提取本地文件信息
	* 创建一个输出流写入HDFS 文件
	* 遍历蹦迪绿文件 打开输入流读取文件

```java
	public static void main(String[] args) {
		Configuration conf = new Configuration();
		FileSystem hdfs = FileSystem.get(conf);
		FileSystem local = FileSystem.getLocal(conf);

		Path inputDir = new Path(args[0]);
		Path hdfsFile = new Path(args[1]);

		try{
			FileStatus[] inputFiles = local.listStatus(inputDir);
			FSDataOutputStream out = hdfs.create(hdfsFile);

			for (int i=0; i<inputFiles.length ;i++ ) {
				System.out.println(inputFiles{i}.getpath().getName*());
				FSDataInputStream in = local.opne(inputFilesi[i].getpath());
			byte buffer[] = new byte[256];
			int bytesRead=0;
			while([bytesRead=in.read(buffer)]>0);
				outwrite((byter,0,bytesRead);
			}
			in.close();
		}
			out.close();
		}catch(IOException e ){
			e.printtackTrace();
		}

	}

```			

--- 

## Hadoop 数据类型
> MapReduce 不允许是任意类 可以将键与值称为整数字符单并不是
java 提供的标准类 只是为了让键值可以移动 MapReduce 提供了一序列化的过程

* key value 常用的类型列表
	* BooleanWritable   布尔类封装
	* ByteWritable 
	* DoubleWritable 
	* FloatWritable 
	* IntWritable 
	* LongWritable
	* Text

* 支持自定义数据类型只要实现Writable WritbleComparable<T>

```java
	
	public class Edge implements WritbleComparable<Edge>{

		private String departureNode;
		private String arrivalNode;

		public String getDepartureode(){
			reporter departureNode;
		}
	}



```


* Mapper 
> 普通类作为Mapper 继承MapReduceBase 并实现 Mapper 接口

* 构造解析方法
	* void configure jobconf job 
	* void close()

	void map(k1 key,
		V1 value,
		OutputCollector<k2,v2>output
		Reporter reporter
	)
	
	
	
	---





## Hadoop 机制


* 层级队列组织方式
	* 在一个Hadoop集群中，管理员将所有计算资源划分给了若干个队列，每个队列对应了一个“组织”
	* 其中有一个组织“Org1”，它分到了60%的资源，它内部包含3中类型的作业：
		1. 产品线作业
		2. 实验性作业—分属于三个不用的项目：Proj1，Proj2和Proj3
		3. 其他类型作业

* Org1管理员想更有效地控制这60%资源，比如将大部分资源分配给产品线作业的同时，能够让实验性作业和其他类型作业有最少资源保证。考虑到产品线作业提交频率很低，当有产品线作业提交时，必须第一时间得到资源，剩下的资源才给其他类型的作业，然而，一旦产品线作业运行结束，实验性作业和其他类型作业必须马上获取未使用的资源，一个可能的配置方式如下：
```xml

grid {
Org1 min=60% {
priority min=90% {
production min=82%
proj1 min=6% max=10%
proj2 min=6%
proj3 min=6%
}
miscellaneous min=10%
}
Org2 min=40%
}

```
* 这就引出来层级队列组织方式。
	* 子队列
		1. 队列可以嵌套，每个队列均可以包含子队列。
		2. 用户只能将作业提交到最底层的队列，即叶子队列。
	* 最少容量
		1. 每个子队列均有一个“最少容量比”属性，表示可以使用父队列的容量的百分比
		2. 调度器总是优先选择当前资源使用率最低的队列，并为之分配资源。比如同级的两个队列Q1和Q2，他们的最少容量均为30
		而Q1已使用10，Q2已使用12，则调度器会优先将资源分配给Q1。
		3. 最少容量不是“总会保证的最低容量”，也就是说，如果一个队列的最少容量为20，而该队列中所有队列仅使用了5，
		那么剩下的15可能会分配给其他需要的队列。
		4. 最少容量的值为不小于0的数，但也不能大于“最大容量”。
	* 最大容量
		1. 为了防止一个队列超量使用资源，可以为队列设置一个最大容量，这是一个资源使用上限，任何时刻使用的资源总量不能超过该值。
		2. 默认情况下队列的最大容量是无限大，这意味着，当一个队列只分配了20%的资源，所有其他队列没有作业时，该队列可能使用100%的资源，当其他队列有作业提交时，再逐步归还。


* 如何将一个队列中的资源分配给它的各个子队列？
	* 当一个TaskTracker发送心跳请求一个新任务时，调度器会按照以下策略为之选择任务：
		1. 按照 比值{used capacity}/{minimum-capaity},对所有子队列排序；
		2. 选择一个比值{used capacity}/{minimum-capaity}最小的队列：
		如果是一个叶子队列，且有处于pending状态的任务，则选择一个任务（不能超过maximum capacity）；
		否则，递归地从这个队列的子队列中选择任务。
		3. 如果没有找到任务，则查看下一个队列。
			* 层级队列组织方式在 0.21.x和0.22.x中引入，但仅有Capacity Scheduler支持该组织方式	
				（https://issues.apache.org/jira/browse/MAPREDUCE-824 
			* 最新的YARN（Hadoop 0.23.x和2.0.x-alpha）也为Fair Scheduler增加了层级队列的支持，具体参考：
				https://issues.apache.org/jira/browse/YARN-187。

* 如何配置？
	* 以0.21.x为例，管理员可在配置文件mapred-queues.xml中配置层级队列，配置方式如下：
```xml
<queues>
<queue>
<name>Org1</name>
<queue>
<name>production</name>
<properties>
<property key=”capacity” value=”20″/>
<property key=” maximum-capacity” value=”20″/>
<property key=”supports-priority” value=”true”/>
<property key=”minimum-user-limit-percent” value=”30″/>
<property key=”maximum-initialized-jobs-per-user” value=”10″/>
<property key=”user-limit” value=”30″/>
</properties>
</queue>
<queue>
<name>miscellaneous</name>
<properties>
<property key=”capacity” value=”10″/>
<property key=” maximum-capacity” value=”20″/>
<property key=”user-limit” value=”20″/>
</properties>
</queue>
。。。。。。。
</queues>
管理员可在capacity-scheduler.xml中设置一些参数的默认值和Capacity独有的配置：
<configuration>
<property>
<name>mapred.capacity-scheduler.default-supports-priority</name>
<value>false</value>
</property>
<property>
<name>mapred.capacity-scheduler.default-minimum-user-limit-percent</name>
<value>100</value>
</property>
<property>
<name>mapred.capacity-scheduler.default-maximum-initialized-jobs-per-user</name>
<value>2</value>
</property>
<property>
<name>mapred.capacity-scheduler.init-poll-interval</name>
<value>5000</value>
</property>
<property>
<name>mapred.capacity-scheduler.init-worker-threads</name>
<value>5</value>
</property>
</configuration>

```
