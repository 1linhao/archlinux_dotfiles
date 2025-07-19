#!/bin/bash

# --- 配置文件 ---
# 该文件定义了脚本所需的全局变量和路径，方便统一管理。

# 获取脚本根目录
# 使用 realpath 来解析符号链接，确保路径的准确性
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# 定义数据存储目录
DATA_DIR="$SCRIPT_DIR/data"

# 定义 JSON 日志文件路径
LOG_FILE="$DATA_DIR/paru_update_log.json"
