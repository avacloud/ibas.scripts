# tomcat
运行应用使用的容器镜像

## 主要内容 | content
* tomcat:ibas-alpine （华文宋体）
~~~
docker build --force-rm -f ./dockerfile -t avacloud/tomcat:ibas-alpine ./
~~~
* tomcat:ibas-wincore （vs c++库; sql native client 2012）
~~~
copy /y %WINDIR%\System32\oledlg.dll %CD%\oledlg_x64.dll
copy /y %WINDIR%\SysWOW64\oledlg.dll %CD%\oledlg_x86.dll
docker build --force-rm -f ./dockerfile-wincore -t avacloud/tomcat:ibas-wincore ./
~~~
* tomcat:ibas-b1[H][93]-[14]  H：HANA（可选）；93：B1版本；14：补丁版本
~~~
docker build --force-rm -f ./dockerfile-wincore-b1di -t avacloud/tomcat:ibas-b193-14 ./
~~~
注意：使用时需要在注册表中注册SLD地址
HKLM:\SOFTWARE\SAP\SAP Manage
SLDaddress = https://b1c-server.avacloud.cc/sld/sld0100.svc
