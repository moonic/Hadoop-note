# Spark Runtime

* Spark file 
	* Spark 分布式计算框架
	* Local  单机模式 本地开启一些线程来完成任务
	* Standalone model 运行在专门的管理器上面
	* YARN model
	* Mesoes mode

* Spark 基本概念
	* Applcation 基于spark用户应用程序包 	包含了driver program 集群中多个executor
	* Driver Program 运行Applcation main函数并创建
		SparkContext 
	* Executor 为应用程序运行在worker node上的进程上
	* 进程复制运行Task 并负责数据存在内存或者磁盘上
	* Custer Manager 集群上获取资源的外部服务
	* Worker Node 集群中运行Applcation代码的节点提供这样的资源管理功能 提供计算框架
	* Task 送到executor上执行的单元
	* job 拆分成Tasj并执行计算的单元 soark Actaion
	* Stage job被拆臣Task 每组称为
	* DAGScheduler 更具job 基于Stage DAG提交stage 给TaskScheduler
	* Transformations spakr API 的类型 返回一个RDD采用策略

* 一切以 RDDW为基础
	* 容错的并行的数据类型 soark 控制所有数据的基本抽象
		* 不变的数据存储结构
		* 支持跨集群的分布式数据结构
		* 更具记录的key对结构进行分区
		* 提供范粗粒操作
		* 数据存在的内存中 提供了低延迟的特性

* RDD产生
		* 并行化Scaka集合
		* 通过外部数据源获得 hdfs hbase
		* 通过其他的RDD变换

* Transformations
	* mapPartitions Similar to map but runs separately on  each partition block of the  RDD so  func must be of type Iterator when running on an Rdd of type 

	 * mapPartitionsWithIndex Similar to  mapPartitions but  also provides func with an integer value representing the index of the partition

	 * sample sample a fraction fraction of the data with or without  replcaiton using a give random number generator seed 

* 宽依赖与窄依赖
	* 字RDD每个风趣雨来所用RDD 分区对RDD基于
		key 进行重组reduce 比如 groupBykey reduceBykey
	* 对二个RDD基于key进行join重组比如join 经过大量
		shuffle 生成RDD进程缓存避免失败进程重新计算的开销
			reduce是action reduceBtkey 完完全全不同.

	 * 所有的RDD进行依赖

	*  Transformations 
		* groupBykey when called on a  database of pairs returns a databaset of pairs Note IF toy  are grouping in order to perform an aggregation Observer each key

	*  Actions 
	 	reduce() Aggregate the elements of the database using 
	 		a function func The functioni should be commutative and 
	 		  associative so that it can be compute correctly 
	 	collect() Return all the elements of the databaset as  an 
	 		array at the driver program This is usually useful after 
	 			a filter of other operation that returns 
	 	count()  foreach() takesample()
	
	RDD 缓存
		spark 使用 persist cache 将任意RDD缓存到内存 磁盘文件系统
		 缓存是容错的一个RDD分片丢失 可以通过构建 transformation
		 被缓存RDD被使用的时候 存取速度会被大大加速 60做cache其余的task
	#内存对象管理 自学
		rdd.persist() rdd.cache() rdd.unpersist()

* RDD 共享变量 广播变量 和累加器
		广播变量
			缓存到各个节点的内存中 而不是每个Task
			被创建 能在集群运行 所有的函数调用
			只读的不能再 被广播后修改

		累加器
			只支持加法操作可以高效的并行 使用计算和变脸的求和
			 支持数据类型的标准可以使用集合的计数器 用户可以添加新的类型
			  只用驱动程序才能故去累积器的值
* RDD 模型优势
		低不变 好粗颗粒模型 一致性 性能
		低错误 容灾错
		数据本地化 RDD分区任务调度
		尽管受到 Transformations Actions Model 的限制RDD 并行Mapred

* spark on YARN
	YARN环境运行 按照spark应用程序中driver 分布式不同
	   yarn-client 模型运行 在客户机上面卞 yarn申请运行exeutoryunxtask
	   yarn-cluster 作为一个 appMaster在yarn集群 中启动然后
	   	向RM申请资源启动execut运行Task
* 运行模式下设置的模式变量
	exprort SPARK_YARN_USER_ENV =
	spark.yarn.ApplcationMaster 10 RM 等待spark APPMaster 启动次数
	spark.yarn.submit.file.replcation 3 HDFS 文件复制因子
	perserve.staging.files false  true job 结束将stage 相关文件保留
	提交应用程序的TARN 队列名称 默认default 队列
	工作目录 yatn 中的 NodeManager

* Spark SQL 类数据仓库模式
	* Integrated 
	  * seemlessly mix SQL queries with spark programs 
	  	Unified Data Access 
	  		Load and query data from a varitety of sources 
	 * Hive Compatibilirt 
	 		* Run ummodified Hive Queries on existing warehouses 
	 * Standard Connectivity 
	 		* Connect through JDBC or ODBC

* RDD Schema 
	spark + RDDs 对可区分模糊集合功能的装换

	SQL + SchemaRDDs 对开发区元组 

* spark SQL
	SQLContext 
		所有SQL功能的人口
		SparkContext 封装和扩展
		val sc:SparkContext // AN existing SparkContext
		val sqlCoontext = new org.apache.spark.sql

* RDD 转成关系 Relation
	// Define the schema using a case class
	case class person(name:String ,age:Int)
	// Create an RDD of persion objects and register it as a table 
	val people = sc.textFile().map(_.split)
	people.regosterAstable

* 内存缓存表
	spark SQL 使用内存对垒机构来缓存表
		查询所需要的列
		分配更少的对象
		自动选择最佳的压缩模式
