#!/bin/bash
echo '****************************************************************************'
echo '                   synchronize_code_files.sh                                '
echo '                           by niuren.zhu                                    '
echo '                              2025.12.30                                    '
echo '  note:                                                                     '
echo '      1. synchronize code files and handle tf management status.            '
echo '      2. the replacement contents is written in file replacements.txt.      '
echo '  parameter:                                                                '
echo '        $1             source folder.                                       '
echo '        $2             target folder.                                       '
echo '****************************************************************************'
# 工作目录
WORK_FOLDER=$(pwd)
# 设置参数变量
SOURCE_FOLDER=$1
if [ ! -e "${SOURCE_FOLDER}" ]; then
    echo not found source folder.
    exit 1
fi
TARGET_FOLDER=$2
if [ ! -e "${TARGET_FOLDER}" ]; then
    echo not found target folder.
    exit 1
fi
TARGET_FOLDER=$(cd "${TARGET_FOLDER}" && pwd -P)
SOURCE_FOLDER=$(cd "${SOURCE_FOLDER}" && pwd -P)

# 检查工具
tf info "${SOURCE_FOLDER}"
if [ "$?" != "0" ]; then
    echo please install Team Explorer Everywhere.
    exit 1
fi

# 函数：同步文件
synchronize() {
  SOURCE_FILE=$1
  TARGET_FILE=$2
  FILE_PATH=${SOURCE_FILE#${SOURCE_FOLDER}/}
  echo ---sync: ${FILE_PATH}
  if [ "${TARGET_FILE}" == "" ]; then
    TARGET_FILE=${TARGET_FOLDER}/${FILE_PATH}
  fi
  mkdir -p ${TARGET_FILE%/*}
  if [ -e ${TARGET_FILE} ]; then
    tf checkout ${TARGET_FILE}
    cp -f ${SOURCE_FILE} ${TARGET_FILE}
  else
    cp ${SOURCE_FILE} ${TARGET_FILE} && tf add ${TARGET_FILE}
  fi
# 修正文件内容，非mac替换sed -i "" 为 sed -i
  if [ -e "${WORK_FOLDER}/replacements.txt" ]; then
    cat "${WORK_FOLDER}/replacements.txt" | while read -r REPLACEMENT; do
      if [ "${REPLACEMENT}" = "" ]; then
        continue;
      fi
      if [ "${REPLACEMENT:0:1}" = "#" ]; then
        continue;
      fi
      if [ "$(uname)" = "Darwin" ]; then
        sed -i "" "${REPLACEMENT}" ${TARGET_FILE}
      else
        sed -i "${REPLACEMENT}" ${TARGET_FILE}
      fi
    done
  fi
}

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}
echo --Source Folder: ${SOURCE_FOLDER}
echo --Target Folder: ${TARGET_FOLDER}

CODE_TYPES="*.java *.properties *.xml *.ts *.json"
SKIP_FILES="pom.xml app.xml config.json index.ui.c.d.ts index.ui.m.d.ts"

# 清理干扰文件
rm -rf "${SOURCE_FOLDER}/release"
find "${SOURCE_FOLDER}" -name "target" -type d -exec rm -rf {} \;
find "${TARGET_FOLDER}" -name "target" -type d -exec rm -rf {} \;

# 查找待处理文件
for CODE_TYPE in ${CODE_TYPES}; do
  find "${SOURCE_FOLDER}" -name "${CODE_TYPE}" -path "*/src/main/*" | while read -r CODE_FILE; do
    FILE_NAME=${CODE_FILE##*/}
    if echo "${SKIP_FILES}" | grep -q "${FILE_NAME}"; then
      continue
    fi
    synchronize ${CODE_FILE}
  done
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
