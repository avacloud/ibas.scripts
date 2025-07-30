#!/bin/bash
echo '****************************************************************************'
echo '                   k8s_archive_customer_data.sh                             '
echo '                           by niuren.zhu                                    '
echo '                              2025.07.30                                    '
echo '  note:                                                                     '
echo '      1.  archive customer data.                                            '
echo '  parameter:                                                                '
echo '      -d [data folder]        customer data folder.                         '
echo '      -c [customers]          customers, space division. (c001 c002 c003)   '
echo '      -b [backup folder]      backup to folder                              '
echo '****************************************************************************'
# 设置参数变量
while getopts "d:c:b:" arg; do
    case $arg in
    b)
        BACKUP_FOLDER=$OPTARG
        ;;
    c)
        CUSTOMERS=$OPTARG
        ;;
    d)
        DATA_FOLDER=$OPTARG
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)

if [ "${BACKUP_FOLDER}" = "" ]; then
    echo please set backup folder.
    exit 1
fi
if [ "${DATA_FOLDER}" = "" ]; then
    DATA_FOLDER=${WORK_FOLDER}
fi
if [ "${CUSTOMERS}" = "" ]; then
    CUSTOMERS=$(find ${DATA_FOLDER} -mindepth 1 -maxdepth 1 -type d -printf '%f ')
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}

BACKUP_TIME=$(date +%Y%m%d%H%M)

# 执行备份
cd ${DATA_FOLDER}
for CUSTOMER_NAME in ${CUSTOMERS}; do
    if [ -e "${DATA_FOLDER}/${CUSTOMER_NAME}" ]; then
        echo "****** backing up: ${CUSTOMER_NAME} ******"
        if [ -e "${DATA_FOLDER}/${CUSTOMER_NAME}" ]; then
            mkdir -p ${BACKUP_FOLDER}/${CUSTOMER_NAME}
        fi

        BACKUP_FILE="${BACKUP_FOLDER}/${CUSTOMER_NAME}/${CUSTOMER_NAME}_${BACKUP_TIME}.tar.gz"

        tar -czv -f ${BACKUP_FILE} ${CUSTOMER_NAME}
    fi
done
cd ${WORK_FOLDER}


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
