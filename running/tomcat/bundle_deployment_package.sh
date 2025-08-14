#!/bin/bash
echo '****************************************************************************'
echo '                      bundle_deployment_package.sh                          '
echo '                           by niuren.zhu                                    '
echo '                              2025.07.23                                    '
echo '  note:                                                                     '
echo '      1. bundle tomcat package, include scripts, tools, configs.            '
echo '  parameter:                                                                '
echo '      -v [tomcat version]        tomcat version.                            '
echo '      -j [java url]              java download url.                         '
echo '****************************************************************************'
# 设置参数变量
while getopts ":t:j" arg; do
    case $arg in
    t)
        TOMCAT_VERSION=$OPTARG
        ;;
    j)
        JAVA_URL=$OPTARG
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)
# 设置默认变量值
if [ "${TOMCAT_VERSION}" = "" ]; then
    TOMCAT_VERSION="9.0.108"
fi
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}-windows-x64.zip"

if [ "${JAVA_URL}" = "" ]; then
    JAVA_URL="http://maven.colorcoding.org/repository/software/java/ibm-semeru-open-jdk_x64_windows_8u452b09_openj9-0.51.0.zip"
fi

SCRIPTS_URL="http://maven.colorcoding.org/repository/maven-releases/org/colorcoding/tools/btulz.scripts/latest/btulz.scripts-latest.tar"
SCRIPTS_TOOLS_URL="http://maven.colorcoding.org/repository/maven-releases/org/colorcoding/tools/btulz.scripts/win-tools/btulz.scripts-win-tools.tar"
BTULZ_URL="http://maven.colorcoding.org/repository/maven-releases/org/colorcoding/tools/btulz.transforms/latest/btulz.transforms-latest.tar"

echo --checking tools
curl -V | sed -n '1p'
if [ "$?" != "0" ]; then
    echo please install curl.
    exit 1
fi
unzip -v | sed -n '1p'
if [ "$?" != "0" ]; then
    echo please install unzip.
    exit 1
fi
zip -v | sed -n '1p'
if [ "$?" != "0" ]; then
    echo please install zip.
    exit 1
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}

TEMP_FOLDER=${WORK_FOLDER}/temp
if [ -e "${TEMP_FOLDER}" ]; then
    rm -rf "${TEMP_FOLDER}"
fi
mkdir -p "${TEMP_FOLDER}"

# 下载tomcat
echo ---download: ${TOMCAT_URL}
curl -fSL --retry 3 ${TOMCAT_URL} -o ${TEMP_FOLDER}/tomcat.zip
if [ ! -e "${TEMP_FOLDER}/tomcat.zip" ]; then
    echo not found tomcat package.
    exit 1
fi
unzip -q -d ${TEMP_FOLDER}/ ${TEMP_FOLDER}/tomcat.zip
TOMCAT_FOLDER=${TEMP_FOLDER}/apache-tomcat-${TOMCAT_VERSION}

# 更新配置文件
TOMCAT_DATA_FOLDER=${WORK_FOLDER}/container/tomcat
if [ -e "${TOMCAT_DATA_FOLDER}/bin" ]; then
    cp -rf "${TOMCAT_DATA_FOLDER}/bin" ${TOMCAT_FOLDER}/
fi
if [ -e "${TOMCAT_DATA_FOLDER}/conf" ]; then
    cp -rf "${TOMCAT_DATA_FOLDER}/conf" ${TOMCAT_FOLDER}/
fi
if [ -e "${TOMCAT_DATA_FOLDER}/ibas" ]; then
    cp -rf "${TOMCAT_DATA_FOLDER}/ibas" ${TOMCAT_FOLDER}/
fi
cp -rf "${TOMCAT_DATA_FOLDER}/packages.txt" ${TOMCAT_FOLDER}/
cp -rf "${TOMCAT_DATA_FOLDER}/readme.txt" ${TOMCAT_FOLDER}/
mkdir -p ${TOMCAT_FOLDER}/ibas/data
mkdir -p ${TOMCAT_FOLDER}/ibas/conf
mkdir -p ${TOMCAT_FOLDER}/ibas/logs
mkdir -p ${TOMCAT_FOLDER}/ibas_lib
mkdir -p ${TOMCAT_FOLDER}/ibas_tools
mkdir -p ${TOMCAT_FOLDER}/ibas_packages
rd /s /q ${TOMCAT_FOLDER}/webapps && mkdir -p ${TOMCAT_FOLDER}/webapps

# 增加运行脚本
echo ---download: ${SCRIPTS_URL}
curl -fSL --retry 3 ${SCRIPTS_URL} -o ${TEMP_FOLDER}/btulz.scripts.tar
if [ ! -e "${TEMP_FOLDER}/btulz.scripts.tar" ]; then
    echo not found scripts package.
    exit 1
fi
cd "${TOMCAT_FOLDER}" \
&& tar -xvf "${TEMP_FOLDER}/btulz.scripts.tar" \
    --strip-components=1 ibas/deploy_apps.bat ibas/download_apps.bat ibas/initialize_apps.bat ibas/startcat.bat
cd "${WORK_FOLDER}"

echo ---download: ${BTULZ_URL}
curl -fSL --retry 3 ${BTULZ_URL} -o ${TEMP_FOLDER}/btulz.transforms.tar
if [ ! -e "${TEMP_FOLDER}/btulz.transforms.tar" ]; then
    echo not found transforms package.
    exit 1
fi
cd "${TOMCAT_FOLDER}/ibas_tools" && tar -xvf "${TEMP_FOLDER}/btulz.transforms.tar"
cd "${WORK_FOLDER}"

echo ---download: ${SCRIPTS_TOOLS_URL}
curl -fSL --retry 3 ${SCRIPTS_TOOLS_URL} -o ${TEMP_FOLDER}/btulz.tools.tar
if [ ! -e "${TEMP_FOLDER}/btulz.tools.tar" ]; then
    echo not found tools package.
    exit 1
fi
cd "${TOMCAT_FOLDER}/ibas_tools" && tar -xvf "${TEMP_FOLDER}/btulz.tools.tar"
cd "${WORK_FOLDER}"

# 打包无java
echo ---packaging: ${TOMCAT_FOLDER}
cd ${TEMP_FOLDER}
zip -9 -q -r apache-tomcat-${TOMCAT_VERSION}-windows-x64.zip ./apache-tomcat-${TOMCAT_VERSION}/*
cd ${WORK_FOLDER}


# 下载java
echo ---download: ${JAVA_URL}
curl -fSL --retry 3 ${JAVA_URL} -o ${TEMP_FOLDER}/openjdk.zip
if [ ! -e "${TEMP_FOLDER}/openjdk.zip" ]; then
    echo not found java package.
    exit 1
fi
unzip -q -d ${TEMP_FOLDER}/ ${TEMP_FOLDER}/openjdk.zip
mv ${TEMP_FOLDER}/jdk* ${TOMCAT_FOLDER}/jdk
rm -rf ${TOMCAT_FOLDER}/jdk/src.zip
rm -rf ${TOMCAT_FOLDER}/jdk/sample

# 打包含java
echo ---packaging: ${TOMCAT_FOLDER}
cd ${TEMP_FOLDER}
zip -9 -q -r apache-tomcat-${TOMCAT_VERSION}-windows-x64_with_jdk.zip ./apache-tomcat-${TOMCAT_VERSION}/*
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
