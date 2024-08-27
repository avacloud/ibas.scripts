# tomcat
B1 DI运行环境

## 主要内容 | content
* tomcat:ibas-b1[H][93]-[14]  H：HANA（可选）；93：B1版本；14：补丁版本
~~~
REM 注意：从B1的安装包中拷贝[Prerequisites]和[DI API]文件夹到[.\Packages]目录。
docker build --force-rm -f ./dockerfile-wincore-b1di -t avacloud/tomcat:ibas-b193-14 ./
REM 注意：如果安装SLD代理，则使用此参数修改地址
docker build --force-rm -f ./dockerfile-wincore-b1di -t avacloud/tomcat:ibas-b193-14 --build-arg SLDaddress="https://b1c-server.com/sld/sld0100.svc" ./
~~~