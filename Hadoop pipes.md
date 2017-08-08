# Hadoop pipes

Hadoop pipes允许用户使用C++语言进行MapReduce程序设计。
它采用的主要方法是将应用逻辑相关的C++代码放在单独的进程中，然后通过Socket让Java代码与C++代码通信。
从很大程度上说，这种方法类似于Hadoop Streaming，不同之处是通信方式不同：一个是标准输入输出，另一个是socket。
org.apache.hadoop.mapred.pipes.Submitter包中有一个public static方法用于提交作业,该方法将作业封装成一个JobConf对象和一个main方法（接收一个应用程序，可选的配置文件，输入目录和输出目录等），main方法的CLI(Client Line Interface)如下：

bin/hadoop pipes \
 
[-input inputDir] \ #输入数据目录
 
[-output outputDir] \ #输出数据目录
 
[-jar applicationJarFile] \  #应用程序jar包
 
[-inputformat class] \ #Java版的InputFormat
 
[-map class] \ #Java版的Mapper
 
[-partitioner class] \#Java版的Partitioner
 
[-reduce class] \#Java版的Reducer
 
[-writer class] \ #Java版的 RecordWriter
 
[-program program url] \  #C++可执行程序
 
[-conf configuration file] \#xml配置文件
 
[-D property=value] \ #配置JobConf属性
 
[-fs local|namenode:port] \#配置namenode
 
[-jt local|jobtracker:port] \#配置jobtracker
 
[-files comma separated list of files] \ #已经上传文件到HDFS中的文件，它们可以像在本地一样打开
 
[-libjars comma separated list of jars] \#要添加到classpath 中的jar包
 
[-archives comma separated list of archives]#已经上传到HDFS中的jar文件，可以 在程序中直接使用
本文主要介绍了Hadoop pipes的设计原理，包括设计架构，设计细节等。
2.	Hadoop pipes设计架构

用户通过bin/hadoop pipes将作业提交到org.apache.hadoop.mapred.pipes中的Submmit类，它首先会进行作业参数配置（调用函数setupPipesJob），然后通过JobClient(conf).submitJob(conf)将作业提交到Hadoop集群中。
在函数setupPipesJob中，Java代码会使用ServerScoket创建服务器对象，然后通过ProcessBuilder执行C++binary， C++binary实际上是一个Socket client，它从Java server中接收key/value数据，经过处理（map，partition或者reduce等）后，返还给Java server，并由Java Server将数据写到HDFS或者磁盘。
3.	Hadoop pipes设计细节
Hadoop pipes允许用户用C++编写五个基本组件：mapper，reducer，partitioner，combiner，recordReader，这五个组件可以是Java编写的，也可以是C++编写的，下面分别介绍这几个函数的执行过程。

（1）	mapper
Pipes会根据用户的配置定制InputFormat，如果用户要使用Java的InputFormat（hadoop.pipes.java.recordreader=true），则Hadoop会使用户输入的InputFormat（默认为TextInputFormat）；如果用户使用C++的InputFormat，则Pipes Java端的代码会读取每个InputSplit，并调用downlink.runMap(reporter.getInputSplit(), job.getNumReduceTasks(), isJavaInput);通过socket传输给C++端的runMap(string _inputSplit, int _numReduces, bool pipedInput)函数。
在C++端，RecordReader会解析整个InputSplit，获取数据来源（主要是文件路径）和每个key/value对，并交给map函数处理，map将每个key/value的处理结果通过emit(const string& key, const string& value)函数返还给Java Server。
（2）	paritioner
C++端处理完的结果会通过emit(const string& key, const string& value)函数传给Java Server，以便将数据写到磁盘上。在emit函数中，如果用户定义了自己的paritioner，则Pipes会通过该函数判断当前key/value将给哪个reduce task处理，并调用partitionedOutput(int reduce, const string& key,const string& value)函数将key/value传递给相应的reduce task。
（3）	reducer
reducer的执行过程与mapper基本一致。

4.	总结
Hadoop pipes给C++程序员提供了一个编写MapReduce作业的方案，它使用socket让Java和C++之间进行通信，这类似于thrift RPC的原理，也许Hadoop Pipes用thrift编写会更加简单。
Hadoop pipes使用Java代码从HDFS上读写数据，并将处理逻辑封装到C++中，数据会通过socket从Java传输给C++，这虽然增加了数据传输的代价，但对于计算密集型的作业，其性能也许会有改进。

5.	参考资料
http://wiki.apache.org/hadoop/HowToDebugMapReducePrograms
http://cs.smith.edu/dftwiki/index.php/Hadoop_Tutorial_2.2_–_Running_C%2B%2B_Programs_on_Hadoop
http://www.itberry.com/?p=42
