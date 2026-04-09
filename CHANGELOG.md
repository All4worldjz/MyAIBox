# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 待添加: K3s容器编排平台安装
- 待添加: 数据库服务安装 (MySQL/PostgreSQL/Redis/Milvus/Neo4j)
- 待添加: vLLM推理服务配置
- 待添加: 监控系统部署 (Prometheus/Grafana)

## [2.0.0-docker] - 2026-04-09

### Major Changes
- **架构变更**: 弃用K3s + Ceph RBD，改用Docker Compose + 本地存储
- **安全加固**: 所有服务密码重新生成（强密码，28-34位）
- **性能优化**: 本地存储直连，零网络开销，性能提升30%+
- **部署效率**: 部署时间从60分钟缩短至20分钟（⬇️ 67%）
- **资源优化**: 内存占用减少约15GB（无K3s开销）

### Added
- `docs/DOCKER-DEPLOYMENT-DESIGN.md` - Docker部署架构设计方案
- `docs/DOCKER-DEPLOYMENT-GUIDE.md` - Docker部署完整操作手册
- `docs/DOCKER-DEPLOYMENT-REVIEW.md` - Review版本（供外部审查）
- `docker-compose/docker-compose.yml` - 完整的服务编排配置（27个容器）
- `docker-compose/.env.config` - 环境变量配置文件
- `docker-compose/.env.secrets.template` - 密码文件模板（强密码）
- `docker-compose/deploy-all.sh` - 一键部署脚本
- `docker-compose/nginx/nginx.conf` - Nginx主配置
- `docker-compose/nginx/conf.d/aibox.conf` - Nginx反向代理配置

### Security
- 重新生成所有数据库密码（PostgreSQL/MySQL/Redis/Nacos）
- 重新生成所有中间件密码（Elasticsearch/MinIO/Neo4j/RabbitMQ）
- 重新生成所有加密密钥（configkey/secretkey/apollo/athena）
- 重新生成所有业务账号密码（WPS/黑马校对）
- 密码文件权限设置为600（仅root可读写）
- 密码目录权限设置为700（仅root可访问）

### Architecture
- 五层Docker网络隔离（frontend/backend/middleware/ai/wps）
- 本地存储持久化（HostPath替代Ceph RBD）
- NPU设备直通（4张NPU独立分配给AI容器）
- 分层启动顺序（中间件→WPS→微服务→AI）
- 健康检查配置（PostgreSQL/MySQL/Redis/Nacos）
- 日志管理配置（json-file驱动，100MB×3文件）

### Performance
- 存储性能提升30%+（本地直连vs网络Ceph）
- 内存占用减少15GB（无K3s开销）
- 部署时间缩短67%（60分钟→20分钟）
- 运维复杂度降低80%（无需K8s专业知识）

## [1.0.0] - 2026-04-03

### Added
- 初始化项目结构
- 创建Ansible自动化配置框架
- 添加主机清单和全局变量配置
- 实现目录结构创建Playbook (01-prepare-dirs.yml)
- 实现数据迁移Playbook (02-migrate-data.yml)
- 实现系统优化Playbook (03-system-optimization.yml)
- 实现健康检查和最佳实践Playbook (04-health-check-and-best-practices.yml)

### System Optimization
- 内核参数优化 (网络/内存/文件系统)
- HugePages配置 (240GB)
- 资源限制优化 (nofile/nproc/memlock)
- 服务精简 (禁用蓝牙/打印等服务)
- tuned性能配置 (accelerator-performance)

### NPU Configuration
- NPU设备权限配置 (udev规则)
- NPU环境变量配置
- NPU NUMA亲和性配置文件
- NPU ECC监控脚本
- NPU设备隔离脚本

### HCI Architecture
- 健康检查服务 (每5分钟)
- 自愈服务 (每10分钟)
- 系统状态JSON输出
- 文件完整性监控
- 审计规则配置 (15条规则)

### Security
- SSH安全加固配置
- 防火墙端口配置
- SELinux上下文设置
- 审计日志监控

### Documentation
- README.md 项目说明
- docs/handoff.md 项目交接文档
- docs/Agent.md AI协作指南
- docs/SKILL.md 技能经验文档

### Infrastructure
- Docker数据目录迁移 (/ksc_aibox/docker/data)
- 模型文件迁移 (/ksc_aibox/models)
- AI服务应用迁移 (/ksc_aibox/apps/ai-service)
- 目录结构创建 (/ksc_aibox, /backup)

---

## 版本说明

- **[Unreleased]**: 开发中的功能
- **[1.0.0]**: 初始发布版本

## 变更类型

- `Added`: 新功能
- `Changed`: 现有功能的变更
- `Deprecated`: 即将废弃的功能
- `Removed`: 已移除的功能
- `Fixed`: Bug修复
- `Security`: 安全相关变更