#!/bin/bash
# KSC AIBox 一键复制到U盘脚本
# 自动检测U盘并复制文件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
USB_AUTORUN_DIR="$PROJECT_DIR/usb-autorun"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo -e "KSC AIBox 一键复制到U盘"
echo -e "==========================================${NC}"

# 检查操作系统
OS_TYPE=$(uname -s)
echo -e "${BLUE}操作系统: $OS_TYPE${NC}"

# 检测U盘函数
detect_usb_devices() {
    local devices=""
    
    case $OS_TYPE in
        Darwin)
            # macOS - 使用diskutil
            echo -e "${BLUE}检测可移动存储设备...${NC}"
            diskutil list external | grep -E "/dev/disk[0-9]+" | while read line; do
                dev=$(echo "$line" | grep -oE "/dev/disk[0-9]+")
                if [ -n "$dev" ]; then
                    # 获取设备信息
                    info=$(diskutil info "$dev" 2>/dev/null)
                    name=$(echo "$info" | grep "Volume Name" | awk -F: '{print $2}' | xargs)
                    size=$(echo "$info" | grep "Total Size" | awk -F: '{print $2}' | xargs | cut -d' ' -f1)
                    fstype=$(echo "$info" | grep "File System" | awk -F: '{print $2}' | xargs)
                    mountpoint=$(echo "$info" | grep "Mount Point" | awk -F: '{print $2}' | xargs)
                    
                    echo "$dev|$name|$size|$fstype|$mountpoint"
                fi
            done
            ;;
        Linux)
            # Linux - 使用lsblk
            echo -e "${BLUE}检测可移动存储设备...${NC}"
            lsblk -o NAME,LABEL,SIZE,FSTYPE,MOUNTPOINT,TRAN | grep -E "usb|sd|mmc" | while read line; do
                name=$(echo "$line" | awk '{print $1}')
                label=$(echo "$line" | awk '{print $2}')
                size=$(echo "$line" | awk '{print $3}')
                fstype=$(echo "$line" | awk '{print $4}')
                mountpoint=$(echo "$line" | awk '{print $5}')
                
                if [ -n "$name" ]; then
                    echo "/dev/$name|$label|$size|$fstype|$mountpoint"
                fi
            done
            ;;
        *)
            echo -e "${RED}不支持的操作系统: $OS_TYPE${NC}"
            return 1
            ;;
    esac
}

# 列出U盘设备
list_usb_devices() {
    echo ""
    echo -e "${YELLOW}检测到的U盘设备:${NC}"
    echo ""
    echo "序号 | 设备      | 名称       | 大小   | 文件系统 | 挂载点"
    echo "-----|-----------|------------|--------|----------|--------"
    
    local index=1
    while IFS='|' read -r dev name size fstype mountpoint; do
        if [ -n "$dev" ]; then
            printf "%3d  | %-9s | %-10s | %-6s | %-8s | %s\n" "$index" "$dev" "$name" "$size" "$fstype" "$mountpoint"
            USB_DEVICES["$index"]="$dev|$mountpoint"
            ((index++))
        fi
    done < <(detect_usb_devices)
    
    echo ""
}

# 选择U盘
select_usb() {
    declare -a USB_DEVICES
    list_usb_devices
    
    if [ ${#USB_DEVICES[@]} -eq 0 ]; then
        echo -e "${RED}未检测到U盘设备${NC}"
        echo -e "${YELLOW}请插入U盘后重新执行此脚本${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}请输入要使用的U盘序号 (1-${#USB_DEVICES[@]}):${NC}"
    read -r selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#USB_DEVICES[@]} ]; then
        echo -e "${RED}无效的选择${NC}"
        return 1
    fi
    
    SELECTED_USB="${USB_DEVICES[$selection]}"
    return 0
}

# 挂载U盘
mount_usb() {
    local dev=$(echo "$SELECTED_USB" | cut -d'|' -f1)
    local existing_mount=$(echo "$SELECTED_USB" | cut -d'|' -f2)
    
    if [ -n "$existing_mount" ] && [ "$existing_mount" != "Not mounted" ]; then
        USB_MOUNT="$existing_mount"
        echo -e "${GREEN}U盘已挂载: $USB_MOUNT${NC}"
        return 0
    fi
    
    # 需要挂载
    USB_MOUNT="/tmp/ksc-usb-mount-$RANDOM"
    mkdir -p "$USB_MOUNT"
    
    echo -e "${BLUE}挂载U盘到: $USB_MOUNT${NC}"
    
    case $OS_TYPE in
        Darwin)
            mount -t msdos "$dev" "$USB_MOUNT" 2>/dev/null || \
            mount -t exfat "$dev" "$USB_MOUNT" 2>/dev/null || \
            mount "$dev" "$USB_MOUNT" 2>/dev/null || {
                echo -e "${RED}挂载失败${NC}"
                return 1
            }
            ;;
        Linux)
            mount "$dev" "$USB_MOUNT" || {
                echo -e "${RED}挂载失败${NC}"
                return 1
            }
            ;;
    esac
    
    echo -e "${GREEN}U盘挂载成功${NC}"
    return 0
}

# 复制文件
copy_files() {
    echo ""
    echo -e "${BLUE}复制文件到U盘...${NC}"
    
    # 创建目标目录
    TARGET_DIR="$USB_MOUNT/usb-autorun"
    mkdir -p "$TARGET_DIR"
    
    # 复制所有文件
    cp -r "$USB_AUTORUN_DIR"/* "$TARGET_DIR/"
    
    # 设置权限
    chmod +x "$TARGET_DIR/autorun.sh"
    chmod +x "$TARGET_DIR/recovery-shell.sh"
    
    # 创建快速启动脚本
    cat > "$USB_MOUNT/START_HERE.sh" << 'EOF'
#!/bin/bash
# KSC AIBox 快速启动脚本
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=========================================="
echo "KSC AIBox 系统恢复"
echo "=========================================="
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用root用户执行"
    echo "执行: sudo bash $0"
    exit 1
fi
bash "$SCRIPT_DIR/usb-autorun/autorun.sh" --force
echo ""
echo "恢复完成！请检查:"
echo "  - ls -la /ksc_aibox"
echo "  - cat /ksc_aibox/VERSION"
EOF
    chmod +x "$USB_MOUNT/START_HERE.sh"
    
    # 计算复制大小
    COPIED_SIZE=$(du -sh "$TARGET_DIR" | cut -f1)
    
    echo -e "${GREEN}文件复制完成！${NC}"
    echo -e "${GREEN}复制大小: $COPIED_SIZE${NC}"
    
    # 显示复制内容
    echo ""
    echo -e "${BLUE}复制的内容:${NC}"
    ls -la "$USB_MOUNT/"
    echo ""
    ls -la "$TARGET_DIR/"
}

# 设置U盘标签
set_usb_label() {
    local dev=$(echo "$SELECTED_USB" | cut -d'|' -f1)
    
    echo ""
    echo -e "${YELLOW}是否设置U盘标签为 'KSC_AUTO'? (y/n)${NC}"
    read -r answer
    
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        echo -e "${BLUE}设置U盘标签...${NC}"
        
        case $OS_TYPE in
            Darwin)
                diskutil rename "$dev" "KSC_AUTO" && \
                echo -e "${GREEN}U盘标签已设置为: KSC_AUTO${NC}" || \
                echo -e "${RED}设置标签失败${NC}"
                ;;
            Linux)
                # 根据文件系统类型设置标签
                fstype=$(lsblk -no FSTYPE "$dev" 2>/dev/null)
                case $fstype in
                    ext2|ext3|ext4)
                        e2label "$dev" "KSC_AUTO"
                        ;;
                    vfat|fat32)
                        fatlabel "$dev" "KSC_AUTO"
                        ;;
                    exfat)
                        exfatlabel "$dev" "KSC_AUTO"
                        ;;
                    *)
                        echo -e "${YELLOW}无法自动设置标签，请手动设置${NC}"
                        ;;
                esac
                ;;
        esac
    fi
}

# 卸载U盘（可选）
unmount_usb() {
    echo ""
    echo -e "${YELLOW}是否卸载U盘? (y/n)${NC}"
    read -r answer
    
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        echo -e "${BLUE}卸载U盘...${NC}"
        
        case $OS_TYPE in
            Darwin)
                # macOS需要先同步
                sync
                diskutil unmount "$USB_MOUNT" 2>/dev/null || umount "$USB_MOUNT" 2>/dev/null
                ;;
            Linux)
                sync
                umount "$USB_MOUNT"
                ;;
        esac
        
        rmdir "$USB_MOUNT" 2>/dev/null || true
        echo -e "${GREEN}U盘已卸载，可以安全拔出${NC}"
    else
        echo -e "${YELLOW}U盘保持挂载状态: $USB_MOUNT${NC}"
        echo -e "${YELLOW}请手动卸载后再拔出${NC}"
    fi
}

# 主函数
main() {
    # 检查源目录
    if [ ! -d "$USB_AUTORUN_DIR" ]; then
        echo -e "${RED}错误: usb-autorun目录不存在${NC}"
        echo -e "${YELLOW}请先执行 package-usb-autorun.sh 创建文件${NC}"
        exit 1
    fi
    
    # 检测并选择U盘
    if ! select_usb; then
        exit 1
    fi
    
    # 挂载U盘
    if ! mount_usb; then
        exit 1
    fi
    
    # 复制文件
    copy_files
    
    # 设置标签
    set_usb_label
    
    # 卸载
    unmount_usb
    
    echo ""
    echo -e "${GREEN}=========================================="
    echo -e "复制完成！"
    echo -e "==========================================${NC}"
    echo ""
    echo -e "${YELLOW}在目标系统上执行:${NC}"
    echo "  sudo bash START_HERE.sh"
    echo ""
    echo -e "${YELLOW}或:${NC}"
    echo "  sudo bash usb-autorun/autorun.sh"
    echo ""
}

# 执行主函数
main "$@"