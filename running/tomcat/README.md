# tomcat
运行应用使用的容器镜像

## 主要内容 | content
* tomcat:ibas-alpine （华文宋体）
~~~
docker build -f ./dockerfile -t avacloud/tomcat:ibas-alpine ./
~~~
* tomcat:ibas-wincore （系统缺失dll）
~~~
REM 注意：从当前系统拷贝缺失DLL。
mkdir %CD%\container\Windows\System32\
copy /y %WINDIR%\System32\oledlg.dll CD%\container\Windows\System32\

mkdir %CD%\container\Windows\SysWOW64\
copy /y %WINDIR%\SysWOW64\oledlg.dll %CD%\container\Windows\SysWOW64\
docker build -f ./dockerfile-wincore -t avacloud/tomcat:ibas-wincore ./
~~~
* tomcat:crviewer-alpine (水晶报表查看)
~~~
docker build -f ./dockerfile-crviewer -t avacloud/tomcat:crviewer-alpine ./
~~~
* tomginx:ibas-alpine (Tomat:8080 + Nginx:80)
~~~
docker build -f ./dockerfile-nginx -t avacloud/tomginx:ibas-alpine ./
~~~
* bundle_deployment_package.sh (独立打包脚本)
~~~
./bundle_deployment_package.sh
~~~
