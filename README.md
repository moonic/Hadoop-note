# Hadoop-note

 * google 的低成本之道
    * 互联网公司在创立的时候 盈利状态不好 不会去买强大的计算机硬件
      * 导致在技术上得到不断的突破 为了对付大量数据的存储 海量数据的计算 而形成了分布式框架雏形
    
* 大量网页如何存储
    * google 搜索引擎每天 扒取的网页上亿如何存储
        - 存储在硬盘中显然是不行的 也没有这么大的容量 都存取
--- 

# Hadoop 1.0
		* 文件系统 + 计算框架
	1. 计算资源和模型的调度
	2. 集训规模受到以及调度管理能力的限制
	3. 单一的计算模型 MR

## 2.0	基于 YARN 框架的调度
	*  管理资源好模型的耦合 
	* 二级调度
	* 更多的计算机模型的支持 优秀的计算模型 避免集群中的数据移动问题

* 数据的访问 NOSQL Solr Spark Pig Cascading 
	
# YARN 数据操作系统

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
	每个Slave节点的代理程序
	为应用程序启动容器
	task构建容器环境
	所在节点提供管理本地资源的简单服务
	Container
* ApplicationMaster 
	管理APP
	代表App 向RM申请 释放计算资源 与NM交互
	管理内部的 Container	
	  生命周期
	  Failover处理
	  状态监控 VR继续执行

* YARN error
	ResourceManager 
	 单点故障 基于Zookeeper的HA
 	NodeManager
	  失败RM告诉对应的AM 决定处理失败的任务
	ApplcationMaster	
	   失败RM负责重启
	    RMAPPSMaster 保存运行完成task
* YARN confgrouter
	  tarn-site,xml
	    ect/hadoop/conf/yarn-site.xml
    通信地质类   保持资源的通信不会发生错误
    目录类
    资源类 
    安全类
    节点健康类

* 资源调度
    双层调度
	ResouceManager资源分配给ApplcationMaster	将资源げTask
    基于资源预留的调度
	当资源不够的时候为Task 预留 直到资源满足
	 异步分配
   调度算法 Dominant Resource Fairness 
  资源管理器
	FIFO Capacity Scheduler
	Fair Scheduler 
	也可以自己写算法实现

* YARN Capacity Scheduler 重点自己找资料
  * 配置文件 @操作命令 @资源管理器 重点 自己找资料 明天总结出俩

## Spark 淘宝过度 到Spark中集群中过去
  简介
   Scalc 语言的学习
   部署Spark Standalone 集群
    运行原理 编译模型 算子模型
    Spark on YARN 之上 YARN 具有队列优先级等管理关系
    Spark SQL 作为数据仓库

  分布式计算框架 分布式存起框架
   大数据二大技术 MapReduce  hadoop 一次性的数据流进行迭代
