# HA(High Availability)
* HA和Federaion
  * HA即为High Availability
    * 用于解决NameNode单点故障问题，该特性通过热备的方式为主NameNode提供一个备用者，一旦主NameNode出现故障，可以迅速切换至备NameNode
    * 从而实现不间断对外提供服务。Federation即为“联邦”，该特性允许一个HDFS集群中存在多个NameNode同时对外提供服务
    * NameNode分管一部分目录（水平切分），彼此之间相互隔离，但共享底层的DataNode存储资源。
  * 在一个典型的HDFSHA场景中，通常由两个NameNode组成
    * 一个处于active状态，另一个处于standby状态
    * Active NameNode对外提供服务，比如处理来自客户端的RPC请求，而Standby NameNode则不对外提供服务，仅同步active namenode的状态，以便能够在它失败时快速进行切换。
  * 为了能够实时同步Active和Standby两个NameNode的元数据信息（实际上editlog）
    * 需提供一个共享存储系统，可以是NFS、QJM（Quorum Journal Manager）或者Bookeeper，Active Namenode将数据写入共享存储系统
    * 而Standby监听该系统，一旦发现有新数据写入，则读取这些数据，并加载到自己内存中，以保证自己内存状态与Active NameNode保持基本一致
    * 如此这般，在紧急情况下standby便可快速切为active namenode。
