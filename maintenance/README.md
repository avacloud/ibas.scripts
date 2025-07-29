# maintenance
运维相关脚本

## 主要内容 | content
* k8s_cleanup_running_logs.sh  清理运行日志
~~~
~~~
* k8s_backup_running_images.sh  备份当前运行中的镜像
~~~
~~~
* openui5_unzip_packages.sh  解压openui5的压缩包
~~~
~~~
* mysql_backup_database.sh  备份mysql数据库
~~~
 ./mysql_backup_database.sh -u root -p 1q2w3e -h "rm-2ze1sc6qr877owde8.mysql.rds.aliyuncs.com" -d "c00002-05 c00002-06"
~~~
* mysql_init_db_user.sh  初始化mysql数据库、用户、权限
~~~
 ./mysql_backup_database.sh -u root -p 1q2w3e -c ./app.xml
~~~
