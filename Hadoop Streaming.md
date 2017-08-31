# Hadoop Streaming
> Hadoop Streaming是Hadoop提供的一个编程工具，它允许用户使用任何可执行文件或者脚本文件作为Mapper和Reducer，例如：采用shell脚本语言中的一些命令作为mapper和reducer（cat作为mapper，wc作为reducer）

$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/contrib/streaming/hadoop-*-streaming.jar \
-input myInputDirs \
-output myOutputDir \
-mapper cat \
-reducer wc

## Hadoop Streaming原理

* mapper和reducer会从标准输入中读取用户数据，一行一行处理后发送给标准输出。
* Streaming工具会创建MapReduce作业，发送给各个tasktracker，同时监控整个作业的执行过程。
* Map/Reduce框架和streaming mapper/reducer之间的基本通信协议
  * 如果一个文件（可执行或者脚本）作为mapper，mapper初始化时，每一个mapper任务会把该文件作为一个单独进程启动，mapper任务运行时，它把输入切分成行并把每一行提供给可执行文件进程的标准输入 同时，mapper收集可执行文件进程标准输出的内容，并把收到的每一行内容转化成key/value对，作为mapper的输出。默认情况下，一行中第一个tab之前的部分作为key，之后的（不包括tab）作为value。如果没有tab，整行作为key值，value值为null。

## Hadoop Streaming用法

Usage: $HADOOP_HOME/bin/hadoop jar \
$HADOOP_HOME/contrib/streaming/hadoop-*-streaming.jar [options]
options：
1. -input：输入文件路径
2. -output：输出文件路径
3. -mapper：用户自己写的mapper程序，可以是可执行文件或者脚本
4. -reducer：用户自己写的reducer程序，可以是可执行文件或者脚本
5. -file：打包文件到提交的作业中，可以是mapper或者reducer要用的输入文件，如配置文件，字典等。
6. -partitioner：用户自定义的partitioner程序
7. -combiner：用户自定义的combiner程序（必须用java实现）
-D：作业的一些属性（以前用的是-jonconf），具体有：
  1. mapred.map.tasks：map task数目
  2. mapred.reduce.tasks：reduce task数目
  3. stream.map.input.field.separator/stream.map.output.field.separator： map task输入/输出数
据的分隔符,默认均为\t。
  4. stream.num.map.output.key.fields：指定map task输出记录中key所占的域数目
  5. stream.reduce.input.field.separator/stream.reduce.output.field.separator：reduce task输入/输出数据的分隔符，默认均为\t。
  6. stream.num.reduce.output.key.fields：指定reduce task输出记录中key所占的域数目
另外，Hadoop本身还自带一些好用的Mapper和Reducer：

## Hadoop聚集功能
> Aggregate提供一个特殊的reducer类和一个特殊的combiner类，并且有一系列的“聚合器”（例如“sum”，“max”，“min”等）用于聚合一组value的序列。用户可以使用Aggregate定义一个mapper插件类，这个类用于为mapper输入的每个key/value对产生“可聚合项”。Combiner/reducer利用适当的聚合器聚合这些可聚合项。要使用Aggregate，只需指定“-reducer aggregate”。

*  字段的选取（类似于Unix中的‘cut’）
  * Hadoop的工具类org.apache.hadoop.mapred.lib.FieldSelectionMapReduc帮助用户高效处理文本数据，就像unix中的“cut”工具。工具类中的map函数把输入的key/value对看作字段的列表。 用户可以指定字段的分隔符（默认是tab），可以选择字段列表中任意一段（由列表中一个或多个字段组成）作为map输出的key或者value。 同样，工具类中的reduce函数也把输入的key/value对看作字段的列表，用户可以选取任意一段作为reduce输出的key或value。
 
 * Mapper和Reducer实现
本节试图用尽可能多的语言编写Mapper和Reducer，包括Java，C，C++，Shell脚本，python等
由于Hadoop会自动解析数据文件到Mapper或者Reducer的标准输入中，以供它们读取使用，所有应先了解各个语言获取标准输入的方法。
（1Z   Java语言：
见Hadoop自带例子
（2）    C++语言：
string key;
while(cin>>key){
  cin>>value;
   ….
}
（3）  C语言：
char buffer[BUF_SIZE];
while(fgets(buffer, BUF_SIZE - 1, stdin)){
  int len = strlen(buffer);
  …
}
（4）  Shell脚本
管道
（5）  Python脚本
1
2
3
import sys
for line in sys.stdin:
.......
为了说明各种语言编写Hadoop Streaming程序的方法，下面以WordCount为例，WordCount作业的主要功能是对用户输入的数据中所有字符串进行计数。
（1）C语言实现

//mapper
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
 
#define BUF_SIZE        2048
#define DELIM   "\n"
 
int main(int argc, char *argv[]){
     char buffer[BUF_SIZE];
     while(fgets(buffer, BUF_SIZE - 1, stdin)){
            int len = strlen(buffer);
            if(buffer[len-1] == '\n')
             buffer[len-1] = 0;
 
            char *querys  = index(buffer, ' ');
            char *query = NULL;
            if(querys == NULL) continue;
            querys += 1; /*  not to include '\t' */
 
            query = strtok(buffer, " ");
            while(query){
                   printf("%s\t1\n", query);
                   query = strtok(NULL, " ");
            }
     }
     return 0;
}
//---------------------------------------------------------------------------------------
//reducer
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
 
#define BUFFER_SIZE     1024
#define DELIM   "\t"
 
int main(int argc, char *argv[]){
 char strLastKey[BUFFER_SIZE];
 char strLine[BUFFER_SIZE];
 int count = 0;
 
 *strLastKey = '\0';
 *strLine = '\0';
 
 while( fgets(strLine, BUFFER_SIZE - 1, stdin) ){
   char *strCurrKey = NULL;
   char *strCurrNum = NULL;
 
   strCurrKey  = strtok(strLine, DELIM);
   strCurrNum = strtok(NULL, DELIM); /* necessary to check error but.... */
 
   if( strLastKey[0] == '\0'){
     strcpy(strLastKey, strCurrKey);
   }
 
   if(strcmp(strCurrKey, strLastKey)) {
     printf("%s\t%d\n", strLastKey, count);
     count = atoi(strCurrNum);
   } else {
     count += atoi(strCurrNum);
   }
   strcpy(strLastKey, strCurrKey);
 
 }
 printf("%s\t%d\n", strLastKey, count); /* flush the count */
 return 0;
}
（2）C++语言实现
//mapper
#include <stdio.h>
#include <string>
#include <iostream>
using namespace std;
 
int main(){
        string key;
        string value = "1";
        while(cin>>key){
                cout<<key<<"\t"<<value<<endl;
        }
        return 0;
}
//------------------------------------------------------------------------------------------------------------
//reducer
#include <string>
#include <map>
#include <iostream>
#include <iterator>
using namespace std;
int main(){
        string key;
        string value;
        map<string, int> word2count;
        map<string, int>::iterator it;
        while(cin>>key){
                cin>>value;
                it = word2count.find(key);
                if(it != word2count.end()){
                        (it->second)++;
                }
                else{
                        word2count.insert(make_pair(key, 1));
                }
        }
 
        for(it = word2count.begin(); it != word2count.end(); ++it){
                cout<<it->first<<"\t"<<it->second<<endl;
        }
        return 0;
}
（3）shell脚本语言实现
简约版，每行一个单词：
$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/hadoop-streaming.jar \
    -input myInputDirs \
    -output myOutputDir \
    -mapper cat \
   -reducer  wc
详细版，每行可有多个单词（由史江明编写）： mapper.sh
#! /bin/bash
while read LINE; do
  for word in $LINE
  do
    echo "$word 1"
  done
done
reducer.sh
#! /bin/bash
count=0
started=0
word=""
while read LINE;do
  newword=`echo $LINE | cut -d ' '  -f 1`
  if [ "$word" != "$newword" ];then
    [ $started -ne 0 ] && echo "$word\t$count"
    word=$newword
    count=1
    started=1
  else
    count=$(( $count + 1 ))
  fi
done
echo "$word\t$count"
（4）Python脚本语言实现
#!/usr/bin/env python
 
import sys
 
# maps words to their counts
word2count = {}
 
# input comes from STDIN (standard input)
for line in sys.stdin:
    # remove leading and trailing whitespace
    line = line.strip()
    # split the line into words while removing any empty strings
    words = filter(lambda word: word, line.split())
    # increase counters
    for word in words:
        # write the results to STDOUT (standard output);
        # what we output here will be the input for the
        # Reduce step, i.e. the input for reducer.py
        #
        # tab-delimited; the trivial word count is 1
        print '%s\t%s' % (word, 1)
#---------------------------------------------------------------------------------------------------------
#!/usr/bin/env python
 
from operator import itemgetter
import sys
 
# maps words to their counts
word2count = {}
 
# input comes from STDIN
for line in sys.stdin:
    # remove leading and trailing whitespace
    line = line.strip()
 
    # parse the input we got from mapper.py
    word, count = line.split()
    # convert count (currently a string) to int
    try:
        count = int(count)
        word2count[word] = word2count.get(word, 0) + count
    except ValueError:
        # count was not a number, so silently
        # ignore/discard this line
        pass
 
# sort the words lexigraphically;
#
# this step is NOT required, we just do it so that our
# final output will look more like the official Hadoop
# word count examples
sorted_word2count = sorted(word2count.items(), key=itemgetter(0))
 
# write the results to STDOUT (standard output)
for word, count in sorted_word2count:
    print '%s\t%s'% (word, count)

* 常见问题及解决方案
  1. 作业总是运行失败，
提示找不多执行程序， 比如“Caused by: java.io.IOException: Cannot run program “/user/hadoop/Mapper”: error=2, No such file or directory”：
可在提交作业时，采用-file选项指定这些文件， 比如上面例子中，可以使用“-file Mapper -file Reducer” 或者 “-file Mapper.py -file Reducer.py”， 这样，Hadoop会将这两个文件自动分发到各个节点上，比如：
$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/contrib/streaming/hadoop-*-streaming.jar \
-input myInputDirs \
-output myOutputDir \
-mapper Mapper.py\
-reducer Reducerr.py\
-file Mapper.py \
-file Reducer.py

  2. 用脚本编写时，第一行需注明脚本解释器，默认是shell   （3）如何对Hadoop Streaming程序进行测试？   Hadoop Streaming程序的一个优点是易于测试，比如在Wordcount例子中，可以运行以下命令在本地进行测试：
