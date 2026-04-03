#!/bin/bash
# KSC AIBox U盘自动执行脚本
# 系统恢复后自动检测并执行必要操作
# 版本: 1.0.0

set -e

# ================================================
# 全局变量和配置
# ================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/ksc-aibox-autorun.log"
CONFIG_FILE="${SCRIPT_DIR}/recovery-config.yml"
MARKER_FILE="/ksc_aibox/.autorun_completed"
USB_MARKER="KSC_AIBOX_AUTORUN"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ================================================
# 日志函数
# ================================================
log() {
    local level=$1
    local msg=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    
    case $level in
        INFO)  echo -e "${GREEN}[INFO]${NC} $msg" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $msg" ;;
        DEBUG) echo -e "${BLUE}[DEBUG]${NC} $msg" ;;
    esac
}

# ================================================
# 检测U盘
# ================================================
detect_usb() {
    log INFO "开始检测U盘..."
    
    # 查找所有可移动存储设备
    for device in /dev/disk/by-label/*; do
        if [ -L "$device" ]; then
            label=$(basename "$device")
            if [[ "$label" == *"$USB_MARKER"* ]] || [[ "$label" == "KSC_AUTO"* ]]; then
                # 找到标记的U盘
                actual_device=$(readlink -f "$device")
                mount_point="/mnt/ksc-autorun-usb"
                
                log INFO "检测到U盘: $label ($actual_device)"
                
                # 挂载U盘
                mkdir -p "$mount_point"
                mount "$actual_device" "$mount_point" 2>/dev/null || {
                    log WARN "U盘已挂载或挂载失败，尝试其他方式..."
                    # 查找已挂载的U盘
                    mount_point=$(findmnt -n -o TARGET -S "$actual_device" 2>/dev/null || echo "")
                    if [ -z "$mount_point" ]; then
                        log ERROR "无法挂载U盘"
                        return 1
                    fi
                }
                
                # 检查U盘上是否有autorun脚本
                if [ -f "$mount_point/autorun.sh" ] || [ -f "$mount_point/usb-autorun/autorun.sh" ]; then
                    log INFO "找到autorun脚本"
                    USB_MOUNT="$mount_point"
                    return 0
                fi
            fi
        fi
    done
    
    # 如果没有找到标记的U盘，检查当前脚本所在目录
    if [ -f "$SCRIPT_DIR/recovery-shell.sh" ]; then
        log INFO "使用当前目录作为执行源"
        USB_MOUNT="$SCRIPT_DIR"
        return 0
    fi
    
    log ERROR "未找到有效的U盘或执行脚本"
    return 1
}

# ================================================
# 检查系统状态
# ================================================
check_system_status() {
    log INFO "检查系统状态..."
    
    # 检查是否已经执行过
    if [ -f "$MARKER_FILE" ]; then
        last_run=$(cat "$MARKER_FILE")
        log WARN "系统已于 $last_run 执行过自动恢复"
        log INFO "如需重新执行，请删除 $MARKER_FILE 文件"
        return 1
    fi
    
    # 检查必要的系统条件
    # 1. 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then
        log ERROR "请使用root用户执行此脚本"
        return 1
    fi
    
    # 2. 检查操作系统
    if [ ! -f /etc/os-release ]; then
        log ERROR "无法识别操作系统"
        return 1
    fi
    
    os_id=$(grep '^ID=' /etc/os-release | cut -d'=' -f2)
    log INFO "操作系统: $os_id"
    
    # 3. 检查磁盘空间
    available_space=$(df -h / | tail -1 | awk '{print $4}')
    log INFO "可用磁盘空间: $available_space"
    
    # 4. 检查网络连接（可选）
    if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        log INFO "网络连接正常"
        NETWORK_OK=true
    else
        log WARN "网络连接不可用，部分功能可能受限"
        NETWORK_OK=false
    fi
    
    return 0
}

# ================================================
# 解析配置文件
# ================================================
parse_config() {
    log INFO "解析配置文件..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log WARN "配置文件不存在，使用默认配置"
        # 默认配置
        EXEC_MODE="shell"
        STEPS="dirs,system,npu,docker,verify"
        KSC_AIBOX_ROOT="/ksc_aibox"
        BACKUP_ROOT="/backup"
        return 0
    fi
    
    # 简单解析YAML配置
    EXEC_MODE=$(grep '^exec_mode:' "$CONFIG_FILE" | awk '{print $2}' || echo "shell")
    STEPS=$(grep '^steps:' "$CONFIG_FILE" | awk '{print $2}' || echo "all")
    KSC_AIBOX_ROOT=$(grep '^ksc_aibox_root:' "$CONFIG_FILE" | awk '{print $2}' || echo "/ksc_aibox")
    BACKUP_ROOT=$(grep '^backup_root:' "$CONFIG_FILE" | awk '{print $2}' || echo "/backup")
    
    log INFO "执行模式: $EXEC_MODE"
    log INFO "执行步骤: $STEPS"
    log INFO "应用目录: $KSC_AIBOX_ROOT"
    log INFO "备份目录: $BACKUP_ROOT"
    
    return 0
}

# ================================================
# 执行Shell版本恢复
# ================================================
run_shell_recovery() {
    log INFO "执行Shell版本恢复脚本..."
    
    recovery_script="${USB_MOUNT}/recovery-shell.sh"
    if [ ! -f "$recovery_script" ]; then
        recovery_script="${SCRIPT_DIR}/recovery-shell.sh"
    fi
    
    if [ ! -f "$recovery_script" ]; then
        log ERROR "找不到Shell恢复脚本"
        return 1
    fi
    
    # 执行恢复脚本
    chmod +x "$recovery_script"
    bash "$recovery_script" \
        --root "$KSC_AIBOX_ROOT" \
        --backup "$BACKUP_ROOT" \
        --steps "$STEPS" \
        --log "$LOG_FILE"
    
    return $?
}

# ================================================
# 执行Ansible版本恢复
# ================================================
run_ansible_recovery() {
    log INFO "执行Ansible版本恢复..."
    
    # 检查Ansible是否安装
    if ! command -v ansible-playbook &> /dev/null; then
        log WARN "Ansible未安装，尝试安装..."
        
        if command -v dnf &> /dev/null; then
            dnf install -y ansible
        elif command -v yum &> /dev/null; then
            yum install -y ansible
        elif command -v pip3 &> /dev/null; then
            pip3 install ansible
        else
            log ERROR "无法安装Ansible，切换到Shell模式"
            EXEC_MODE="shell"
            return 1
        fi
    fi
    
    playbook="${USB_MOUNT}/recovery-ansible.yml"
    if [ ! -f "$playbook" ]; then
        playbook="${SCRIPT_DIR}/recovery-ansible.yml"
    fi
    
    if [ ! -f "$playbook" ]; then
        log ERROR "找不到Ansible playbook"
        return 1
    fi
    
    # 创建临时inventory
    inventory_file="/tmp/ksc-aibox-inventory"
    echo "[aibox]" > "$inventory_file"
    echo "localhost ansible_connection=local" >> "$inventory_file"
    
    # 执行playbook
    ansible-playbook -i "$inventory_file" "$playbook" \
        -e "ksc_aibox_root=$KSC_AIBOX_ROOT" \
        -e "backup_root=$BACKUP_ROOT" \
        -e "steps=$STEPS" \
        -v
    
    return $?
}

# ================================================
# 完成标记
# ================================================
mark_completed() {
    log INFO "标记执行完成..."
    
    mkdir -p "$(dirname "$MARKER_FILE")"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$MARKER_FILE"
    
    # 创建执行报告
    report_file="/ksc_aibox/config/AUTORUN_REPORT.md"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
# KSC AIBox 自动恢复执行报告

## 执行时间
$(date '+%Y-%m-%d %H:%M:%S')

## 执行模式
$EXEC_MODE

## 执行步骤
$STEPS

## 系统信息
- 操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- 内核版本: $(uname -r)
- 主机名: $(hostname)

## 目录配置
- 应用目录: $KSC_AIBOX_ROOT
- 备份目录: $BACKUP_ROOT

## 日志文件
$LOG_FILE

## 状态
✅ 执行完成
EOF
    
    log INFO "执行报告已保存到: $report_file"
}

# ================================================
# 清理和卸载
# ================================================
cleanup() {
    log INFO "清理临时文件..."
    
    # 卸载U盘（如果是我们挂载的）
    if [ -n "$USB_MOUNT" ] && [ "$USB_MOUNT" != "$SCRIPT_DIR" ]; then
        if mountpoint -q "$USB_MOUNT" 2>/dev/null; then
            umount "$USB_MOUNT" 2>/dev/null || true
            rmdir "$USB_MOUNT" 2>/dev/null || true
        fi
    fi
    
    # 清理临时inventory
    rm -f /tmp/ksc-aibox-inventory
}

# ================================================
# 主函数
# ================================================
main() {
    local args="$@"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_RUN=true
                shift
                ;;
            --mode)
                EXEC_MODE="$2"
                shift 2
                ;;
            --steps)
                STEPS="$2"
                shift 2
                ;;
            --help|-h)
                echo "KSC AIBox U盘自动执行脚本"
                echo ""
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --force     强制执行（忽略完成标记）"
                echo "  --mode      执行模式 (shell|ansible)"
                echo "  --steps     执行步骤 (all|dirs,system,npu,docker,verify)"
                echo "  --help      显示帮助信息"
                echo ""
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    log INFO "=========================================="
    log INFO "KSC AIBox 自动恢复脚本启动"
    log INFO "=========================================="
    
    # 检测U盘
    if ! detect_usb; then
        log ERROR "U盘检测失败，退出"
        exit 1
    fi
    
    # 检查系统状态
    if ! check_system_status; then
        if [ "$FORCE_RUN" != "true" ]; then
            log INFO "使用 --force 参数强制重新执行"
            exit 0
        fi
        log WARN "强制执行模式，忽略状态检查"
    fi
    
    # 解析配置
    parse_config
    
    # 执行恢复
    case $EXEC_MODE in
        shell)
            if ! run_shell_recovery; then
                log ERROR "Shell恢复执行失败"
                cleanup
                exit 1
            fi
            ;;
        ansible)
            if ! run_ansible_recovery; then
                log WARN "Ansible执行失败，尝试Shell模式"
                if ! run_shell_recovery; then
                    log ERROR "所有恢复模式执行失败"
                    cleanup
                    exit 1
                fi
            fi
            ;;
        both)
            run_shell_recovery
            run_ansible_recovery
            ;;
        *)
            log ERROR "未知执行模式: $EXEC_MODE"
            exit 1
            ;;
    esac
    
    # 标记完成
    mark_completed
    
    # 清理
    cleanup
    
    log INFO "=========================================="
    log INFO "KSC AIBox 自动恢复完成!"
    log INFO "=========================================="
    log INFO "请检查日志文件: $LOG_FILE"
    log INFO "请检查执行报告: /ksc_aibox/config/AUTORUN_REPORT.md"
    
    exit 0
}

# 执行主函数
main "$@"