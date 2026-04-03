#!/bin/bash
#
# Huawei Ascend 910B NPU 备份脚本
# 
# 使用方法:
#   ./backup-npu.sh <目标服务器IP> [SSH密码]
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/npu-backup"

TARGET_HOST="${1}"
SSH_PASSWORD="${2}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 主函数
main() {
    if [ -z "$TARGET_HOST" ]; then
        echo "用法: $0 <目标服务器IP> [SSH密码]"
        exit 1
    fi
    
    log_info "=========================================="
    log_info "Huawei Ascend 910B NPU 备份"
    log_info "=========================================="
    log_info "目标服务器: $TARGET_HOST"
    log_info "备份目录: $BACKUP_DIR"
    log_info ""
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 下载驱动
    log_info "下载驱动文件..."
    ssh "root@${TARGET_HOST}" 'tar -czf - -C /usr/local/Ascend driver' | tar -xzf - -C "$BACKUP_DIR/"
    
    # 下载固件
    log_info "下载固件文件..."
    ssh "root@${TARGET_HOST}" 'tar -czf - -C /usr/local/Ascend firmware' | tar -xzf - -C "$BACKUP_DIR/"
    
    # 下载 CANN
    log_info "下载 CANN 文件..."
    ssh "root@${TARGET_HOST}" 'tar -czf - -C /usr/local/Ascend cann-9.0.0-beta.2' | tar -xzf - -C "$BACKUP_DIR/"
    
    # 下载固件设备文件
    log_info "下载固件设备文件..."
    ssh "root@${TARGET_HOST}" 'tar -czf - -C / home/bios' | tar -xzf - -C "$BACKUP_DIR/"
    
    # 下载配置文件
    log_info "下载配置文件..."
    ssh "root@${TARGET_HOST}" 'tar -czf - /etc/ascend_install.info /etc/Ascend /etc/modules-load.d/ascend.conf /usr/local/Ascend/version.info' | tar -xzf - -C "$BACKUP_DIR/"
    
    # 显示备份结果
    log_info ""
    log_info "=========================================="
    log_info "备份完成!"
    log_info "=========================================="
    du -sh "$BACKUP_DIR"/*
}

main "$@"