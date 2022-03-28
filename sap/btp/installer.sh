#!/bin/bash
echo '****************************************************************************'
echo '                     installer.sh                                           '
echo '                           by Niuren.Zhu                                    '
echo '                              2021.06.30                                    '
echo '  note：                                                                     '
echo '    1. install and setup.                                                   '
echo '****************************************************************************'
# 设置参数变量
# 工作目录
WORK_FOLDER=$(pwd)
# 环境变量目录
mkdir -p ${HOME}/.local/bin
if [ ! -e ${HOME}/.profile.d ]; then
    mkdir -p ${HOME}/.profile.d
    cat >>${HOME}/.bashrc <<EOF

# user's path
PATH="${HOME}/.local/bin:\$PATH"

# user's profiles
if [ -d ${HOME}/.profile.d ]; then
    for i in ${HOME}/.profile.d/*.sh; do
        if [ -r \$i ]; then
            . \$i
        fi
    done
    unset i
fi

# no proxy
no_proxy=\$no_proxy,.microsoft.com,.avatech.com.cn,.avacloud.com.cn
NO_PROXY=\$NO_PROXY,.microsoft.com,.avatech.com.cn,.avacloud.com.cn

EOF
fi

# 检查环境
echo --checking tools
# swtich to java 8
if [ ! -e /extbin/bin/java8 ]; then
    echo please install java 8.
    exit 1
fi
if [ ! -e ${HOME}/java8 ]; then
    mkdir -p ${HOME}/java8
    ln -s /extbin/bin/java8 ${HOME}/java8/bin
fi
${HOME}/java8/bin/set-default
# maven setting
mvn -version
if [ "$?" != "0" ]; then
    echo please install maven.
    exit 1
fi
export MAVEN_HOME=${HOME}/.m2
if [ ! -e ${HOME}/.profile.d/mvn.sh ]; then
    cat >${HOME}/.profile.d/mvn.sh <<EOF
export MAVEN_HOME=${MAVEN_HOME}
EOF
fi
mkdir -p ${MAVEN_HOME}/conf/
if [ -f ${MAVEN_HOME}/settings.xml ]; then
    if [ ! -h ${MAVEN_HOME}/settings.xml ]; then
        mv -f ${MAVEN_HOME}/settings.xml ${MAVEN_HOME}/conf/
    fi
fi
if [ ! -e ${MAVEN_HOME}/settings.xml ]; then
    ln -s ${MAVEN_HOME}/conf/settings.xml ${MAVEN_HOME}/settings.xml
fi
echo ---
# node
echo npm version $(npm -v)
if [ "$?" != "0" ]; then
    echo please install nodejs and npm.
    exit 1
fi
# typescript
if [ ! -e ${HOME}/.node_modules_global/bin/tsc ]; then
    npm install -g typescript@3.9.10
fi
# uglify-es
if [ ! -e ${HOME}/.node_modules_global/bin/uglifyjs ]; then
    npm install -g uglify-es
fi
echo ---
# curl
echo curl Version $(curl -V)
if [ "$?" != "0" ]; then
    echo please install curl.
    exit 1
fi
echo ---
# user's path
PATH="${HOME}/.local/bin:$PATH"
no_proxy=$no_proxy,.microsoft.com,.avatech.com.cn,.avacloud.com.cn
NO_PROXY=$NO_PROXY,.microsoft.com,.avatech.com.cn,.avacloud.com.cn
# git-tf
GIT_TF_VERSION=2.0.3.20131219
if [ ! -e ${HOME}/.git-tf ]; then
    curl -sL https://download.microsoft.com/download/A/E/2/AE23B059-5727-445B-91CC-15B7A078A7F4/git-tf-${GIT_TF_VERSION}.zip -O &&
        unzip -q -o git-tf-${GIT_TF_VERSION}.zip -d ${HOME} &&
        mv -f ${HOME}/git-tf-${GIT_TF_VERSION} ${HOME}/.git-tf &&
        rm -rf git-tf-${GIT_TF_VERSION}.zip
    cat >${HOME}/.profile.d/git-tf.sh <<EOF
export PATH="${HOME}/.git-tf:$PATH"
EOF
fi
PATH="${HOME}/.git-tf:$PATH"
echo $(git-tf --version)
if [ "$?" != "0" ]; then
    echo please install git-tf.
    exit 1
fi
echo ---
# tee clc
TEE_VERSION=14.123.1
if [ ! -e ${HOME}/.tee-clc ]; then
    curl -L https://github.com/Microsoft/team-explorer-everywhere/releases/download/${TEE_VERSION}/TEE-CLC-${TEE_VERSION}.zip -O &&
        unzip -q -o TEE-CLC-${TEE_VERSION}.zip -d ${HOME} &&
        mv -f ${HOME}/TEE-CLC-${TEE_VERSION} ${HOME}/.tee-clc &&
        rm -rf TEE-CLC-${TEE_VERSION}.zip
    cat >${HOME}/.profile.d/tf.sh <<EOF
export PATH="${HOME}/.tee-clc:$PATH"
EOF
fi
PATH="${HOME}/.tee-clc:$PATH"
echo tee clc:
echo $(tf eula -accept)
if [ "$?" != "0" ]; then
    echo please install tee clc.
    exit 1
fi
echo ---
# code home
export CODE_HOME=${HOME}/projects
if [ ! -e ${HOME}/.profile.d/codes.sh ]; then
    cat >${HOME}/.profile.d/codes.sh <<EOF
export CODE_HOME=${CODE_HOME}
EOF
fi
echo "Code Home: ${CODE_HOME}"
echo ---
export LESSCHARSET=utf-8
# exit
echo "--please exit the terminal to reload environment variables !!!"
