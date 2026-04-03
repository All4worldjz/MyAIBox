#!/bin/bash
#
# Huawei Ascend 910B NPU 自动安装脚本
# 
# 使用方法:
#   ./install-npu.sh <目标服务器IP> [SSH密码]
#
# 示例:
#   ./install-npu.sh 10.212.128.192
#   ./install-npu.sh 10.212.128.192 mypassword
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/npu-backup"
ANSIBLE_DIR="${PROJECT_DIR}/ansible"

# 默认值
TARGET_HOST=""
SSH_PASSWORD=""
ANSIBLE_USER="root"

# 帮助信息
show_help() {
    cat << EOF
Huawei Ascend 910B NPU 自动安装脚本

用法:
    $0 <目标服务器IP> [SSH密码]

示例:
    $0 10.212.128.192
    $0 10.212.128.192 mypassword

参数:
    目标服务器IP    目标服务器的 IP 地址
    SSH密码         SSH 密码 (可选，不提供则使用密钥)

EOF
}

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查 Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible 未安装，请先安装: pip install ansible"
        exit 1
    fi
    
    # 检查备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "备份目录不存在: $BACKUP_DIR"
        exit 1
    fi
    
    # 检查备份文件
    if [ ! -d "$BACKUP_DIR/driver" ]; then
        log_error "驱动文件不存在: $BACKUP_DIR/driver"
        exit 1
    fi
    
    if [ ! -d "$BACKUP_DIR/cann-9.0.0-beta.2" ]; then
        log_error "CANN 文件不存在: $BACKUP_DIR/cann-9.0.0-beta.2"
        exit 1
    fi
    
    log_info "前置条件检查通过"
}

# 同步备份文件到目标服务器
sync_files() {
    log_info "同步文件到目标服务器: $TARGET_HOST"
    
    # 同步驱动文件
    rsync -avz --progress "$BACKUP_DIR/driver/" "root@${TARGET_HOST}:/usr/local/Ascend/driver/" 2>/dev/null || \
        ssh "root@${TARGET_HOST}" "mkdir -p /usr/local/Ascend/driver" && \
        scp -r "$BACKUP_DIR/driver/"* "root@${TARGET_HOST}:/usr/local/Ascend/driver/"
    
    # 同步固件文件
    rsync -avz --progress "$BACKUP_DIR/firmware/" "root@${TARGET_HOST}:/usr/local/Ascend/firmware/" 2>/dev/null || \
        ssh "root@${TARGET_HOST}" "mkdir -p /usr/local/Ascend/firmware" && \
        scp -r "$BACKUP_DIR/firmware/"* "root@${TARGET_HOST}:/usr/local/Ascend/firmware/"
    
    # 同步 CANN 文件
    rsync -avz --progress "$BACKUP_DIR/cann-9.0.0-beta.2/" "root@${TARGET_HOST}:/usr/local/Ascend/cann-9.0.0-beta.2/" 2>/dev/null || \
        ssh "root@${TARGET_HOST}" "mkdir -p /usr/local/Ascend" && \
        scp -r "$BACKUP_DIR/cann-9.0.0-beta.2/" "root@${TARGET_HOST}:/usr/local/Ascend/"
    
    # 同步固件设备文件
    if [ -d "$BACKUP_DIR/home/bios/driver/device" ]; then
        rsync -avz --progress "$BACKUP_DIR/home/bios/driver/device/" "root@${TARGET_HOST}:/home/bios/driver/device/" 2>/dev/null || \
            ssh "root@${TARGET_HOST}" "mkdir -p /home/bios/driver/device" && \
            scp -r "$BACKUP_DIR/home/bios/driver/device/"* "root@${TARGET_HOST}:/home/bios/driver/device/"
    fi
    
    log_info "文件同步完成"
}

# 运行 Ansible playbook
run_ansible() {
    log_info "运行 Ansible 安装..."
    
    cd "$ANSIBLE_DIR"
    
    # 创建临时 inventory
    cat > inventory-temp.ini << EOF
[npu_servers]
${TARGET_HOST} ansible_user=root ansible_connection=ssh
EOF
    
    # 运行 playbook
    ansible-playbook \
        -i inventory-temp.ini \
        -e "ansible_ssh_pass=${SSH_PASSWORD}" \
        playbooks/01-install-npu-full-stack.yml
    
    # 清理临时文件
    rm -f inventory-temp.ini
    
    log_info "Ansible 安装完成"
}

# 远程执行安装
remote_install() {
    log_info "开始远程安装到: $TARGET_HOST"
    
    # 1. 环境准备
    log_info "步骤 1/7: 环境准备"
    ssh "root@${TARGET_HOST}" << 'EOF'
set -e
# 禁用 SELinux
setenforce 0 2>/dev/null || true
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

# 禁用防火墙
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

# 创建目录
mkdir -p /home/bios/driver/device
mkdir -p /var/log/ascend_seclog
mkdir -p /etc/ascend
mkdir -p /etc/Ascend

echo "环境准备完成"
EOF

    # 2. 安装驱动
    log_info "步骤 2/7: 安装驱动"
    ssh "root@${TARGET_HOST}" << 'EOF'
set -e
cd /usr/local/Ascend/driver/tools
chmod +x install_npudrv.sh
./install_npudrv.sh --install-for-all || true
echo "驱动安装完成"
EOF

    # 3. 安装固件
    log_info "步骤 3/7: 安装固件"
    ssh "root@${TARGET_HOST}" << 'EOF'
set -e
# 复制固件到设备路径 (910B 必须)
cp -r /usr/local/Ascend/driver/device/* /home/bios/driver/device/ 2>/dev/null || true
chmod 644 /home/bios/driver/device/* 2>/dev/null || true
restorecon -Rv /home/bios/driver/device/ 2>/dev/null || true
echo "固件安装完成"
EOF

    # 4. 安装 CANN
    log_info "步骤 4/7: 安装 CANN"
    ssh "root@${TARGET_HOST}" << 'EOF'
set -e
# 创建符号链接
ln -sf /usr/local/Ascend/cann-9.0.0-beta.2 /usr/local/Ascend/cann 2>/dev/null || true
ln -sf /usr/local/Ascend/cann/aarch64-linux/bin /usr/local/Ascend/cann/bin 2>/dev/null || true
echo "CANN 安装完成"
EOF

    # 5. 配置模块
    log_info "步骤 5/7: 配置模块"
    ssh "root@${TARGET_HOST}" << 'EOF'
set -e
# 配置模块自动加载
cat > /etc/modules-load.d/ascend.conf << 'MODULEEOF'
mdev
drv_vascend
MODULEEOF

# 加载模块
modprobe mdev 2>/dev/null || true
modprobe drv_vascend 2>/dev/null || true
echo "模块配置完成"
EOF

    # 6. 配置环境变量
    log_info "步骤 6/7: 配置环境变量"
    ssh "root@${TARGET_HOST}" << 'EOF'
set -e
# 全局环境变量
cat > /etc/profile.d/ascend-cann.sh << 'ENVEOF'
export ASCEND_INSTALL_PATH=/usr/local/Ascend
export ASCEND_TOOLKIT_HOME=/usr/local/Ascend/cann
export PATH=$PATH:/usr/local/Ascend/cann/bin:/usr/local/Ascend/cann/compiler/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Ascend/cann/lib64
export PYTHONPATH=$PYTHONPATH:/usr/local/Ascend/cann/python/site-packages
ENVEOF

# root 环境变量
echo "source /usr/local/Ascend/cann/set_env.sh" >> /root/.bashrc 2>/dev/null || true

chmod 644 /etc/profile.d/ascend-cann.sh
echo "环境变量配置完成"
EOF

    # 7. 验证
    log_info "步骤 7/7: 验证安装"
    ssh "root@${TARGET_HOST}" << 'EOF'
set -e
sleep 30

echo "=== 设备文件 ==="
ls -la /dev/davinci* 2>/dev/null || echo "无设备文件"

echo ""
echo "=== npu-smi ==="
source /usr/local/Ascend/cann/set_env.sh 2>/dev/null || true
which npu-smi && npu-smi info || echo "npu-smi 不可用"

echo ""
echo "=== 版本信息 ==="
cat /usr/local/Ascend/version.info 2>/dev/null || echo "无版本信息"
EOF

    log_info "远程安装完成"
}

# 主函数
main() {
    # 解析参数
    if [ $# -lt 1 ]; then
        show_help
        exit 1
    fi
    
    TARGET_HOST="$1"
    SSH_PASSWORD="$2"
    
    log_info "=========================================="
    log_info "Huawei Ascend 910B NPU 自动安装"
    log_info "=========================================="
    log_info "目标服务器: $TARGET_HOST"
    log_info "项目目录: $PROJECT_DIR"
    log_info ""
    
    # 检查前置条件
    check_prerequisites
    
    # 选择安装方式
    if command -v ansible-playbook &> /dev/null && [ -n "$SSH_PASSWORD" ]; then
        log_info "使用 Ansible 方式安装"
        sync_files
        run_ansible
    else
        log_info "使用远程脚本方式安装"
        remote_install
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "安装完成!"
    log_info "=========================================="
    log_info ""
    log_info "请执行以下命令重启系统并验证:"
    log_info "  ssh root@$TARGET_HOST 'reboot'"
    log_info "  # 等待 2 分钟后"
    log_info "  ssh root@$TARGET_HOST 'npu-smi info'"
    log_info ""
}

# 运行主函数
main "$@"