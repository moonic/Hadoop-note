# MR2 Model

 Hadoop 0.23.0是一个通用的资源分配框架，它不仅支持MapReduce计算框架，同时也支持流式计算框架，迭代计算框架，MPI等。
 实现时采用基于了事件驱动机制，异步编程模型，如下图所示：
该图片来自《Hadoop 0.23 MRv2分析》

EventHandler被称作事件处理器， 每种事件类型对应一种EventHandler，其对事件的处理过程通过状态机来描述，handler 接收到一个事件后，使处理对象当前状态跳转到另外一个状态，同时触发一个动作。

* 状态机 
每个对象被建模成有限状态机，如：
  * RM：Application，ApplicationAttempt，Container，Node
  * AM：Job，Task，AttemptTask
  * NM：Container，Application
  * 如：application的状态机如下，刚开始application所处状态为NEW，待收到一个STARTED事件后，会转化成SUBMITTED状态。

* 基于actors model的事件模型 该模型有以下几个特点：
  * 每一个计算实体可以：
  *  向其他actor发送有限个信息
  * 收到的消息时触发一个行为
  * 创建若干个新的actor
  * 固有的并行性
  * 异步的

* 如上图所示(小写表示状态，大写表示事件)，两个actor（实际上是C++对象）对应两个不同的状态机
  * 某些actor的事件（如事件A）会触发actor内部状态的转化，而另外一些事件（如事件Y）会触发其他actor的状态转化。具体事例，在后续的文章中会提到。
  * Hadoop-0.23.0代码并不像之前的Hadoop代码那样容易阅读，由于采用了actor model，其代码逻辑具有跳跃性，往往在看某个代码块时，由于逻辑需要，会跳跃到另外一个代码块，这之后又会跳跃，….。

* 为了更容易地阅读Hadoop-0.23.0代码，本人拟按照以下步骤进行：
<1> 熟悉其主要模块（ResourceManager，NodeManager，Client，ApplicationMaster）的功能；
<2> 阅读各个模块之间的通信协议；
<3> 分别深入各个模块，画出各个对象的状态机及搞清其转化逻辑；
<4> 分析各个模块主要功能的实现方法。
