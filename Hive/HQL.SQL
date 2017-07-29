HiveQL

创建表：
hive> CREATE TABLE pokes (foo INT, bar STRING); 
        Creates a table called pokes with two columns, the first being an integer and the other a string

创建一个新表，结构与其他一样
hive> create table new_table like records;

创建分区表：
hive> create table logs(ts bigint,line string) partitioned by (dt String,country String);

加载分区表数据：
hive> load data local inpath '/home/hadoop/input/hive/partitions/file1' into table logs partition (dt='2001-01-01',country='GB');

展示表中有多少分区：
hive> show partitions logs;

展示所有表：
hive> SHOW TABLES;
        lists all the tables
hive> SHOW TABLES '.*s';

lists all the table that end with 's'. The pattern matching follows Java regular
expressions. Check out this link for documentation 

显示表的结构信息
hive> DESCRIBE invites;
        shows the list of columns

更新表的名称：
hive> ALTER TABLE source RENAME TO target;

添加新一列
hive> ALTER TABLE invites ADD COLUMNS (new_col2 INT COMMENT 'a comment');

删除表：
hive> DROP TABLE records;
删除表中数据，但要保持表的结构定义
hive> dfs -rmr /user/hive/warehouse/records;

从本地文件加载数据：
hive> LOAD DATA LOCAL INPATH '/home/hadoop/input/ncdc/micro-tab/sample.txt' OVERWRITE INTO TABLE records;

显示所有函数：
hive> show functions;

查看函数用法：
hive> describe function substr;

查看数组、map、结构
hive> select col1[0],col2['b'],col3.c from complex;


内连接：
hive> SELECT sales.*, things.* FROM sales JOIN things ON (sales.id = things.id);

查看hive为某个查询使用多少个MapReduce作业
hive> Explain SELECT sales.*, things.* FROM sales JOIN things ON (sales.id = things.id);

外连接：
hive> SELECT sales.*, things.* FROM sales LEFT OUTER JOIN things ON (sales.id = things.id);
hive> SELECT sales.*, things.* FROM sales RIGHT OUTER JOIN things ON (sales.id = things.id);
hive> SELECT sales.*, things.* FROM sales FULL OUTER JOIN things ON (sales.id = things.id);

in查询：Hive不支持，但可以使用LEFT SEMI JOIN
hive> SELECT * FROM things LEFT SEMI JOIN sales ON (sales.id = things.id);


Map连接：Hive可以把较小的表放入每个Mapper的内存来执行连接操作
hive> SELECT /*+ MAPJOIN(things) */ sales.*, things.* FROM sales JOIN things ON (sales.id = things.id);

INSERT OVERWRITE TABLE ..SELECT：新表预先存在
hive> FROM records2
    > INSERT OVERWRITE TABLE stations_by_year SELECT year, COUNT(DISTINCT station) GROUP BY year 
    > INSERT OVERWRITE TABLE records_by_year SELECT year, COUNT(1) GROUP BY year
    > INSERT OVERWRITE TABLE good_records_by_year SELECT year, COUNT(1) WHERE temperature != 9999 AND (quality = 0 OR quality = 1 OR quality = 4 OR quality = 5 OR quality = 9) GROUP BY year;  

CREATE TABLE ... AS SELECT：新表表预先不存在
hive>CREATE TABLE target AS SELECT col1,col2 FROM source;

创建视图：
hive> CREATE VIEW valid_records AS SELECT * FROM records2 WHERE temperature !=9999;

查看视图详细信息：
Hive> DESCRIBE EXTENDED valid_records;
	Sqoop
		将Hadoop和关系型数据库中的数据库相互专营的工具将一根关系系数据库
		   中的数据导入的Hadoop 中的Hive导入
