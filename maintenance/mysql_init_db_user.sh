#!/bin/bash
echo '****************************************************************************'
echo '                   mysql_init_db_user.sh                                    '
echo '                        by niuren.zhu                                       '
echo '                           2025.07.29                                       '
echo '  note:                                                                     '
echo '      1. create db and init user, from config file.                         '
echo '  parameter:                                                                '
echo '      -u [user]              super user, can create db, user, privileges.   '
echo '      -p [password]          super user password.                           '
echo '      -c [ibas config file]  to be init user from.                          '
echo '****************************************************************************'
# 设置参数变量
while getopts "u:p:c:" arg; do
    case $arg in
    u)
        MYSQL_USER=$OPTARG
        ;;
    p)
        MYSQL_PASSWORD=$OPTARG
        ;;
    c)
        CONFIG_FILE=$OPTARG
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)
if [ "${MYSQL_USER}" = "" ]; then
    echo please set mysql user.
    exit 1
fi
if [ "${MYSQL_PASSWORD}" = "" ]; then
    echo please set mysql password.
    exit 1
fi
if [ "${CONFIG_FILE}" = "" ]; then
    echo please set config file.
    exit 1
fi
if [ ! -e "${CONFIG_FILE}" ]; then
    echo not found config file.
    exit 1
fi


echo --checking tools
mysql --version
if [ "$?" != "0" ]; then
    echo please install mysql cli.
    exit 1
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}

# 提取 MasterDbUserID
DB_USER=$(awk -F'"' '
    /<add key="MasterDbUserID"/ {
        for(i=1; i<=NF; i++) {
            if ($i ~ /value=/) {
                print $(i+1)
                exit
            }
        }
    }
' "${CONFIG_FILE}")
if [ "${DB_USER}" = "" ]; then
    echo not found db user in config file.
    exit 1
fi

# 提取 MasterDbUserPassword
DB_PASSWORD=$(awk -F'"' '
    /<add key="MasterDbUserPassword"/ {
        for(i=1; i<=NF; i++) {
            if ($i ~ /value=/) {
                print $(i+1)
                exit
            }
        }
    }
' "${CONFIG_FILE}")
if [ "${DB_PASSWORD}" = "" ]; then
    echo not found db user password in config file.
    exit 1
fi

# 提取 MasterDbName
DB_NAME=$(awk -F'"' '
    /<add key="MasterDbName"/ {
        for(i=1; i<=NF; i++) {
            if ($i ~ /value=/) {
                print $(i+1)
                exit
            }
        }
    }
' "${CONFIG_FILE}")
if [ "${DB_NAME}" = "" ]; then
    echo not found db name in config file.
    exit 1
fi

# 提取 MasterDbServer
MYSQL_HOST=$(awk -F'"' '
    /<add key="MasterDbServer"/ {
        for(i=1; i<=NF; i++) {
            if ($i ~ /value=/) {
                print $(i+1)
                exit
            }
        }
    }
' "${CONFIG_FILE}")
if [ "${MYSQL_HOST}" = "" ]; then
    echo not found db server in config file.
    exit 1
fi

echo ---DB Server: ${MYSQL_HOST}
echo ---DB Name: ${DB_NAME}
echo ---DB User: ${DB_USER}
echo ---DB Password: ********

# 创建数据库及用户
echo ----create db and user.
mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4;
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
EOF
echo ----grant privileges.
# 给用户分配数据库权限
mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} <<EOF
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
GRANT SELECT ON \`mysql\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# 计算执行时间
END_TIME=$(date +'%Y-%m-%d %H:%M:%S')
if [ "$(uname)" = "Darwin" ]; then
    # macOS
    START_SECONDS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_TIME" +%s)
    END_SECONDS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$END_TIME" +%s)
else
    START_SECONDS=$(date --date="$START_TIME" +%s)
    END_SECONDS=$(date --date="$END_TIME" +%s)
fi
echo --Completion Time: ${END_TIME}, $((END_SECONDS - START_SECONDS)) seconds.
