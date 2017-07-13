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
