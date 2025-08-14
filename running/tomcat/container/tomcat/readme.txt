注意：
    1. 请保证mklink命令可运行，组策略打开或使用管理员权限。
    2. JAVA运行环境，要求1.8版本。
    3. ibas/conf，为应用配置目录。
    4. ibas_packages，为应用更新war包目录。
    5. ibas_tools，为常用工具目录。
    6. jdk，若存在则为java运行时目录。
	
说明：
    1. deploy_apps.bat，应用包释放脚本，应用包应放在ibas_packages目录。
    2. initialize_apps.bat，创建数据库结构脚本。使用前请调整app.xml配置。
    3. startcat.bat，切换配置文件并启动tomcat。
    4. download_apps.bat，为应用下载脚本。

使用：
    1. 运行 download_apps.bat，根据提示输入下载版本。
    2. 运行 deploy_apps.bat，释放下载的应用包。
    3. 运行 startcat.bat，根据提示选择配置文件。
    4. 运行 initialize_apps.bat，创建数据库结构。