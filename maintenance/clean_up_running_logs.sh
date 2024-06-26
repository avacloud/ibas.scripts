#!/bin/bash
echo '****************************************************************************'
echo '                   clean_up_running_logs.sh                                 '
echo '                           by niuren.zhu                                    '
echo '                              2024.06.26                                    '
echo '  note:                                                                     '
echo '      1. clean up runing logs.                                              '
echo '  parameter:                                                                '
echo '        $1             days ago.                                            '
echo '****************************************************************************'
# 设置参数变量
# 工作目录
WORK_FOLDER=$(pwd)
# 清理天数
DAYS_AGO=$1
if [ "${DAYS_AGO}" = "" ]; then
    DAYS_AGO=15
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}
echo --Work Folder: ${WORK_FOLDER}
echo --Days Ago: ${DAYS_AGO}

# 开始执行命令
echo --working, please wait.
find ${WORK_FOLDER} -type f -name "ibas_runtime_*.log" -mtime +${DAYS_AGO} -exec rm -f {} \;
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
