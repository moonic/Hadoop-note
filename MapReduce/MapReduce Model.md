# MapReduce


* Mapper 
> 普通类作为Mapper 继承MapReduceBase 并实现 Mapper 接口

* 构造解析方法
	* void configure jobconf job 
	* void close()


* Mapper 接口负责 数据处理 Mapper<k1,v1,k2,v2> java泛型
	* void map(k1 key,
		V1 value,
		OutputCollector<k2,v2>output
		Reporter reporter
	)

* 给定键值对并生成一个 列表 OutputCollector接到并输出
	* IdentityMapper K,V  直接输出
	* InverseMapper  K,V  反转
	* RegexMapper<K>     实现Mapper
	* TokenCountMapper   生成一个token，1 对


* Reducer
	* MapReduce基类上扩展 运行配置实现接口单一方法
	* Reduce任务 接到输出时候 排序低啊用reduce()函数
	* 迭代生成列表

* Partitoner 重定向Mapper输出
	* 多个reducer 采取方法确认Mapper输出给谁
	* HashPartitioner 类前置执行策略
* 定制 Partitoner 
	* 实现configure()和getPartition函数
	* 返回一个 reduce 任务之间的整数

```java
	public class EdgePartitoner implements Partitoner<Edge,Writable>{

		public int getDepartureode(Edge key ,Writable value,int numPartitoner){
			return key.getDepartureode().hashCode()%numPartitoner;
		}
		public void configure (JobConf conf){}

		}

}


```

* combiner 本地Reduce
	* 分发Mapper结果之前 本地化Reduce

* 预定义类 重整 mapper reducer 类

···java
	public class WordCountor2{
		public static void main(String[] args) {
			JobClient client = new JobClient();
			JobClient conf = new JobConf(WordCount2.class);

			FilesInputFormat.addInputPath(conf,new Path(args[0]));
			FileOutputFormat.setOutputPath(conf,new Path[args[1]])
		
			conf.setOutputPathKeyClass(Text.class);
		}
	}



```
