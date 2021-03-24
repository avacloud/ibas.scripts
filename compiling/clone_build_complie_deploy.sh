#!/bin/bash
echo '****************************************************************************'
echo '              clone_build_complie_deploy.sh                                 '
echo '                           by Niuren.Zhu                                    '
echo '                           2021.03.19                                       '
echo '  note：                                                                     '
echo '    1. clone from GitHub.                                                    '
echo '    2. clone from TFS.                                                       '
echo '    3. builds & complies.                                                   '
echo '    4. deploy wars.                                                         '
echo '****************************************************************************'
# 设置参数变量
# 工作目录
WORK_FOLDER=$(pwd)
# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time：${START_TIME}
echo --Work Folder：${WORK_FOLDER}

# 检查环境
echo --checking tools
java -version
if [ "$?" != "0" ]; then
    echo please install jdk.
    exit 1
fi
mvn -version
if [ "$?" != "0" ]; then
    echo please install maven.
    exit 1
fi
npm -v
if [ "$?" != "0" ]; then
    echo please install nodejs and npm.
    exit 1
fi
tsc -v
if [ "$?" != "0" ]; then
    echo please run [npm install -g typescript].
    exit 1
fi
uglifyjs -V
if [ "$?" != "0" ]; then
    echo please run [npm install -g uglify-es].
    exit 1
fi
# 设置配置
echo "--please confirm settings, Entry to skip."
read -p "---replace maven setting? (yes or [n]o):" REPLACE
if [ "${REPLACE}" = "y" ]; then
    if [ -e ${MAVEN_HOME}/conf/settings.xml ]; then
        cp -f ${WORK_FOLDER}/conf/maven.settings.xml ${MAVEN_HOME}/conf/settings.xml
    fi
fi
read -p "---tfs user ("\\" must be "\\\\"):" TFS_USER
if [ "${TFS_USER}" != "" ]; then
    git config --global git-tf.server.username "${TFS_USER}"
fi
read -p "---tfs password:" TFS_PWD
if [ "${TFS_PWD}" != "" ]; then
    git config --global git-tf.server.password "${TFS_PWD}"
fi

read -p "--deploy war packages to repository? (yes or [n]o):" DEPLOY
if [ "${DEPLOY}" = "y" ]; then
    read -p "---packages version ($(date +%Y%m%d%H%M)):" VERSION
    if [ "${VERSION}" = "" ]; then
        VERSION=$(date +%Y%m%d%H%M)
    fi
fi

# 初始环境变量
echo --do tasks
if [ "${CODE_HOME}" = "" ]; then
    CODE_HOME=${WORK_FOLDER}
fi
if [ "${GIT_URL}" = "" ]; then
    GIT_URL=https://github.com
fi
if [ "${TFS_URL}" = "" ]; then
    TFS_URL=http://tfs.avatech.com.cn:8080/tfs
fi
if [ "${MAVEN_URL}" = "" ]; then
    MAVEN_URL=http://nexus.avacloud.com.cn/repository/maven-releases
fi

echo --get btulz.scripts
if [ ! -e ${WORK_FOLDER}/btulz.scripts ]; then
    git clone --depth 1 ${GIT_URL}/color-coding/btulz.scripts.git
    if [ -e ${WORK_FOLDER}/btulz.scripts/ibas ]; then
        chmod +x ${WORK_FOLDER}/btulz.scripts/ibas/*.sh
    fi
    if [ ! -e ${WORK_FOLDER}/copy_wars.sh ]; then
        ln -s ${WORK_FOLDER}/btulz.scripts/ibas/copy_wars.sh ${WORK_FOLDER}/copy_wars.sh
    fi
fi

echo --do git tasks
for COMPILE_ORDER in $(ls git*.compile_order.txt | awk '//{print $NF}'); do
    echo --do task: ${COMPILE_ORDER}
    # 获得目录
    GROUP_FOLDER=${COMPILE_ORDER%.compile_order.txt*}
    GROUP_FOLDER=${GROUP_FOLDER//.//}
    CODE_FOLDER=${CODE_HOME}/${GROUP_FOLDER}
    mkdir -p ${CODE_FOLDER}
    cd ${CODE_FOLDER}
    # 链接脚本
    if [ ! -e ${CODE_FOLDER}/builds.sh ]; then
        ln -s ${WORK_FOLDER}/btulz.scripts/ibas/builds.sh ${CODE_FOLDER}/builds.sh
    fi
    if [ ! -e ${CODE_FOLDER}/compiles.sh ]; then
        ln -s ${WORK_FOLDER}/btulz.scripts/ibas/compiles.sh ${CODE_FOLDER}/compiles.sh
    fi
    if [ ! -e ${CODE_FOLDER}/deploy_wars.sh ]; then
        ln -s ${WORK_FOLDER}/btulz.scripts/ibas/deploy_wars.sh ${CODE_FOLDER}/deploy_wars.sh
    fi
    if [ -e ${CODE_FOLDER}/compile_order.txt ]; then
        rm -rf ${CODE_FOLDER}/compile_order.txt
    fi
    # 编译
    while read line; do
        folder=${line%% *}
        others=${line#* }
        if [ "${folder}" = "${others}" ]; then
            others=
        fi
        echo ---${folder}
        collection=${folder%/*}
        folder=${folder##*/}

        if [ -e "${CODE_FOLDER}/${folder}/.git" ]; then
            cd ${CODE_FOLDER}/${folder} && git pull --depth 1
        else
            git clone --depth 1 ${GIT_URL}/${collection}/${folder}.git ${others}
        fi
        echo ${folder} >>${CODE_FOLDER}/compile_order.txt
    done <${WORK_FOLDER}/${COMPILE_ORDER} | sed 's/\r//g'
    cd ${CODE_FOLDER}
    ./builds.sh && ./compiles.sh
    # 清理编译临时文件
    find . -name "target" -type d -exec rm -rf {} \; >/dev/null
    # 存在脚本则上传war包
    if [ "${DEPLOY}" = "y" ]; then
        echo --deploy wars to [${MAVEN_URL}], and version [${VERSION}]
        ./deploy_wars.sh ${VERSION} ${MAVEN_URL}
    fi
done
cd ${WORK_FOLDER}

echo --do tfs tasks
for COMPILE_ORDER in $(ls tfs*.compile_order.txt | awk '//{print $NF}'); do
    echo --do task: ${COMPILE_ORDER}
    # 获得目录
    GROUP_FOLDER=${COMPILE_ORDER%.compile_order.txt*}
    GROUP_FOLDER=${GROUP_FOLDER//.//}
    CODE_FOLDER=${CODE_HOME}/${GROUP_FOLDER}
    mkdir -p ${CODE_FOLDER}
    cd ${CODE_FOLDER}
    # 链接脚本
    if [ ! -e ${CODE_FOLDER}/builds.sh ]; then
        ln -s ${WORK_FOLDER}/btulz.scripts/ibas/builds.sh ${CODE_FOLDER}/builds.sh
    fi
    if [ ! -e ${CODE_FOLDER}/compiles.sh ]; then
        ln -s ${WORK_FOLDER}/btulz.scripts/ibas/compiles.sh ${CODE_FOLDER}/compiles.sh
    fi
    if [ ! -e ${CODE_FOLDER}/deploy_wars.sh ]; then
        ln -s ${WORK_FOLDER}/btulz.scripts/ibas/deploy_wars.sh ${CODE_FOLDER}/deploy_wars.sh
    fi
    if [ -e ${CODE_FOLDER}/compile_order.txt ]; then
        rm -rf ${CODE_FOLDER}/compile_order.txt
    fi
    # 编译基础项目
    if [ ! -e ${CODE_FOLDER}/ibas-typescript ]; then
        git clone --depth 1 ${GIT_URL}/color-coding/ibas-typescript.git
    else
        cd ${CODE_FOLDER}/ibas-typescript && git pull --depth 1
    fi
    cd ${CODE_FOLDER}
    chmod +x ibas-typescript/*.sh && ibas-typescript/build_all.sh

    # 编译
    while read line; do
        folder=${line%% *}
        others=${line#* }
        if [ "${folder}" = "${others}" ]; then
            others=
        fi
        echo ---${folder}
        collection=${folder%/*}
        folder=${folder##*/}

        if [ -e "${CODE_FOLDER}/${folder}" ]; then
            cd ${CODE_FOLDER}/${folder} && git tf pull --rebase
        else
            git tf clone ${TFS_URL}/${collection} /${folder} ${CODE_FOLDER}/${folder}
        fi
        echo ${folder} >>${CODE_FOLDER}/compile_order.txt
    done <${WORK_FOLDER}/${COMPILE_ORDER} | sed 's/\r//g'
    cd ${CODE_FOLDER}
    ./builds.sh && ./compiles.sh
    # 清理编译临时文件
    find . -name "target" -type d -exec rm -rf {} \; >/dev/null
    # 存在脚本则上传war包
    if [ "${DEPLOY}" = "y" ]; then
        echo --deploy wars to [${MAVEN_URL}], and version [${VERSION}]
        ./deploy_wars.sh ${VERSION} ${MAVEN_URL}
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
echo --结束时间：${END_TIME}，共$((END_SECONDS - START_SECONDS))秒
