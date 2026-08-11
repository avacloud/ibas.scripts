#!/bin/bash
echo '****************************************************************************'
echo '                    cf_batch_deploy.sh                                      '
echo '                           by niuren.zhu                                    '
echo '                              2026.08.11                                    '
echo '  note:                                                                     '
echo '      1. batch deploy cf.*.yaml in current folder.                         '
echo '      2. deploy by cf push with DOWNLOAD_URL and DOWNLOAD_TOKEN.           '
echo '  parameter:                                                                '
echo '      -u [download url]       config files download url.                   '
echo '      -t [download token]     config files download token.                 '
echo '      -f [filter]             file name filter, optional.                  '
echo '      -c                      continue on error, default stop.             '
echo '****************************************************************************'
# 设置参数变量
while getopts "u:t:f:c" arg; do
    case $arg in
    u)
        DOWNLOAD_URL=$OPTARG
        ;;
    t)
        DOWNLOAD_TOKEN=$OPTARG
        ;;
    f)
        FILE_FILTER=$OPTARG
        ;;
    c)
        CONTINUE_ON_ERROR="ON"
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)
# 参数校验
if [ "${DOWNLOAD_URL}" = "" ]; then
    echo please set download url.
    exit 1
fi
if [ "${DOWNLOAD_TOKEN}" = "" ]; then
    echo please set download token.
    exit 1
fi

# 检查环境
echo --checking tools
cf --version
if [ "$?" != "0" ]; then
    echo please install cf cli.
    exit 1
fi
echo --checking cf target
cf target
if [ "$?" != "0" ]; then
    echo please login and set cf target.
    echo e.g. cf login -a https://api.xxx.xxx -o ORG -s SPACE
    exit 1
fi

# 查找并过滤部署清单
DEPLOY_FILES=()
for MANIFEST_FILE in "${WORK_FOLDER}"/cf.*.yaml; do
    # 无匹配时 glob 保持原样，跳过
    if [ ! -e "${MANIFEST_FILE}" ]; then
        continue
    fi
    # 按名称过滤
    if [ "${FILE_FILTER}" != "" ]; then
        case "${MANIFEST_FILE}" in
            *${FILE_FILTER}*) ;;
            *) continue ;;
        esac
    fi
    DEPLOY_FILES+=("${MANIFEST_FILE}")
done
if [ ${#DEPLOY_FILES[@]} -eq 0 ]; then
    if [ "${FILE_FILTER}" != "" ]; then
        echo not found manifest matched filter: ${FILE_FILTER}
    else
        echo not found cf.*.yaml in ${WORK_FOLDER}.
    fi
    exit 1
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}
echo --Work Folder: ${WORK_FOLDER}
echo --Filter: ${FILE_FILTER:-all}
echo --Manifests: ${DEPLOY_FILES[*]}

# 部署应用
TOTAL=0
SUCCESS=0
FAILED=0
for MANIFEST_FILE in "${DEPLOY_FILES[@]}"; do
    TOTAL=$((TOTAL + 1))
    echo ===========================================================================
    echo --deploy [${TOTAL}/${#DEPLOY_FILES[@]}]: ${MANIFEST_FILE}
    cf push -f "${MANIFEST_FILE}" --var DOWNLOAD_URL="${DOWNLOAD_URL}" --var DOWNLOAD_TOKEN="${DOWNLOAD_TOKEN}"
    if [ "$?" = "0" ]; then
        SUCCESS=$((SUCCESS + 1))
        echo --deploy success: ${MANIFEST_FILE}
    else
        FAILED=$((FAILED + 1))
        echo --deploy failed: ${MANIFEST_FILE}
        if [ "${CONTINUE_ON_ERROR}" != "ON" ]; then
            echo --stop on error, use -c to continue.
            break
        fi
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
echo ===========================================================================
echo --Completion Time: ${END_TIME}, $((END_SECONDS - START_SECONDS)) seconds.
echo --Total: ${TOTAL}, Success: ${SUCCESS}, Failed: ${FAILED}.
