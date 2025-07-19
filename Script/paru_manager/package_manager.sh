#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# --- 包管理器 (Controller - Core Logic) ---
# 封装了所有与系统包管理器（paru, pacman, downgrade）交互的命令。
# 此脚本是核心功能的“后端”，负责执行实际操作，但不负责展示。

# 检查脚本依赖的工具是否安装
# 如果未安装，会提示用户并尝试自动安装
# 返回: 0=所有依赖满足, 1=用户拒绝安装导致依赖缺失
pkg_check_dependencies() {
    # 【修复】增加对 sponge (属于 moreutils) 的依赖检查，这是确保文件能被正确写入的关键
    local missing=0
    for cmd in paru jq downgrade sponge; do
        if ! command -v "$cmd" &> /dev/null; then
            local pkg_to_install="$cmd"
            if [ "$cmd" == "sponge" ]; then
                pkg_to_install="moreutils"
            fi
            
            echo "警告：依赖工具 '$cmd' (由软件包 '$pkg_to_install' 提供) 未安装。"
            read -p "是否要立即使用 paru 安装 '$pkg_to_install'? (y/n): " choice
            if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
                paru -S --noconfirm "$pkg_to_install"
                if ! command -v "$cmd" &> /dev/null; then
                    echo "错误：'$cmd' 安装失败，请手动安装后重试。"
                    missing=1
                fi
            else
                echo "错误：用户取消安装。脚本无法继续，请先安装 '$cmd'。"
                missing=1
            fi
        fi
    done
    # Convert missing to a standard exit code. 0 for success, 1 for failure.
    if [ "$missing" -ne 0 ]; then
        return 1
    else
        return 0
    fi
}

# 获取已安装软件包的当前版本号
# 增加了重试机制以提高稳定性
# 参数1: pkg_name - 软件包名称
# 返回: 版本号字符串，如果获取失败则返回空
pkg_get_current_version() {
    local pkg_name=$1
    local attempts=3
    local delay=2
    local current_version

    for ((i=1; i<=attempts; i++)); do
        current_version=$(pacman -Qi "$pkg_name" 2>/dev/null | grep -E '^版本' | awk '{print $3}')
        if [ -n "$current_version" ]; then
            echo "$current_version"
            return 0
        fi
        # 在最后一次尝试失败后不再打印重试信息
        if [ $i -lt $attempts ]; then
            echo "尝试 $i/$attempts：无法获取 $pkg_name 的版本，等待 $delay 秒后重试..." >&2
            sleep $delay
        fi
    done
    echo ""
    return 1
}

# 检查可用的更新
# 返回: 一个由 "包名 旧版本 -> 新版本" 组成的字符串列表，每行一条记录
pkg_get_upgradable() {
    # 捕获 paru 的输出，过滤出有效的更新行
    paru -Qu 2>/dev/null | grep -- '->' || true
}

# 执行系统更新
# 参数: 要忽略的软件包列表，每个包名作为独立的参数 (e.g., pkg_perform_upgrade pkg1 pkg2)
# 返回: paru 命令的退出码
pkg_perform_upgrade() {
    local ignore_pkgs=("$@")
    local ignore_option=""

    if [ ${#ignore_pkgs[@]} -gt 0 ]; then
        # 将数组转换为逗号分隔的字符串以传递给 --ignore
        local ignore_list
        ignore_list=$(IFS=,; echo "${ignore_pkgs[*]}")
        ignore_option="--ignore=$ignore_list"
    fi

    echo "正在执行更新... paru -Syu $ignore_option --noconfirm"
    paru -Syu $ignore_option --noconfirm
}

# 执行软件包降级
# 参数1: pkg_name - 要降级的软件包名称
# 参数2: target_version - 目标版本号
# 返回: downgrade 命令的退出码
pkg_perform_downgrade() {
    local pkg_name=$1
    local target_version=$2
    
    echo "正在降级 $pkg_name 至版本 $target_version..."
    # 使用 sudo 执行降级操作
    sudo downgrade "$pkg_name=$target_version" -- --noconfirm
}
