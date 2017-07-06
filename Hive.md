## Hive 功能及其使用
  * 组件及其架构 UI
	  * 用户结构CLI JDBC/ODBC WEBUI Thrift Server
	 	  * Driver 接收查询组件
	 	  * compiler 解析查询
	 	  * Execution Engine 还行compiler的执行计划
	 	  * Metastore  一般生产使用mysql来使用执行计划

*Hive逻辑对象
	* Database 
	* Table  关系数据库中的表类似 外部表可以映射到Hive中
	* Partition 分区 一个表拥有一到多个分区 字段每个作为多个分区
	* Bucket 桶  组织分区的高级 组成 哈希列簇 来管理
	* Metastore  ---元数据存储
	 	* 数据抽象
	 	* 数据发现

* 数据类型 -- 自己了解

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


* Sqoop
  * 将Hadoop和关系型数据库中的数据库相互专营的工具将一根关系系数据库
		   中的数据导入的Hadoop 中的Hive导入
