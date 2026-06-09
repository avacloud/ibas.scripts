#!/bin/bash
echo '****************************************************************************'
echo '                   k8s_backup_running_images.sh                             '
echo '                           by niuren.zhu                                    '
echo '                              2025.07.01                                    '
echo '  note:                                                                     '
echo '      1. backup running images to repository.                               '
echo '      2. if repository not set, only pull images to local.                  '
echo '  parameter:                                                                '
echo '      -r [repository]        backup repository, optional.                   '
echo '      -n [namespace]         k8s namespace, default customer.               '
echo '      -f [filters]           image filters, default /avacloud/.             '
echo '****************************************************************************'
# 设置参数变量
while getopts "r:n:f:" arg; do
    case $arg in
    r)
        BACKUP_REPOSITORY=$OPTARG
        ;;
    n)
        K8S_NAMESPACE=$OPTARG
        ;;
    f)
        IMAGE_FILTERS=$OPTARG
        ;;
    esac
done
# 工作目录
WORK_FOLDER=$(pwd)
# 查询的命名空间
if [ "${K8S_NAMESPACE}" = "" ]; then
    K8S_NAMESPACE=customer
fi
# 镜像过滤条件
if [ "${IMAGE_FILTERS}" = "" ]; then
    IMAGE_FILTERS=/avacloud/
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}

if [ "${BACKUP_REPOSITORY}" = "" ]; then
    echo --Mode: Pull images to local only
else
    echo --Mode: Pull, tag and push to repository: "${BACKUP_REPOSITORY}"
fi

# 开始执行命令
kubectl get pods -n "${K8S_NAMESPACE}" --field-selector=status.phase=Running \
    -o jsonpath="{.items[*].spec.containers[*].image}" |
    tr -s ' ' '\n' | sort -u | grep "${IMAGE_FILTERS}" | while read -r IMAGE; do
    IMAGE_REPO="${IMAGE%%/*}"
    IMAGE_NAME="${IMAGE#*/}"

    if [ "${BACKUP_REPOSITORY}" = "" ]; then
        echo --[PULL] "${IMAGE}"
        buildah pull "${IMAGE}"
    else
        IMAGE_BACKUP="${BACKUP_REPOSITORY}/${IMAGE_NAME}"
        echo --[BACKUP] repository: "${IMAGE_REPO}", name: "${IMAGE_NAME}"
        buildah pull "${IMAGE}" && buildah tag "${IMAGE}" "${IMAGE_BACKUP}"
        echo ----tagged: "${IMAGE_BACKUP}"
        buildah push "${IMAGE_BACKUP}"
        echo ----pushed: "${IMAGE_BACKUP}"
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
