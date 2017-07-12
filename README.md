# Big Data 
 
* 我们的生活被数据包围 用户的数据指数级增长使得机器存储更多的数据
	 * 数据的增加而让商业软件 SEO西药获得 用户的需求
	 * Google MapReduce 来适用庞大的数据 
	 * Doug Cutting开源版本的MapReduce
	 * Hadoop成为很多平台的核心部分

* Hadoop大规模分布式数据处理成为关键性技能
	* 分布式系统和数据处理系统方面的定位 MapReduce定位模型

---

## Hadoop

 * google 的低成本之道
    * 互联网公司在创立的时候 盈利状态不好 并不会去买强大的计算机硬件
      * 导致在技术上得到不断的突破 为了对付大量数据的存储 海量数据的计算 而形成了分布式框架雏形
    
* 大量数据如何存储
	* google 搜索引擎每天 扒取的网页上亿如何存储
		* 存储在硬盘中显然是不行的 也没有这么大的容量的存取

* 故障如何解除
	* 发生故障的时候使用数据的副本 就是余磁盘列的工作方式
	* 数据合并 各种不同的分布式系统组合起来多个来源是数据
	如何保证正确性
		* MapReduce提供了编程模型 解决读写的问题
			* Map Reduce 接口就是整合

* 提供了一个稳定的共享存储和分析系统作为Hadoop的核心功能存在

--- 

## Hadoop 1.0
	* 文件系统 + 计算框架
		1. 计算资源和模型的调度
		2. 集训规模受到以及调度管理能力的限制
		3. 单一的计算模型 MR

## 2.0	基于 YARN 框架的调度
	*  管理资源好模型的耦合 
	* 二级调度
	* 更多的计算机模型的支持 优秀的计算模型 避免集群中的数据移动问题

* 数据的访问 NOSQL Solr Spark Pig Cascading 
	
* 网格计算
	* 高性能计算和网格计算在做大规模的数据处理
	* 将信息传递接口一样的API
		* 就是作业分配给机器集群 访问文件系统
	* 一个存储区域网络进行管理 当节点访问大量数据的时候成为问题

---

### Hadoop子项目


* Core 分布式文件系统通用组件的接口
* Avro 高效跨语言的RPC数据系列系统 持久化数据存储
* MapReduce 分布式数据处理模型
* HDFS 分布式文件系统
* Pig 数据流语言的运行环境 检测数据集合
* Hbase 分布式 列式 数据库
* ZooKeeper 分布式高可用性的协调服务
* Hive 分布式数据仓库 提供基于SQL的查询语言
* Chukwa 分布式数据收集分析系统


### YARN 数据操作系统

* YARN = Yet Another Resource Negotiator 
	  * 单独MarReduce作业
	  *  RM 与NodeManager 每个节点组成的数据计算管理框架

* 核心组件 ResiurceManager	
   * 复制各个NodeManager的资源进行管理和调度 由二个组件
* 调度器 
	 * Scheduler 更具容量 队列等限制条件将资源给APP
	* ASM 应用资源管理器
	  * 系统的启动程序包括系统程序的提交与调度器的启动 	

* NodeManager  申请容器的使用
	* 每个Slave节点的代理程序
	* 为应用程序启动容器
	* task构建容器环境
	* 所在节点提供管理本地资源的简单服务
	* Container

* ApplicationMaster 
	* 管理APP
	* 代表App 向RM申请 释放计算资源 与NM交互
	* 管理内部的 Container	
	   * 生命周期
	   * Failover处理
	   * 状态监控 VR继续执行

* YARN error
	* ResourceManager 
	 * 单点故障 基于Zookeeper的HA
 	* NodeManager
	  * 失败RM告诉对应的AM 决定处理失败的任务
	* ApplcationMaster	
	   * 失败RM负责重启
	    * RMAPPSMaster 保存运行完成task
* YARN confgrouter
	  * tarn-site,xml
	   * ect/hadoop/conf/yarn-site.xml
   * 通信地质类   保持资源的通信不会发生错误
   * 目录类
   * 资源类 
   * 安全类
   * 节点健康类

* 资源调度
* 双层调度
	* ResouceManager资源分配给ApplcationMaster	将资源げTask基于资源预留的调度
	* 当资源不够的时候为Task 预留 直到资源满足
	* 异步分配
	* 调度算法 Dominant Resource Fairness 
	* 资源管理器
	FIFO Capacity Scheduler
	Fair Scheduler 
	也可以自己写算法实现

* YARN Capacity Scheduler 重点自己找资料
  * 配置文件 @操作命令 @资源管理器 重点 自己找资料 明天总结出俩

## Spark 淘宝过度 到Spark中集群中过去
 * Scalc 语言的学习
    * 部署Spark Standalone 集群
    * 运行原理 编译模型 算子模型
    * Spark on YARN 之上 YARN 具有队列优先级等管理关系
    * Spark SQL 作为数据仓库
    
* 分布式计算框架 分布式存起框架
	* 大数据二大技术 MapReduce  hadoop 一次性的数据流进行迭代
