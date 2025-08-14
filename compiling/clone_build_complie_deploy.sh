#!/bin/bash
echo '****************************************************************************'
echo '              clone_build_complie_deploy.sh                                 '
echo '                           by niuren.zhu                                    '
echo '                              2021.03.19                                    '
echo '  note:                                                                     '
echo '    1. clone from GitHub.                                                    '
echo '    2. clone from TFS.                                                       '
echo '    3. builds & complies.                                                   '
echo '    4. deploy wars.                                                         '
echo '  parameter:                                                                '
echo '      -q             quiet mode, no interaction.                           '
echo '      -r             replace maven setting file.                           '
echo '      -i [id]        maven id.                                             '
echo '      -m [user]      maven user.                                           '
echo '      -w [password]  maven password.                                       '
echo '      -u [user]      tfs user.                                             '
echo '      -p [password]  tfs password.                                         '
echo '      -d [version]   deploy packages to repository,                         '
echo '                         version default value is today.                    '
echo '      -s             code files is stored in /dev/shm .                     '
echo '****************************************************************************'
# 设置参数变量
while getopts ":qrd:u:p:" arg; do
    case $arg in
    q)
        QUIET_MODE=y
        ;;
    r)
        REPLACE=y
        ;;
    d)
        DEPLOY=y
        VERSION=$OPTARG
        ;;
    u)
        TFS_USER=$OPTARG
        ;;
    p)
        TFS_PWD=$OPTARG
        ;;
    i)
        MAVEN_ID=$OPTARG
        ;;
    m)
        MAVEN_USER=$OPTARG
        ;;
    w)
        MAVEN_PWD=$OPTARG
        ;;
    s)
        STORED_TMP=y
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)
# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time:${START_TIME}
echo --Work Folder:${WORK_FOLDER}

# 检查命令是否有效
echo --checking tools
mvn -version
if [ "$?" != "0" ]; then
    echo please install maven.
    exit 1
fi
echo -n "TypeScript " && tsc -v
if [ "$?" != "0" ]; then
    echo please run [npm install -g typescript].
    exit 1
fi
uglifyjs -V
if [ "$?" != "0" ]; then
    echo please run [npm install -g uglify-es].
    exit 1
fi
git-tf --version
if [ "$?" != "0" ]; then
    echo please install git-tf.
    exit 1
fi

# 配置交互，非安静模式时
if [ "${QUIET_MODE}" != "y" ]; then
    # 设置配置
    echo "--please confirm settings, Entry to skip."
    if [ "${REPLACE}" = "" ]; then
        read -p "---replace maven setting? (yes or [n]o):" REPLACE
    fi
    if [ "${REPLACE}" = "y" ]; then
        if [ "${MAVEN_ID}" = "" ]; then
            read -p "----maven server id ([ibas-maven]):" MAVEN_ID
            if [ "${MAVEN_ID}" = "" ]; then
                MAVEN_ID=ibas-maven
            fi
        fi
        if [ "${MAVEN_USER}" = "" ]; then
            read -p "----maven server user ([admin]):" MAVEN_USER
            if [ "${MAVEN_USER}" = "" ]; then
                MAVEN_USER=admin
            fi
        fi
        if [ "${MAVEN_PWD}" = "" ]; then
            read -p "----maven server user password:" MAVEN_PWD
        fi
    fi
    if [ "${TFS_USER}" = "" ]; then
        read -p "---tfs user ("\\" must be "\\\\"):" TFS_USER
    fi
    if [ "${TFS_USER}" != "" ]; then
        if [ "${TFS_PWD}" = "" ]; then
            read -p "---tfs password:" TFS_PWD
        fi
    fi
    if [ "${DEPLOY}" = "" ]; then
        read -p "---deploy war packages to repository? (yes or [n]o):" DEPLOY
        if [ "${DEPLOY}" = "y" ]; then
            if [ "${VERSION}" = "" ]; then
                read -p "----packages version ($(date +%Y%m%d%H%M)):" VERSION
            fi
        fi
    fi
    if [ "${STORED_TMP}" = "" ]; then
        read -p "---compiles files is stored in /tmp? (yes or [n]o):" STORED_TMP
    fi
fi

: <<!
echo Quiet: ${QUIET_MODE}
echo Replace: ${REPLACE}
echo Maven Id: ${MAVEN_ID}
echo Maven User: ${MAVEN_USER}
echo Maven Password: ${MAVEN_PWD}
echo Deploy: ${DEPLOY} and Version ${VERSION}
echo TFS User: ${TFS_USER}
echo TFS Password: ${TFS_PWD}
exit 1
!

# 配置文件替换
if [ "${REPLACE}" = "y" ]; then
    if [ -e ~/.m2/conf/settings.xml ]; then
        cp -f ~/.m2/conf/settings.xml ~/.m2/conf/settings.bak.xml
        rm -rf ~/.m2/conf/settings.xml
    fi
    cat >~/.m2/conf/settings.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
      <id>${MAVEN_ID}</id>
      <username>${MAVEN_USER}</username>
      <password>${MAVEN_PWD}</password>
    </server>
  </servers>
  <mirrors>
    <mirror>
        <id>maven-default-http-blocker</id>
        <mirrorOf>external:http2:*</mirrorOf>
        <name>Disable HTTP blocked. (Replace http to http2)</name>
        <url>http://0.0.0.0/</url>
        <blocked>true</blocked>
    </mirror>
  </mirrors>
</settings>
EOF
fi
# TFS配置
if [ "${TFS_USER}" != "" ]; then
    git config --global git-tf.server.username "${TFS_USER}"
    if [ "${TFS_PWD}" != "" ]; then
        git config --global git-tf.server.password "${TFS_PWD}"
    fi
fi
# 检查部署war包时的版本号
if [ "${DEPLOY}" = "y" ]; then
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
    TFS_URL=https://code.avacloud.com.cn:8443/tfs
fi
if [ "${MAVEN_URL}" = "" ]; then
    MAVEN_URL=https://nexus.avacloud.com.cn/repository/maven-avacloud
fi

# 使用虚拟磁盘
if [ "${STORED_TMP}" = "y" ]; then
    TMP_HOME=/tmp/codes

    mkdir -p ${TMP_HOME}/git
    ln -bfsv ${TMP_HOME}/git ${CODE_HOME}/git

    mkdir -p ${TMP_HOME}/tfs
    ln -bfsv ${TMP_HOME}/tfs ${CODE_HOME}/tfs
fi

echo --clear maven repository
if [ -e ~/.m2/repository/org/colorcoding ]; then
    rm -rf ~/.m2/repository/org/colorcoding
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
            cd ${CODE_FOLDER}/${folder} && git pull --rebase
        else
            git clone --depth 1 ${GIT_URL}/${collection}/${folder}.git ${others}
        fi
        # 使用虚拟磁盘
        if [ "${STORED_TMP}" = "y" ]; then
            if [ -e "${CODE_FOLDER}/${folder}/compile_order.txt" ]; then
                while read item; do
                    rm -rf ${CODE_FOLDER}/${folder}/${item}/target
                    mkdir -p ${TMP_HOME}/${folder}/${item}/target && ln -bfsv ${TMP_HOME}/${folder}/${item}/target ${CODE_FOLDER}/${folder}/${item}/target
                done <"${CODE_FOLDER}/${folder}/compile_order.txt" | sed 's/\r//g'
            fi
        fi
        echo ${folder} >>${CODE_FOLDER}/compile_order.txt
    done <${WORK_FOLDER}/${COMPILE_ORDER} | sed 's/\r//g'
    cd ${CODE_FOLDER}
    ./builds.sh && ./compiles.sh
    # 清理编译临时文件
    find . -name "target" -type d | xargs rm -rf >/dev/null
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
        cd ${CODE_FOLDER}/ibas-typescript && git pull --rebase
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
        # 使用虚拟磁盘
        if [ "${STORED_TMP}" = "y" ]; then
            if [ -e "${CODE_FOLDER}/${folder}" ]; then
                cd ${CODE_FOLDER}/${folder}
                for item in $(ls -l | grep ^d); do
                    rm -rf ${CODE_FOLDER}/${folder}/${item}/target
                    mkdir -p ${TMP_HOME}/${folder}/${item}/target && ln -bfsv ${TMP_HOME}/${folder}/${item}/target ${CODE_FOLDER}/${folder}/${item}/target
                done
            fi
        fi
        echo ${folder} >>${CODE_FOLDER}/compile_order.txt
    done <${WORK_FOLDER}/${COMPILE_ORDER} | sed 's/\r//g'
    cd ${CODE_FOLDER}
    ./builds.sh && ./compiles.sh
    # 清理编译临时文件
    find . -name "target" -type d | xargs rm -rf >/dev/null
    # 存在脚本则上传war包
    if [ "${DEPLOY}" = "y" ]; then
        echo --deploy wars to [${MAVEN_URL}], and version [${VERSION}]
        ./deploy_wars.sh ${VERSION} ${MAVEN_URL}
    fi
done
cd ${WORK_FOLDER}

if [ "${DEPLOY}" = "y" ]; then
    echo --Deploy Version: [${VERSION}]
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
