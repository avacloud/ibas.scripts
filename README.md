# ibas.scripts
avacloud 编译发布脚本

### 编译 | compiling
* clone_build_complie_deploy.sh
~~~
git*.compile_order.txt          使用git命令获取代码的项目清单
tfs*.compile_order.txt          使用git tf命令获取代码的项目清单
~~~

### 使用 | using
* compiling @ cloud foundry
~~~
cf push compiling -u none -k 4g -m 512m --no-route -o avacloud/compiling:ibas && \
cf run-task compiling "cd /root/codes/ibas.scripts/compiling && ./clone_build_complie_deploy.sh -q -r -u $USER -p $PWD -d 202105250000" --name COMPILING
~~~

