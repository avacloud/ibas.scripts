# building
构建应用的镜像

## 主要内容 | content
* [customer]/avacloud/nginx:[yyyy][mm][dd][hh][mm]
~~~
docker build -f ./dockerfile-nginx -t c00001/avacloud/nginx:202207120542 ./
~~~
* [customer]/avacloud/tomcat:[yyyy][mm][dd][hh][mm]
~~~
docker build -f ./dockerfile-tomcat -t c00001/avacloud/tomcat:202207120542 ./
~~~
* [customer]/avacloud/nginx:[yyyy][mm][dd][hh][mm]
~~~
docker build -f ./dockerfile-upgrade-nginx -t c00006/avacloud/nginx:202507070542 \
  --build-arg BASE_IMAGE="repo.avacloud.com.cn/c00006/avacloud/nginx:202207120542" \
  ./
~~~
* [customer]/avacloud/tomcat:[yyyy][mm][dd][hh][mm]
~~~
docker build -f ./dockerfile-upgrade-tomcat -t c00001/avacloud/tomcat:202507070542 \
  --build-arg BASE_IMAGE="c00001/avacloud/tomcat:202207120542" \
  ./
~~~

