# building
构建应用的镜像

## 主要内容 | content
* nginx:vstore-[yyyy][mm][dd][hh][mm]
~~~
docker build --force-rm -f ./dockerfile-nginx -t avacloud/nginx:vstore-202207120542 ./
~~~
* tomcat:vstore-[yyyy][mm][dd][hh][mm]
~~~
docker build --force-rm -f ./dockerfile-tomcat -t avacloud/tomcat:vstore-202207120542 ./
~~~
