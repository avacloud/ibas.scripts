#!/bin/bash
echo '****************************************************************************'
echo '                   mysql_backup_database.sh                                 '
echo '                           by niuren.zhu                                    '
echo '                              2025.07.15                                    '
echo '  note:                                                                     '
echo '      1. backup mysql database.                                             '
echo '      2. support local mysql or docker container.                           '
echo '  parameter:                                                                '
echo '      -u [user]              mysql user.                                    '
echo '      -p [password]          mysql password.                                '
echo '      -h [host]              mysql host, optional for container mode.       '
echo '      -f [backup folder]     database backup folder.                        '
echo '      -d [db name]           database name, space division. (db1 db2 db3)   '
echo '      -c [container]         docker container name, optional.               '
echo '      -e [backup expire day] backup expire day, defalut 14 days.            '
echo '      -x                     clear expired backup database.                 '
echo '****************************************************************************'
# 设置参数变量
while getopts "u:p:h:f:d:c:e:x" arg; do
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
        CONTAINER_NAME=$OPTARG
        ;;
    e)
        EXPIRE_DAYS=$OPTARG
        ;;
    x)
        CLEAR_EXPIRED_BACKUP="ON"
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
if [ "${CONTAINER_NAME}" = "" ] && [ "${MYSQL_HOST}" = "" ]; then
    echo please set mysql host or container name.
    exit 1
fi

echo --checking tools
# 自动检测容器运行时：优先 docker，其次 podman
if [ "${CONTAINER_NAME}" != "" ]; then
    if command -v docker > /dev/null 2>&1; then
        DOCKER_CMD="docker"
    elif command -v podman > /dev/null 2>&1; then
        DOCKER_CMD="podman"
    else
        echo please install docker or podman.
        exit 1
    fi
    echo --Container runtime: ${DOCKER_CMD}
    ${DOCKER_CMD} --version
    if [ "$?" != "0" ]; then
        echo ${DOCKER_CMD} not available.
        exit 1
    fi
    # 检查容器是否存在且运行中
    CONTAINER_STATUS=$(${DOCKER_CMD} ps --filter "name=^${CONTAINER_NAME}$" --filter "status=running" --format "{{.Names}}")
    if [ "${CONTAINER_STATUS}" != "${CONTAINER_NAME}" ]; then
        echo container not found or not running: ${CONTAINER_NAME}
        exit 1
    fi
    echo --Mode: ${DOCKER_CMD} container [${CONTAINER_NAME}]
    # 检查容器内是否有mysql命令
    ${DOCKER_CMD} exec "${CONTAINER_NAME}" mysql --version
    if [ "$?" != "0" ]; then
        echo mysql not found in container: ${CONTAINER_NAME}
        exit 1
    fi
else
    # 本地模式
    mysql --version
    if [ "$?" != "0" ]; then
        echo please install mysql cli.
        exit 1
    fi
    echo --Mode: Local mysql
fi
gzip -V | sed -n '1p'
if [ "$?" != "0" ]; then
    echo please install gzip.
    exit 1
fi
# 检查perl（用于移除DEFINER信息）
perl -v > /dev/null 2>&1
if [ "$?" != "0" ]; then
    echo please install perl.
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
    mkdir -p "${BACKUP_DIR}"
fi

# 未指定数据库，则获取全部库
if [ "${BACKUP_DATABASES}" = "" ]; then
    if [ "${CONTAINER_NAME}" != "" ]; then
        BACKUP_DATABASES=$(${DOCKER_CMD} exec "${CONTAINER_NAME}" mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|sys|mysql|__recycle_bin__)")
    else
        BACKUP_DATABASES=$(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|sys|mysql|__recycle_bin__)")
    fi
fi

# 检测是否支持GTID（MySQL 5.6+支持--set-gtid-purged，MariaDB和旧版MySQL不支持）
echo --checking GTID support
if [ "${CONTAINER_NAME}" != "" ]; then
    GTID_MODE=$(${DOCKER_CMD} exec "${CONTAINER_NAME}" mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -N -B -e "SELECT @@global.gtid_mode;" 2>/dev/null)
else
    GTID_MODE=$(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} -N -B -e "SELECT @@global.gtid_mode;" 2>/dev/null)
fi
if [ "${GTID_MODE}" != "" ]; then
    echo --GTID mode: ${GTID_MODE}, using --set-gtid-purged=OFF
    GTID_OPTION="--set-gtid-purged=OFF"
else
    echo --GTID not supported, skipping --set-gtid-purged
    GTID_OPTION=""
fi

# 移除存储过程/函数/触发器中的DEFINER信息，避免跨服务器还原时报错
# 与mysql_restore_database.sh使用相同的perl正则，保持一致性
# 匹配 DEFINER=`user`@`host`（mysqldump标准格式）和 DEFINER=user@host（无引号格式）
PERL_STRIP_DEFINER='s/DEFINER\s*=\s*`[^`]+`@`[^`]+`//gi; s/DEFINER\s*=\s*[\w.%]+@[\w.%]+//gi;'

# 执行备份
for DB_NAME in ${BACKUP_DATABASES}; do
    echo "****** backing up: ${DB_NAME} ******"

    BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${BACKUP_TIME}.sql.gz"

    # 使用mysqldump备份并压缩，通过perl移除DEFINER信息
    if [ "${CONTAINER_NAME}" != "" ]; then
        ${DOCKER_CMD} exec "${CONTAINER_NAME}" mysqldump -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${DB_NAME} \
          --default-character-set=${MYSQL_CHARSET} --single-transaction ${GTID_OPTION} \
          --routines --triggers 2>/dev/null \
          | perl -pe "${PERL_STRIP_DEFINER}" \
          | gzip > ${BACKUP_FILE}
    else
        mysqldump -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} ${DB_NAME} \
          --default-character-set=${MYSQL_CHARSET} --single-transaction ${GTID_OPTION} \
          --routines --triggers 2>/dev/null \
          | perl -pe "${PERL_STRIP_DEFINER}" \
          | gzip > ${BACKUP_FILE}
    fi

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
if [ "${CLEAR_EXPIRED_BACKUP}" = "ON" ]; then
    if [ -e "${BACKUP_FOLDER}" ];then
        echo "clear expired backup database."
        find "${BACKUP_FOLDER}" -name "*.sql.gz" -mtime +"${EXPIRE_DAYS}" -exec rm -f {} \;
        find "${BACKUP_FOLDER}" -type d -empty -delete;
    fi
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
