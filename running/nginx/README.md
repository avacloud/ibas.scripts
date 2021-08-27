# nginx
运行应用使用的容器镜像

## 主要内容 | content
* nginx:ibas-alpine
~~~
docker build --force-rm -f ./dockerfile -t avacloud/nginx:ibas-alpine ./
~~~
* nginx:ibas-wincore
~~~
docker build --force-rm -f ./dockerfile-wincore -t avacloud/nginx:ibas-wincore ./
~~~
