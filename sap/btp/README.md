## BTP | SAP Business Application Studio
 BTP 系统相关命令

## Docker Images
* compiling:ibas-alpine
~~~
docker build --force-rm -f ./btp/dockerfile.cli -t avacloud/compiling:ibas-alpine ./
~~~
* developing:ibas
~~~
docker build --force-rm -f ./btp/dockerfile.desktop -t avacloud/developing:ibas ./
~~~

## BAS | SAP Business Application Studio
* installer.sh    安装编译环境及设置变量
~~~
java11 & java8
npm
maven
git-tf
tf
~~~

## Cloud Foundry
* compiling
~~~
cf push compiling -u none -k 4g -m 512m --no-route -o avacloud/compiling:ibas-alpine && \
cf run-task compiling "cd /root/codes/ibas.scripts/compiling && ./clone_build_complie_deploy.sh -q -r -u $USER -p $PWD -d 202105250000" --name COMPILING
~~~
* developing
~~~
cf push developing -u none -k 4g -m 2g -o avacloud/developing:ibas
~~~
* deploy application
~~~
cf push -f cf.manifest.yaml --var DOWNLOAD_TOKEN=xxxxxx --var DOWNLOAD_URL=https://xxxx.xxxx.xxx/operations/services/rest/customer/c00002/p01
~~~
* batch deploy application
~~~
cd sap/btp/deploy
./batch_deploy.sh -u https://xxxx.xxxx.xxx/operations/services/rest/customer/c00002/p01 -t xxxxxx                  # 部署当前目录全部 cf.*.yaml
./batch_deploy.sh -u https://xxxx.xxxx.xxx/operations/services/rest/customer/c00002/p01 -t xxxxxx -f agt          # 仅部署名称含 agt 的清单
./batch_deploy.sh -u https://xxxx.xxxx.xxx/operations/services/rest/customer/c00002/p01 -t xxxxxx -c              # 出错继续部署下一个
~~~
* update db objects
~~~
cf ssh avacloud -c 'cd $CATALINA_HOME && PATH=$JAVA_HOME/bin:$PATH && ./initialize_apps.sh'
~~~
* update service_routing
~~~
cf ssh avacloud -c 'cd $CATALINA_HOME && PATH=$JAVA_HOME/bin:$PATH && ./update_routing.sh'
~~~