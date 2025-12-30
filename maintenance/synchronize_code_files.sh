#!/bin/bash
echo '****************************************************************************'
echo '                   synchronize_code_files.sh                                '
echo '                           by niuren.zhu                                    '
echo '                              2025.12.30                                    '
echo '  note:                                                                     '
echo '      1. synchronize code files and handle tf management status.            '
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
  if [ -e ${TARGET_FILE} ]; then
    tf checkout ${TARGET_FILE}
    cp -f ${SOURCE_FILE} ${TARGET_FILE}
  else
    cp ${SOURCE_FILE} ${TARGET_FILE} && tf add ${TARGET_FILE}
  fi
# 修正文件内容，非mac替换sed -i "" 为 sed -i
  sed -i "" 's/.data.Decimal;/.common.Decimals;/g' "${TARGET_FILE}"
  sed -i "" 's/.mapping.BusinessObjectUnit;/.bo.BusinessObjectUnit;/g' "${TARGET_FILE}"
  sed -i "" 's/.mapping.DbField;/.db.DbField;/g' "${TARGET_FILE}"
  sed -i "" 's/.mapping.DbFieldType;/.db.DbFieldType;/g' "${TARGET_FILE}"
  sed -i "" 's/.mapping.LogicContract;/.logic.LogicContract;/g' "${TARGET_FILE}"
  sed -i "" 's/.mapping.Value;/.common.Value;/g' "${TARGET_FILE}"
  sed -i "" 's/.core.RepositoryException;/.repository.RepositoryException;/g' "${TARGET_FILE}"
  sed -i "" 's/.serialization.Serializable/.core.Serializable/g' "${TARGET_FILE}"
  sed -i "" 's/Decimal.ZERO/Decimals.VALUE_ZERO/g' "${TARGET_FILE}"
  sed -i "" 's/Decimal.ONE/Decimals.VALUE_ONE/g' "${TARGET_FILE}"
  sed -i "" 's/IConfigurationManager/ConfigurationManager/g' "${TARGET_FILE}"
  sed -i "" 's/ConfigurationFactory.create().createManager()/ConfigurationFactory.createManager()/g' "${TARGET_FILE}"
  sed -i "" 's/FileRepository.CRITERIA_CONDITION_ALIAS_FILE_NAME/FileRepository.CONDITION_ALIAS_FILE_NAME/g' "${TARGET_FILE}"
  sed -i "" 's/this.getRepository().setRepositoryFolder(FileService.WORK_FOLDER)/this.setRepositoryFolder(FileService.WORK_FOLDER)/g' "${TARGET_FILE}"
}

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}
echo --Source Folder: ${SOURCE_FOLDER}
echo --Target Folder: ${TARGET_FOLDER}

CODE_TYPES="*.java *.properties *.xml *.ts *.json"
CODE_FILES="~code_files.txt"

# 清理干扰文件
rm -f "${WORK_FOLDER}/${CODE_FILES}"
rm -rf "${SOURCE_FOLDER}/release"
find "${SOURCE_FOLDER}" -name "target" -type d -exec rm -rf {} \;
find "${TARGET_FOLDER}" -name "target" -type d -exec rm -rf {} \;

# 查找待处理文件
for CODE_TYPE in ${CODE_TYPES}; do
    find "${SOURCE_FOLDER}" -name "${CODE_TYPE}" -path "*/src/main/*" | while read -r CODE_FILE; do
        FILE_NAME=${CODE_FILE##*/}
        if [ ${FILE_NAME} == "pom.xml" ]; then
            continue
        fi
        if [ ${FILE_NAME} == "app.xml" ]; then
            continue
        fi
        if [ ${FILE_NAME} == "config.json" ]; then
            continue
        fi
        synchronize ${CODE_FILE}
    done
done
#

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
