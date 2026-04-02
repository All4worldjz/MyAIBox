# KSC AIBox - 金山政务AI一体机部署项目

## 项目概述

本项目用于自动化部署和配置金山政务AI一体机，基于HCI（超融合基础架构）和Appliance模式设计，实现"开箱即用"的产品形态。

## 目标服务器

- **IP地址**: 10.212.128.192
- **操作系统**: openEuler 24.03 LTS-SP1 (ARM64)
- **CPU**: 华为鲲鹏920 5220, 64核 (2插座×32核)
- **内存**: 250GB DDR4
- **NPU**: 华为昇腾910B4-1 × 4张, 每张64GB HBM
- **存储**: Samsung 990 PRO 4TB NVMe SSD

## 项目结构

```
MyAIBox/
├── ansible/                    # Ansible自动化配置
│   ├── ansible.cfg             # Ansible配置文件
│   ├── inventory/              # 主机清单
│   │   └── hosts               # 目标服务器定义
│   ├── group_vars/             # 全局变量
│   │   └── all.yml             # 通用配置变量
│   ├── playbooks/              # Playbook剧本
│   │   ├── 01-prepare-dirs.yml         # 目录结构创建
│   │   ├── 02-migrate-data.yml         # 数据迁移
│   │   ├── 03-system-optimization.yml  # 系统优化
│   │   └── 04-health-check-and-best-practices.yml  # 健康检查
│   ├── roles/                  # Ansible角色
│   ├── files/                  # 静态文件
│   │   ├── configs/            # 配置文件模板
│   │   ├── scripts/            # 脚本文件
│   │   └── systemd/            # systemd服务文件
│   └── templates/              # 模板文件
│
├── docs/                       # 项目文档
│   ├── architecture.md         # 架构设计文档
│   ├── deployment-guide.md     # 部署指南
│   └── troubleshooting.md      # 故障排查指南
│
├── scripts/                    # 本地执行脚本
│   └── deploy.sh               # 一键部署脚本
│
├── .gitignore                  # Git忽略配置
├── README.md                   # 项目说明
└── VERSION                     # 版本信息
```

## 部署阶段

### 阶段1: 基础准备 ✅
- [x] SSH免密登录配置
- [x] 服务器硬件检查
- [x] NPU驱动状态验证
- [x] Ansible项目结构创建
- [x] 目录结构创建 (/ksc_aibox, /backup)

### 阶段2: 数据迁移 ✅
- [x] Docker数据目录迁移
- [x] 模型文件迁移
- [x] 应用文件迁移

### 阘段3: 系统优化 ✅
- [x] 内核参数优化
- [x] HugePages配置
- [x] 服务精简
- [x] 安全加固
- [x] NPU NUMA亲和性配置

### 阘段4: HCI架构优化 ✅
- [x] 健康检查服务
- [x] 自愈服务
- [x] 审计规则配置
- [x] 维护脚本创建

### 阘段5: 技术底座安装 (待执行)
- [ ] K3s容器编排平台
- [ ] MySQL数据库
- [ ] PostgreSQL数据库
- [ ] Redis缓存
- [ ] Milvus向量数据库
- [ ] Neo4j图数据库
- [ ] MinIO对象存储

### 阘段6: 应用部署 (待执行)
- [ ] vLLM推理服务
- [ ] AI Service应用
- [ ] 监控系统 (Prometheus/Grafana)

### 阘段7: 测试验证 (待执行)
- [ ] 冒烟测试
- [ ] 回归测试

## 使用方法

### 执行单个Playbook
```bash
cd ansible
ansible-playbook -i inventory/hosts playbooks/01-prepare-dirs.yml
```

### 执行全部优化
```bash
cd ansible
ansible-playbook -i inventory/hosts playbooks/03-system-optimization.yml
ansible-playbook -i inventory/hosts playbooks/04-health-check-and-best-practices.yml
```

### 查看系统状态
```bash
ssh root@10.212.128.192 "cat /ksc_aibox/config/system-status.json"
```

## HCI一体机特性

- **健康检查**: 每5分钟自动检查系统状态
- **自愈服务**: 每10分钟自动恢复故障服务
- **审计监控**: 关键操作和配置变更审计
- **完整性监控**: 配置文件SHA256基线校验
- **一键恢复**: 快速故障恢复脚本
- **诊断收集**: 系统信息自动打包

## 设计原则

- **可用性**: 开箱即用，零配置启动
- **安全性**: 默认安全配置，审计监控
- **易维护性**: 自动化运维，一键恢复
- **稳定性**: 自愈机制，健康监控

## 版本信息

- **版本**: 1.0.0
- **创建时间**: 2026-04-03
- **维护团队**: KSC AIBox Team

## 许可证

内部项目，仅供金山政务AI一体机部署使用。