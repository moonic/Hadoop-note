# Hadoop 发展史
 
* 生活被数据包围 用户的数据指数级增长使得机器存储更多的数据
	 * 数据的增加而让商业软件 SEO西药获得 用户的需求
	 * Google MapReduce 来适用庞大的数据 
	 * Doug Cutting开源版本的MapReduce
	 * Hadoop成为很多平台的核心部分

* Hadoop大规模分布式数据处理成为关键性技能
	* 分布式系统和数据处理系统方面的定位 MapReduce定位模型


## Hadoop
> 开源框架 编写运行分布式 应用处理的大规模数据
分布式技术是宽泛不断变化的领域 

* 方便 
	* 部署在商用机器上的大型集群上 EC2 亚马逊的计算云
* 健壮 
	* 致力于在商用硬件运行 容许大量类似故障
* 可扩展 
	* 通过增加几区节点 线性扩展处理更大的数据集
* 简单 
	* 运行用户快速编写高校并行的代码


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
				* 为离线处理大规模数据分析而设计 不合适对纪律随机查写
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

* 发展史
	* Apache Lucene 子项目 全文本索引查询库 给顶一个文本集合
		* 根加方便的搜索 建立一个完整的web搜索银杏
	* Google 论文 GFS文件系统  MapReduce框架
		* 将Nutch 移植上去 提升了可扩展性 处理几亿个网页 运行在今节点集群上
	* 专业项目实行网络扩展需要的技术出来了hadoop


* Hadoop 构建模块
	* 全配置的集群运行Hadoop 不同服务器运行守护进程daemons 守护
		* NameNode DataNode
			* 分布式计算你与分布式存储才去 主从 master slave结构
			* Hadoop文件系统HDFS NameNode 位于HDFS主端
			* 执行地城IO任务 NameNode追踪文件如何被分成文件块
			* 
		* Secondary NameNode
		* JobTracker 
		* TaskTracker



