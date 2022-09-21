# tomcat
运行应用使用的容器镜像

## 主要内容 | content
* tomcat:ibas-alpine （华文宋体）
~~~
docker build --force-rm -f ./dockerfile -t avacloud/tomcat:ibas-alpine ./
~~~
* tomcat:ibas-wincore （系统缺失dll）
~~~
REM 注意：从当前系统拷贝缺失DLL。
copy /y %WINDIR%\System32\oledlg.dll %CD%\oledlg_x64.dll
copy /y %WINDIR%\SysWOW64\oledlg.dll %CD%\oledlg_x86.dll
docker build --force-rm -f ./dockerfile-wincore -t avacloud/tomcat:ibas-wincore ./
~~~
* tomcat:crviewer-alpine (水晶报表查看)
~~~
docker build --force-rm -f ./dockerfile-crviewer -t avacloud/tomcat:crviewer-alpine ./
~~~
