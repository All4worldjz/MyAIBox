# QWEN.md - KSC AIBox 项目上下文

## 项目概述

**KSC AIBox** 是金山政务AI一体机的自动化部署项目，基于 HCI（超融合基础架构）和 Appliance 模式，实现"开箱即用"的产品形态。

### 核心信息

| 项目 | 详情 |
|------|------|
| **版本** | 1.0.0 (2026-04-03) / 2.0.0-docker (2026-04-09) |
| **分支** | dev |
| **目标系统** | openEuler 24.03 LTS-SP3 (ARM64) |
| **自动化引擎** | Ansible 2.x |
| **开发语言** | Bash / YAML (Ansible Playbooks) |

### 目标服务器硬件

- **CPU**: 华为鲲鹏920 5220, 64核 (2插座×32核)
- **内存**: 250GB DDR4 (NUMA节点0: 131GB, NUMA节点1: 131GB)
- **NPU**: 华为昇腾910B4-1 × 4张, 每张64GB HBM
- **存储**: Samsung 990 PRO 4TB NVMe SSD
- **网络**: 华为HNS GE/10GE/25GE (6端口)
- **管理**: 华为iBMC (Hi171x)

### 软件栈

- **操作系统**: openEuler 24.03 LTS-SP3
- **内核**: 6.6.0-144.0.0.130.oe2403sp3.aarch64
- **架构**: ARM64 (aarch64)
- **Docker**: 18.09.0.346 (openEuler 定制版)
- **NPU驱动**: 25.5.1
- **NPU固件**: 7.8.0.6.201 (待冷启动生效)
- **CANN**: 9.0.0-beta.2
- **容器编排**: Docker Compose (弃用K3s + Ceph RBD)

## 项目结构

```
MyAIBox/
├── ansible/                        # Ansible自动化配置（核心）
│   ├── ansible.cfg                 # Ansible配置文件
│   ├── inventory-npu.ini           # NPU服务器主机清单
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
│       ├── 05-system-upgrade-sp3.yml       # 系统升级到SP3
│       ├── 06-system-fixes.yml             # 系统修复
│       ├── 07-deploy-k3s-and-apps-npu-shared.yml  # K3s部署
│       └── 08-deploy-commercial-appliance-v2.yml  # 商业版部署
│
├── docker-compose/                 # Docker Compose编排
│   ├── docker-compose.yml          # 服务编排配置（27个容器）
│   ├── deploy-all.sh               # Docker一键部署脚本
│   └── nginx/                      # Nginx配置
│
├── docs/                           # 项目文档
│   ├── Agent.md                    # AI协作指南
│   ├── handoff.md                  # 项目交接文档
│   ├── SKILL.md                    # 技能经验文档
│   ├── SYSTEM-CONFIGURATION.md     # 系统配置文档
│   ├── memory-management-architecture.md  # 内存管理架构
│   ├── DOCKER-DEPLOYMENT-DESIGN.md # Docker部署设计
│   ├── DOCKER-DEPLOYMENT-GUIDE.md  # Docker部署指南
│   └── NPU-DRIVER-INSTALLATION.md  # NPU驱动安装
│
├── drivers/                        # NPU驱动和CANN工具链
│   ├── NPU-910B/                   # 昇腾910B驱动
│   └── ...                         # CANN OPS/AMCT/NNAL/Toolkit
│
├── scripts/                        # 本地执行脚本
│   ├── deploy.sh                   # 一键部署脚本（入口）
│   ├── sync-agent-skills.sh        # AI Agent技能同步脚本
│   ├── match-skills.py             # 技能场景匹配引擎
│   ├── install-npu.sh              # NPU安装脚本
│   ├── backup-npu.sh               # NPU备份脚本
│   └── ...                         # 其他工具脚本
│
├── src/
│   └── agent-skills/               # AI Agent技能定义（47个技能）
│       ├── ascend-npu-driver-install/
│       ├── ascendc-operator-dev/
│       ├── triton-operator-dev/
│       └── ...                     # 更多技能模块
│
├── examples/                       # 示例配置
├── usb-autorun/                    # USB自动运行配置
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

### Docker Compose部署

```bash
# Docker方式部署所有服务
cd docker-compose
./deploy-all.sh
```

### Ansible直接调用

```bash
cd ansible
ansible-playbook -i inventory/hosts playbooks/01-prepare-dirs.yml
ansible-playbook -i inventory-npu.ini playbooks/00-install-npu-driver.yml
```

### AI Agent技能同步

```bash
# 同步最新AI Agent技能
./scripts/sync-agent-skills.sh

# 检查是否有可用更新
./scripts/sync-agent-skills.sh --check

# 技能场景匹配
python3 scripts/match-skills.py "任务描述"
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
- NPU设备 (`davinci0-3`, 驱动版本 `25.5.1`)
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
- Docker Compose架构部署（27个容器）
- AI Agent Skills（47个技能）

### 待完成 ⏳

- NPU固件冷启动生效
- vLLM推理服务配置修复
- 监控系统部署 (Prometheus/Grafana)
- 冒烟测试与回归测试

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

## AI Agent技能体系（47个）

### 环境部署族 (5个)
- `ascend-docker` — Ascend NPU Docker容器创建
- `ascend-npu-driver-install` — NPU驱动端到端安装
- `cann-operator-env-config` — CANN环境配置
- `atc-model-converter` — ATC模型转换
- `hccl-test` — HCCL集合通信测试

### AscendC算子开发族 (12个)
- `ascendc-operator-dev` — 端到端算子开发编排器
- `ascendc-operator-design` — 算子需求分析与设计
- `ascendc-operator-code-gen` — 代码生成
- `ascendc-operator-compile-debug` — 编译调试
- `ascendc-operator-precision-eval` — 精度评估
- `ascendc-operator-performance-optim` — 性能优化
- 等...

### Triton算子开发族 (9个)
- `triton-operator-dev` — Triton算子全流程开发
- `triton-operator-design` — Triton算子设计
- `triton-operator-code-gen` — Triton代码生成
- 等...

### CATLASS算子开发族 (4个)
- `catlass-operator-dev` — CATLASS算子开发编排器
- 等...

### Megatron迁移族 (4个)
- `megatron-change-analyzer` — Megatron变更分析
- `megatron-migration-generator` — 迁移生成器
- 等...

### MindSpeed LLM测试族 (7个)
- `code-comprehension` — 代码理解
- `generate-unit-test` — 单元测试生成
- 等...

### NPU运维族 (6个)
- `npu-smi` — NPU设备管理命令参考
- `npu-adapter-reviewer` — GPU到NPU适配审查
- `ascend-inference-repos-copilot` — 推理生态问答
- 等...

### 通用工具族 (7个)
- `auto-bug-fixer` — 自动bug修复
- `python-refactoring` — Python代码重构
- `skill-auditor` — 技能安全审计
- 等...

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
- `06-*` — 系统修复
- `07-*` — K3s部署
- `08-*` — 商业版部署

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

## 架构演进

### v1.0.0 (2026-04-03)
- 初始版本
- 基于K3s + Ceph RBD架构

### v2.0.0-docker (2026-04-09)
- **弃用K3s + Ceph RBD**
- **改用Docker Compose + 本地存储**
- 部署时间从60分钟缩短至20分钟（⬇️ 67%）
- 内存占用减少约15GB（无K3s开销）
- 性能提升30%+（本地直连存储）
- 27个容器服务，五层网络隔离

## 相关文档

- `README.md` — 项目说明
- `docs/MULTI-AGENT-COMMAND-CENTER.md` — 🤖 **多AI协同指挥中枢（单一真相来源，首先读取）**
- `docs/handoff.md` — 项目交接文档 (已完成/待办事项)
- `docs/Agent.md` — AI工具协作指南
- `docs/SKILL.md` — 踩坑/排错/优化经验
- `docs/SYSTEM-CONFIGURATION.md` — 系统配置文档
- `docs/memory-management-architecture.md` — 内存管理架构
- `docs/DOCKER-DEPLOYMENT-GUIDE.md` — Docker部署操作手册
- `docs/AI-TOOLS-WORK-ALIGNMENT-REPORT.md` — AI工具工作历史对齐报告
- `CHANGELOG.md` — 变更日志
