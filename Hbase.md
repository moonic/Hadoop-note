## Hbase NOSQL（Big Table 论文）

> HBase在Hadoop之上提供了类似于Bigtable的能力。
适合于非结构化数据存储的数据库。另一个不同的是HBase基于列的而不是基于行的模式。

* 目的
	* 廉价PC Server上搭建起大规模结构化存储集群。

* 模型
	* 逻辑模型
		* 有序映射的映射集合
	* 物理模型
		* 面向列族
	* 数据模型
		 * 列表来存储数据。这是在关系型数据库里面的说法，但这种描述并不确切，这可以帮助理解HBase表的多维映射


* 分布式面向列簇的数据存储系统位于HDFS的上层
		  * apache开源项目 Hadoop分布式的生态成员
		  * 数据逻辑上为组织表 行和列

* Hbase vs HDFS （重点）
	* 都是分布式存储系统 可扩展到上千个界定规模
	* 没有随机读取就使用HDFS 


* HDFS 批处理
		不能个别查找 不能记录更新操作

* Hbase
		解决上面的为题
			快速记录查找
			支持记录插入
			支持更新
		创建新版本数据的方式完成

*  Hbase VS RDBMS
	* 列簇      行
	* 单行      ACID事务
	* get/put/scan SQL
	* rowkey    二级索引任意列	 
	* TB 		   PB
	* 非常好	 依赖中间层牺牲功能

* 特点
	* 表只能有一个主键 row key
	* 没有join
	* 列式存储 扫描查询作为列

* 集群
	* Hbase Master   Zookeeper Server (无法保存到本地 获取元数据信息)

	
	NodeManager 
	Hbase RegionServer 
	dataNode 

* 数据模型（big table）
	* 稀疏列簇模式
	* 每行有一个key 
	* 每个记录分割成诺干列簇 column Families 
	* 每个列簇包一个多个列

* cell qualifier 单元修饰符
	Timestamp 时间睉
	Region 区域 

* row key
	* 表中的行是字节数组 最大长度为64kb
	* 任何字符串作为键
	* 表中的行键值进行排序 按照Row key
	* byte order排序

Column Family

* 逻辑视图 
* 物理视图
	
  * HFIle 格式结构
		* 基本的元数据是不能被压缩的
		* hash列簇的结构

* Hbase 表的特点
	   * 大 面向列 稀疏 
	   * 每个cell中的数据可以有多个版本 
* Hbase是字符串没有类型
	* 强一致性
	* 水平伸缩
	* 行事务
	* 支持单行查询方式 和一级索引
	* 支持行书屋
	* 支持三种查询方法
	* 基于rowkey索引
	* 高性能的随机写
* Hadoop 无缝集成
	* 可以直接谢雨Hbase
	* 存放在Hbase数据直接通过Hadoop来分析
  * Hbase Shell DDL 等语法 自己了解
  * 权限管理 bulkload等操作


* Hbase 架构
	* 依赖Zookeeper
	* 保证任何时候 集群只有一个master
	* 存储所用的Region 寻址入口
	* 实时监控Region Server 上线和下线信息
	* 存储Hbase的schema table 元数据

* Hbase Compaction 
	* 防止小文件过多 保证查询的效率
	* 必要的时候将小文件合成相对较大的文件
	* 成为compaction
	* 合并文件
	* 清楚删除 过期 多余版本的数据
	* 提高读写数据的效率
		二类 Compaction

* Hbase Design Tuning Tips 
	* 同列簇最后有相同的业务数据模式
	* 表中必要定义太多列
	* 适当预分区
	* Rowkey设计唯一 必要太长
	* 更具业务设计 I你memory TTL MaxVersion等值
	* 适当Major Compaction 不要在高峰期执行

