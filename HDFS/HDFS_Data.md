# HDFS Data
> HDFS中存放的数据文件很大，以数据节点的形式保存在文件中Data_Node

* 读取数据
  * 先调用FileSystem对象的open方法 
  * 获取的是一个DistributedFileSystem的实例
    * DistributedFileSystem通过RPC(远程过程调用)获得文件的第一批block的locations
    * 同一block按照重复数会返回多个locations这些locations按照hadoop拓扑结构排序，距离客户端近的排在前面。
  * 前两步会返回一个FSDataInputStream对象，该对象会被封装成 DFSInputStream对象
      * DFSInputStream可以方便的管理datanode和namenode数据流。客户端调用read方 法
        * DFSInputStream就会找出离客户端最近的datanode并连接datanode。
  * 数据从datanode源源不断的流向客户端
  * 如果第一个block块的数据读完了 就会关闭指向第一个block块的datanode连接，接着读取下一个block块。这些操作对客户端来说是透明的
    * 从客户端的角度来看只是读一个持续不断的流。
  * 如果第一批block都读完了，DFSInputStream就会去namenode拿下一批blocks的location，然后继续读
    * 如果所有的block块都读完，这时就会关闭掉所有的流。

* 写数据
  * 客户端通过调用 DistributedFileSystem 的create方法，创建一个新的文件。
  * DistributedFileSystem 通过 RPC（远程过程调用）调用 NameNode，去创建一个没有blocks关联的新文件。
    * 创建前，NameNode 会做各种校验，比如文件是否存在，客户端有无权限去创建等。如果校验通过，NameNode 就会记录下新文件，否则就会抛出IO异常。
  * 前两步结束后会返回 FSDataOutputStream 的对象，和读文件的时候相似
    * FSDataOutputStream 被封装成 DFSOutputStream，DFSOutputStream 可以协调 NameNode和 DataNode。
      * 客户端开始写数据到DFSOutputStream,DFSOutputStream会把数据切成一个个小packet，然后排成队列 data queue。
  * DataStreamer 会去处理接受 data queue，它先问询 NameNode 这个新的 block 最适合存储的在哪几个DataNode里
    * 比如重复数是3，那么就找到3个最适合的 DataNode，把它们排成一个 pipeline。DataStreamer 把 packet 按队列输出到管道的第一个 DataNode 中
      * 第一个 DataNode又把 packet 输出到第二个 DataNode 中，以此类推。
  * DFSOutputStream 还有一个队列叫 ack queue，也是由 packet 组成，等待DataNode的收到响应
    * 当pipeline中的所有DataNode都表示已经收到的时候，这时akc queue才会把对应的packet包移除掉。
  * 客户端完成写数据后，调用close方法关闭写入流。
  * DataStreamer 把剩余的包都刷到 pipeline 里 等待 ack 信息，收到最后一个 ack 后，通知 DataNode 把文件标示为已完成。
