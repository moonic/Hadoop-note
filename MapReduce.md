# MapReduce
> 用于数据处理的编程模型 可以让Hadoop运行各种语言编写的MapReduce程序

* 使用Hadoop进行数据分析
  * 提供的并行处理机制将 MapReuce作业
  

* Map and reduce
	* Map
		* 输入原始NCD数据 选择每一行为文本输入输出格式
		* 使用Map函数找出年份和气温 作为输人发送
		* reduce函数 对数据处理让后进行分组


```java

Java MapReuce
	
	public class MaxTemperatureMapper extends MapReuceBase 
		implements Mapper<LongWritable,Text,Text,IntWritable>{

		private static final int Missing = 9999;

		public void map(LongWritable key,Text value,
			OutputCollector<Text,IntWritable>output,Reporter reporter) theros IOException{
				String line = value.toString();
				String year = line.substring(15,19);

			int airTemperature;
			if(linme.charAt(54))
		}
	}
```

* Mapper 接口是一个泛型类型 4个形式参数指定amp的输入输出类型


### 分布化
	* 作为大数据流进行输入

* 数据流
	* job是客户执行的单位 包括输入数据
	MapReduce 程序配置信息 分成Task来工作
	* map reduce任务
	
	
