# maintenance
运维相关脚本

## 主要内容 | content

### k8s_archive_customer_data.sh - 归档客户数据
将客户数据打包备份到指定目录
~~~
# 归档所有客户数据
./k8s_archive_customer_data.sh -b /backup/2026-06-09

# 归档指定客户数据
./k8s_archive_customer_data.sh -d /data -c "c001 c002 c003" -b /backup/2026-06-09
~~~

### k8s_backup_running_images.sh - 备份当前运行中的镜像
备份k8s集群中正在运行的镜像到指定仓库，或不指定仓库仅pull到本地
~~~
# 仅pull镜像到本地（不推送）
./k8s_backup_running_images.sh -n customer

# 备份镜像到指定仓库
./k8s_backup_running_images.sh -r registry.example.com -n customer

# 备份指定过滤条件的镜像
./k8s_backup_running_images.sh -r registry.example.com -n production -f /avacloud/
~~~

### k8s_cleanup_running_logs.sh - 清理运行日志
清理过期的日志文件和临时文件
~~~
# 清理当前目录14天前的日志
./k8s_cleanup_running_logs.sh

# 清理指定目录30天前的日志
./k8s_cleanup_running_logs.sh -f /data/logs -e 30
~~~

### nexus_cleanup_unused_images.sh - 清理Nexus未使用的Docker镜像
清理Nexus仓库中不在k8s使用且已超期的Docker镜像，固定只处理tomcat和nginx镜像
~~~
# 清理未使用且超过30天的镜像（默认）
./nexus_cleanup_unused_images.sh \
  -u admin -p admin123 \
  -h http://nexus:8081 \
  -r docker-hosted

# 清理未使用且超过60天的镜像，指定k8s命名空间
./nexus_cleanup_unused_images.sh \
  -u admin -p admin123 \
  -h http://nexus:8081 \
  -r docker-hosted \
  -n customer \
  -e 60

# 查看所有k8s命名空间中的过期镜像（不限定命名空间）
./nexus_cleanup_unused_images.sh \
  -u admin -p admin123 \
  -h http://nexus:8081 \
  -r docker-hosted \
  -d

# 追加额外过滤条件（在tomcat/nginx基础上）
./nexus_cleanup_unused_images.sh \
  -u admin -p admin123 \
  -h http://nexus:8081 \
  -r docker-hosted \
  -f "avacloud"
~~~

参数说明：
- `-u` `-p` Nexus用户名和密码
- `-h` Nexus仓库地址
- `-r` Nexus仓库名称
- `-n` k8s命名空间，不传则查所有命名空间
- `-f` 额外镜像过滤条件（在tomcat/nginx基础上追加）
- `-e` 超期天数，默认30天
- `-d` dry-run模式，只列示过期镜像不删除

### openui5_unzip_packages.sh - 解压openui5的压缩包
解压当前目录下的openui5-runtime压缩包
~~~
# 解压到当前目录
./openui5_unzip_packages.sh

# 解压到指定目录
./openui5_unzip_packages.sh /path/to/target
~~~

### mysql_backup_database.sh - 备份mysql数据库
备份MySQL数据库并压缩存储
~~~
# 备份指定数据库
./mysql_backup_database.sh \
  -u root -p 1q2w3e \
  -h rm-2ze1sc6qr877owde8.mysql.rds.aliyuncs.com \
  -d "c00002-05 c00002-06"

# 备份所有数据库并清理30天前的备份
./mysql_backup_database.sh \
  -u root -p 1q2w3e \
  -h mysql.example.com \
  -f /backup/mysql \
  -c -e 30
~~~

### mysql_init_db_user.sh - 初始化mysql数据库、用户、权限
从配置文件中读取数据库信息并创建数据库和用户
~~~
# 从配置文件初始化数据库
./mysql_init_db_user.sh -u root -p 1q2w3e -c ./app.xml
~~~

### synchronize_code_files.sh - 同步TFS项目代码
同步TFS项目代码，处理签出及新增（适用已初始化项目）
~~~
# 同步代码，./replacements.txt 文件中定义需要替换的文件内容
./synchronize_code_files.sh ~/source ~/target
~~~
