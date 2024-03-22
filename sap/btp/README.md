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

