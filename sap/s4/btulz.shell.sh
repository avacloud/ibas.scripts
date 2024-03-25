#!/bin/sh
echo '****************************************************************************'
echo '             btulz.shell.bat                                                '
echo '                      by niuren.zhu                                         '
echo '                           2018.04.17                                       '
echo '  说明：                                                                    '
echo '    1. 快速启动btulz.transforms.shell.jar。                                 '
echo '    2. 当前目录不存在btulz.transforms.shell.jar，则尝试下载。               '
echo '    3. 脚本使用curl命令，请提前配置到PATH。                                 '
echo '****************************************************************************'
# 设置参数变量
cd $(dirname $0)
WORK_FOLDER=${PWD}
BTULZ_SHELL=btulz.transforms.shell-0.1.1.jar

echo --工作目录:[${WORK_FOLDER}]
echo --使用应用:[${BTULZ_SHELL}]

if [ -e "${WORK_FOLDER}/${BTULZ_SHELL}" ]; then
  java -jar "${WORK_FOLDER}/${BTULZ_SHELL}"
  echo --启动成功
  exit 0
fi
echo --应用[${BTULZ_SHELL}]不存在
TOOLS_URL=https://maven.colorcoding.org/repository/maven-releases/org/colorcoding/tools/btulz.transforms/latest/btulz.transforms-latest.tar
echo --下载:[${TOOLS_URL}]
curl -fsSL ${TOOLS_URL} -o btulz.transforms-latest.tar &&
  mkdir -p ./tmp/ &&
  tar -xvf btulz.transforms-latest.tar -C ./tmp/ &&
  cp ./tmp/btulz.transforms.*.jar ./ &&
  cp ./tmp/log4j-*.jar ./ &&
  cp ./tmp/dom4j-*.jar ./ &&
  rm -rf ./tmp/

if [ -e "${WORK_FOLDER}/${BTULZ_SHELL}" ]; then
  java -jar "${WORK_FOLDER}/${BTULZ_SHELL}"
  echo --启动成功
  exit 0
fi
echo --无法启动[${BTULZ_SHELL}]
