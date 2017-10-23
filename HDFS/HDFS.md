#  HDFS 
* 高度容错性的系统，适合部署在廉价的机器上。
  * 提供高吞吐量的数据访问，非常适合大规模数据集上的应用。
  * 放宽了一部分POSIX约束，来实现流式读取文件系统数据的目的。
	* 最开始是作为Apache Nutch搜索引擎项目的基础架构而开发的。
	   * Apache Hadoop Core项目的一部分
     
## data Model
* 类似文件系统 目录和文件保存数据 Znode  
  * 临时节点
  * 序列节点
 	* 原子操作 读写 
	* 访问控制 Perm ALL READ WRITE CREATE DELETE ADMIN 

* 提供非常简单的编程接口
	支持 监听 Client Zndoe设置监听

* 统一命名访问 Name Service
	* create wir PERSISTENT_SEQUENTIAL
	* 配置管理 confguration management
	* 集群管理  Group Membership
	* Masters watch + EPHEMERAL_SEQUENTAL
 		* Slaves getChidren to find masters 

* 共享锁 Locks	
	* create with EPHEMERAL
	*列队管理
		* P:List of create with EPHEMERAL_SEQUEMTIAL
		* C：getChildren wath create tag zonde

* HDFS 高可用性
	NameNode 存在单节点故事 SPOF 对于一个NameNode 分区
	  出现意外 整个集群 将无法使用
	HA Active/Standby 实现在NameNode 热备来解决问题
	稳定的实现是基于 Qurom journal Manager 机制
   QJM Journal Node节点 来达到高可用性
	原理是 用2N+1 JQM save EditLog 写数据占用大多

* HDFS 的集中缓存管理
	* 提供了缓存加速机制 Centralized Cache anagement
 	* 读取到pin到内存
	* 为了锁定内存
	* 依赖JNI使用libhadoop.so POSIX资源限制

* HDFS 缓存管理
     * cache Directive 是缓存path 是目录包括目录下的文件 
	      * 不包括子文件 replcaiton 缓存的副本
        * cache pool 管理实体 unix 权限限制用户组 访问缓存
        * 运行用户向关村添加 删除缓存指令
	      * 读写 加一个TTL 最大值
