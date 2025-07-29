#!/bin/bash
echo '****************************************************************************'
echo '                   k8s_cleanup_running_logs.sh                              '
echo '                           by niuren.zhu                                    '
echo '                              2024.06.26                                    '
echo '  note:                                                                     '
echo '      1. clean up runing logs.                                              '
echo '  parameter:                                                                '
echo '      -f [clean folder]             cleaning folder.                        '
echo '      -e [clean expire day]         file expire day, defalut 14 days.       '
echo '****************************************************************************'
# 设置参数变量
while getopts "f:e:" arg; do
    case $arg in
    f)
        CLEAN_FOLDER=$OPTARG
        ;;
    e)
        EXPIRE_DAYS=$OPTARG
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)
if [ "${CLEAN_FOLDER}" = "" ]; then
    CLEAN_FOLDER=${WORK_FOLDER}
fi
# 清理天数
if [ "${EXPIRE_DAYS}" = "" ]; then
    EXPIRE_DAYS=14
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}
echo --Work Folder: ${CLEAN_FOLDER}
echo --Days Ago: ${EXPIRE_DAYS}

# 开始执行命令
echo --working, clean logs please waiting.

# 清理日志文件
find ${CLEAN_FOLDER} -type f -name "ibas_*.log" -mtime +${EXPIRE_DAYS} -exec rm -f {} \;

# 清理水晶报表运行文件
find ${CLEAN_FOLDER} -type d -name "crystalreports_files" | while read -r FOLDER_ITEM; do
    echo --working, clean crystal reports runging logs please waiting.
    find ${FOLDER_ITEM} -type f -name "Params.properties" -mtime +${EXPIRE_DAYS} -exec rm -f {} \;
    find ${FOLDER_ITEM} -type f -name "ReportFile.rpt" -mtime +${EXPIRE_DAYS} -exec rm -f {} \;
    find ${FOLDER_ITEM} -type d -empty -delete;
done

# 清理集成任务运行日志
find ${CLEAN_FOLDER} -type d -name "integration_files" | while read -r FOLDER_ITEM; do
    echo --working, clean integration runging logs please waiting.
    find ${FOLDER_ITEM} -type f -name "*.txt" -mtime +${EXPIRE_DAYS} -exec rm -f {} \;
done

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
