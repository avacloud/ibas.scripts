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
备份MySQL数据库并压缩存储，支持本地mysql或docker容器
~~~
# 备份指定数据库（本地模式）
./mysql_backup_database.sh \
  -u root -p 1q2w3e \
  -h rm-2ze1sc6qr877owde8.mysql.rds.aliyuncs.com \
  -d "c00002-05 c00002-06"

# 备份所有数据库并清理30天前的备份
./mysql_backup_database.sh \
  -u root -p 1q2w3e \
  -h mysql.example.com \
  -f /backup/mysql \
  -x -e 30

# 通过容器备份（无需指定host）
./mysql_backup_database.sh \
  -u root -p 1q2w3e \
  -c mysql_container \
  -f /backup/mysql
~~~

参数说明：
- `-u` MySQL用户名
- `-p` MySQL密码
- `-h` MySQL主机地址（容器模式可省略）
- `-f` 备份目录，默认当前目录
- `-d` 数据库名称，空格分隔多个，不传则备份全部
- `-c` docker容器名称，可选
- `-e` 备份过期天数，默认14天
- `-x` 清理过期备份

### mssql_restore_database.sh - 还原sql server数据库
将SQL Server备份文件（.bak）还原到指定数据库，还原后自动改为简单恢复模式并收缩空间，支持本地sqlcmd或docker/podman容器，可还原到不同的数据库名
~~~
# 本地模式还原
./mssql_restore_database.sh \
  -u sa -p 1q2w3e \
  -h mssql.example.com -P 1433 \
  -d target_db \
  -f /backup/db.bak

# 通过容器还原
./mssql_restore_database.sh \
  -u sa -p 1q2w3e \
  -d target_db \
  -f /backup/db.bak \
  -c mssql_container
~~~

参数说明：
- `-u` SQL Server用户名，默认sa
- `-p` SQL Server密码
- `-h` SQL Server主机地址（容器模式可省略）
- `-P` SQL Server端口，默认1433
- `-d` 目标数据库名称
- `-f` 备份文件（.bak）
- `-c` docker/podman容器名称，可选

### mysql_restore_database.sh - 还原mysql数据库
将MySQL备份文件还原到指定数据库，支持本地mysql或docker容器，自动表名大写转换，自动移除DEFINER子句
~~~
# 本地模式还原
./mysql_restore_database.sh \
  -u root -p 1q2w3e \
  -h mysql.example.com \
  -d target_db \
  -f /backup/db.sql

# 通过容器还原（支持.sql.gz压缩文件）
./mysql_restore_database.sh \
  -u root -p 1q2w3e \
  -d target_db \
  -f /backup/db.sql.gz \
  -c mysql_container

# 跳过表名大写转换
./mysql_restore_database.sh \
  -u root -p 1q2w3e \
  -h mysql.example.com \
  -d target_db \
  -f /backup/db.sql \
  -S
~~~

参数说明：
- `-u` MySQL用户名
- `-p` MySQL密码
- `-h` MySQL主机地址（容器模式可省略）
- `-d` 数据库名称
- `-f` SQL文件，支持.sql和.sql.gz
- `-c` docker容器名称，可选
- `-S` 跳过表名大写转换

### mysql_init_db_user.sh - 初始化mysql数据库、用户、权限
从配置文件中读取数据库信息并创建数据库和用户
~~~
# 从配置文件初始化数据库
./mysql_init_db_user.sh -u root -p 1q2w3e -c ./app.xml
~~~

### synchronize_code_files.sh - 同步TFS项目代码（v1->v2全流程）
同步TFS项目代码，自动处理差异分析、删除/重命名、签出/新增、替换规则、验证修复
~~~
./synchronize_code_files.sh ~/Codes/AVA/Cloud/ibas.xxx ~/Codes/AVA/Cloud-v2/ibas.xxx
~~~

参数说明：
- `$1` 源项目路径（v1）
- `$2` 目标项目路径（v2）

功能特性：
- 自动分析文件差异（新增/删除/修改/相同）
- 自动处理删除文件（`tf delete`）
- 自动处理大小写重命名（两步重命名法解决 TFS 大小写不敏感问题）
- 批量签出/新增（`tf checkout`/`tf add`，每批50个文件）
- 应用替换规则（`replacements.txt`，`sed -f` 批量替换）
- 自动验证所有文件（应用替换规则后比对），失败自动重试修复
- 输出汇总报告（Total/Copied/Checkout/Add/Delete/Rename/Verify）
- 记录日志文件（`sync_log_*.txt`，被 .tfignore 自动忽略）
