# small paper

小文件是指文件size小于HDFS上block大小的文件。这样的文件会给hadoop的扩展性和性能带来严重问题。首先，在HDFS中，任何block，文件或者目录在内存中均以对象的形式存储，每个对象约占150byte，如果有1000 0000个小文件，每个文件占用一个block，则namenode大约需要2G空间。如果存储1亿个文件，则namenode需要20G空间（见参考资料[1][4][5]）。这样namenode内存容量严重制约了集群的扩展。 其次，访问大量小文件速度远远小于访问几个大文件。HDFS最初是为流式访问大文件开发的，如果访问大量小文件，需要不断的从一个datanode跳到另一个datanode，严重影响性能。最后，处理大量小文件速度远远小于处理同等大小的大文件的速度。每一个小文件要占用一个slot，而task启动将耗费大量时间甚至大部分时间都耗费在启动task和释放task上。
本文首先介绍了hadoop自带的解决小文件问题的方案（以工具的形式提供），包括Hadoop Archive，Sequence file和CombineFileInputFormat；然后介绍了两篇从系统层面解决HDFS小文件的论文，一篇是中科院计算所2009年发表的，用以解决HDFS上存储地理信息小文件的方案；另一篇是IBM于2009年发表的，用以解决HDFS上存储ppt小文件的方案。
2、  HDFS文件读写流程
在正式介绍HDFS小文件存储方案之前，我们先介绍一下当前HDFS上文件存取的基本流程。
(1)  读文件流程
1）client端发送读文件请求给namenode，如果文件不存在，返回错误信息，否则，将该文件对应的block及其所在datanode位置发送给client
2） client收到文件位置信息后，与不同datanode建立socket连接并行获取数据。
(2) 写文件流程
1） client端发送写文件请求，namenode检查文件是否存在，如果已存在，直接返回错误信息，否则，发送给client一些可用datanode节点
2） client将文件分块，并行存储到不同节点上datanode上，发送完成后，client同时发送信息给namenode和datanode
3）  namenode收到的client信息后，发送确信信息给datanode
4）  datanode同时收到namenode和datanode的确认信息后，提交写操作。
3、  Hadoop自带的解决方案
对于小文件问题，Hadoop本身也提供了几个解决方案，分别为：Hadoop Archive，Sequence file和CombineFileInputFormat。
（1） Hadoop Archive
Hadoop Archive或者HAR，是一个高效地将小文件放入HDFS块中的文件存档工具，它能够将多个小文件打包成一个HAR文件，这样在减少namenode内存使用的同时，仍然允许对文件进行透明的访问。
对某个目录/foo/bar下的所有小文件存档成/outputdir/ zoo.har：
hadoop archive -archiveName zoo.har -p /foo/bar /outputdir
当然，也可以指定HAR的大小(使用-Dhar.block.size)。
HAR是在Hadoop file system之上的一个文件系统，因此所有fs shell命令对HAR文件均可用，只不过是文件路径格式不一样，HAR的访问路径可以是以下两种格式：
har://scheme-hostname:port/archivepath/fileinarchive
har:///archivepath/fileinarchive(本节点)
可以这样查看HAR文件存档中的文件：
hadoop dfs -ls har:///user/zoo/foo.har
输出：
har:///user/zoo/foo.har/hadoop/dir1
har:///user/zoo/foo.har/hadoop/dir2
使用HAR时需要两点，第一，对小文件进行存档后，原文件并不会自动被删除，需要用户自己删除；第二，创建HAR文件的过程实际上是在运行一个mapreduce作业，因而需要有一个hadoop集群运行此命令。
此外，HAR还有一些缺陷：第一，一旦创建，Archives便不可改变。要增加或移除里面的文件，必须重新创建归档文件。第二，要归档的文件名中不能有空格，否则会抛出异常，可以将空格用其他符号替换(使用-Dhar.space.replacement.enable=true 和-Dhar.space.replacement参数)。
（2） Sequence file
sequence file由一系列的二进制key/value组成，如果为key小文件名，value为文件内容，则可以将大批小文件合并成一个大文件。
Hadoop-0.21.0中提供了SequenceFile，包括Writer，Reader和SequenceFileSorter类进行写，读和排序操作。如果hadoop版本低于0.21.0的版本，实现方法可参见[3]。
（3）CombineFileInputFormat
CombineFileInputFormat是一种新的inputformat，用于将多个文件合并成一个单独的split，另外，它会考虑数据的存储位置。
4、  小文件问题解决方案
上一节中提到的方案均需要用户自己编写程序，每隔一段时间对小文件进行merge以便减少小文件数量。那么能不能直接将小文件处理模块嵌到HDFS中，以便自动识别用户上传的小文件，然后自动对它们进行merge呢？
本节介绍了两篇论文针试图在系统层面解决HDFS小文件问题。这两篇论文对不同的应用提出了解决方案，实际上思路类似：在原有HDFS基础上添加一个小文件处理模块，当一个文件到达时，判断该文件是否属于小文件，如果是，则交给小文件处理模块处理，否则，交给通用文件处理模块处理。小文件处理模块的设计思想是，先将很多小文件合并成一个大文件，然后为这些小文件建立索引，以便进行快速存取和访问。
论文[4]针对WebGIS系统的特点提出了解决HDFS小文件存储的方案。WebGIS是结合web和地理信息系统(GIS)而诞生的一种新系统。在WebGIS中，为了使浏览器和服务器之间传输的数据量尽可能地少，数据通常被切分成KB的小文件存储在分布式文件系统中。论文结合WebGIS中数据相关性特征，将保存相邻地理位置信息的小文件合并成一个大的文件，并为这些小文件建立索引以便对小文件进行存取。

该论文将size小于16MB的文件当做小文件，需将它们合并成64MB(默认的block size)，并建立索引，索引结构和文件存储方式见上图。索引方式是一般的定长hash索引。
论文[5]针对Bluesky系统(http://www.bluesky.cn/)的特点提出了解决HDFS小文件存储的方案。Bluesky是中国电子教学共享系统，里面的ppt文件和视频均存放在HDFS上。该系统的每个课件由一个ppt文件和几张该ppt文件的预览快照组成。当用户请求某页ppt时，其他相关的ppt可能在接下来的时间内也会被查看，因而文件的访问具有相关性和本地性。本文主要有2个idea：第一，将属于同一个课件的文件合并成一个大文件，以提高小文件存储效率。第二，提出了一种two-level prefetching机制以提高小文件读取效率，即索引文件预取和数据文件预取。索引文件预取是指当用户访问某个文件时，该文件所在的block对应的索引文件被加载到内存中，这样，用户访问这些文件时不必再与namenode交互了。数据文件预取是指用户访问某个文件时，将该文件所在课件中的所有文件加载到内存中，这样，如果用户继续访问其他文件，速度会明显提高。
下图展示的是在BlueSky中上传文件的过程：

下图展示的是在BlueSky中阅览文件的过程：

5、  总结
Hadoop目前还没有一个系统级的通用的解决HDFS小文件问题的方案。它自带的三种方案，包括Hadoop Archive，Sequence file和CombineFileInputFormat，需要用户根据自己的需要编写程序解决小文件问题；而第四节提到的论文均是针对特殊应用提出的解决方案，没有形成一个比较通用的技术方案。
