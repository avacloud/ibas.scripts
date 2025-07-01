#!/bin/bash
echo '****************************************************************************'
echo '                   unzip_openui5_packages.sh                               '
echo '                           by niuren.zhu                                    '
echo '                              2025.07.03                                    '
echo '  note:                                                                     '
echo '      1. release current folder openui5 packages.                           '
echo '  parameter:                                                                '
echo '        $1             work folder.                                         '
echo '****************************************************************************'
# 设置参数变量
# 工作目录
WORK_FOLDER=$1
if [ "${WORK_FOLDER}" = "" ]; then
    WORK_FOLDER=$(pwd)
fi

# 检查工具
unzip -v
if [ "$?" != "0" ]; then
    echo please install unzip.
    exit 1
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}

# 开始执行命令
ls openui5-runtime-*.zip | while read -r FILE_NAME; do
    FOLDER_NAME="${FILE_NAME##*-}"
    FOLDER_NAME="${FOLDER_NAME%*.zip}"
    echo --packages: ${FILE_NAME}, folder: ${FOLDER_NAME}
    if [ ! -e ${WORK_FOLDER}/${FOLDER_NAME} ]; then
        unzip -q ${FILE_NAME} -d ${FOLDER_NAME}
    fi
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
