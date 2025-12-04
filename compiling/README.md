# compiling
应用编译相关

## 主要内容 | content
* clone_build_complie_deploy.sh
~~~
git*.compile_order.txt          使用git命令获取代码的项目清单
tfs*.compile_order.txt          使用git tf命令获取代码的项目清单
~~~

## 其他 | others
### 编译变量 ###
~~~
# 生产配置
export MAVEN_PACKAGE_ARGUMENTS=-Pprod
# 前端不保留压缩前文件
export TS_COMPRESS_NO_ORIGINAL=true
~~~
