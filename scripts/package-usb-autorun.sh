#!/bin/bash
# KSC AIBox U盘自动执行方案打包脚本
# 用于创建可部署的压缩包

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
USB_AUTORUN_DIR="$PROJECT_DIR/usb-autorun"
OUTPUT_DIR="$PROJECT_DIR/dist"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PACKAGE_NAME="ksc-aibox-usb-autorun-$TIMESTAMP"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo -e "KSC AIBox U盘自动执行方案打包工具"
echo -e "==========================================${NC}"

# 检查源目录
if [ ! -d "$USB_AUTORUN_DIR" ]; then
    echo -e "${RED}错误: usb-autorun目录不存在${NC}"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 创建临时打包目录
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/$PACKAGE_NAME"

echo -e "${BLUE}步骤1: 准备打包文件...${NC}"
mkdir -p "$PACKAGE_DIR"

# 复制usb-autorun文件
cp -r "$USB_AUTORUN_DIR" "$PACKAGE_DIR/"

# 设置脚本权限
chmod +x "$PACKAGE_DIR/usb-autorun/autorun.sh"
chmod +x "$PACKAGE_DIR/usb-autorun/recovery-shell.sh"

# 创建快速启动脚本（放在根目录）
cat > "$PACKAGE_DIR/START_HERE.sh" << 'EOF'
#!/bin/bash
# KSC AIBox 快速启动脚本
# 直接执行此脚本即可开始系统恢复

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "KSC AIBox 系统恢复"
echo "=========================================="
echo ""
echo "请确保以root用户执行此脚本"
echo ""

# 检查是否为root
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用root用户执行"
    echo "执行: sudo bash $0"
    exit 1
fi

# 执行恢复脚本
bash "$SCRIPT_DIR/usb-autorun/autorun.sh" --force

echo ""
echo "=========================================="
echo "恢复完成！"
echo "=========================================="
echo ""
echo "请检查:"
echo "  - 目录结构: ls -la /ksc_aibox"
echo "  - 版本信息: cat /ksc_aibox/VERSION"
echo "  - 执行日志: tail -100 /var/log/ksc-aibox-autorun.log"
echo ""
EOF
chmod +x "$PACKAGE_DIR/START_HERE.sh"

# 创建U盘标签说明
cat > "$PACKAGE_DIR/U盘标签设置.txt" << 'EOF'
U盘标签设置说明
================

为了使自动检测功能正常工作，建议将U盘标签设置为以下之一：
- KSC_AUTO
- KSC_AIBOX_AUTORUN

Linux设置方法:
  # 查看U盘设备
  lsblk
  
  # 设置标签（假设U盘是/dev/sdb1）
  e2label /dev/sdb1 KSC_AUTO      # ext2/ext3/ext4
  fatlabel /dev/sdb1 KSC_AUTO     # FAT32
  exfatlabel /dev/sdb1 KSC_AUTO   # exFAT

macOS设置方法:
  diskutil list                    # 查看U盘设备
  diskutil rename /dev/disk2 KSC_AUTO

Windows设置方法:
  在文件管理器中右键U盘 -> 属性 -> 重命名
EOF

# 创建部署说明
cat > "$PACKAGE_DIR/部署说明.txt" << 'EOF'
KSC AIBox U盘自动执行方案部署说明
================================

1. 准备U盘
   - 将整个压缩包内容解压到U盘根目录
   - 或直接复制整个文件夹到U盘

2. 设置U盘标签（可选）
   - 参考 "U盘标签设置.txt"

3. 在目标系统执行
   方式A - 快速启动:
     sudo bash START_HERE.sh
   
   方式B - 使用autorun脚本:
     sudo bash usb-autorun/autorun.sh
   
   方式C - 仅执行Shell脚本:
     sudo bash usb-autorun/recovery-shell.sh --steps all
   
   方式D - 使用Ansible:
     ansible-playbook -i inventory usb-autorun/recovery-ansible.yml

4. 验证结果
   ls -la /ksc_aibox
   cat /ksc_aibox/VERSION
   tail -100 /var/log/ksc-aibox-autorun.log

5. 强制重新执行
   rm /ksc_aibox/.autorun_completed
   sudo bash usb-autorun/autorun.sh --force

详细说明请参考: usb-autorun/README.md
EOF

echo -e "${BLUE}步骤2: 创建压缩包...${NC}"

# 创建tar.gz压缩包
cd "$TEMP_DIR"
tar -czf "$OUTPUT_DIR/$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME"

# 创建zip压缩包（Windows兼容）
cd "$PACKAGE_DIR"
zip -r "$OUTPUT_DIR/$PACKAGE_NAME.zip" .

# 计算文件大小
TAR_SIZE=$(du -h "$OUTPUT_DIR/$PACKAGE_NAME.tar.gz" | cut -f1)
ZIP_SIZE=$(du -h "$OUTPUT_DIR/$PACKAGE_NAME.zip" | cut -f1)

echo -e "${BLUE}步骤3: 创建校验文件...${NC}"

# 创建SHA256校验
cd "$OUTPUT_DIR"
sha256sum "$PACKAGE_NAME.tar.gz" > "$PACKAGE_NAME.tar.gz.sha256"
sha256sum "$PACKAGE_NAME.zip" > "$PACKAGE_NAME.zip.sha256"

# 清理临时目录
rm -rf "$TEMP_DIR"

echo -e "${GREEN}=========================================="
echo -e "打包完成！"
echo -e "==========================================${NC}"
echo ""
echo "输出文件:"
echo "  - $OUTPUT_DIR/$PACKAGE_NAME.tar.gz ($TAR_SIZE)"
echo "  - $OUTPUT_DIR/$PACKAGE_NAME.zip ($ZIP_SIZE)"
echo ""
echo "校验文件:"
echo "  - $OUTPUT_DIR/$PACKAGE_NAME.tar.gz.sha256"
echo "  - $OUTPUT_DIR/$PACKAGE_NAME.zip.sha256"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "  1. 将压缩包解压到U盘根目录"
echo "  2. 在目标系统执行: sudo bash START_HERE.sh"
echo ""