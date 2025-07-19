#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# --- 主脚本 (Frontend / View-Controller) ---
# 这是用户交互的入口。它负责：
# 1. 引入其他模块（配置、数据、包管理）。
# 2. 显示菜单和信息给用户 (View)。
# 3. 接收和解析用户的输入 (Controller)。
# 4. 调用后端模块函数来执行用户的请求。

# --- 初始化 ---
# 获取脚本所在目录，并引入其他模块
SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/data_manager.sh"
source "$SCRIPT_DIR/package_manager.sh"

# --- 视图函数 (UI Display Functions) ---

# 显示主菜单
ui_show_main_menu() {
    echo -e "\n============================="
    echo "  Paru 更新与降级管理器"
    echo "============================="
    echo "  u - 检查并更新软件包"
    echo "  d - 从历史记录降级软件包"
    echo "  q - 退出脚本"
    echo "-----------------------------"
    # 【修复】删除了此处的 read 命令，以避免双重输入
}

# --- 流程控制函数 (Workflow Handlers) ---

# 处理更新流程
handle_update_flow() {
    echo "正在检查可用的更新..."
    local updates
    updates=$(pkg_get_upgradable)

    if [ -z "$updates" ]; then
        echo "恭喜！系统已是最新状态。"
        return
    fi

    declare -A pkg_map
    declare -A version_map
    local pkg_to_ignore=()
    local index=1

    echo -e "\n--- 可用的更新列表 ---"
    while IFS= read -r line; do
        local pkg_name=$(echo "$line" | awk '{print $1}')
        local old_version=$(echo "$line" | awk '{print $2}')
        local new_version=$(echo "$line" | awk '{print $4}')
        
        # 从此处的函数调用重定向标准输入，以防止它干扰 `while read` 循环
        local is_ignored
        is_ignored=$(data_is_version_in_ignore_list "$pkg_name" "upgrade" "$new_version" < /dev/null)

        local skip_flag=""
        if [[ "$is_ignored" == "true" ]]; then
            skip_flag="[自动跳过]"
            pkg_to_ignore+=("$pkg_name")
        fi

        echo "$index. $pkg_name ($old_version -> $new_version) $skip_flag"
        pkg_map[$index]="$pkg_name"
        version_map[$pkg_name]="$old_version $new_version"
        ((index++))
    done <<< "$updates"

    echo -e "\n--- 请选择操作 ---"
    echo "  a - 更新所有 (会自动忽略标记为[自动跳过]的包)"
    echo "  i - 手动选择要忽略的包进行更新"
    echo "  q - 返回主菜单"

    local user_choice
    read -p "请输入您的选择 (a/i/q): " user_choice

    case $user_choice in
        a|A)
            # 更新所有非忽略的包
            ;;
        i|I)
            read -p "请输入要忽略的软件包编号 (用空格分隔): " ignore_nums
            local unique_ignore_pkgs=()
            for num in $ignore_nums; do
                if [ -n "${pkg_map[$num]}" ]; then
                    local pkg_to_add_ignore=${pkg_map[$num]}
                    local versions=(${version_map[$pkg_to_add_ignore]})
                    local new_version_to_ignore=${versions[1]}
                    # 【新增】将用户选择忽略的版本添加到json的忽略列表
                    data_add_to_ignore_list "$pkg_to_add_ignore" "upgrade" "$new_version_to_ignore"
                    echo "已将 $pkg_to_add_ignore 的更新版本 $new_version_to_ignore 添加到忽略列表。"
                    # 将其加入本次更新的忽略列表
                    unique_ignore_pkgs+=("$pkg_to_add_ignore")
                else
                    echo "警告：编号 $num 无效，已跳过。"
                fi
            done
            # 合并自动忽略和手动忽略的包，并去重
            pkg_to_ignore+=("${unique_ignore_pkgs[@]}")
            pkg_to_ignore=($(printf "%s\n" "${pkg_to_ignore[@]}" | sort -u))
            ;;
        q|Q)
            echo "操作已取消，返回主菜单。"
            return
            ;;
        *)
            echo "无效选择，操作已取消。"
            return
            ;;
    esac

    # 准备执行更新
    local packages_to_update=()
    for i in $(seq 1 $((index-1))); do
        local pkg_name=${pkg_map[$i]}
        local should_ignore=0
        for ignored in "${pkg_to_ignore[@]}"; do
            if [[ "$ignored" == "$pkg_name" ]]; then
                should_ignore=1
                break
            fi
        done
        
        if [[ $should_ignore -eq 0 ]]; then
            packages_to_update+=("$pkg_name")
            local versions=(${version_map[$pkg_name]})
            data_log_upgrade "$pkg_name" "${versions[0]}" "${versions[1]}"
        fi
    done

    if [ ${#packages_to_update[@]} -eq 0 ]; then
        echo "没有需要更新的软件包。"
        return
    fi
    
    echo "以下软件包将被忽略: ${pkg_to_ignore[*]}"
    pkg_perform_upgrade "${pkg_to_ignore[@]}"
    echo "更新流程完成。"
}


# 处理降级流程
handle_downgrade_flow() {
    echo -e "\n--- 可降级的软件包列表 (基于更新历史, 72小时内) ---"
    mapfile -t upgrade_logs < <(data_get_upgrade_logs)

    if [ ${#upgrade_logs[@]} -eq 0 ]; then
        echo "没有找到符合条件的、可从历史记录降级的软件包。"
        return
    fi

    declare -A pkg_map
    local index=1
    for log in "${upgrade_logs[@]}"; do
        # 使用制表符作为分隔符读取
        IFS=$'\t' read -r pkg_name old_version new_version <<< "$log"
        
        local current_version
        current_version=$(pkg_get_current_version "$pkg_name")
        if [ -z "$current_version" ]; then
            current_version="[未安装]"
        fi

        echo "$index. $pkg_name (当前: $current_version -> 目标: $old_version)"
        pkg_map[$index]="$pkg_name $old_version $current_version"
        ((index++))
    done

    read -p "请输入要降级的软件包编号 (用空格分隔，或输入'q'取消): " selections
    if [[ "$selections" == "q" || -z "$selections" ]]; then
        echo "操作已取消。"
        return
    fi

    for sel in $selections; do
        if [ -n "${pkg_map[$sel]}" ]; then
            local details=(${pkg_map[$sel]})
            local pkg_name=${details[0]}
            local target_version=${details[1]}
            local before_version=${details[2]}

            if [[ "$before_version" == "[未安装]" ]]; then
                echo "软件包 $pkg_name 未安装，无法降级。"
                continue
            fi

            if pkg_perform_downgrade "$pkg_name" "$target_version"; then
                local after_version
                after_version=$(pkg_get_current_version "$pkg_name")
                if [[ "$after_version" == "$target_version" ]];
                then
                    echo "$pkg_name 已成功降级到 $after_version"
                    data_log_downgrade "$pkg_name" "$before_version" "$after_version"
                    # 【新增】将导致问题的版本(降级前的版本)加入到更新忽略列表
                    echo "将版本 $before_version 添加到 $pkg_name 的更新忽略列表，以防将来再次更新。"
                    data_add_to_ignore_list "$pkg_name" "upgrade" "$before_version"
                else
                    echo "警告：$pkg_name 降级后版本 ($after_version) 与目标版本 ($target_version) 不符！"
                fi
            else
                echo "错误：$pkg_name 降级失败。"
            fi
        else
            echo "警告：无效的选择：$sel"
        fi
    done
    echo "降级流程完成。"
}

# --- 主程序入口 ---
main() {
    # 1. 检查依赖
    if ! pkg_check_dependencies; then
        exit 1
    fi

    # 2. 初始化数据文件
    data_init_log

    # 3. 进入主循环
    while true; do
        ui_show_main_menu
        # 【修复】将 read 命令移至此处，并作为唯一的输入点
        read -p "请输入您的选择: " choice
        case $choice in
            u|U)
                handle_update_flow
                ;;
            d|D)
                handle_downgrade_flow
                ;;
            q|Q)
                echo "正在退出..."
                exit 0
                ;;
            *)
                echo "无效的选择，请重新输入。"
                ;;
        esac
    done
}

# 运行主程序
main
