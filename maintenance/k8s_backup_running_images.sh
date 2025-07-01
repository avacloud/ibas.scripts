#!/bin/bash
echo '****************************************************************************'
echo '                   k8s_backup_running_images.sh                             '
echo '                           by niuren.zhu                                    '
echo '                              2025.07.01                                    '
echo '  note:                                                                     '
echo '      1. backup running images to repository.                               '
echo '  parameter:                                                                '
echo '        $1             backup repository.                                   '
echo '        $2             k8s namespace.                                      '
echo '        $3             image filters.                                      '
echo '****************************************************************************'
# 设置参数变量
# 工作目录
WORK_FOLDER=$(pwd)
# 备份仓库地址
BACKUP_REPOSITORY=$1
if [ "${BACKUP_REPOSITORY}" = "" ]; then
    echo "please set backup repository."
fi
# 查询的命名空间
K8S_NAMESPACE=$2
if [ "${K8S_NAMESPACE}" = "" ]; then
    K8S_NAMESPACE=customer
fi

# 镜像过滤条件
IMAGE_FILTERS=$3
if [ "${IMAGE_FILTERS}" = "" ]; then
    IMAGE_FILTERS=/avacloud/
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}

# 开始执行命令
kubectl get pods -n ${K8S_NAMESPACE} --field-selector=status.phase=Running \
    -o jsonpath="{.items[*].spec.containers[*].image}" |
    tr -s ' ' '\n' | sort -u | grep ${IMAGE_FILTERS} | while read -r IMAGE; do
    IMAGE_REPO="${IMAGE%%/*}"
    IMAGE_NAME="${IMAGE#*/}"
    IMAGE_BACKUP=${BACKUP_REPOSITORY}/${IMAGE_NAME}

    if [ "${BACKUP_REPOSITORY}" = "" ]; then
        echo --image: ${IMAGE}
    else
        echo --repository: ${IMAGE_REPO}, name: ${IMAGE_NAME}
        docker pull ${IMAGE} && docker tag ${IMAGE} ${IMAGE_BACKUP}
        echo --backup: ${IMAGE_BACKUP}
        docker push ${IMAGE_BACKUP}
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
