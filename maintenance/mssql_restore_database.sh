#!/bin/bash
echo '****************************************************************************'
echo '                   mssql_restore_database.sh                                '
echo '                           by niuren.zhu                                    '
echo '                              2026.07.24                                    '
echo '  note:                                                                     '
echo '      1. restore sql server backup file (.bak) to database.                 '
echo '      2. support local sqlcmd or docker/podman container.                  '
echo '      3. allow restore to a different database name.                       '
echo '  parameter:                                                                '
echo '      -u [user]              sql server user, default sa.                  '
echo '      -p [password]          sql server password.                          '
echo '      -h [host]              sql server host, optional for container mode. '
echo '      -P [port]              sql server port, default 1433.                '
echo '      -d [db name]           target database name to restore to.           '
echo '      -f [bak file]          backup file (.bak).                           '
echo '      -c [container]         docker/podman container name, optional.       '
echo '****************************************************************************'
# 设置参数变量
while getopts "u:p:h:P:d:f:c:" arg; do
    case $arg in
    u)
        MSSQL_USER=$OPTARG
        ;;
    p)
        MSSQL_PASSWORD=$OPTARG
        ;;
    h)
        MSSQL_HOST=$OPTARG
        ;;
    P)
        MSSQL_PORT=$OPTARG
        ;;
    d)
        DB_NAME=$OPTARG
        ;;
    f)
        BAK_FILE=$OPTARG
        ;;
    c)
        CONTAINER_NAME=$OPTARG
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)
# 默认值
if [ "${MSSQL_USER}" = "" ]; then
    MSSQL_USER=sa
fi
if [ "${MSSQL_PORT}" = "" ]; then
    MSSQL_PORT=1433
fi
# SQL Server数据目录（容器内）
DATA_DIR="/var/opt/mssql/data/"

# 参数校验
if [ "${MSSQL_PASSWORD}" = "" ]; then
    echo please set sql server password.
    exit 1
fi
if [ "${DB_NAME}" = "" ]; then
    echo please set target database name.
    exit 1
fi
if [ "${BAK_FILE}" = "" ]; then
    echo please set backup file.
    exit 1
fi
if [ "${CONTAINER_NAME}" = "" ] && [ "${MSSQL_HOST}" = "" ]; then
    echo please set sql server host or container name.
    exit 1
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}
echo --Backup File: ${BAK_FILE}
echo --Database: ${DB_NAME}

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
    # 检查容器内sqlcmd路径（v18优先，其次v17）
    if ${DOCKER_CMD} exec "${CONTAINER_NAME}" /opt/mssql-tools18/bin/sqlcmd -? > /dev/null 2>&1; then
        SQLCMD_PATH="/opt/mssql-tools18/bin/sqlcmd"
    elif ${DOCKER_CMD} exec "${CONTAINER_NAME}" /opt/mssql-tools/bin/sqlcmd -? > /dev/null 2>&1; then
        SQLCMD_PATH="/opt/mssql-tools/bin/sqlcmd"
    else
        echo sqlcmd not found in container: ${CONTAINER_NAME}
        exit 1
    fi
    echo --sqlcmd: ${SQLCMD_PATH}
    # 检查本地备份文件
    if [ ! -e "${BAK_FILE}" ]; then
        echo not found backup file: ${BAK_FILE}
        exit 1
    fi
    # 复制备份文件到容器内
    BAK_FILE_NAME=$(basename "${BAK_FILE}")
    CONTAINER_BAK="${DATA_DIR}restore_temp_${BAK_FILE_NAME}"
    echo --copying backup file to container: ${CONTAINER_BAK}
    ${DOCKER_CMD} cp "${BAK_FILE}" "${CONTAINER_NAME}:${CONTAINER_BAK}"
    if [ "$?" != "0" ]; then
        echo error: failed to copy backup file to container.
        exit 1
    fi
    # 确保mssql用户可读
    ${DOCKER_CMD} exec "${CONTAINER_NAME}" chown mssql:mssql "${CONTAINER_BAK}" 2>/dev/null
    # 容器内连接本地SQL Server
    SQLCMD_SERVER="localhost"
else
    # 本地模式
    sqlcmd -? > /dev/null 2>&1
    if [ "$?" != "0" ]; then
        echo please install sqlcmd.
        exit 1
    fi
    echo --Mode: Local sqlcmd
    SQLCMD_PATH="sqlcmd"
    # 本地模式下备份文件路径须为SQL Server可访问的路径
    BAK_FILE_NAME=$(basename "${BAK_FILE}")
    CONTAINER_BAK="${BAK_FILE}"
    SQLCMD_SERVER="${MSSQL_HOST},${MSSQL_PORT}"
    echo --note: backup file path must be accessible by sql server.
fi

# 构建sqlcmd基础命令
run_sqlcmd() {
    if [ "${CONTAINER_NAME}" != "" ]; then
        ${DOCKER_CMD} exec "${CONTAINER_NAME}" "${SQLCMD_PATH}" -S "${SQLCMD_SERVER}" -U "${MSSQL_USER}" -P "${MSSQL_PASSWORD}" -C -b "$@"
    else
        "${SQLCMD_PATH}" -S "${SQLCMD_SERVER}" -U "${MSSQL_USER}" -P "${MSSQL_PASSWORD}" -C -b "$@"
    fi
}

# 获取备份文件中的逻辑文件名
echo --reading backup file list...
FILELIST=$(run_sqlcmd -h -1 -W -s "|" -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = '${CONTAINER_BAK}'" 2>/dev/null)
if [ $? -ne 0 ] || [ "${FILELIST}" = "" ]; then
    echo "error: failed to read backup file list."
    # 清理容器内临时文件
    if [ "${CONTAINER_NAME}" != "" ]; then
        ${DOCKER_CMD} exec "${CONTAINER_NAME}" rm -f "${CONTAINER_BAK}" 2>/dev/null
    fi
    exit 1
fi

# 解析逻辑文件名，构建MOVE子句
MOVE_CLAUSES=""
DATA_IDX=0
LOG_IDX=0

while IFS='|' read -r LOGICAL_NAME _PHYSICAL TYPE _REST; do
    # 去除首尾空白
    LOGICAL_NAME=$(echo "${LOGICAL_NAME}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    TYPE=$(echo "${TYPE}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # 跳过空行
    [ "${LOGICAL_NAME}" = "" ] && continue
    if [ "${TYPE}" = "D" ]; then
        DATA_IDX=$((DATA_IDX + 1))
        if [ ${DATA_IDX} -eq 1 ]; then
            TARGET_FILE="${DATA_DIR}${DB_NAME}.mdf"
        else
            TARGET_FILE="${DATA_DIR}${DB_NAME}_${DATA_IDX}.ndf"
        fi
        MOVE_CLAUSES="${MOVE_CLAUSES}MOVE '${LOGICAL_NAME}' TO '${TARGET_FILE}', "
        echo --  data file: ${LOGICAL_NAME} -> ${TARGET_FILE}
    elif [ "${TYPE}" = "L" ]; then
        LOG_IDX=$((LOG_IDX + 1))
        if [ ${LOG_IDX} -eq 1 ]; then
            TARGET_FILE="${DATA_DIR}${DB_NAME}_log.ldf"
        else
            TARGET_FILE="${DATA_DIR}${DB_NAME}_log_${LOG_IDX}.ldf"
        fi
        MOVE_CLAUSES="${MOVE_CLAUSES}MOVE '${LOGICAL_NAME}' TO '${TARGET_FILE}', "
        echo --  log file: ${LOGICAL_NAME} -> ${TARGET_FILE}
    fi
done <<< "${FILELIST}"

# 检查是否解析到文件
if [ "${MOVE_CLAUSES}" = "" ]; then
    echo "error: no data or log files found in backup."
    if [ "${CONTAINER_NAME}" != "" ]; then
        ${DOCKER_CMD} exec "${CONTAINER_NAME}" rm -f "${CONTAINER_BAK}" 2>/dev/null
    fi
    exit 1
fi
# 去除末尾的", "
MOVE_CLAUSES=${MOVE_CLAUSES%, *}

# 如果目标数据库已存在，断开现有连接
echo --disconnecting existing sessions if database exists: ${DB_NAME}
run_sqlcmd -Q "IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '${DB_NAME}') ALTER DATABASE [${DB_NAME}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;" 2>/dev/null

# 执行还原
echo "****** restoring: ${BAK_FILE} -> ${DB_NAME} ******"
RESTORE_SQL="RESTORE DATABASE [${DB_NAME}] FROM DISK = '${CONTAINER_BAK}' WITH ${MOVE_CLAUSES}, REPLACE, RECOVERY, STATS = 10;"
echo --SQL: ${RESTORE_SQL}
run_sqlcmd -Q "${RESTORE_SQL}"
RESTORE_RESULT=$?

if [ ${RESTORE_RESULT} -ne 0 ]; then
    echo "error: restore failed."
    # 还原失败时尝试恢复多用户模式
    run_sqlcmd -Q "IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '${DB_NAME}') ALTER DATABASE [${DB_NAME}] SET MULTI_USER;" 2>/dev/null
    if [ "${CONTAINER_NAME}" != "" ]; then
        ${DOCKER_CMD} exec "${CONTAINER_NAME}" rm -f "${CONTAINER_BAK}" 2>/dev/null
    fi
    exit 1
fi

# 恢复多用户模式
echo --setting database to multi_user mode: ${DB_NAME}
run_sqlcmd -Q "ALTER DATABASE [${DB_NAME}] SET MULTI_USER;" 2>/dev/null

# 设置为简单恢复模式并收缩数据库空间
echo --setting recovery model to simple: ${DB_NAME}
run_sqlcmd -Q "ALTER DATABASE [${DB_NAME}] SET RECOVERY SIMPLE;" 2>/dev/null

echo --shrinking database: ${DB_NAME}
run_sqlcmd -Q "DBCC SHRINKDATABASE ([${DB_NAME}]);" 2>/dev/null

# 修复孤立用户（Orphaned Users）
# 还原到不同服务器时，数据库用户的SID与服务器登录账户不匹配，导致无法登录
# 通过sp_change_users_login自动修复已有登录账户的映射关系
echo --fixing orphaned users: ${DB_NAME}
run_sqlcmd -d "${DB_NAME}" -Q "SET NOCOUNT ON; DECLARE @sql NVARCHAR(MAX); SELECT @sql = @sql + 'ALTER USER [' + name + '] WITH LOGIN = [' + name + ']; ' FROM sys.database_principals WHERE type = 'S' AND name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys') AND name NOT LIKE '##%##'; EXEC sp_executesql @sql;" 2>/dev/null
echo --orphaned users fixed.

# 清理容器内临时备份文件
if [ "${CONTAINER_NAME}" != "" ]; then
    echo --cleanup temp backup file in container.
    ${DOCKER_CMD} exec "${CONTAINER_NAME}" rm -f "${CONTAINER_BAK}" 2>/dev/null
fi

# 验证还原结果
echo --verifying database: ${DB_NAME}
DB_STATE=$(run_sqlcmd -h -1 -W -Q "SET NOCOUNT ON; SELECT state_desc FROM sys.databases WHERE name = '${DB_NAME}';" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [ "${DB_STATE}" = "ONLINE" ]; then
    echo "success: restored ${BAK_FILE} to ${DB_NAME} (ONLINE)"
else
    echo "warning: database state is '${DB_STATE}', please check manually."
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
