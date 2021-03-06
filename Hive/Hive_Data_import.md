Hive Data import

* 4种方法
  1. 从本地文件系统中导入数据到Hive表；
  2. 从HDFS上导入数据到Hive表；
  3. 别的表中查询出相应的数据并导入到Hive表中；
  4. 创建表的时候通过从别的表中查询出相应的记录并插入到所创建的表中。


* 从本地文件系统中导入数据到Hive表
  * 先在Hive里面创建好表
 
```
hive> create table wyp


这个表很简单，只有四个字段，具体含义我就不解释了。本地文件系统里面有个/home/wyp/wyp.txt文件，内容如下：
[wyp@master ~]$ cat wyp.txt


wyp.txt文件中的数据列之间是使用\t分割的，可以通过下面的语句将这个文件里面的数据导入到wyp表里面，操作如下：
hive> load data local inpath 'wyp.txt' into table wyp;


这样就将wyp.txt里面的内容导入到wyp表里面去了，可以到wyp表的数据目录下查看，如下命令：

hive> dfs -ls /user/hive/warehouse/wyp ;
Found 1 items
-rw-r--r--3 wyp supergroup 67 2014-02-19 18:23 /hive/warehouse/wyp/wyp.txt
复制代码

```

* 注意的是：
  * 和我们熟悉的关系型数据库不一样，Hive现在还不支持在insert语句里面直接给出一组记录的文字形式
  * 不支持INSERT INTO …. VALUES形式的语句。

* HDFS上导入数据到hive表
  * 从本地文件系统中将数据导入到Hive表的过程中 
  * 是先将数据临时复制到HDFS的一个目录下，假设有下面这个文件/home/wyp/add.txt，具体的操作如下：

```
[wyp@master /home/q/hadoop-2.2.0]$ bin/hadoop fs -cat /home/wyp/add.txt


需要插入数据的内容，这个文件是存放在HDFS上/home/wyp目录
（和一中提到的不同，一中提到的文件是存放在本地文件系统上）里面
我们可以通过下面的命令将这个文件里面的内容导入到Hive表中，具体操作如下

hive> load data inpath '/home/wyp/add.txt' into table wyp;

hive> select * from wyp;

```

* 数据的确导入到wyp表中了
  * 注意load data inpath ‘/home/wyp/add.txt’ into table wyp
  * 里面是没有local这个单词的，这个是和一中的区别。


* 从别的表中查询出相应的数据并导入到Hive表中
  * 假设Hive中有test表，其建表语句如下所示：

```
hive> create table test(


大体和wyp表的建表语句类似，只不过test表里面用age作为了分区字段。对于分区，这里在做解释一下：
分区：在Hive中，表的每一个分区对应表下的相应目录，所有分区的数据都是存储在对应的目录中。比如wyp表有dt和city两个分区，则对应dt=20131218,city=BJ对应表的目录为/user/hive/warehouse/dt=20131218/city=BJ，所有属于这个分区的数据都存放在这个目录中。

下面语句就是将wyp表中的查询结果并插入到test表中：
hive> insert into table test
    > partition (age='25')
    > select id, name, tel
    > from wyp;
+------------------------------------------------------------------+
|           这里输出了一堆Mapreduce任务信息，这里省略                     |
+------------------------------------------------------------------+
Total MapReduce CPU Time Spent: 1 seconds 310 msec
OK
Time taken: 19.125 seconds

hive> select * from test;


这里做一下说明：
我们知道我们传统数据块的形式insert into table values（字段1，字段2），这种形式hive是不支持的。

通过上面的输出，我们可以看到从wyp表中查询出来的东西已经成功插入到test表中去了！如果目标表（test）中不存在分区字段，可以去掉partition (age=’25′)语句。当然，我们也可以在select语句里面通过使用分区值来动态指明分区：
hive> set hive.exec.dynamic.partition.mode=nonstrict;
hive> insert into table test
    > partition (age)
    > select id, name,
    > tel, age
    > from wyp;
+------------------------------------------------------------------+
|           这里输出了一堆Mapreduce任务信息，这里省略                     |
+------------------------------------------------------------------+
Total MapReduce CPU Time Spent: 1 seconds 510 msec
OK
Time taken: 17.712 seconds

hive> select * from test;


这种方法叫做动态分区插入，但是Hive中默认是关闭的，所以在使用前需要先把hive.exec.dynamic.partition.mode设置为nonstrict。
当然，Hive也支持insert overwrite方式来插入数据，从字面我们就可以看出，overwrite是覆盖的意思
执行完这条语句的时候，相应数据目录下的数据将会被覆盖！而insert into则不会，注意两者之间的区别。例子如下：

hive> insert overwrite table test


更可喜的是，Hive还支持多表插入，什么意思呢？在Hive中，我们可以把insert语句倒过来，把from放在最前面，它的执行效果和放在后面是一样的，如下：
hive> show create table test3;
OK
CREATE  TABLE test3(
  id int,
  name string)
Time taken: 0.277 seconds, Fetched: 18 row(s)

hive> from wyp

hive> select * from test3;


可以在同一个查询中使用多个insert子句，这样的好处是我们只需要扫描一遍源表就可以生成多个不相交的输出。这个很酷吧！

四、在创建表的时候通过从别的表中查询出相应的记录并插入到所创建的表中

在实际情况中，表的输出结果可能太多，不适于显示在控制台上，这时候，将Hive的查询输出结果直接存在一个新的表中是非常方便的，我们称这种情况为CTAS（create table .. as select）如下：

hive> create table test4
    > as
    > select id, name, tel
    > from wyp;

hive> select * from test4;


```

* 数据就插入到test4表中去了，CTAS操作是原子的，因此如果select查询由于某种原因而失败，新表是不会创建的！
