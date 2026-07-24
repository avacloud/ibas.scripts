#!/bin/bash
echo '****************************************************************************'
echo '                   mysql_restore_database.sh                                '
echo '                           by niuren.zhu                                    '
echo '                              2026.07.24                                    '
echo '  note:                                                                     '
echo '      1. restore mysql backup file to database.                            '
echo '      2. support local mysql or docker container.                           '
echo '      3. auto uppercase table names.                                        '
echo '      4. auto remove DEFINER clause (avoid user not exist error).           '
echo '  parameter:                                                                '
echo '      -u [user]              mysql user.                                    '
echo '      -p [password]          mysql password.                                '
echo '      -h [host]              mysql host, optional for container mode.       '
echo '      -d [db name]           database name.                                 '
echo '      -f [sql file]          sql file, support .sql and .sql.gz.            '
echo '      -c [container]         docker container name, optional.               '
echo '      -S                     skip uppercase table names.                    '
echo '****************************************************************************'
# 设置参数变量
while getopts "u:p:h:d:f:c:S" arg; do
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
    d)
        DB_NAME=$OPTARG
        ;;
    f)
        SQL_FILE=$OPTARG
        ;;
    c)
        CONTAINER_NAME=$OPTARG
        ;;
    S)
        SKIP_UPPERCASE="ON"
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)

# 参数校验
if [ "${MYSQL_USER}" = "" ]; then
    echo please set mysql user.
    exit 1
fi
if [ "${MYSQL_PASSWORD}" = "" ]; then
    echo please set mysql password.
    exit 1
fi
if [ "${DB_NAME}" = "" ]; then
    echo please set database name.
    exit 1
fi
if [ "${SQL_FILE}" = "" ]; then
    echo please set sql file.
    exit 1
fi
if [ ! -e "${SQL_FILE}" ]; then
    echo not found sql file: ${SQL_FILE}
    exit 1
fi
if [ "${CONTAINER_NAME}" = "" ] && [ "${MYSQL_HOST}" = "" ]; then
    echo please set mysql host or container name.
    exit 1
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}
echo --SQL File: ${SQL_FILE}
echo --Database: ${DB_NAME}
echo --Uppercase: $([ "${SKIP_UPPERCASE}" = "ON" ] && echo "OFF" || echo "ON")

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

# 检查perl（用于表名大写转换）
if [ "${SKIP_UPPERCASE}" != "ON" ]; then
    perl -v > /dev/null 2>&1
    if [ "$?" != "0" ]; then
        echo please install perl, or use -S to skip uppercase.
        exit 1
    fi
fi

# 检查gzip（如果是.gz文件）
if [[ "${SQL_FILE}" == *.gz ]]; then
    gzip -V > /dev/null 2>&1
    if [ "$?" != "0" ]; then
        echo please install gzip.
        exit 1
    fi
fi

# 创建数据库（如果不存在）
echo --creating database if not exists: ${DB_NAME}
if [ "${CONTAINER_NAME}" != "" ]; then
    ${DOCKER_CMD} exec "${CONTAINER_NAME}" mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} \
        -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4;" 2>/dev/null
else
    mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} \
        -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4;" 2>/dev/null
fi

# 设置全局参数：允许导入函数和存储过程（避免 binlog 报错 ERROR 1418）
echo --setting log_bin_trust_function_creators = 1
if [ "${CONTAINER_NAME}" != "" ]; then
    ${DOCKER_CMD} exec "${CONTAINER_NAME}" mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} \
        -e "SET GLOBAL log_bin_trust_function_creators = 1;" 2>/dev/null
else
    mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} \
        -e "SET GLOBAL log_bin_trust_function_creators = 1;" 2>/dev/null
fi

# 执行还原
echo "****** restoring: ${SQL_FILE} -> ${DB_NAME} ******"

# 构建读取SQL的管道
{
    # 前置设置：关闭外键检查，避免导入顺序导致的约束报错
    echo "SET FOREIGN_KEY_CHECKS=0;"
    if [[ "${SQL_FILE}" == *.gz ]]; then
        gunzip -c "${SQL_FILE}"
    else
        cat "${SQL_FILE}"
    fi
} | {
    # 通用处理：始终执行
    perl -pe '
        # 移除Windows换行符
        s/\r//g;
        # 注释掉USE语句，避免切换到其他数据库
        s/^(USE\s+`[^`]+`\s*;)/-- $1/gi;
        # 移除DEFINER子句，避免目标库不存在原定义用户报错
        # 匹配 DEFINER=`user`@`host`（mysqldump标准格式）
        s/DEFINER\s*=\s*`[^`]+`@`[^`]+`//gi;
        # 匹配 DEFINER=user@host（无引号格式）
        s/DEFINER\s*=\s*[\w.%]+@[\w.%]+//gi;
    '
} | {
    # 表名大写转换（可跳过）
    if [ "${SKIP_UPPERCASE}" = "ON" ]; then
        cat
    else
        perl -pe '
            # CREATE TABLE / DROP TABLE / ALTER TABLE [IF NOT EXISTS / IF EXISTS]
            s/((?:CREATE|DROP|ALTER)\s+TABLE\s+(?:IF\s+(?:NOT\s+)?EXISTS\s+)?)`([^`]+)`/$1`\U$2`/gi;
            # INSERT INTO
            s/(INSERT\s+INTO\s+)`([^`]+)`/$1`\U$2`/gi;
            # LOCK TABLES
            s/(LOCK\s+TABLES\s+)`([^`]+)`/$1`\U$2`/gi;
            # DELETE FROM
            s/(DELETE\s+FROM\s+)`([^`]+)`/$1`\U$2`/gi;
            # UPDATE
            s/(UPDATE\s+)`([^`]+)`/$1`\U$2`/gi;
            # REFERENCES（外键引用的表名）
            s/(REFERENCES\s+)`([^`]+)`/$1`\U$2`/gi;
            # TRUNCATE [TABLE]
            s/(TRUNCATE\s+(?:TABLE\s+)?)`([^`]+)`/$1`\U$2`/gi;
            # RENAME TABLE
            s/(RENAME\s+TABLE\s+)`([^`]+)`/$1`\U$2`/gi;
            # CREATE INDEX ... ON
            s/(ON\s+)`([^`]+)`(\s*\()/$1`\U$2`$3/gi;
            # CREATE VIEW / ALTER VIEW ... AS SELECT ... FROM
            s/((?:CREATE|ALTER)\s+VIEW\s+)`([^`]+)`/$1`\U$2`/gi;
            s/(FROM\s+)`([^`]+)`/$1`\U$2`/gi;
            s/(JOIN\s+)`([^`]+)`/$1`\U$2`/gi;
        '
    fi
} | {
    # 还原到MySQL
    if [ "${CONTAINER_NAME}" != "" ]; then
        ${DOCKER_CMD} exec -i "${CONTAINER_NAME}" mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} --default-character-set=utf8mb4 "${DB_NAME}"
    else
        mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} --default-character-set=utf8mb4 "${DB_NAME}"
    fi
}
# 捕获管道最后一步的退出状态
RESTORE_RESULT=${PIPESTATUS[3]}

# 检查结果
if [ ${RESTORE_RESULT} -ne 0 ]; then
    echo "error: restore failed."
    exit 1
else
    echo "success: restored ${SQL_FILE} to ${DB_NAME}"
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
