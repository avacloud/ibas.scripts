# nginx
运行应用使用的容器镜像

## 主要内容 | content
* compiling:ibas-alpine
~~~
docker build --force-rm -f ./dockerfile_compiling -t avacloud/compiling:ibas-alpine ./
~~~
* developing:ibas
~~~
docker build --force-rm -f ./dockerfile_developing -t avacloud/developing:ibas ./
~~~
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
