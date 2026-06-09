#!/bin/bash
echo '****************************************************************************'
echo '                nexus_cleanup_unused_images.sh                             '
echo '                           by niuren.zhu                                    '
echo '                              2026.06.11                                    '
echo '  note:                                                                     '
echo '      1. cleanup unused docker images from Nexus Repository.               '
echo '      2. only delete images not in use and older than expire days.          '
echo '      3. always process tomcat and nginx images only.                      '
echo '  parameter:                                                                '
echo '      -u [username]          Nexus username.                                '
echo '      -p [password]          Nexus password.                                '
echo '      -h [host]              Nexus repository URL.                          '
echo '      -r [repository]        Nexus repository name.                         '
echo '      -n [namespace]         k8s namespace, omit to search all namespaces.  '
echo '      -f [filters]           additional image filters (on top of tomcat/nginx).'
echo '      -e [expire days]       image expire days, default 30 days.            '
echo '      -d                     delete mode, actually remove expired images.   '
echo '****************************************************************************'
# 设置参数变量
DRY_RUN=1
while getopts "u:p:h:r:n:f:e:d" arg; do
    case $arg in
    u)
        NEXUS_USER=$OPTARG
        ;;
    p)
        NEXUS_PASSWORD=$OPTARG
        ;;
    h)
        NEXUS_URL=$OPTARG
        ;;
    r)
        NEXUS_REPO=$OPTARG
        ;;
    n)
        K8S_NAMESPACE=$OPTARG
        ;;
    f)
        EXTRA_FILTERS=$OPTARG
        ;;
    e)
        EXPIRE_DAYS=$OPTARG
        ;;
    d)
        DRY_RUN=0
        ;;
    esac
done

# Nexus仓库地址
if [ "${NEXUS_URL}" = "" ]; then
    echo "please set Nexus host."
    exit 1
fi

# Nexus仓库名称
if [ "${NEXUS_REPO}" = "" ]; then
    echo "please set Nexus repository name."
    exit 1
fi

# 查询的命名空间（为空则查所有命名空间）
if [ "${K8S_NAMESPACE}" = "" ]; then
    K8S_NAMESPACE_FLAG="--all-namespaces"
else
    K8S_NAMESPACE_FLAG="-n ${K8S_NAMESPACE}"
fi

# 镜像过滤条件 - 固定处理 tomcat 和 nginx，-f 传入额外过滤条件
IMAGE_FILTERS="tomcat\|nginx"
if [ "${EXTRA_FILTERS}" != "" ]; then
    IMAGE_FILTERS="${IMAGE_FILTERS}\|${EXTRA_FILTERS}"
fi

# 超期天数
if [ "${EXPIRE_DAYS}" = "" ]; then
    EXPIRE_DAYS=30
fi

# 开始时间
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
echo --Start Time: ${START_TIME}
echo --Expire Days: ${EXPIRE_DAYS}
if [ "${DRY_RUN}" = "1" ]; then
    echo --Mode: DRY-RUN \(list only, no deletion\)
else
    echo --Mode: DELETE \(will remove expired images\)
fi

# 检查工具
echo --checking tools
jq --version
if [ "$?" != "0" ]; then
    echo please install jq.
    exit 1
fi

# 获取k8s中正在运行的镜像列表
if [ -n "${K8S_NAMESPACE}" ]; then
    echo --Fetching running images from k8s namespace: "${K8S_NAMESPACE}"
else
    echo --Fetching running images from all k8s namespaces
fi
RUNNING_IMAGES=$(kubectl get pods ${K8S_NAMESPACE_FLAG} --field-selector=status.phase=Running \
    -o jsonpath="{.items[*].spec.containers[*].image}" | tr -s ' ' '\n' | sort -u)

# 提取镜像名称和标签（去掉registry前缀，与Nexus格式对齐）
# k8s格式: [registry/]name:tag  如 docker.avacloud.com.cn/c00002/avacloud/nginx:2.0
# Nexus格式: name:tag           如 c00002/avacloud/nginx:2.0
# Docker规范: 第一个路径段含 . 或 : 的是registry主机名，需去掉
RUNNING_IMAGE_LIST=""
RUNNING_IMAGE_COUNT=0
while read -r IMAGE; do
    [ -z "${IMAGE}" ] && continue
    K8S_IMAGE="${IMAGE}"
    # 去掉registry前缀（第一个路径段含.或:说明是主机名）
    FIRST_PART="${K8S_IMAGE%%/*}"
    if echo "${FIRST_PART}" | grep -q '[.:]'; then
        K8S_IMAGE="${K8S_IMAGE#*/}"
    fi
    [ -z "${K8S_IMAGE}" ] && continue
    RUNNING_IMAGE_LIST="${RUNNING_IMAGE_LIST}${K8S_IMAGE}"$'\n'
    ((RUNNING_IMAGE_COUNT++))
done <<< "${RUNNING_IMAGES}"

echo --Found ${RUNNING_IMAGE_COUNT} running images in k8s.
echo --Running image list:
echo "${RUNNING_IMAGE_LIST}" | sort -u | while read -r line; do echo "  ${line}"; done

# 获取Nexus中的所有镜像
echo --Fetching images from Nexus repository: "${NEXUS_REPO}"
NEXUS_IMAGES=""
CONTINUATION_TOKEN=""

# 循环获取所有分页数据
while true; do
    if [ -z "${CONTINUATION_TOKEN}" ]; then
        HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
            "${NEXUS_URL}/service/rest/v1/components?repository=${NEXUS_REPO}")
    else
        HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
            "${NEXUS_URL}/service/rest/v1/components?repository=${NEXUS_REPO}&continuationToken=${CONTINUATION_TOKEN}")
    fi

    # 分离响应体和HTTP状态码
    HTTP_STATUS=$(echo "${HTTP_RESPONSE}" | tail -n1)
    RESPONSE=$(echo "${HTTP_RESPONSE}" | sed '$d')

    # 检查HTTP状态码
    if [ "${HTTP_STATUS}" != "200" ]; then
        echo "Error: HTTP ${HTTP_STATUS} - Failed to fetch images from Nexus"
        echo "Response: ${RESPONSE}"
        break
    fi

    # 检查响应是否有效
    if [ -z "${RESPONSE}" ]; then
        echo "Warning: Empty response from Nexus API"
        break
    fi

    # 验证JSON格式
    if ! echo "${RESPONSE}" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON response from Nexus API"
        echo "Response preview: ${RESPONSE:0:200}"
        break
    fi

    # 提取镜像列表、创建时间和组件ID（格式: name:tag|lastModified|componentId）
    PAGE_IMAGES=$(echo "${RESPONSE}" | jq -r '.items[] | select(.assets | length > 0) | .name + ":" + .version + "|" + .assets[0].lastModified + "|" + .id' 2>/dev/null)
    if [ -n "${PAGE_IMAGES}" ]; then
        # 应用镜像过滤条件
        FILTERED_IMAGES=$(echo "${PAGE_IMAGES}" | grep "${IMAGE_FILTERS}")
        if [ -n "${FILTERED_IMAGES}" ]; then
            NEXUS_IMAGES="${NEXUS_IMAGES}${FILTERED_IMAGES}"$'\n'
        fi
    fi

    # 检查是否有下一页
    CONTINUATION_TOKEN=$(echo "${RESPONSE}" | jq -r '.continuationToken // empty')
    if [ -z "${CONTINUATION_TOKEN}" ]; then
        break
    fi
done

CLEANED_COUNT=0
KEPT_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

# 计算过期时间点
if [ "$(uname)" = "Darwin" ]; then
    # macOS
    EXPIRE_TIMESTAMP=$(date -v-${EXPIRE_DAYS}d +%s)
    EXPIRE_DATE=$(date -r ${EXPIRE_TIMESTAMP} +"%Y-%m-%d %H:%M:%S")
else
    # Linux
    EXPIRE_TIMESTAMP=$(date -d "-${EXPIRE_DAYS} days" +%s)
    EXPIRE_DATE=$(date -d "@${EXPIRE_TIMESTAMP}" +"%Y-%m-%d %H:%M:%S")
fi
echo --Expire Timestamp: ${EXPIRE_TIMESTAMP} "'"$EXPIRE_DATE"'"

# 辅助函数: 将ISO8601时间转换为unix时间戳
parse_iso8601_timestamp() {
    local ISO_TIME="$1"
    if [ "$(uname)" = "Darwin" ]; then
        # macOS: 去掉毫秒和时区后解析 (如 2024-01-15T10:30:00.000Z -> 2024-01-15T10:30:00)
        local CLEAN_TIME=$(echo "${ISO_TIME}" | sed -E 's/\.[0-9]+[Z+-].*$//')
        date -j -f "%Y-%m-%dT%H:%M:%S" "${CLEAN_TIME}" +%s 2>/dev/null || echo ""
    else
        # Linux: GNU date可直接解析ISO8601
        date -d "${ISO_TIME}" +%s 2>/dev/null || echo ""
    fi
}

# 检查每个Nexus镜像是否在k8s中运行
while read -r NEXUS_IMAGE_LINE; do
    if [ -z "${NEXUS_IMAGE_LINE}" ]; then
        continue
    fi

    # 解析镜像名称、时间和组件ID (格式: name:tag|lastModified|componentId)
    NEXUS_IMAGE=$(echo "${NEXUS_IMAGE_LINE}" | cut -d'|' -f1)
    LAST_MODIFIED=$(echo "${NEXUS_IMAGE_LINE}" | cut -d'|' -f2)
    COMPONENT_ID=$(echo "${NEXUS_IMAGE_LINE}" | cut -d'|' -f3)

    IMAGE_NAME="${NEXUS_IMAGE%:*}"
    IMAGE_TAG="${NEXUS_IMAGE##*:}"

    if echo "${RUNNING_IMAGE_LIST}" | grep -qxF "${NEXUS_IMAGE}"; then
        echo --[KEEP] "${NEXUS_IMAGE}" is running in k8s.
        ((KEPT_COUNT++))
    else
        # 检查镜像是否超期
        IMAGE_TIMESTAMP=$(parse_iso8601_timestamp "${LAST_MODIFIED}")

        # 时间解析失败时跳过，避免误删
        if [ -z "${IMAGE_TIMESTAMP}" ]; then
            echo --[ERROR] "${NEXUS_IMAGE}" failed to parse timestamp. \(Created: ${LAST_MODIFIED}\) - SKIPPED
            ((ERROR_COUNT++))
            continue
        fi

        if [ "${IMAGE_TIMESTAMP}" -ge "${EXPIRE_TIMESTAMP}" ]; then
            echo --[SKIP] "${NEXUS_IMAGE}" is not in use but not expired. \(Created: ${LAST_MODIFIED}\)
            ((SKIPPED_COUNT++))
        else
            if [ "${DRY_RUN}" = "1" ]; then
                echo --[EXPIRED] "${NEXUS_IMAGE}" is not in use and expired. \(Created: ${LAST_MODIFIED}\)
                ((CLEANED_COUNT++))
            else
                echo --[DELETE] "${NEXUS_IMAGE}" is not in use and expired. \(Created: ${LAST_MODIFIED}\)

                # 使用初始获取时保存的组件ID删除镜像
                if [ -n "${COMPONENT_ID}" ]; then
                    HTTP_DELETE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
                        "${NEXUS_URL}/service/rest/v1/components/${COMPONENT_ID}")
                    if [ "${HTTP_DELETE_STATUS}" = "204" ]; then
                        echo ----Deleted: "${NEXUS_IMAGE}"
                        ((CLEANED_COUNT++))
                    else
                        echo ----Failed to delete: "${NEXUS_IMAGE}" \(HTTP ${HTTP_DELETE_STATUS}\)
                        ((ERROR_COUNT++))
                    fi
                else
                    echo ----Missing component ID for: "${NEXUS_IMAGE}" - SKIPPED
                    ((ERROR_COUNT++))
                fi
            fi
        fi
    fi
done <<< "${NEXUS_IMAGES}"

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

echo '****************************************************************************'
echo --Summary:
TOTAL_COUNT=$(echo "${NEXUS_IMAGES}" | grep -c . 2>/dev/null || echo 0)
echo ----"Total images in Nexus: ${TOTAL_COUNT}"
echo ----"Images kept (running in k8s): ${KEPT_COUNT}"
echo ----"Images skipped (not expired): ${SKIPPED_COUNT}"
if [ "${DRY_RUN}" = "1" ]; then
    echo ----"Images expired (would be deleted): ${CLEANED_COUNT}"
else
    echo ----"Images cleaned (deleted): ${CLEANED_COUNT}"
fi
if [ "${ERROR_COUNT}" -gt 0 ]; then
    echo ----"Errors: ${ERROR_COUNT}"
fi
echo --Completion Time: ${END_TIME}, $((END_SECONDS - START_SECONDS)) seconds.
echo '****************************************************************************'
