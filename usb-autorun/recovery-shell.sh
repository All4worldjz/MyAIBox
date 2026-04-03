#!/bin/bash
# KSC AIBox 系统恢复 Shell 脚本
# 纯Shell版本，不依赖Ansible
# 版本: 1.0.0

set -e

# ================================================
# 全局变量
# ================================================
SCRIPT_NAME="KSC AIBox Recovery Shell Script"
VERSION="1.0.0"

# 默认配置
KSC_AIBOX_ROOT="/ksc_aibox"
BACKUP_ROOT="/backup"
LOG_FILE="/var/log/ksc-aibox-recovery.log"
STEPS="all"

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
        STEP)  echo -e "${BLUE}[STEP]${NC} $msg" ;;
    esac
}

# ================================================
# 目录结构定义（兼容bash 3.x+）
# ================================================
# 使用普通数组，在函数中动态生成路径

# 一级目录列表
KSC_DIR_NAMES="apps data models k3s docker logs scripts config tmp"

# apps子目录列表
APPS_DIR_NAMES="ascend vllm ai-service custom"

# data子目录列表
DATA_DIR_NAMES="mysql postgres redis milvus neo4j minio"

# models子目录列表
MODELS_DIR_NAMES="llm embedding rerank vl mineru"

# backup子目录列表
BACKUP_DIR_NAMES="system application archive logs"

# ================================================
# 步骤1: 创建目录结构
# ================================================
step_create_dirs() {
    log STEP "步骤1: 创建目录结构"

    log INFO "创建ksc_aibox主目录..."
    mkdir -p "$KSC_AIBOX_ROOT"
    chmod 0755 "$KSC_AIBOX_ROOT"

    # 创建一级子目录
    for name in $KSC_DIR_NAMES; do
        dir="$KSC_AIBOX_ROOT/$name"
        mkdir -p "$dir"
        chmod 0755 "$dir"
        log INFO "创建: $dir"
    done

    # 创建apps子目录
    for name in $APPS_DIR_NAMES; do
        dir="$KSC_AIBOX_ROOT/apps/$name"
        mkdir -p "$dir"
        chmod 0755 "$dir"
        log INFO "创建: $dir"
    done
    # apps额外子目录
    mkdir -p "$KSC_AIBOX_ROOT/apps/vllm/config"
    mkdir -p "$KSC_AIBOX_ROOT/apps/vllm/logs"
    mkdir -p "$KSC_AIBOX_ROOT/apps/vllm/scripts"
    mkdir -p "$KSC_AIBOX_ROOT/apps/ai-service/workspace"
    mkdir -p "$KSC_AIBOX_ROOT/apps/ai-service/config"
    mkdir -p "$KSC_AIBOX_ROOT/apps/ai-service/logs"

    # 创建data子目录
    for name in $DATA_DIR_NAMES; do
        dir="$KSC_AIBOX_ROOT/data/$name"
        mkdir -p "$dir"
        chmod 0755 "$dir"
        log INFO "创建: $dir"
    done

    # 创建models子目录
    for name in $MODELS_DIR_NAMES; do
        dir="$KSC_AIBOX_ROOT/models/$name"
        mkdir -p "$dir"
        chmod 0755 "$dir"
        log INFO "创建: $dir"
    done

    # 创建k3s子目录
    mkdir -p "$KSC_AIBOX_ROOT/k3s/data"
    mkdir -p "$KSC_AIBOX_ROOT/k3s/storage"
    mkdir -p "$KSC_AIBOX_ROOT/k3s/manifests"
    mkdir -p "$KSC_AIBOX_ROOT/k3s/helm"
    mkdir -p "$KSC_AIBOX_ROOT/k3s/kubeconfig"

    # 创建docker子目录
    mkdir -p "$KSC_AIBOX_ROOT/docker/data"
    mkdir -p "$KSC_AIBOX_ROOT/docker/compose"
    mkdir -p "$KSC_AIBOX_ROOT/docker/config"
    mkdir -p "$KSC_AIBOX_ROOT/docker/scripts"

    # 创建logs子目录
    mkdir -p "$KSC_AIBOX_ROOT/logs/vllm"
    mkdir -p "$KSC_AIBOX_ROOT/logs/ai-service"
    mkdir -p "$KSC_AIBOX_ROOT/logs/k3s"
    mkdir -p "$KSC_AIBOX_ROOT/logs/mysql"
    mkdir -p "$KSC_AIBOX_ROOT/logs/postgres"
    mkdir -p "$KSC_AIBOX_ROOT/logs/redis"
    mkdir -p "$KSC_AIBOX_ROOT/logs/milvus"
    mkdir -p "$KSC_AIBOX_ROOT/logs/neo4j"
    mkdir -p "$KSC_AIBOX_ROOT/logs/system"

    # 创建scripts子目录
    mkdir -p "$KSC_AIBOX_ROOT/scripts/install"
    mkdir -p "$KSC_AIBOX_ROOT/scripts/backup"
    mkdir -p "$KSC_AIBOX_ROOT/scripts/restore"
    mkdir -p "$KSC_AIBOX_ROOT/scripts/monitor"
    mkdir -p "$KSC_AIBOX_ROOT/scripts/maintenance"

    # 创建config子目录
    mkdir -p "$KSC_AIBOX_ROOT/config/ansible"
    mkdir -p "$KSC_AIBOX_ROOT/config/env"
    mkdir -p "$KSC_AIBOX_ROOT/config/secrets"
    mkdir -p "$KSC_AIBOX_ROOT/config/systemd"

    # 创建backup目录
    log INFO "创建backup目录..."
    mkdir -p "$BACKUP_ROOT"
    chmod 0755 "$BACKUP_ROOT"

    for name in $BACKUP_DIR_NAMES; do
        dir="$BACKUP_ROOT/$name"
        mkdir -p "$dir"
        chmod 0755 "$dir"
        log INFO "创建: $dir"
    done
    
    # 创建backup详细子目录
    mkdir -p "$BACKUP_ROOT/system/root_fs"
    mkdir -p "$BACKUP_ROOT/system/config/etc"
    mkdir -p "$BACKUP_ROOT/system/config/fstab"
    mkdir -p "$BACKUP_ROOT/system/config/systemd"
    mkdir -p "$BACKUP_ROOT/system/packages"
    mkdir -p "$BACKUP_ROOT/application/ksc_aibox"
    mkdir -p "$BACKUP_ROOT/application/databases/mysql"
    mkdir -p "$BACKUP_ROOT/application/databases/postgres"
    mkdir -p "$BACKUP_ROOT/application/databases/milvus"
    mkdir -p "$BACKUP_ROOT/application/databases/neo4j"
    mkdir -p "$BACKUP_ROOT/application/models"
    mkdir -p "$BACKUP_ROOT/application/docker"
    mkdir -p "$BACKUP_ROOT/archive/monthly"
    mkdir -p "$BACKUP_ROOT/archive/yearly"
    
    log INFO "目录结构创建完成"
}

# ================================================
# 步骤2: 系统优化
# ================================================
step_system_optimization() {
    log STEP "步骤2: 系统优化"
    
    # 设置主机名
    log INFO "设置主机名..."
    hostnamectl set-hostname "ksc-aibox-node01" 2>/dev/null || true
    
    # 更新hosts文件
    log INFO "更新/etc/hosts..."
    if ! grep -q "ksc-aibox-node01" /etc/hosts; then
        sed -i 's/^127\.0\.0\.1/127.0.0.1   localhost localhost.localdomain ksc-aibox-node01/' /etc/hosts
    fi
    
    # 创建sysctl优化配置
    log INFO "配置内核参数..."
    cat > /etc/sysctl.d/99-ksc-aibox-optimization.conf << 'EOF'
# KSC AIBox 系统优化配置

# === 网络优化 ===
net.core.somaxconn = 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_max_tw_buckets = 65535

# === 内存优化 ===
vm.swappiness = 10
vm.dirty_ratio = 40
vm.dirty_background_ratio = 10
vm.overcommit_memory = 1
vm.max_map_count = 262144
vm.min_free_kbytes = 1048576

# === 文件系统 ===
fs.file-max = 2097152
fs.nr_open = 2097152
fs.aio-max-nr = 1048576

# === 内核信号 ===
kernel.sem = 250 32000 100 1024
kernel.pid_max = 4194304

# === 共享内存 ===
kernel.shmmax = 68719476736
kernel.shmall = 4294967296

# === 鲲鹏网络优化 ===
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.optmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 30000
EOF
    
    # 应用sysctl配置
    sysctl -p /etc/sysctl.d/99-ksc-aibox-optimization.conf 2>/dev/null || true
    
    # 配置资源限制
    log INFO "配置系统资源限制..."
    cat > /etc/security/limits.d/99-ksc-aibox.conf << 'EOF'
# KSC AIBox 资源限制配置
*    soft    nofile    655350
*    hard    nofile    655350
root soft    nofile    655350
root hard    nofile    655350
*    soft    nproc     655350
*    hard    nproc     655350
root soft    nproc     655350
root hard    nproc     655350
*    soft    memlock   unlimited
*    hard    memlock   unlimited
root soft    memlock   unlimited
root hard    memlock   unlimited
*    soft    stack     unlimited
*    hard    stack     unlimited
EOF
    
    # 禁用不必要的服务
    log INFO "禁用不必要的服务..."
    for svc in bluetooth.service cups.service avahi-daemon.service ModemManager.service; do
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
    done
    
    # 配置tuned性能模式
    log INFO "配置性能模式..."
    if command -v tuned-adm &> /dev/null; then
        tuned-adm profile accelerator-performance 2>/dev/null || true
    fi
    
    # SSH安全加固
    log INFO "SSH安全加固..."
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' /etc/ssh/sshd_config 2>/dev/null || true
    systemctl reload sshd 2>/dev/null || true
    
    # 配置防火墙
    log INFO "配置防火墙..."
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --set-default-zone=public 2>/dev/null || true
        # 开放必要端口
        for port in 6443/tcp 9000/tcp 9001/tcp 9090/tcp 3000/tcp 3306/tcp 5432/tcp 6379/tcp 19530/tcp 7687/tcp; do
            firewall-cmd --permanent --add-port="$port" 2>/dev/null || true
        done
        firewall-cmd --reload 2>/dev/null || true
    fi
    
    log INFO "系统优化完成"
}

# ================================================
# 步骤3: NPU配置
# ================================================
step_npu_config() {
    log STEP "步骤3: NPU配置"
    
    # 检查NPU驱动是否存在
    if ! command -v npu-smi &> /dev/null; then
        log WARN "NPU驱动未安装，跳过NPU配置"
        return 0
    fi
    
    # 配置HugePages
    log INFO "配置HugePages..."
    current_hugepages=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
    if [ "$current_hugepages" -lt 128000 ]; then
        echo 128000 > /proc/sys/vm/nr_hugepages
        echo "vm.nr_hugepages = 128000" >> /etc/sysctl.d/99-ksc-aibox-hugepages.conf
    fi
    
    # 创建NPU设备权限配置
    log INFO "配置NPU设备权限..."
    cat > /etc/udev/rules.d/99-npu.rules << 'EOF'
# NPU设备权限配置
KERNEL=="davinci[0-9]*", MODE="0666"
KERNEL=="davinci_manager", MODE="0666"
KERNEL=="devmm_svm", MODE="0666"
KERNEL=="hisi_hdc", MODE="0666"
EOF
    
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    
    # 创建NPU环境变量配置
    log INFO "配置NPU环境变量..."
    cat > /etc/profile.d/ksc-aibox-npu.sh << 'EOF'
# KSC AIBox NPU环境变量
export ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit
export ASCEND_HOME_PATH=/usr/local/Ascend
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:$LD_LIBRARY_PATH
export PATH=/usr/local/Ascend/bin:$PATH
export ASCEND_VISIBLE_DEVICES=0,1,2,3
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
EOF
    
    # 创建NUMA绑定脚本
    log INFO "创建NPU NUMA绑定脚本..."
    cat > "$KSC_AIBOX_ROOT/scripts/maintenance/npu-numa-bind.sh" << 'EOF'
#!/bin/bash
# NPU NUMA亲和性绑定脚本
NPU_ID=$1
shift
case $NPU_ID in
    0|1) NUMA_NODE=0 ;;
    2|3) NUMA_NODE=1 ;;
    *) echo "Invalid NPU ID: $NPU_ID"; exit 1 ;;
esac
echo "Binding NPU $NPU_ID to NUMA node $NUMA_NODE"
numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE "$@"
EOF
    chmod +x "$KSC_AIBOX_ROOT/scripts/maintenance/npu-numa-bind.sh"
    
    # 检查NPU状态
    log INFO "检查NPU状态..."
    npu-smi info -l 2>/dev/null >> "$LOG_FILE" || true
    
    log INFO "NPU配置完成"
}

# ================================================
# 步骤4: Docker配置
# ================================================
step_docker_config() {
    log STEP "步骤4: Docker配置"
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        log WARN "Docker未安装，跳过Docker配置"
        return 0
    fi
    
    # 创建Docker配置目录
    mkdir -p /etc/docker
    mkdir -p /etc/systemd/system/docker.service.d
    
    # 配置Docker daemon
    log INFO "配置Docker daemon..."
    cat > /etc/docker/daemon.json << EOF
{
    "data-root": "$KSC_AIBOX_ROOT/docker/data",
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 65535,
            "Soft": 65535
        }
    }
}
EOF
    
    # 创建Docker systemd override
    cat > /etc/systemd/system/docker.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --data-root=$KSC_AIBOX_ROOT/docker/data
EOF
    
    # 重载systemd
    systemctl daemon-reload
    
    # 重启Docker服务
    log INFO "重启Docker服务..."
    systemctl restart docker
    systemctl enable docker
    
    # 等待Docker就绪
    sleep 5
    
    # 验证Docker配置
    if docker info &> /dev/null; then
        log INFO "Docker配置成功"
        docker info | grep "Docker Root Dir" >> "$LOG_FILE"
    else
        log WARN "Docker配置可能存在问题"
    fi
}

# ================================================
# 步骤5: 创建监控脚本
# ================================================
step_create_scripts() {
    log STEP "步骤5: 创建监控和维护脚本"
    
    # 创建健康检查脚本
    log INFO "创建健康检查脚本..."
    cat > "$KSC_AIBOX_ROOT/scripts/monitor/system-health-check.sh" << 'EOF'
#!/bin/bash
# KSC AIBox 系统健康检查脚本
LOG_FILE="/ksc_aibox/logs/health-check.log"
STATUS_FILE="/ksc_aibox/config/system-status.json"

echo "=== Health Check at $(date) ===" >> $LOG_FILE

# NPU健康检查
npu_status="OK"
if command -v npu-smi &> /dev/null; then
    for i in 0 1 2 3; do
        health=$(npu-smi info -t health -i $i -c 0 2>/dev/null | grep "Health Status" | awk '{print $NF}')
        if [ "$health" != "OK" ]; then
            npu_status="WARNING"
            echo "[WARN] NPU$i health: $health" >> $LOG_FILE
        fi
    done
fi

# 磁盘健康检查
disk_status="PASSED"
if command -v smartctl &> /dev/null; then
    disk_status=$(smartctl -H /dev/nvme0n1 2>/dev/null | grep "SMART overall" | awk '{print $NF}')
fi

# 内存检查
mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
mem_percent=$((mem_available * 100 / mem_total))

# Docker服务检查
docker_status=$(systemctl is-active docker 2>/dev/null || echo "unknown")

# 生成状态JSON
cat > $STATUS_FILE << JSONEOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "npu_status": "$npu_status",
    "disk_status": "$disk_status",
    "memory_percent": $mem_percent,
    "docker_status": "$docker_status",
    "system_load": "$(cat /proc/loadavg | awk '{print $1}')"
}
JSONEOF

echo "Health check completed" >> $LOG_FILE
EOF
    chmod +x "$KSC_AIBOX_ROOT/scripts/monitor/system-health-check.sh"
    
    # 创建自愈脚本
    log INFO "创建自愈脚本..."
    cat > "$KSC_AIBOX_ROOT/scripts/maintenance/self-healing.sh" << 'EOF'
#!/bin/bash
# KSC AIBox 自愈脚本
LOG_FILE="/ksc_aibox/logs/self-healing.log"

log() {
    echo "[HEALING] $(date): $1" >> $LOG_FILE
}

log "Starting self-healing check..."

# Docker服务自愈
if [ "$(systemctl is-active docker 2>/dev/null)" != "active" ]; then
    log "Docker service not active, attempting restart..."
    systemctl restart docker
fi

# 时间同步自愈
if command -v chronyc &> /dev/null; then
    chronyc makestep >> $LOG_FILE 2>/dev/null
fi

log "Self-healing check completed"
EOF
    chmod +x "$KSC_AIBOX_ROOT/scripts/maintenance/self-healing.sh"
    
    # 创建快速恢复脚本
    log INFO "创建快速恢复脚本..."
    cat > "$KSC_AIBOX_ROOT/scripts/maintenance/quick-recovery.sh" << 'EOF'
#!/bin/bash
# KSC AIBox 一键恢复脚本
set -e
LOG_FILE="/ksc_aibox/logs/recovery.log"

log() {
    echo "[RECOVERY] $(date): $1" >> $LOG_FILE
    echo "$1"
}

log "Starting quick recovery..."

# 重启关键服务
log "Restarting critical services..."
systemctl restart docker 2>/dev/null || true
systemctl restart sshd 2>/dev/null || true
systemctl restart firewalld 2>/dev/null || true
systemctl restart chronyd 2>/dev/null || true

# 清理Docker资源
log "Cleaning Docker resources..."
docker system prune -f >> $LOG_FILE 2>/dev/null || true

# 同步时间
log "Syncing time..."
chronyc makestep >> $LOG_FILE 2>/dev/null || true

log "Quick recovery completed!"
EOF
    chmod +x "$KSC_AIBOX_ROOT/scripts/maintenance/quick-recovery.sh"
    
    # 创建systemd服务
    log INFO "创建健康检查服务..."
    cat > /etc/systemd/system/ksc-aibox-health-check.service << 'EOF'
[Unit]
Description=KSC AIBox Health Check Service
After=network.target

[Service]
Type=oneshot
ExecStart=/ksc_aibox/scripts/monitor/system-health-check.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    cat > /etc/systemd/system/ksc-aibox-health-check.timer << 'EOF'
[Unit]
Description=KSC AIBox Health Check Timer

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    systemctl daemon-reload
    systemctl enable ksc-aibox-health-check.timer 2>/dev/null || true
    systemctl start ksc-aibox-health-check.timer 2>/dev/null || true
    
    log INFO "监控脚本创建完成"
}

# ================================================
# 步骤6: 验证
# ================================================
step_verify() {
    log STEP "步骤6: 验证配置"
    
    log INFO "验证目录结构..."
    if [ -d "$KSC_AIBOX_ROOT" ] && [ -d "$BACKUP_ROOT" ]; then
        log INFO "✅ 目录结构正常"
    else
        log ERROR "❌ 目录结构异常"
    fi
    
    log INFO "验证内核参数..."
    local somaxconn=$(sysctl -n net.core.somaxconn 2>/dev/null || echo "unknown")
    local max_map_count=$(sysctl -n vm.max_map_count 2>/dev/null || echo "unknown")
    log INFO "somaxconn=$somaxconn, max_map_count=$max_map_count"
    
    log INFO "验证HugePages..."
    local hugepages=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
    log INFO "HugePages_Total=$hugepages"
    
    log INFO "验证Docker..."
    if systemctl is-active docker &> /dev/null; then
        log INFO "✅ Docker服务正常"
        docker info 2>/dev/null | grep "Docker Root Dir" | head -1 >> "$LOG_FILE"
    else
        log WARN "⚠️ Docker服务未运行"
    fi
    
    log INFO "验证NPU..."
    if command -v npu-smi &> /dev/null; then
        npu-smi info -l 2>/dev/null | head -5 >> "$LOG_FILE"
        log INFO "✅ NPU驱动已安装"
    else
        log WARN "⚠️ NPU驱动未安装"
    fi
    
    log INFO "验证防火墙..."
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --list-ports 2>/dev/null >> "$LOG_FILE"
        log INFO "✅ 防火墙配置正常"
    fi
    
    # 创建版本信息文件
    log INFO "创建版本信息文件..."
    cat > "$KSC_AIBOX_ROOT/VERSION" << EOF
KSC AIBox 版本信息
==================
版本: $VERSION
恢复时间: $(date '+%Y-%m-%d %H:%M:%S')
主机名: $(hostname)

系统信息:
- 操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- 内核: $(uname -r)
- 架构: $(uname -m)

目录结构:
- 应用目录: $KSC_AIBOX_ROOT/apps
- 数据目录: $KSC_AIBOX_ROOT/data
- 模型目录: $KSC_AIBOX_ROOT/models
- 备份目录: $BACKUP_ROOT
EOF
    
    log INFO "验证完成"
}

# ================================================
# 主函数
# ================================================
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --root)
                KSC_AIBOX_ROOT="$2"
                shift 2
                ;;
            --backup)
                BACKUP_ROOT="$2"
                shift 2
                ;;
            --steps)
                STEPS="$2"
                shift 2
                ;;
            --log)
                LOG_FILE="$2"
                shift 2
                ;;
            --help|-h)
                echo "$SCRIPT_NAME v$VERSION"
                echo ""
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --root      应用根目录 (默认: /ksc_aibox)"
                echo "  --backup    备份根目录 (默认: /backup)"
                echo "  --steps     执行步骤 (默认: all)"
                echo "              可选: dirs,system,npu,docker,scripts,verify"
                echo "  --log       日志文件路径"
                echo "  --help      显示帮助"
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
    log INFO "$SCRIPT_NAME v$VERSION"
    log INFO "=========================================="
    log INFO "应用目录: $KSC_AIBOX_ROOT"
    log INFO "备份目录: $BACKUP_ROOT"
    log INFO "执行步骤: $STEPS"
    
    # 执行步骤
    if [[ "$STEPS" == "all" ]]; then
        step_create_dirs
        step_system_optimization
        step_npu_config
        step_docker_config
        step_create_scripts
        step_verify
    else
        # 按指定步骤执行
        IFS=',' read -ra STEP_ARRAY <<< "$STEPS"
        for step in "${STEP_ARRAY[@]}"; do
            case $step in
                dirs)    step_create_dirs ;;
                system)  step_system_optimization ;;
                npu)     step_npu_config ;;
                docker)  step_docker_config ;;
                scripts) step_create_scripts ;;
                verify)  step_verify ;;
                *)       log WARN "未知步骤: $step" ;;
            esac
        done
    fi
    
    log INFO "=========================================="
    log INFO "系统恢复完成!"
    log INFO "=========================================="
    log INFO "日志文件: $LOG_FILE"
    log INFO "版本文件: $KSC_AIBOX_ROOT/VERSION"
    
    exit 0
}

# 执行主函数
main "$@"