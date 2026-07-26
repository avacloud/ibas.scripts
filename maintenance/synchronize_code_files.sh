#!/bin/bash
echo '****************************************************************************'
echo '                   synchronize_code_files.sh                                '
echo '                           by niuren.zhu                                    '
echo '                              2025.12.30                                    '
echo '  note:                                                                     '
echo '      1. synchronize code files and handle tf management status.            '
echo '      2. the replacement contents is written in file replacements.txt.      '
echo '      3. auto detect and handle delete/rename.                              '
echo '      4. verify all files after synchronization.                            '
echo '  parameter:                                                                '
echo '        $1             source folder.                                       '
echo '        $2             target folder.                                       '
echo '****************************************************************************'

# ===========================================================================
# 配置
# ===========================================================================
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPLACEMENTS="${SCRIPT_DIR}/replacements.txt"
BATCH_SIZE=50

# macOS / Linux sed 兼容
if [ "$(uname)" = "Darwin" ]; then
  SED_INPLACE=("-i" "")
else
  SED_INPLACE=("-i")
fi

# ===========================================================================
# 参数校验
# ===========================================================================
SOURCE_FOLDER=$1
[ -e "${SOURCE_FOLDER}" ] || { echo "ERROR: source folder not found."; exit 1; }
TARGET_FOLDER=$2
[ -e "${TARGET_FOLDER}" ] || { echo "ERROR: target folder not found."; exit 1; }
TARGET_FOLDER=$(cd "${TARGET_FOLDER}" && pwd -P)
SOURCE_FOLDER=$(cd "${SOURCE_FOLDER}" && pwd -P)

tf info "${SOURCE_FOLDER}" > /dev/null 2>&1 || { echo "ERROR: tf not available or source not in workspace."; exit 1; }
[ -f "${REPLACEMENTS}" ] || { echo "ERROR: replacements.txt not found at ${REPLACEMENTS}"; exit 1; }

# ===========================================================================
# 初始化
# ===========================================================================
START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
LOG_FILE="${TARGET_FOLDER}/sync_log_$(date +%Y%m%d_%H%M%S).txt"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

# 创建 sed 脚本（过滤注释和空行，一次加载所有规则）
SED_SCRIPT="${TMP_DIR}/rules.sed"
grep -v '^#' "${REPLACEMENTS}" | grep -v '^$' > "${SED_SCRIPT}"
SED_RULE_COUNT=$(wc -l < "${SED_SCRIPT}")

# 统计计数器
TOTAL=0; COPIED=0; CHECKOUT_OK=0; CHECKOUT_FAIL=0
ADD_OK=0; ADD_FAIL=0; DELETE_OK=0; RENAME_OK=0
VERIFY_OK=0; VERIFY_FAIL=0; VERIFY_FIXED=0

echo "--Start Time: ${START_TIME}"
echo "--Source: ${SOURCE_FOLDER}"
echo "--Target: ${TARGET_FOLDER}"
echo "--Replacements: ${SED_RULE_COUNT} rules"
echo "--Log: ${LOG_FILE}"
echo ""

# ===========================================================================
# 函数
# ===========================================================================
log() { echo "[$(date '+%H:%M:%S')] $*" >> "${LOG_FILE}"; }
say() { echo "$*"; log "$*"; }

should_skip() {
  local fname=$1
  for s in "pom.xml" "app.xml" "config.json" "index.ui.c.d.ts" "index.ui.m.d.ts"; do
    [ "$fname" = "$s" ] && return 0
  done
  return 1
}

# 收集文件列表（相对路径），输出到指定文件
collect_files() {
  local folder=$1 outfile=$2
  : > "$outfile"
  while IFS= read -r -d '' file; do
    should_skip "$(basename "$file")" && continue
    echo "${file#${folder}/}" >> "$outfile"
  done < <(find "$folder" \( -name "*.java" -o -name "*.properties" -o -name "*.xml" -o -name "*.ts" -o -name "*.json" \) -path "*/src/main/*" -type f -print0)
  sort -o "$outfile" "$outfile"
}

# 复制单个文件 + 应用替换 + 验证
sync_file() {
  local relpath=$1
  local src="${SOURCE_FOLDER}/${relpath}"
  local tgt="${TARGET_FOLDER}/${relpath}"

  mkdir -p "${tgt%/*}"

  # 复制文件（失败则尝试修复权限后重试）
  if ! cp -f "$src" "$tgt" 2>/dev/null; then
    chmod u+w "$tgt" 2>/dev/null
    cp -f "$src" "$tgt" 2>/dev/null || {
      say "  [CP_FAIL] ${relpath}"
      VERIFY_FAIL=$((VERIFY_FAIL + 1))
      return 1
    }
  fi
  COPIED=$((COPIED + 1))

  # 应用替换规则（单次 sed -f 调用）
  sed "${SED_INPLACE[@]}" -f "${SED_SCRIPT}" "$tgt" 2>/dev/null

  # 验证：源文件应用替换后与目标比对
  local expected="${TMP_DIR}/expected"
  rm -f "$expected"
  cp "$src" "$expected"
  sed "${SED_INPLACE[@]}" -f "${SED_SCRIPT}" "$expected" 2>/dev/null
  if diff -q "$expected" "$tgt" > /dev/null 2>&1; then
    VERIFY_OK=$((VERIFY_OK + 1))
  else
    # 验证失败，重新复制并替换
    chmod u+w "$tgt" 2>/dev/null
    cp -f "$src" "$tgt"
    sed "${SED_INPLACE[@]}" -f "${SED_SCRIPT}" "$tgt" 2>/dev/null
    if diff -q "$expected" "$tgt" > /dev/null 2>&1; then
      VERIFY_FIXED=$((VERIFY_FIXED + 1))
      log "  [FIXED] ${relpath}"
    else
      VERIFY_FAIL=$((VERIFY_FAIL + 1))
      say "  [VERIFY_FAIL] ${relpath}"
    fi
  fi
}

# ===========================================================================
# 第1步：清理干扰文件
# ===========================================================================
say "Step 1: Cleaning up..."
rm -rf "${SOURCE_FOLDER}/release"
find "${SOURCE_FOLDER}" -name "target" -type d -exec rm -rf {} + 2>/dev/null
find "${TARGET_FOLDER}" -name "target" -type d -exec rm -rf {} + 2>/dev/null

# ===========================================================================
# 第2步：收集文件列表并分析差异
# ===========================================================================
say "Step 2: Collecting and analyzing..."
SOURCE_LIST="${TMP_DIR}/source.txt"
TARGET_LIST="${TMP_DIR}/target.txt"
collect_files "${SOURCE_FOLDER}" "${SOURCE_LIST}"
collect_files "${TARGET_FOLDER}" "${TARGET_LIST}"

ONLY_SOURCE="${TMP_DIR}/only_source.txt"
ONLY_TARGET="${TMP_DIR}/only_target.txt"
COMMON="${TMP_DIR}/common.txt"
comm -23 "${SOURCE_LIST}" "${TARGET_LIST}" > "${ONLY_SOURCE}"
comm -13 "${SOURCE_LIST}" "${TARGET_LIST}" > "${ONLY_TARGET}"
comm -12 "${SOURCE_LIST}" "${TARGET_LIST}" > "${COMMON}"

SRC_COUNT=$(wc -l < "${SOURCE_LIST}")
TGT_COUNT=$(wc -l < "${TARGET_LIST}")
NEW_COUNT=$(wc -l < "${ONLY_SOURCE}")
DEL_COUNT=$(wc -l < "${ONLY_TARGET}")
COM_COUNT=$(wc -l < "${COMMON}")
say "  Source: ${SRC_COUNT} | Target: ${TGT_COUNT} | Common: ${COM_COUNT} | New: ${NEW_COUNT} | Delete/Rename: ${DEL_COUNT}"

# ===========================================================================
# 第3步：预处理 - 处理删除和重命名
# ===========================================================================
if [ "${DEL_COUNT}" -gt 0 ]; then
  say "Step 3: Pre-processing (delete/rename)..."
  while IFS= read -r relpath; do
    [ -z "$relpath" ] && continue
    tgt="${TARGET_FOLDER}/${relpath}"
    bname=$(basename "$relpath")
    dname=$(dirname "$relpath")
    lower=$(echo "$bname" | tr 'A-Z' 'a-z')

    # 在新增列表中查找大小写不敏感的同目录匹配（重命名检测）
    case_match=""
    while IFS= read -r src_rel; do
      [ -z "$src_rel" ] && continue
      s_base=$(basename "$src_rel")
      s_dir=$(dirname "$src_rel")
      s_lower=$(echo "$s_base" | tr 'A-Z' 'a-z')
      if [ "$s_lower" = "$lower" ] && [ "$s_dir" = "$dname" ]; then
        case_match="$src_rel"; break
      fi
    done < "${ONLY_SOURCE}"

    if [ -n "$case_match" ]; then
      # 大小写重命名：两步重命名法（TFS 大小写不敏感）
      say "  Rename: ${bname} -> $(basename "$case_match")"
      temp="${TARGET_FOLDER}/${dname}/.tmp_rename_$$_$(basename "$case_match")"
      tf undo "$tgt" > /dev/null 2>&1
      tf rename "$tgt" "$temp" > /dev/null 2>&1
      tf rename "$temp" "${TARGET_FOLDER}/${case_match}" > /dev/null 2>&1
      RENAME_OK=$((RENAME_OK + 1))
      # 从新增列表中移除已处理项
      grep -v "^${case_match}$" "${ONLY_SOURCE}" > "${ONLY_SOURCE}.tmp" && mv "${ONLY_SOURCE}.tmp" "${ONLY_SOURCE}"
    else
      # 真正的删除
      say "  Delete: ${relpath}"
      tf delete "$tgt" > /dev/null 2>&1 && DELETE_OK=$((DELETE_OK + 1)) || log "  [DELETE_FAIL] ${relpath}"
    fi
  done < "${ONLY_TARGET}"
  echo ""
fi

# ===========================================================================
# 第4步：批量签出已有文件
# ===========================================================================
say "Step 4: Batch checkout..."
CO_COUNT=$(wc -l < "${COMMON}")
if [ "$CO_COUNT" -gt 0 ]; then
  # 收集所有已有文件路径，批量 checkout（每批 BATCH_SIZE 个）
  batch=()
  while IFS= read -r relpath; do
    [ -z "$relpath" ] && continue
    batch+=("${TARGET_FOLDER}/${relpath}")
    if [ ${#batch[@]} -ge $BATCH_SIZE ]; then
      tf checkout -noprompt "${batch[@]}" > /dev/null 2>&1
      batch=()
    fi
  done < "${COMMON}"
  [ ${#batch[@]} -gt 0 ] && tf checkout -noprompt "${batch[@]}" > /dev/null 2>&1

  # 检查签出结果（TFS 签出后文件变为可写）
  while IFS= read -r relpath; do
    [ -z "$relpath" ] && continue
    tgt="${TARGET_FOLDER}/${relpath}"
    if [ -w "$tgt" ]; then
      CHECKOUT_OK=$((CHECKOUT_OK + 1))
    else
      # 签出失败（.tfignore 文件等），直接改权限
      chmod u+w "$tgt" 2>/dev/null
      CHECKOUT_FAIL=$((CHECKOUT_FAIL + 1))
      log "  [CHECKOUT_SKIP] ${relpath}"
    fi
  done < "${COMMON}"
fi
say "  Checked out: ${CHECKOUT_OK} | Skipped: ${CHECKOUT_FAIL}"

# ===========================================================================
# 第5步：复制 + 替换 + 验证
# ===========================================================================
say "Step 5: Copy, replace & verify..."
# 合并共同文件和新增文件
cat "${COMMON}" "${ONLY_SOURCE}" | grep -v '^$' > "${TMP_DIR}/all_to_sync.txt"
TOTAL=$(wc -l < "${TMP_DIR}/all_to_sync.txt")
current=0

while IFS= read -r relpath; do
  [ -z "$relpath" ] && continue
  current=$((current + 1))
  [ $((current % 50)) -eq 0 ] && say "  Progress: ${current}/${TOTAL}..."
  sync_file "$relpath"
done < "${TMP_DIR}/all_to_sync.txt"

# ===========================================================================
# 第6步：批量添加新增文件
# ===========================================================================
say "Step 6: Batch add new files..."
NEW_FINAL=$(wc -l < "${ONLY_SOURCE}")
if [ "$NEW_FINAL" -gt 0 ]; then
  batch=()
  while IFS= read -r relpath; do
    [ -z "$relpath" ] && continue
    batch+=("${TARGET_FOLDER}/${relpath}")
    if [ ${#batch[@]} -ge $BATCH_SIZE ]; then
      tf add -noprompt "${batch[@]}" > /dev/null 2>&1
      batch=()
    fi
  done < "${ONLY_SOURCE}"
  [ ${#batch[@]} -gt 0 ] && tf add -noprompt "${batch[@]}" > /dev/null 2>&1

  # 检查添加结果
  while IFS= read -r relpath; do
    [ -z "$relpath" ] && continue
    tgt="${TARGET_FOLDER}/${relpath}"
    if tf info "$tgt" 2>/dev/null | grep -q "Change:.*add"; then
      ADD_OK=$((ADD_OK + 1))
    else
      ADD_FAIL=$((ADD_FAIL + 1))
      log "  [ADD_SKIP] ${relpath}"
    fi
  done < "${ONLY_SOURCE}"
fi
say "  Added: ${ADD_OK} | Skipped: ${ADD_FAIL}"

# ===========================================================================
# 第7步：汇总报告
# ===========================================================================
echo ""
echo "=========================================="
echo "  Synchronization Summary"
echo "=========================================="
echo "  Total files:      ${TOTAL}"
echo "  Copied:           ${COPIED}"
echo "  Checkout OK:      ${CHECKOUT_OK}"
echo "  Checkout Skip:    ${CHECKOUT_FAIL} (.tfignore)"
echo "  Add OK:           ${ADD_OK}"
echo "  Add Skip:         ${ADD_FAIL} (.tfignore)"
echo "  Delete OK:        ${DELETE_OK}"
echo "  Rename OK:        ${RENAME_OK}"
echo "  Verify OK:        ${VERIFY_OK}"
echo "  Verify Fixed:     ${VERIFY_FIXED}"
echo "  Verify FAIL:      ${VERIFY_FAIL}"
echo "  Log file:         ${LOG_FILE}"
echo "=========================================="
[ "${VERIFY_FAIL}" -gt 0 ] && echo "WARNING: ${VERIFY_FAIL} files failed verification!"

# 执行时间
END_TIME=$(date +'%Y-%m-%d %H:%M:%S')
if [ "$(uname)" = "Darwin" ]; then
  START_SECONDS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_TIME" +%s)
  END_SECONDS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$END_TIME" +%s)
else
  START_SECONDS=$(date --date="$START_TIME" +%s)
  END_SECONDS=$(date --date="$END_TIME" +%s)
fi
echo "Completed: ${END_TIME}, $((END_SECONDS - START_SECONDS)) seconds."
