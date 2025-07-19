#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# --- 数据管理器 (Model) ---

# 初始化日志文件，确保其始终是一个有效的JSON对象
data_init_log() {
    mkdir -p "$DATA_DIR"
    if ! jq -e 'type == "object"' "$LOG_FILE" >/dev/null 2>&1; then
        echo "{}" > "$LOG_FILE"
        echo "提示：日志文件不存在或无效，已自动初始化。"
    fi
}

# 【内部函数】确保包的基础结构存在
_ensure_pkg_structure() {
    local pkg_name=$1
    jq --arg pkg "$pkg_name" \
       'if .[$pkg] == null then .[$pkg] = {"last_upgrade": null, "last_downgrade": null, "ignore_version": {"upgrade": [], "downgrade": []}} else . end' \
       "$LOG_FILE" | sponge "$LOG_FILE"
}

# 记录一次升级操作
data_log_upgrade() {
    local pkg_name=$1
    local from_version=$2
    local to_version=$3
    local timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

    _ensure_pkg_structure "$pkg_name"
    jq --arg pkg "$pkg_name" \
       --arg from "$from_version" \
       --arg to "$to_version" \
       --arg ts "$timestamp" \
       '.[$pkg].last_upgrade = {from: $from, to: $to, timestamp: $ts}' \
       "$LOG_FILE" | sponge "$LOG_FILE"
}

# 记录一次降级操作
data_log_downgrade() {
    local pkg_name=$1
    local from_version=$2
    local to_version=$3
    local timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

    _ensure_pkg_structure "$pkg_name"
    jq --arg pkg "$pkg_name" \
       --arg from "$from_version" \
       --arg to "$to_version" \
       --arg ts "$timestamp" \
       '.[$pkg].last_downgrade = {from: $from, to: $to, timestamp: $ts}' \
       "$LOG_FILE" | sponge "$LOG_FILE"
}

# 向指定包的忽略列表添加一个版本号
data_add_to_ignore_list() {
    local pkg_name=$1
    local list_type=$2
    local version=$3

    _ensure_pkg_structure "$pkg_name"
    jq --arg pkg "$pkg_name" \
       --arg type "$list_type" \
       --arg ver "$version" \
       '.[$pkg].ignore_version[$type] |= ([.[] | select(. != $ver)] + [$ver] | if length > 10 then del(.[0]) else . end)' \
       "$LOG_FILE" | sponge "$LOG_FILE"
}

# 检查某个版本是否存在于指定包的忽略列表中
# 【优化】根据您的建议，采用类似循环遍历的逻辑 (any) 来进行判断，可读性更好。
data_is_version_in_ignore_list() {
    local pkg_name=$1
    local list_type=$2
    local version=$3

    jq -r --arg pkg "$pkg_name" \
         --arg type "$list_type" \
         --arg ver "$version" \
         'if .[$pkg] and .[$pkg].ignore_version and .[$pkg].ignore_version[$type] then any(.[$pkg].ignore_version[$type][]; . == $ver) else false end' \
         "$LOG_FILE"
}


# 获取可降级的包列表
data_get_upgrade_logs() {
    local now_epoch=$(date +%s)
    local seventy_two_hours_ago=$((now_epoch - 72 * 3600))

    jq -r --argjson threshold "$seventy_two_hours_ago" \
        'keys[] as $pkg | .[$pkg] |
         # 【主要修复】增加对 last_upgrade 字段的健壮性检查。
         # 现在会安全地跳过 last_upgrade 不存在、不为对象或格式错误的条目，从而修复崩溃问题。
         select(type == "object" and (.last_upgrade? | type == "object")) |
         select((.last_upgrade.timestamp | fromdateiso8601) > $threshold) |
         # 【优化】根据您的建议，采用类似循环遍历的逻辑 (any) 来判断版本是否在忽略列表中。
         select(any(.ignore_version.downgrade // []; . == .last_upgrade.from) | not) |
         "\($pkg)\t\(.last_upgrade.from)\t\(.last_upgrade.to)"' \
        "$LOG_FILE"
}
