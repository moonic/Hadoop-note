Spark -shell spark submint
	--yarn-client yarn-cluster 设置在哪运行的参数 
	master MASTER_URL 集群运行的地址
	-class CLASS_NAME spark submit 运行程序类名
	-name NAME 应用程序的名称
	-jars driver本地宝 以及executor类的路径
	conf Arbitrary Spark configuration key=value
	in quotes spaces wrap 

spark-conf.sh
    #Default system properties included when running spakr-submit 
    #This is usefor setting default environmental setings 
	
    spark.master spark://master:7077
    spark.eventLog.enabled true
	spark.serializer 
	spark.driver.memory 5g
	spakr-executor.extaJavaOptions 
	Dkey=value -Dnumbers ="one two three"

Local model 
	本地单机模式 用来测试spark代码 启动几个线程来处理spark应用程序
	常用的环境变量
	  export spark_home =/usr/lib/spark
	  export java_home
	  exprot  Scalc_home
	  exprot CLASS_home
	  examples path 

Standalone model 
	spakr Master-Worker slave 架构在部署之前确认
		Master-Worker 机器配置在slaves文件中
	HDFS 中的数据
	Standalone 运行的参数 driver失败后会重启
	total -executor-cores num 的总核数
