# Hive
> 基于Hadoop的一个数据仓库，将结构化的数据文件映射为一张数据库表
并提供简单的sql查询功能，将sql语句转换为MapReduce任务进行运行。 
建立在Hadoop文件系统上的数据仓库架构，并对存储在HDFS中的数据进行分析和管理；


* 体系结构
		* Hive 跑hadoop 上的数据仓库Facebook开源
		* 面向分布式上的大数据集合

* 数据仓库 关注业务关系型的处理在数据模型上的处理很大的
	 * 差别 报表分析 OLAP OLDP 索引通过账号来进行修改
	 * OLDP 数据仓库 非常的大
	 * 索引超过表 20%运行效率就很少了
	 
* 优势
	* 简单容易 上手 SQL查询语言HQL SQL分析查询语言
		* HQL支持大部分SQL查询 但是插入能力比较查
	* 超大数据的设计计算扩展能力
		* MR作为计算引擎 HDFS 作为存储系统
	* 统一的元数据管库 表的定义涉及什么数据文件 逻辑和对象
		* 提供给其他框架使用
	
* 不足
	* HQL 表达能力比较有限 复杂的不能表达
	* 运行速率比较
	* Hive 自动生成MapReduce 作为有不能智能
	* HQL 调优困难


* Hive 功能及其使用
  * 组件及其架构 UI
	  * 用户结构CLI JDBC/ODBC WEBUI Thrift Server
	 	  * Driver 接收查询组件
	 	  * compiler 解析查询
	 	  * Execution Engine 还行compiler的执行计划
	 	  * Metastore  一般生产使用mysql来使用执行计划

* Hive逻辑对象
	* Database 
	* Table  关系数据库中的表类似 外部表可以映射到Hive中
	* Partition 分区 一个表拥有一到多个分区 字段每个作为多个分区
	* Bucket 桶  组织分区的高级 组成 哈希列簇 来管理
	* Metastore  ---元数据存储
	 	* 数据抽象
	 	* 数据发现

* HiveQL
  * 类SQL
	* 可嵌入MapReduce 脚本
	* 共享中间结果
    *compiler
  	  * 语法分析器
  	  * 语义分析器
  	  * 逻辑计划发生器
  	  * 长训计划发生器

* Hive server
  * cli 
	* web interface  
	* ! Matastore server 保存信息 
	* ! Server 2 并发请求 管理 真正意义的数据仓库产品
	
* HiveQL
  * 创建 修改 数据库
		* create database _name 
		* comment 
	 	* llocation
	 	* key -value 方式描述信息

