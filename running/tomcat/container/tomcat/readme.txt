运行环境说明：
    1. 此包需要在windows 64位环境下运行。
    2. 需要保证mklink命令可运行，组策略（gpedit.msc）配置符号链接权限或使用管理员权限。
    3. JAVA运行环境，要求1.8版本，也可使用自带jdk的包文件。
    4. ibas/conf，为应用配置目录。
    5. ibas_packages，为应用更新war包目录。
    6. ibas_tools，为常用工具目录。
    7. jdk，预置java运行环境。
	
脚本说明：
    1. deploy_apps.bat，应用包释放脚本，应用包应放在ibas_packages目录。
    2. initialize_apps.bat，创建数据库结构脚本。使用前请调整app.xml配置。
    3. startcat.bat，切换配置文件并启动tomcat。
    4. download_apps.bat，为应用下载脚本。
    5. update_routing.bat，根据数据库注册的模块，更新应用路由配置，新增模块后也需要执行。

使用说明：
    1. 运行 download_apps.bat，根据提示输入下载版本，版本号于技术人员索要。
    2. 运行 deploy_apps.bat，释放下载的应用包。
    3. 运行 startcat.bat，根据提示选择配置文件。
    4. 运行 initialize_apps.bat，创建数据库结构。
    5. 运行 update_routing.bat，更新应用路由配置，新增模块后也需要执行。
    6. 浏览器中打开网站 http://localhost:8080/index.html 。