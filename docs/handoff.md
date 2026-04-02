# KSC AIBox 项目交接文档 (Handoff Document)

> 本文档用于项目交接，确保任何AI工具或人类工程师都能接手完成一体机的初始化安装和配置。

## 项目元信息

| 项目 | 值 |
|------|-----|
| **项目名称** | KSC AIBox - 金山政务AI一体机部署 |
| **版本** | 1.0.0 |
| **创建日期** | 2026-04-03 |
| **当前状态** | 系统优化完成，待安装技术底座 |
| **Git分支** | dev |
| **Ansible版本** | 2.x (Python 3.11) |

## 目标服务器配置

### 硬件配置

```
型号: OEM Rack Server
CPU: 华为鲲鹏920 5220, 64核 (2插座×32核)
内存: 250GB DDR4 (NUMA节点0: 131GB, NUMA节点1: 131GB)
NPU: 华为昇腾910B4-1 × 4张, 每张64GB HBM, 驱动版本25.2.3
存储: Samsung 990 PRO 4TB NVMe SSD
网络: 华为HNS GE/10GE/25GE网卡 (6端口)
管理: 华为iBMC (Hi171x)
```

### 软件配置

```
操作系统: openEuler 24.03 LTS-SP1
内核: 6.6.0-72.0.0.76.oe2403sp1.aarch64
架构: ARM64 (aarch64)
SELinux: Enforcing
Docker: 18.09.0
```

### 网络配置

```
IP地址: 10.212.128.192/22
网关: 10.212.128.1
DNS: 10.210.1.40, 10.210.2.40
活动网卡: enp125s0f1
```

### NPU拓扑

```
NUMA节点0 (CPU 0-31):
├── NPU0 (PCIe: 01:00.0) - PHB连接NPU1
└── NPU1 (PCIe: 02:00.0) - PHB连接NPU0

NUMA节点1 (CPU 32-63):
├── NPU2 (PCIe: 81:00.0) - PHB连接NPU3
└── NPU3 (PCIe: 82:00.0) - PHB连接NPU2

跨NUMA通信: SYS (性能较低，避免使用)
```

## 已完成工作

### 阶段1: 基础准备 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| SSH免密登录 | ✅ | root@10.212.128.192 |
| 硬件检查 | ✅ | CPU/内存/NPU/存储正常 |
| NPU驱动验证 | ✅ | 4张NPU健康状态OK |
| Ansible项目结构 | ✅ | 完整目录结构已创建 |

### 阶段2: 目录结构 ✅

```
/ksc_aibox/                    # 主工作分区 (361GB可用)
├── apps/                      # 应用程序
│   └── ai-service/            # AI服务应用
├── data/                      # 数据存储 (预留)
├── docker/data/               # Docker数据目录 (已迁移)
├── models/                    # 模型文件 (333GB)
│   ├── llm/                   # 大语言模型
│   ├── embedding/             # 嵌入模型
│   ├── vl/                    # 视觉语言模型
│   └── mineru/                # MinerU模型
├── k3s/                       # K3s数据 (预留)
├── logs/                      # 日志目录
├── scripts/                   # 运维脚本
│   ├── install/
│   ├── backup/
│   ├── restore/
│   ├── monitor/
│   └── maintenance/
├── config/                    # 配置文件
│   ├── baseline/              # 完整性基线
│   ├── npu-numa-config.yaml   # NPU NUMA配置
│   └── system-status.json     # 系统状态
└── VERSION                    # 版本信息

/backup/                       # 备份分区
├── system/
├── application/
└── archive/
```

### 阶段3: 数据迁移 ✅

| 数据类型 | 原位置 | 新位置 | 大小 |
|----------|--------|--------|------|
| Docker数据 | /var/lib/docker | /ksc_aibox/docker/data | 24GB |
| 模型文件 | /home/aimodel | /ksc_aibox/models | 333GB |
| AI服务 | /opt/ai-service | /ksc_aibox/apps/ai-service | 3.5GB |

### 阶段4: 系统优化 ✅

#### 内核参数优化

```bash
# 网络优化
net.core.somaxconn = 65535
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# 内存优化
vm.swappiness = 10
vm.max_map_count = 262144
vm.overcommit_memory = 1

# 文件系统
fs.file-max = 2097152
```

#### HugePages配置

```bash
vm.nr_hugepages = 122949  # 约240GB
```

#### 服务精简

```bash
# 已禁用服务
- bluetooth.service
- cups.service
- avahi-daemon.service
- ModemManager.service

# 已启用服务
- docker.service
- sshd.service
- firewalld.service
- tuned.service (accelerator-performance)
- chronyd.service
- rngd.service
```

### 阶段5: HCI架构优化 ✅

#### 健康检查服务

```bash
# 每5分钟执行
/ksc_aibox/scripts/monitor/system-health-check.sh

# 输出状态文件
/ksc_aibox/config/system-status.json
```

#### 自愈服务

```bash
# 每10分钟执行
/ksc_aibox/scripts/maintenance/self-healing.sh

# 功能:
- Docker服务自愈
- 网络服务自愈
- 时间同步自愈
```

#### 安全审计

```bash
# 审计规则 (15条)
- NPU设备访问监控
- 配置文件修改监控
- 用户切换监控
- 时间修改监控
```

## 待完成工作

### 阶段6: 技术底座安装 (待执行)

| 组件 | 状态 | 优先级 |
|------|------|--------|
| K3s | ❌ 待安装 | P0 |
| MySQL | ❌ 待安装 | P1 |
| PostgreSQL | ❌ 待安装 | P1 |
| Redis | ❌ 待安装 | P1 |
| Milvus | ❌ 待安装 | P2 |
| Neo4j | ❌ 待安装 | P2 |
| MinIO | ❌ 待安装 | P2 |

### 阶段7: 应用部署 (待执行)

| 应用 | 状态 | 优先级 |
|------|------|--------|
| vLLM | ⚠️ 容器存在配置错误 | P0 |
| AI Service | ✅ 运行中 | P0 |
| Prometheus | ❌ 待安装 | P2 |
| Grafana | ❌ 待安装 | P2 |

### 阶段8: 测试验证 (待执行)

| 测试类型 | 状态 |
|----------|------|
| 冒烟测试 | ❌ 待执行 |
| 回归测试 | ❌ 待执行 |

## 关键配置文件位置

### 本地 (控制机)

```
/Users/whoami2028/Workshop/GITREPO/MyAIBox/
├── ansible/
│   ├── ansible.cfg           # Ansible配置
│   ├── inventory/hosts       # 主机清单
│   ├── group_vars/all.yml    # 全局变量
│   └── playbooks/            # Playbook剧本
└── README.md                 # 项目说明
```

### 远程服务器

```
/etc/sysctl.d/99-ksc-aibox-optimization.conf    # 内核参数
/etc/sysctl.d/99-ksc-aibox-hugepages.conf       # HugePages
/etc/security/limits.d/99-ksc-aibox.conf        # 资源限制
/etc/udev/rules.d/99-npu.rules                  # NPU设备权限
/etc/profile.d/ksc-aibox-npu.sh                 # NPU环境变量
/etc/docker/daemon.json                         # Docker配置
/etc/audit/rules.d/ksc-aibox.rules              # 审计规则
/etc/systemd/system/ksc-aibox-*.service         # HCI服务
/ksc_aibox/config/                              # 配置目录
/ksc_aibox/scripts/                             # 脚本目录
```

## 快速命令参考

### 连接服务器

```bash
ssh root@10.212.128.192
```

### 执行Playbook

```bash
cd /Users/whoami2028/Workshop/GITREPO/MyAIBox/ansible
/Library/Frameworks/Python.framework/Versions/3.11/bin/ansible-playbook -i inventory/hosts playbooks/<playbook-name>.yml
```

### 检查系统状态

```bash
# 系统健康状态
cat /ksc_aibox/config/system-status.json

# NPU状态
npu-smi info -l

# 服务状态
systemctl status docker sshd firewalld

# HugePages
grep HugePages /proc/meminfo
```

### 故障恢复

```bash
# 一键恢复
/ksc_aibox/scripts/maintenance/quick-recovery.sh

# 收集诊断信息
/ksc_aibox/scripts/maintenance/collect-system-info.sh
```

## 注意事项

### SELinux

- 当前模式: Enforcing
- 如遇权限问题，检查SELinux上下文
- 不要轻易设置为Permissive或Disabled

### NPU使用

- 使用NPU0+1或NPU2+3配对以获得最佳性能
- 跨NUMA使用NPU会有性能损耗
- 容器设备映射使用 /dev/davinci0-3

### 内存管理

- HugePages已配置240GB
- 剩余内存约10GB用于系统
- 注意监控内存使用情况

### Docker

- 数据目录已迁移到/ksc_aibox/docker/data
- 使用overlay2存储驱动
- 日志限制: 100MB × 3文件

## 联系信息

- 项目仓库: /Users/whoami2028/Workshop/GITREPO/MyAIBox
- Git分支: dev
- 文档位置: /Users/whoami2028/Workshop/GITREPO/MyAIBox/docs/

---

*本文档由Qwen Code自动生成，最后更新: 2026-04-03*