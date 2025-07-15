#!/bin/bash
echo '****************************************************************************'
echo '                   mysql_backup_database.sh                                 '
echo '                           by niuren.zhu                                    '
echo '                              2025.07.15                                    '
echo '  note:                                                                     '
echo '      1. backup mysql database.                                             '
echo '  parameter:                                                                '
echo '      -u [user]              mysql user.                                    '
echo '      -p [password]          mysql password.                                '
echo '      -h [host]              mysql host.                                    '
echo '      -f [backup folder]     database backup folder.                        '
echo '      -d [db name]           database name, space division. (db1 db2 db3)   '
echo '      -c [clear expired db]  clear expired backup database.                 '
echo '      -e [backup expire day] backup expire day, defalut 14 days.            '
echo '****************************************************************************'
# 设置参数变量
while getopts ":u:p:h:f:d:c:e" arg; do
    case $arg in
    u)
        MYSQL_USER=$OPTARG
        ;;
    p)
        MYSQL_PASSWORD=$OPTARG
        ;;
    h)
        MYSQL_HOST=$OPTARG
        ;;
    f)
        BACKUP_FOLDER=$OPTARG
        ;;
    d)
        BACKUP_DATABASES=$OPTARG
        ;;
    c)
        CLEAR_EXPIRED_BACKUP="ON"
        ;;
    e)
        EXPIRE_DAYS=$OPTARG
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)
# 备份路径
if [ "${BACKUP_FOLDER}" = "" ]; then
    BACKUP_FOLDER=${WORK_FOLDER}
fi
if [ "${MYSQL_USER}" = "" ]; then
    echo please set mysql user.
    exit 1
fi
if [ "${MYSQL_PASSWORD}" = "" ]; then
    echo please set mysql password.
    exit 1
fi
if [ "${MYSQL_HOST}" = "" ]; then
    echo please set mysql host.
    exit 1
fi

echo --checking tools
mysql --version
if [ "$?" != "0" ]; then
    echo please install mysql cli.
    exit 1
fi
gzip -V | sed -n '1p'
if [ "$?" != "0" ]; then
    echo please install gzip.
    exit 1
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}

MYSQL_CHARSET="utf8mb4"
BACKUP_TIME=$(date +%Y%m%d%H%M)
BACKUP_YMD=$(date +%Y-%m-%d)
BACKUP_DIR=${BACKUP_FOLDER}/${BACKUP_YMD}
if [ "${EXPIRE_DAYS}" = "" ]; then
    EXPIRE_DAYS=14
fi


# 创建备份目录
if [ ! -e "${BACKUP_DIR}" ]; then
    mkdir -p ${BACKUP_DIR}
fi

# 未指定数据库，则获取全部库
if [ "${BACKUP_DATABASES}" = "" ]; then
    BACKUP_DATABASES=$(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|sys|mysql|__recycle_bin__)")
fi

# 执行备份
for DB_NAME in ${BACKUP_DATABASES}; do
    echo "****** backing up: ${DB_NAME} ******"

    BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${BACKUP_TIME}.sql.gz"

    # 使用mysqldump备份并压缩
    mysqldump -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} ${DB_NAME} \
      --default-character-set=${MYSQL_CHARSET} --single-transaction --set-gtid-purged=OFF \
      --routines --triggers \
      | gzip > ${BACKUP_FILE}

    # 检查备份结果
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "error: backup ${DB_NAME} faild."
        if [ -e ${BACKUP_FILE} ]; then
            rm -f "${BACKUP_FILE}"
        fi
    else
        echo "success: ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"
    fi
done

# 如果开启了删除过期备份，则进行删除操作
if [ "${CLEAR_EXPIRED_BACKUP}" == "ON" -a "${BACKUP_FOLDER}" != "" ]; then
    echo "clear expired backup database."
    find "${BACKUP_FOLDER}" -name "*.sql.gz" -mtime +${EXPIRE_DAYS} -exec rm -f {} \;
fi

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
