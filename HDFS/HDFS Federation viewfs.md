# HDFS Federation viewfs

## HDFS Federation产生背景
* 在Hadoop 1.0中，HDFS的单NameNode设计带来诸多问题，包括单点故障、内存受限制约集群扩展性和缺乏隔离机制（不同业务使用同一个NameNode导致业务相互影响）等，为了解决这些问题，Hadoop 2.0引入了基于共享存储的HA解决方案和HDFS Federation，本文重点介绍HDFS Federation。
HDFS Federation是指HDFS集群可同时存在多个NameNode，这些NameNode分别管理一部分数据，且共享所有DataNode的存储资源。这种设计可解决单NameNode存在的以下几个问题：
  1. HDFS集群扩展性。多个NameNode分管一部分目录，使得一个集群可以扩展到更多节点，不再像1.0中那样由于内存的限制制约文件存储数目。
  2. 性能更高效。多个NameNode管理不同的数据，且同时对外提供服务，将为用户提供更高的读写吞吐率。
  3. 良好的隔离性。用户可根据需要将不同业务数据交由不同NameNode管理，这样不同业务之间影响很小。
需要注意的，HDFS Federation并不能解决单点故障问题，也就是说，每个NameNode都存在在单点故障问题，你需要为每个namenode部署一个backup namenode以应对NameNode挂掉对业务产生的影响。

## HDFS Federation架构
  * HDFS Federation的架构我已经在文章“HDFS 设计动机与基本原理”一文中进行了介绍，有兴趣的读者可阅读该文章。

## HDFS Federation配置介绍
  * 本节不会介绍具体的namenode和datanode的配置方法（如果想了解配置方法，可参考文章：“Hadoop升级方案（二）：从Hadoop 1.0升级到2.0（1）”和“Hadoop升级方案（二）：从Hadoop 1.0升级到2.0（2）”），而是重点介绍HDFS客户端配置方法，并通过对客户端配置的讲解让大家深入理解HDFS Federation引入的“client-side mount table”（viewfs）这一概念，这是通过新的文件系统viewfs实现的。
（1） Hadoop 1.0中的配置
在Hadoop 1.0中，只存在一个NameNode，所以，客户端设置NameNode的方式很简单，只需在core-site.xml中进行以下配置：
<property>
    <name>fs.default.name</name>
    <value>hdfs://host0001:9000</value>
 </property>
设置该参数后，当用户使用以下命令访问hdfs时，目录或者文件路径前面会自动补上“hdfs://host0001:9000”：
bin/hadoop fs –ls /home/dongxicheng/data
其中“/home/dongxicheng/data”将被自动替换为“hdfs://host0001:9000/home/dongxicheng/data”
当然，你也可以不在core-site.xml文件中配置fs.default.name参数，这样当你读写一个文件或目录时，需要使用全URI地址，即在前面添加“hdfs://host0001:9000”，比如：
bin/hadoop fs –ls hdfs://host0001:9000/home/dongxicheng/data
（2）Hadoop 2.0中的配置
在Hadoop 2.0中，由于引入了HDFS Federation，当你启用该功能时，会同时存在多个可用的namenode，为了便于配置“fs.default.name”，你可以规划这些namenode的使用方式，比如图片组使用namenode1，爬虫组使用namenode2等等，这样，爬虫组员工使用的HDFS client端的core-site.xml文件可进行如下配置：

<property>
    <name>fs.default.name</name>
    <value>hdfs://namenode1:9000</value>
 </property>
图片组员工使用的HDFS client端的core-site.xml文件可进行如下配置：

<property>
    <name>fs.default.name</name>
    <value>hdfs://namenode2:9000</value>
 </property>
从HDFS和HBase使用者角度看，当仅仅使用单NameNode上管理的数据时，是没有问题的。但是，当考虑HDFS之上的计算类应用，比如YARN/MapReduce应用程序，则可能出现问题。因为这类应用可能涉及到跨NameNode数据读写，这样必须显式的指定全URI，即输入输出目录中必须显式的提供类似“hdfs://namenode2:9000”的前缀，以注明目录管理者NameNode的访问地址。比如：
distcp hdfs://nnClusterY:port/pathSrc hdfs://nnCLusterZ:port/pathDest
为了解决这种麻烦，为用户提供统一的全局HDFS访问入口，HDFS Federation借鉴Linux提供了client-side mount table，这是通过一层新的文件系统viewfs实现的，它实际上提供了一种映射关系，将一个全局（逻辑）目录映射到某个具体的namenode（物理）目录上，采用这种方式后，core-site.xml配置如下：

<configuration xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include href="mountTable.xml"/>
    <property>
      <name>fs.default.name</name>
      <value>viewfs://ClusterName/</value>
    </property>
</configuration>
其中，“ClusterName”是HDFS整个集群的名称，你可以自己定义一个。mountTable.xml配置了全局（逻辑）目录与具体namenode（物理）目录的映射关系，你可以类比linux挂载点来理解。
假设你的集群中有三个namenode，分别是namenode1，namenode2和namenode3，其中，namenode1管理/usr和/tmp两个目录，namenode2管理/projects/foo目录，namenode3管理/projects/bar目录，则可以创建一个名为“cmt”的client-side mount table，并在mountTable.xml中进行如下配置：

<configuration>
  <property>
    <name>fs.viewfs.mounttable.cmt.link./user</name>
    <value> hdfs://namenode1:9000/user </value>
  </property>
  <property>
    <name>fs.viewfs.mounttable.cmt.link./tmp</name>
    <value> hdfs:/ namenode1:9000/tmp </value>
  </property>
  <property>
    <name>fs.viewfs.mounttable.cmt.link./projects/foo</name>
    <value> hdfs://namenode2:9000/projects/foo </value>
  </property>
  <property>
    <name>fs.viewfs.mounttable.cmt.link./projects/bar</name>
    <value> hdfs://namenode3:9000/projects/bar</value>
  </property>
</configuration>
经过以上配置后，你可以像1.0那样，访问HDFS上的文件，比如：
bin/hadoop fs –ls /usr/dongxicheng/data
中的“/usr/dongxicheng/data”将被映射成“hdfs://namenode1:9000/user/dongxicheng/data”。
Client-side mount table的引入为用户使用HDFS带来极大的方便，尤其是跨namenode的数据访问。
4. 参考资料
（1） User Guide for how to use viewfs with federation
（2）Hadoop 23 – dotNext
（3）Hadoop 2.0 NameNode HA和Federation实践
