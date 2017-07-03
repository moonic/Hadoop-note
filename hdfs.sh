HDFS config 
	dfs.replicaiton 
	dfs.namenode.name.dir  /dfs/nn 
	dfs.datanode.data.dir 
	dfs.datanode.du.reserved
	dfs.blocksize 
	dfs.datanode.address 
	dfs.namenode.http.address
	dfs.hearbeat.interval  

HDFS Shell
	df (-h human-readable)
	du (0s summary) file count 
	hdfs dfs -mkdri /tmp/test 
	和普通的linux机制一样

HDFS 基本权限控制 Linux.unix file bil counter model 
	dfs.permsission = true 
	dfs.permissiions,supergroup = hdfs 
	chmod chgrp chown 

HDFS 配置额度
	hdfs dfsadmin setquota 
	hdfs dfsadmin clrqupta 
	
HDFS
    Linux File vi hadoop no pwd execut lib

    hdfs dfs -usage  获取命令
    hdfs dfs -help   命令信息
    hdfs dfs -mkdir  创建文件
    hdfs dfs -rmdir  删除文件
    hdfs dfs -put
    hdfs dfs -ls -R /tmp  子目录的文件
    hdfs dfs -checksum src 校验和命令
    hdfs dfs -tail -f 文本行的信息目录
    hdfs dfs -appenToFile 重复添加到文件的末尾
    hdfs dfs  -cp - p -f
    hdfs dfs -stat  
    hdfs dfs -du -h /src 
    hdfs dfs -du -h -s 

    hdfs.peermissions =true 
    hdfs.permissions.supergroup = hdfs 
    dfs.umask = 022


    hdfs moveFromLocal localsrc -- upload 到分布式文件系统
    hdfs dfs -ls /t* 支持通配符的操作

    
     
 HDFS ACL
 	访问控制列表是ACL 词目的集合 每个ACL词目的集合

 		user rw
 		user：bruce rwx #effectiver
 		grop r-x
 		mask::r 掩码 受到权限的管理
 		other::r 

 		default ACL条目新的子文件目录会继承该条目

 		getfacl -r 获得ACL	
 		-setfacl -r 设置ACL -k移除

HDFS trash
	 HDFS在每个用户目录创建一个回收站目录 存放被删除的文件
	 	在回收周期内HDF将这个文件目录彻底删除

	 	每个节点的 core-site。xml配置为6小时
