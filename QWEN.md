# QWEN.md - KSC AIBox 项目上下文

## 项目概述

**KSC AIBox** 是金山政务AI一体机的自动化部署项目，基于 HCI（超融合基础架构）和 Appliance 模式，实现"开箱即用"的产品形态。

### 核心信息

| 项目 | 详情 |
|------|------|
| **版本** | 1.0.0 (2026-04-03) |
| **分支** | dev |
| **目标系统** | openEuler 24.03 LTS-SP1 (ARM64) |
| **自动化引擎** | Ansible 2.x |
| **开发语言** | Bash / YAML (Ansible Playbooks) |

### 目标服务器硬件

- **CPU**: 华为鲲鹏920 5220, 64核 (2插座×32核)
- **内存**: 250GB DDR4
- **NPU**: 华为昇腾910B4-1 × 4张, 每张64GB HBM
- **存储**: Samsung 990 PRO 4TB NVMe SSD
- **网络**: 华为HNS GE/10GE/25GE (6端口)

## 项目结构

```
MyAIBox/
├── ansible/                        # Ansible自动化配置（核心）
│   ├── ansible.cfg                 # Ansible配置文件
│   ├── inventory-npu.ini           # NPU服务器主机清单
│   ├── files/                      # Ansible文件资源
│   ├── group_vars/
│   │   └── all.yml                # 全局配置变量（路径/端口/NPU等）
│   └── playbooks/                  # Playbook剧本
│       ├── 00-install-npu-driver.yml       # NPU驱动安装
│       ├── 01-install-npu-full-stack.yml   # NPU全栈安装
│       ├── 01-prepare-dirs.yml             # 目录结构创建
│       ├── 02-install-vllm.yml             # vLLM推理服务安装
│       ├── 02-migrate-data.yml             # 数据迁移
│       ├── 03-system-optimization.yml      # 系统优化
│       ├── 04-health-check-and-best-practices.yml  # 健康检查
│       └── 05-system-upgrade-sp3.yml       # 系统升级到SP3
│
├── docs/                           # 项目文档
│   ├── Agent.md                    # AI协作指南
│   ├── handoff.md                  # 项目交接文档
│   ├── SKILL.md                    # 技能经验文档
│   ├── SYSTEM-CONFIGURATION.md     # 系统配置文档
│   ├── memory-management-architecture.md  # 内存管理架构
│   ├── NPU-ANSIBLE-INSTALLATION.md # NPU Ansible安装
│   ├── NPU-DRIVER-INSTALLATION.md  # NPU驱动安装
│   ├── NPU-INSTALLATION-CONTEXT.md # NPU安装上下文
│   ├── installation-guide-analysis.md    # 安装指南分析
│   └── temp-installation-guide/    # 临时安装指南
│
├── drivers/                        # NPU驱动和CANN工具链
│   ├── NPU-910B/                   # 昇腾910B驱动
│   ├── Ascend-cann-910-ops_*/      # CANN OPS
│   ├── Ascend-cann-amct_*/         # CANN AMCT
│   ├── Ascend-cann-nnal_*/         # CANN NNAL
│   └── Ascend-cann-toolkit_*/      # CANN Toolkit
│
├── examples/                       # 示例配置
│   ├── inventory-example
│   ├── group_vars-example.yml
│   └── docker-daemon-example.json
│
├── scripts/                        # 本地执行脚本
│   ├── deploy.sh                   # 一键部署脚本（入口）
│   ├── install-npu.sh              # NPU安装脚本
│   ├── backup-npu.sh               # NPU备份脚本
│   ├── copy-to-usb.sh              # USB拷贝脚本
│   ├── package-usb-autorun.sh      # USB自动运行打包
│   └── README.md
│
├── npu-backup/                     # NPU备份相关
├── usb-autorun/                    # USB自动运行配置
├── dist/                           # 分发文件
│
├── .editorconfig                   # 编辑器配置
├── .gitignore                      # Git忽略配置
├── CHANGELOG.md                    # 变更日志
├── VERSION                         # 版本信息
└── README.md                       # 项目说明
```

## 构建与运行

### 前置条件

- Python 3.11+
- Ansible 2.x
- SSH免密登录目标服务器

### 部署命令

```bash
# 一键部署（执行所有Playbook）
./scripts/deploy.sh all

# 分步执行
./scripts/deploy.sh 01    # 目录结构创建
./scripts/deploy.sh 02    # 数据迁移
./scripts/deploy.sh 03    # 系统优化
./scripts/deploy.sh 04    # 健康检查配置

# 检查模式（不实际执行）
./scripts/deploy.sh -c 03

# 详细输出模式
./scripts/deploy.sh -v 01

# 列出所有可用Playbook
./scripts/deploy.sh -l
```

### Ansible直接调用

```bash
cd ansible
ansible-playbook -i inventory/hosts playbooks/01-prepare-dirs.yml
ansible-playbook -i inventory-npu.ini playbooks/00-install-npu-driver.yml
```

## 配置说明

### 主机清单

- `ansible/inventory/hosts` — 标准部署主机清单
- `ansible/inventory-npu.ini` — NPU驱动安装专用主机清单

编辑 `ansible/inventory/hosts`:

```ini
[aibox]
10.212.128.192

[aibox:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### 全局变量

核心配置文件: `ansible/group_vars/all.yml`

包含以下配置:
- 目录路径 (`ksc_aibox_root: /ksc_aibox`)
- Docker配置
- NPU设备 (`davinci0-3`, 驱动版本 `25.2.3`)
- 服务端口
- 数据库参数
- 系统配置 (`zh_CN.UTF-8`, `Asia/Shanghai`)

## 部署状态

### 已完成 ✅

- SSH免密登录配置
- 服务器硬件检查
- NPU驱动状态验证
- 目录结构创建 (`/ksc_aibox`, `/backup`)
- Docker数据迁移
- 模型文件迁移
- 系统内核优化 (HugePages 240GB, tuned性能配置)
- 服务精简与安全加固
- NPU NUMA配置
- HCI健康检查服务 (每5分钟)
- 自愈服务 (每10分钟)
- 审计监控 (15条审计规则)

### 待完成 ⏳

- K3s容器编排平台
- MySQL/PostgreSQL/Redis/Milvus/Neo4j数据库
- vLLM推理服务
- 监控系统 (Prometheus/Grafana)
- 冒烟测试与回归测试

## 开发约定

### 编码风格

- **Playbook**: YAML格式, 2空格缩进
- **脚本**: Bash, 遵循 `.editorconfig` 配置
- **变量命名**: snake_case, 带前缀分组 (如 `ksc_aibox_dirs.*`, `npu_devices.*`)

### Playbook编号规则

Playbook采用数字前缀排序:
- `00-*` — NPU驱动安装
- `01-*` — 目录准备 / NPU全栈安装
- `02-*` — 数据迁移 / vLLM安装
- `03-*` — 系统优化
- `04-*` — 健康检查
- `05-*` — 系统升级

### Ansible配置要点

- `pipelining = True` — 提升执行效率
- `host_key_checking = False` — 跳过主机密钥检查
- `become_method = sudo` — 使用sudo提权
- SSH连接复用 (`ControlMaster`)

## HCI一体机特性

| 特性 | 说明 |
|------|------|
| **健康检查** | 每5分钟自动检查系统状态, JSON格式输出 |
| **自愈服务** | 每10分钟自动恢复故障服务 |
| **审计监控** | 关键操作和配置变更审计 |
| **完整性监控** | 配置文件SHA256基线校验 |
| **一键恢复** | 快速故障恢复脚本 |

## 关键路径

| 路径 | 用途 |
|------|------|
| `/ksc_aibox` | AI一体机根目录 |
| `/ksc_aibox/apps/` | 应用目录 (ascend/vllm/ai-service) |
| `/ksc_aibox/models/` | 模型文件 (llm/embedding/rerank/vl) |
| `/ksc_aibox/data/` | 数据目录 (mysql/postgres/redis/milvus/neo4j) |
| `/ksc_aibox/docker/` | Docker数据 |
| `/ksc_aibox/k3s/` | K3s相关 |
| `/ksc_aibox/logs/` | 日志 |
| `/backup` | 备份根目录 |

## 相关文档

- `README.md` — 项目说明
- `docs/handoff.md` — 项目交接文档 (已完成/待办事项)
- `docs/Agent.md` — AI工具协作指南
- `docs/SKILL.md` — 踩坑/排错/优化经验
- `docs/SYSTEM-CONFIGURATION.md` — 系统配置文档
- `docs/memory-management-architecture.md` — 内存管理架构
- `CHANGELOG.md` — 变更日志
