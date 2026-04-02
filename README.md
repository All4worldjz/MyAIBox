# KSC AIBox - 金山政务AI一体机部署项目

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/ksc/aibox)
[![License](https://img.shields.io/badge/license-Internal-red.svg)](LICENSE)
[![Ansible](https://img.shields.io/badge/ansible-2.x-green.svg)](https://www.ansible.com/)
[![Platform](https://img.shields.io/badge/platform-openEuler%2024.03-orange.svg)](https://openeuler.org/)

> 基于HCI（超融合基础架构）和Appliance模式的AI一体机自动化部署解决方案

## 📋 项目概述

本项目用于自动化部署和配置金山政务AI一体机，实现"开箱即用"的产品形态。

### 目标服务器

| 组件 | 规格 |
|------|------|
| **CPU** | 华为鲲鹏920 5220, 64核 (2插座×32核) |
| **内存** | 250GB DDR4 |
| **NPU** | 华为昇腾910B4-1 × 4张, 每张64GB HBM |
| **存储** | Samsung 990 PRO 4TB NVMe SSD |
| **网络** | 华为HNS GE/10GE/25GE (6端口) |
| **系统** | openEuler 24.03 LTS-SP1 (ARM64) |

## 🚀 快速开始

### 前置条件

- Python 3.11+
- Ansible 2.x
- SSH免密登录配置完成

### 一键部署

```bash
# 克隆项目
git clone <repository-url>
cd MyAIBox

# 执行部署
./scripts/deploy.sh all
```

### 分步执行

```bash
# 1. 目录结构创建
./scripts/deploy.sh 01

# 2. 数据迁移
./scripts/deploy.sh 02

# 3. 系统优化
./scripts/deploy.sh 03

# 4. 健康检查配置
./scripts/deploy.sh 04
```

## 📁 项目结构

```
MyAIBox/
├── ansible/                    # Ansible自动化配置
│   ├── ansible.cfg             # Ansible配置文件
│   ├── inventory/              # 主机清单
│   │   └── hosts               # 目标服务器定义
│   ├── group_vars/             # 全局变量
│   │   └── all.yml             # 通用配置变量
│   ├── playbooks/              # Playbook剧本
│   │   ├── 01-prepare-dirs.yml
│   │   ├── 02-migrate-data.yml
│   │   ├── 03-system-optimization.yml
│   │   └── 04-health-check-and-best-practices.yml
│   └── roles/                  # Ansible角色 (预留)
│
├── docs/                       # 项目文档
│   ├── handoff.md              # 项目交接文档
│   ├── Agent.md                # AI协作指南
│   └── SKILL.md                # 技能经验文档
│
├── examples/                   # 示例配置
│   ├── inventory-example
│   ├── group_vars-example.yml
│   └── docker-daemon-example.json
│
├── scripts/                    # 本地执行脚本
│   ├── deploy.sh               # 一键部署脚本
│   └── README.md
│
├── .editorconfig               # 编辑器配置
├── .gitignore                  # Git忽略配置
├── CHANGELOG.md                # 变更日志
├── README.md                   # 项目说明
└── VERSION                     # 版本信息
```

## 📊 部署状态

### 已完成 ✅

- [x] SSH免密登录配置
- [x] 服务器硬件检查
- [x] NPU驱动状态验证
- [x] 目录结构创建
- [x] Docker数据迁移
- [x] 模型文件迁移
- [x] 系统内核优化
- [x] HugePages配置
- [x] 服务精简
- [x] 安全加固
- [x] NPU NUMA配置
- [x] HCI健康检查服务
- [x] 自愈服务
- [x] 审计监控

### 待完成 ⏳

- [ ] K3s容器编排平台
- [ ] MySQL数据库
- [ ] PostgreSQL数据库
- [ ] Redis缓存
- [ ] Milvus向量数据库
- [ ] Neo4j图数据库
- [ ] vLLM推理服务
- [ ] 监控系统
- [ ] 冒烟测试
- [ ] 回归测试

## 🔧 配置说明

### 主机清单

编辑 `ansible/inventory/hosts`:

```ini
[aibox]
10.212.128.192

[aibox:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### 全局变量

编辑 `ansible/group_vars/all.yml` 配置:

- 目录路径
- Docker配置
- NPU设备
- 网络端口
- 数据库参数

## 🏠 HCI一体机特性

| 特性 | 说明 |
|------|------|
| **健康检查** | 每5分钟自动检查系统状态 |
| **自愈服务** | 每10分钟自动恢复故障服务 |
| **审计监控** | 关键操作和配置变更审计 |
| **完整性监控** | 配置文件SHA256基线校验 |
| **一键恢复** | 快速故障恢复脚本 |

## 📖 文档

- [项目交接文档](docs/handoff.md) - 已完成工作和待办事项
- [AI协作指南](docs/Agent.md) - 如何使用AI工具协作
- [技能经验文档](docs/SKILL.md) - 踩坑、排错、优化经验

## 🤝 协作

本项目支持AI工具协作，详见 [Agent.md](docs/Agent.md)。

## 📝 变更日志

详见 [CHANGELOG.md](CHANGELOG.md)。

## 📜 许可证

内部项目，仅供金山政务AI一体机部署使用。

---

**维护团队**: KSC AIBox Team  
**创建时间**: 2026-04-03  
**当前版本**: 1.0.0