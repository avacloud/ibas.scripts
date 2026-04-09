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
cf push -f cf.manifest.yaml --var DOWNLOAD_TOKEN=${配置员口令} --var DOWNLOAD_URL=${配置文件下载地址}
~~~
* update db objects
~~~
cf ssh avacloud -c 'cd $CATALINA_HOME && PATH=$JAVA_HOME/bin:$PATH && ./initialize_apps.sh'
~~~
* update service_routing
~~~
cf ssh avacloud -c 'cd $CATALINA_HOME && PATH=$JAVA_HOME/bin:$PATH && ./update_routing.sh'
~~~