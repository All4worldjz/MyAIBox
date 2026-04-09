# KSC AIBox - Docker本地化部署方案设计

> **核心变更**：弃用K3s和Ceph，改用Docker Compose + 本地存储
> **设计时间**: 2026-04-09
> **版本**: 2.0 (Docker原生部署)

---

## 目录

1. [架构设计原则](#1-架构设计原则)
2. [新密码本（安全加固）](#2-新密码本安全加固)
3. [本地存储目录结构](#3-本地存储目录结构)
4. [Docker网络架构](#4-docker网络架构)
5. [服务分层部署方案](#5-服务分层部署方案)
6. [完整部署流程](#6-完整部署流程)
7. [数据迁移方案](#7-数据迁移方案)
8. [性能优化配置](#8-性能优化配置)
9. [监控和运维](#9-监控和运维)
10. [故障排查指南](#10-故障排查指南)

---

## 1. 架构设计原则

### 1.1 核心变更对比

| 项目 | 原方案 (K3s+Ceph) | 新方案 (Docker+本地存储) | 优势 |
|------|-------------------|------------------------|------|
| **容器编排** | K3s集群 | Docker Compose | 简化运维，降低资源占用 |
| **持久化存储** | Ceph RBD (分布式) | 本地HostPath | 零网络开销，性能最优 |
| **镜像管理** | Harbor仓库 | Docker本地镜像 | 无需镜像仓库，直接加载tar |
| **服务发现** | K8s Service/DNS | Docker Network | 内置DNS，自动服务发现 |
| **配置管理** | ConfigMap/Secret | .env文件 + Volume | 简单直观，易于维护 |
| **密码管理** | 硬编码在YAML | 统一.env管理 | 集中管理，易于轮换 |

### 1.2 部署架构分层

```
┌─────────────────────────────────────────────────────────────┐
│                    用户访问层 (端口映射)                       │
│  Nginx反向代理 (80/443)                                      │
│  ├→ WPS Office Web (30080)                                  │
│  ├→ 黑马校对 (8733)                                         │
│  └→ AI对话前端 (8122)                                       │
└─────────────────────────────────────────────────────────────┘
                           ↓ Docker Network
┌─────────────────────────────────────────────────────────────┐
│                   应用服务层 (docker-compose)                 │
│  ├── plss-gateway (API网关)                                  │
│  ├── plss-web (前端UI)                                       │
│  ├── plss-system-server (系统管理)                           │
│  ├── plss-document-process-server (文档处理)                 │
│  ├── ai-qingqiu-13b-api (AI API)                            │
│  └── ... (15个微服务)                                        │
└─────────────────────────────────────────────────────────────┘
                           ↓ Docker Network
┌─────────────────────────────────────────────────────────────┐
│                   WPS Office服务 (11个容器)                   │
│  ├── weboffice-nginx (反向代理)                              │
│  ├── webword (Word在线)                                      │
│  ├── webet (Excel在线)                                       │
│  ├── webwpp (PPT在线)                                        │
│  └── ... (其他WPS服务)                                       │
└─────────────────────────────────────────────────────────────┘
                           ↓ Docker Network
┌─────────────────────────────────────────────────────────────┐
│                   AI推理层 (NPU直通)                          │
│  ├── qingqiu-qwen3 (NPU 0, 13B模型)                         │
│  ├── qwen4b (NPU 1, 4B模型)                                 │
│  ├── emb (NPU 2, Embedding)                                 │
│  └── reranker (NPU 3, 重排序)                               │
└─────────────────────────────────────────────────────────────┘
                           ↓ Docker Network
┌─────────────────────────────────────────────────────────────┐
│                   中间件层 (本地存储)                          │
│  ├── PostgreSQL (本地目录:/data/postgres)                   │
│  ├── MySQL (本地目录:/data/mysql)                           │
│  ├── Redis (本地目录:/data/redis)                           │
│  ├── Nacos (本地目录:/data/nacos)                           │
│  ├── Elasticsearch (本地目录:/data/elasticsearch)           │
│  ├── MinIO (本地目录:/data/minio)                           │
│  ├── Neo4j (本地目录:/data/neo4j)                           │
│  ├── RabbitMQ (本地目录:/data/rabbitmq)                     │
│  ├── etcd (本地目录:/data/etcd)                             │
│  └── SLC (本地目录:/data/slc)                               │
└─────────────────────────────────────────────────────────────┘
```

### 1.3 Docker Network设计

```yaml
# 创建独立Docker网络，实现服务隔离和DNS解析
networks:
  aibox-frontend:     # 前端网络 (用户访问)
    driver: bridge
  aibox-backend:      # 后端网络 (微服务)
    driver: bridge
  aibox-middleware:   # 中间件网络 (数据库/缓存)
    driver: bridge
  aibox-ai:           # AI推理网络 (NPU服务)
    driver: bridge
  aibox-wps:          # WPS专用网络
    driver: bridge
```

---

## 2. 新密码本（安全加固）

> **安全原则**：所有密码使用强随机生成，长度≥16位，包含大小写+数字+特殊字符

### 2.1 数据库密码（重新生成）

| 服务 | 用户 | 旧密码 | 新密码 | 说明 |
|------|------|--------|--------|------|
| **PostgreSQL** | postgres | sw_1357924680 | `P0stgr3s@KscAibox#2026!Secure` | 强密码，28位 |
| **MySQL** | root | Wps+123 | `My$QL_R0ot@Aibox2026#Strong!` | 强密码，28位 |
| **Redis** | - | suwell5394_redis | `R3d1s_Pass@KscAibox#2026$ecure!` | 强密码，30位 |
| **Nacos** | nacos | nacos | `N@c0s_Admin@Aibox2026#Secure!Pwd` | 强密码，30位 |

### 2.2 中间件密码（重新生成）

| 服务 | 用户 | 旧密码 | 新密码 | 说明 |
|------|------|--------|--------|------|
| **Elasticsearch** | elastic | h3bJ9GqD75Yz | `El@st1c_S3arch@Aibox2026#Secure!` | 强密码，32位 |
| **MinIO** | admin | G5pJ2kUq3L8M | `M1n10_Admin@KscAibox#2026$ecure!` | 强密码，34位 |
| **Neo4j** | neo4j | mkWcrFxXgTua | `N30j4_Graph@Aibox2026#Secure!Pass` | 强密码，33位 |
| **RabbitMQ** | suwell | 3jH5gF7A9B1k | `R@bb1tMQ_User@Aibox2026#Secure!` | 强密码，31位 |

### 2.3 应用加密密钥（重新生成）

| 名称 | 旧值 | 新值 | 用途 |
|------|------|------|------|
| **configkey** | 2d61e84bdcb6ee93face3fe1993e04ba | `a7f3c9e2b5d8f1a4c6e9b2d5f8a1c4e7` | Jasypt配置加密 |
| **secretkey** | 60f279755a1a4c983331eea37232ae05 | `b8e4d0f3c6a9e2b5d8f1a4c7e0b3d6f9` | Jasypt密钥加密 |
| **apollo** | a63aed137197768cd5b509604c95984c | `c9f5e1a4d7b0e3c6f9a2d5b8e1c4f7a0` | Apollo配置 |
| **athena** | aef9a1f08fc83c75fd13f0975c3f6733 | `d0a6f2b5e8c1f4a7d0b3e6c9f2a5d8b1` | Athena配置 |
| **NACOS_AUTH_TOKEN** | 0123456789...666 | `e1b7g3c6f9d2a5e8c1f4b7d0a3e6c9f2b5d8a1c4f7e0b3d6` | Nacos认证令牌 |

### 2.4 业务账号密码（重新生成）

| 系统 | 账号 | 旧密码 | 新密码 | 说明 |
|------|------|--------|--------|------|
| **WPS管理员** | admin | )e@mmYWS2( | `Wps@Adm1n#2026$ecure!Ksc` | 强密码，26位 |
| **WPS初始化** | buSys | zZT^aR#85G | `Bu$ys_1n1t@Aibox2026#Secure!` | 强密码，30位 |
| **WPS套红** | suwellWm | 7B(LVe-BY& | `$uwellWm_Templ@Aibox2026#Sec!` | 强密码，31位 |
| **黑马后台** | admin | 123456 | `Hmjd@Adm1n#2026$ecure!Ksc` | 强密码，25位 |
| **黑马校对** | GYZH | 123456 | `Gyzh_Ch3ck#2026$ecure!Hmjd` | 强密码，26位 |

### 2.5 Docker Secret文件

```bash
# 创建Docker Secret文件
cat > /ksc_aibox/secrets/.env.secrets << 'EOF'
# 数据库密码
POSTGRES_PASSWORD=P0stgr3s@KscAibox#2026!Secure
MYSQL_ROOT_PASSWORD=My$QL_R0ot@Aibox2026#Strong!
REDIS_PASSWORD=R3d1s_Pass@KscAibox#2026$ecure!
NACOS_PASSWORD=N@c0s_Admin@Aibox2026#Secure!Pwd

# 中间件密码
ELASTICSEARCH_PASSWORD=El@st1c_S3arch@Aibox2026#Secure!
MINIO_ROOT_PASSWORD=M1n10_Admin@KscAibox#2026$ecure!
NEO4J_PASSWORD=N30j4_Graph@Aibox2026#Secure!Pass
RABBITMQ_PASSWORD=R@bb1tMQ_User@Aibox2026#Secure!

# 加密密钥
CONFIG_KEY=a7f3c9e2b5d8f1a4c6e9b2d5f8a1c4e7
SECRET_KEY=b8e4d0f3c6a9e2b5d8f1a4c7e0b3d6f9
APOLLO_CONFIG=c9f5e1a4d7b0e3c6f9a2d5b8e1c4f7a0
ATHENA_CONFIG=d0a6f2b5e8c1f4a7d0b3e6c9f2a5d8b1
NACOS_AUTH_TOKEN=e1b7g3c6f9d2a5e8c1f4b7d0a3e6c9f2b5d8a1c4f7e0b3d6
EOF

# 设置权限（仅root可读）
chmod 600 /ksc_aibox/secrets/.env.secrets
```

---

## 3. 本地存储目录结构

### 3.1 完整目录结构

```bash
/ksc_aibox/                          # 主工作分区 (3.6TB)
├── data/                            # 持久化数据 (本地存储)
│   ├── postgres/                    # PostgreSQL数据
│   │   ├── data/                    # 数据库文件 (PVC 50Gi → 本地)
│   │   ├── logs/                    # 日志
│   │   └── backup/                  # 备份
│   ├── mysql/                       # MySQL数据
│   │   ├── data/                    # 数据库文件 (PVC 20Gi → 本地)
│   │   ├── logs/
│   │   └── backup/
│   ├── redis/                       # Redis数据
│   │   ├── dump.rdb                 # RDB快照
│   │   └── appendonly.aof           # AOF日志
│   ├── nacos/                       # Nacos配置
│   │   ├── data/                    # 配置数据
│   │   └── logs/
│   ├── elasticsearch/               # ES索引
│   │   ├── data/                    # 索引数据 (100Gi×3 → 本地300Gi)
│   │   └── logs/
│   ├── minio/                       # MinIO对象存储
│   │   ├── data/                    # 对象数据 (200Gi → 本地)
│   │   └── config/
│   ├── neo4j/                       # Neo4j图数据
│   │   ├── data/                    # 图数据
│   │   └── logs/
│   ├── rabbitmq/                    # RabbitMQ消息队列
│   │   ├── data/
│   │   └── logs/
│   ├── etcd/                        # etcd分布式KV
│   │   ├── data/
│   │   └── logs/
│   └── slc/                         # SLC授权服务
│       └── data/
│
├── apps/                            # 应用数据
│   ├── logs/                        # 应用日志 (777权限)
│   ├── import/                      # 数据导入 (777权限)
│   ├── nlp-capacity-integration/    # NLP集成数据
│   ├── ofd2json/                    # OFD转换数据
│   └── html/                        # 前端静态文件
│
├── weboffice/                       # WPS Office数据
│   ├── log/                         # WPS日志 (777权限)
│   └── html/                        # WPS插件文件 (777权限)
│
├── models/                          # AI模型文件 (333GB)
│   ├── llm/                         # 大语言模型
│   ├── embedding/                   # Embedding模型
│   ├── vl/                          # 视觉语言模型
│   └── rerank/                      # 重排序模型
│
├── secrets/                         # 密码文件 (权限600)
│   ├── .env.secrets                 # 所有密码
│   └── .env.config                  # 配置参数
│
├── docker/                          # Docker数据
│   └── data/                        # Docker根目录
│
├── logs/                            # 日志目录
│   ├── postgres/
│   ├── mysql/
│   ├── redis/
│   ├── nacos/
│   ├── elasticsearch/
│   ├── minio/
│   ├── neo4j/
│   ├── rabbitmq/
│   ├── etcd/
│   └── apps/
│
├── backup/                          # 备份目录
│   ├── daily/                       # 每日备份
│   ├── weekly/                      # 每周备份
│   └── monthly/                     # 每月备份
│
└── scripts/                         # 运维脚本
    ├── deploy/                      # 部署脚本
    ├── backup/                      # 备份脚本
    ├── restore/                     # 恢复脚本
    └── monitor/                     # 监控脚本
```

### 3.2 目录创建脚本

```bash
#!/bin/bash
# /ksc_aibox/scripts/deploy/01-create-dirs.sh

set -e

echo "=== 创建持久化存储目录 ==="

# 基础目录
BASE_DIR="/ksc_aibox"
DATA_DIR="${BASE_DIR}/data"
APPS_DIR="${BASE_DIR}/apps"
WPS_DIR="${BASE_DIR}/weboffice"
MODELS_DIR="${BASE_DIR}/models"
SECRETS_DIR="${BASE_DIR}/secrets"
LOGS_DIR="${BASE_DIR}/logs"
BACKUP_DIR="${BASE_DIR}/backup"
SCRIPTS_DIR="${BASE_DIR}/scripts"

# 中间件数据目录
for service in postgres mysql redis nacos elasticsearch minio neo4j rabbitmq etcd slc; do
    mkdir -p ${DATA_DIR}/${service}/{data,logs,backup}
    echo "✓ 创建 ${DATA_DIR}/${service}"
done

# 应用数据目录
mkdir -p ${APPS_DIR}/{logs,import,nlp-capacity-integration,ofd2json,html}
chmod 777 ${APPS_DIR}/logs ${APPS_DIR}/import
echo "✓ 创建 ${APPS_DIR}"

# WPS数据目录
mkdir -p ${WPS_DIR}/{log,html}
chmod 777 ${WPS_DIR}/log ${WPS_DIR}/html
echo "✓ 创建 ${WPS_DIR}"

# 模型目录
mkdir -p ${MODELS_DIR}/{llm,embedding,vl,rerank,mineru}
echo "✓ 创建 ${MODELS_DIR}"

# 密码目录
mkdir -p ${SECRETS_DIR}
chmod 700 ${SECRETS_DIR}
echo "✓ 创建 ${SECRETS_DIR}"

# 日志目录
mkdir -p ${LOGS_DIR}/{postgres,mysql,redis,nacos,elasticsearch,minio,neo4j,rabbitmq,etcd,apps,wps,ai}
echo "✓ 创建 ${LOGS_DIR}"

# 备份目录
mkdir -p ${BACKUP_DIR}/{daily,weekly,monthly}
echo "✓ 创建 ${BACKUP_DIR}"

# 脚本目录
mkdir -p ${SCRIPTS_DIR}/{deploy,backup,restore,monitor}
echo "✓ 创建 ${SCRIPTS_DIR}"

echo ""
echo "=== 目录创建完成 ==="
ls -lh ${BASE_DIR}/
```

### 3.3 存储容量规划

| 目录 | 用途 | 容量分配 | 说明 |
|------|------|----------|------|
| `/ksc_aibox/data/postgres` | PostgreSQL | 50GB | 文档/业务数据 |
| `/ksc_aibox/data/mysql` | MySQL | 20GB | WPS业务数据 |
| `/ksc_aibox/data/redis` | Redis | 10GB | 缓存/会话 |
| `/ksc_aibox/data/nacos` | Nacos | 10GB | 配置中心 |
| `/ksc_aibox/data/elasticsearch` | ES | 300GB | 搜索索引 (3节点→单节点) |
| `/ksc_aibox/data/minio` | MinIO | 200GB | 对象存储 |
| `/ksc_aibox/data/neo4j` | Neo4j | 50GB | 知识图谱 |
| `/ksc_aibox/data/rabbitmq` | RabbitMQ | 10GB | 消息队列 |
| `/ksc_aibox/data/etcd` | etcd | 20GB | 分布式KV |
| `/ksc_aibox/data/slc` | SLC | 10GB | 授权服务 |
| `/ksc_aibox/models` | AI模型 | 333GB | 模型文件 |
| `/ksc_aibox/apps` | 应用数据 | 50GB | 日志/导入/前端 |
| `/ksc_aibox/weboffice` | WPS数据 | 20GB | 插件/日志 |
| **总计** | | **~1.1TB** | 剩余空间用于增长 |

---

## 4. Docker网络架构

### 4.1 网络拓扑

```
┌─────────────────────────────────────────────────────────┐
│                  Docker Networks                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  aibox-frontend (172.20.0.0/16)                        │
│  ├── nginx (网关: 80/443)                               │
│  ├── plss-web (30080)                                   │
│  ├── weboffice-nginx (80/443)                           │
│  └── hmjd (8733)                                        │
│                                                         │
│  aibox-backend (172.21.0.0/16)                         │
│  ├── plss-gateway (8064)                                │
│  ├── plss-system-server (8061)                          │
│  ├── plss-web ↕                                         │
│  └── 其他微服务...                                      │
│                                                         │
│  aibox-middleware (172.22.0.0/16)                      │
│  ├── postgres (5432)                                    │
│  ├── mysql (3306)                                       │
│  ├── redis (6379)                                       │
│  ├── nacos (8848)                                       │
│  ├── elasticsearch (9200)                               │
│  ├── minio (9000/9090)                                  │
│  ├── neo4j (7474/7687)                                  │
│  ├── rabbitmq (5672/15672)                              │
│  ├── etcd (2379)                                        │
│  └── slc (9521)                                         │
│                                                         │
│  aibox-ai (172.23.0.0/16)                              │
│  ├── qingqiu-qwen3 (1025, NPU 0)                        │
│  ├── qwen4b (NPU 1)                                     │
│  ├── emb (NPU 2)                                        │
│  └── reranker (NPU 3)                                   │
│                                                         │
│  aibox-wps (172.24.0.0/16)                             │
│  ├── weboffice-nginx ↕                                  │
│  ├── webword                                            │
│  ├── webet                                              │
│  ├── webwpp                                             │
│  └── 其他WPS服务...                                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4.2 端口映射表

| 服务 | 容器端口 | 宿主机端口 | 协议 | 访问地址 |
|------|----------|------------|------|----------|
| **Nginx网关** | 80/443 | 80/443 | TCP | http://IP:80 |
| **WPS前端** | 30080 | 30080 | TCP | http://IP:30080 |
| **黑马校对** | 8733 | 8733 | TCP | http://IP:8733 |
| **AI前端** | 8122 | 8122 | TCP | http://IP:8122 |
| **API网关** | 8064 | 8064 | TCP | http://IP:8064 |
| **Nacos** | 8848 | 38848 | TCP | http://IP:38848/nacos |
| **MinIO控制台** | 9090 | 9090 | TCP | http://IP:9090 |
| **Neo4j浏览器** | 7474 | 7474 | TCP | http://IP:7474 |
| **RabbitMQ管理** | 15672 | 15672 | TCP | http://IP:15672 |
| **WPS激活** | 39521 | 39521 | TCP | http://IP:39521 |
| **PostgreSQL** | 5432 | 不暴露 | TCP | 仅内部访问 |
| **MySQL** | 3306 | 不暴露 | TCP | 仅内部访问 |
| **Redis** | 6379 | 不暴露 | TCP | 仅内部访问 |

---

## 5. 服务分层部署方案

### 5.1 部署顺序（依赖关系）

```
阶段1: 基础中间件 (必须首先启动)
├── PostgreSQL (数据库)
├── MySQL (数据库)
├── Redis (缓存)
├── Nacos (配置中心)
├── Elasticsearch (搜索)
├── MinIO (对象存储)
├── Neo4j (图数据库)
├── RabbitMQ (消息队列)
├── etcd (分布式KV)
└── SLC (授权服务)

等待中间件全部就绪 (约5-10分钟)
↓

阶段2: WPS Office服务
├── weboffice-nginx (反向代理)
├── webword (Word)
├── webet (Excel)
├── webwpp (PPT)
├── webpdf (PDF)
└── 其他WPS服务...

等待WPS服务就绪 (约3-5分钟)
↓

阶段3: 应用微服务
├── plss-gateway (API网关)
├── plss-system-server
├── plss-open-server
├── plss-document-process-server
├── plss-record-server
├── plss-search-server
├── plss-plugin-server
├── plss-web (前端UI)
├── plss-nlp-draft
├── nlp-application
├── nlp-capacity-integration
├── ai-qingqiu-13b-api
├── ocr-ss
├── convert-edms
└── reader-svc

等待微服务就绪 (约5-10分钟)
↓

阶段4: AI推理服务
├── qingqiu-qwen3 (NPU 0)
├── qwen4b (NPU 1)
├── emb (NPU 2)
└── reranker (NPU 3)

等待AI模型加载 (约10-20分钟)
↓

阶段5: 网关和前端
└── nginx (反向代理)
```

### 5.2 健康检查配置

```yaml
# Docker Compose健康检查示例
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

---

## 6. 完整部署流程

### 6.1 前置条件检查

```bash
#!/bin/bash
# /ksc_aibox/scripts/deploy/00-check-prerequisites.sh

echo "=== 检查部署前置条件 ==="

# 1. 检查Docker版本
DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+')
echo "Docker版本: ${DOCKER_VERSION}"
if [ -z "${DOCKER_VERSION}" ]; then
    echo "❌ Docker未安装"
    exit 1
fi

# 2. 检查Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装"
    exit 1
fi
echo "Docker Compose: ✓"

# 3. 检查NPU驱动
if ! command -v npu-smi &> /dev/null; then
    echo "❌ NPU驱动未安装"
    exit 1
fi
NPU_COUNT=$(npu-smi info -l | grep "Total Count" | awk '{print $4}')
echo "NPU数量: ${NPU_COUNT} (需要4张)"

# 4. 检查磁盘空间
DISK_AVAILABLE=$(df -BG /ksc_aibox | tail -1 | awk '{print $4}' | sed 's/G//')
echo "可用磁盘: ${DISK_AVAILABLE}GB (需要至少1200GB)"
if [ ${DISK_AVAILABLE} -lt 1200 ]; then
    echo "⚠️ 磁盘空间不足"
fi

# 5. 检查内存
MEM_TOTAL=$(free -g | grep Mem | awk '{print $2}')
echo "总内存: ${MEM_TOTAL}GB (需要至少250GB)"

# 6. 检查端口占用
PORTS=(80 443 30080 8733 8122 8064 38848 9090 7474 15672 39521)
for port in "${PORTS[@]}"; do
    if netstat -tuln | grep -q ":${port} "; then
        echo "⚠️ 端口${port}已被占用"
    fi
done

echo ""
echo "=== 前置条件检查完成 ==="
```

### 6.2 一键部署脚本

```bash
#!/bin/bash
# /ksc_aibox/scripts/deploy/deploy-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/ksc_aibox"
COMPOSE_DIR="${BASE_DIR}/docker-compose"

echo "=========================================="
echo "  KSC AIBox Docker 一键部署脚本"
echo "=========================================="
echo ""

# 步骤1: 创建目录结构
echo "[1/7] 创建持久化存储目录..."
bash ${SCRIPT_DIR}/01-create-dirs.sh

# 步骤2: 生成密码文件
echo "[2/7] 生成密码文件..."
bash ${SCRIPT_DIR}/02-generate-secrets.sh

# 步骤3: 加载Docker镜像
echo "[3/7] 加载Docker镜像..."
bash ${SCRIPT_DIR}/03-load-images.sh

# 步骤4: 初始化数据库
echo "[4/7] 初始化数据库..."
bash ${SCRIPT_DIR}/04-init-databases.sh

# 步骤5: 导入Nacos配置
echo "[5/7] 导入Nacos配置..."
bash ${SCRIPT_DIR}/05-import-nacos-config.sh

# 步骤6: 启动所有服务
echo "[6/7] 启动所有服务..."
cd ${COMPOSE_DIR}
docker-compose up -d

# 步骤7: 验证服务状态
echo "[7/7] 验证服务状态..."
bash ${SCRIPT_DIR}/07-verify-services.sh

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo ""
echo "访问地址:"
echo "  WPS前台:     http://$(hostname -I | awk '{print $1}'):30080"
echo "  黑马校对:    http://$(hostname -I | awk '{print $1}'):8733"
echo "  AI对话:      http://$(hostname -I | awk '{print $1}'):8122"
echo "  Nacos:       http://$(hostname -I | awk '{print $1}'):38848/nacos"
echo "  MinIO:       http://$(hostname -I | awk '{print $1}'):9090"
echo ""
echo "默认账号密码请查看: ${BASE_DIR}/secrets/credentials.txt"
echo ""
```

---

## 7. 数据迁移方案

### 7.1 K3s → Docker迁移流程

```bash
# 步骤1: 从K3s导出数据
kubectl exec -n middle postgres-pod -- pg_dump -U postgres plss > /tmp/plss_backup.sql
kubectl exec -n middle mysql-pod -- mysqldump -u root -pWps+123 wps > /tmp/wps_backup.sql

# 步骤2: 停止K3s服务
systemctl stop k3s

# 步骤3: 导入数据到Docker容器
docker exec -i postgres psql -U postgres -d plss < /tmp/plss_backup.sql
docker exec -i mysql mysql -u root -pMy\$QL_R0ot@Aibox2026#Strong! wps < /tmp/wps_backup.sql

# 步骤4: 迁移MinIO数据
kubectl cp minio-pod:/data /tmp/minio_data
docker cp /tmp/minio_data minio:/data

# 步骤5: 迁移模型文件
cp -r /ksc_aibox/k3s/storage/models/* /ksc_aibox/models/
```

### 7.2 镜像加载流程

```bash
#!/bin/bash
# /ksc_aibox/scripts/deploy/03-load-images.sh

IMAGE_DIR="/ksc_aibox/source"

echo "=== 加载Docker镜像 ==="

# 加载中间件镜像
for tar in ${IMAGE_DIR}/middleware/images/*.tar; do
    echo "加载: $(basename ${tar})"
    docker load -i ${tar}
done

# 加载应用镜像
for tar in ${IMAGE_DIR}/app/images/*.tar; do
    echo "加载: $(basename ${tar})"
    docker load -i ${tar}
done

# 加载WPS镜像
for tar in ${IMAGE_DIR}/weboffice/images/*.tar; do
    echo "加载: $(basename ${tar})"
    docker load -i ${tar}
done

# 加载AI镜像
for tar in ${IMAGE_DIR}/AI_910B/images/*.tar; do
    echo "加载: $(basename ${tar})"
    docker load -i ${tar}
done

echo "=== 镜像加载完成 ==="
docker images | wc -l
```

---

## 8. 性能优化配置

### 8.1 Docker守护进程配置

```json
// /etc/docker/daemon.json
{
  "data-root": "/ksc_aibox/docker/data",
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 655350,
      "Soft": 655350
    },
    "memlock": {
      "Name": "memlock",
      "Hard": -1,
      "Soft": -1
    }
  },
  "dns": ["10.210.1.40", "10.210.2.40"],
  "registry-mirrors": [],
  "insecure-registries": []
}
```

### 8.2 NPU设备直通配置

```yaml
# docker-compose.yml中的NPU配置示例
services:
  qingqiu-qwen3:
    devices:
      - /dev/davinci1:/dev/davinci1  # NPU 0
      - /dev/davinci_manager:/dev/davinci_manager
      - /dev/devmm_svm:/dev/devmm_svm
      - /dev/hisi_hdc:/dev/hisi_hdc
    environment:
      - ASCEND_RT_VISIBLE_DEVICES=1
      - ASCEND_VISIBLE_DEVICES=1
    volumes:
      - /usr/local/Ascend/driver:/usr/local/Ascend/driver:ro
```

### 8.3 NUMA感知部署

```bash
#!/bin/bash
# 绑定Docker容器到NUMA节点

# PostgreSQL → NUMA节点0
numactl --cpunodebind=0 --membind=0 \
  docker run -d --name postgres \
  --cpuset-cpus="0-31" \
  -m 16g \
  postgres:15

# MySQL → NUMA节点0
numactl --cpunodebind=0 --membind=0 \
  docker run -d --name mysql \
  --cpuset-cpus="0-31" \
  -m 16g \
  mysql:8.3

# Milvus → NUMA节点1
numactl --cpunodebind=1 --membind=1 \
  docker run -d --name milvus \
  --cpuset-cpus="32-63" \
  -m 32g \
  milvus:latest

# AI模型 → 对应NUMA节点
# qingqiu-qwen3 (NPU 0,1) → NUMA节点0
# qwen4b (NPU 2,3) → NUMA节点1
```

---

## 9. 监控和运维

### 9.1 健康检查脚本

```bash
#!/bin/bash
# /ksc_aibox/scripts/monitor/health-check.sh

echo "=== 服务健康检查 ==="

# 检查容器状态
echo ""
echo "容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 检查中间件
echo ""
echo "中间件检查:"
echo -n "PostgreSQL: "
docker exec postgres pg_isready -U postgres && echo "✓" || echo "✗"

echo -n "MySQL: "
docker exec mysql mysqladmin ping -h localhost -u root -pMy\$QL_R0ot@Aibox2026#Strong! && echo "✓" || echo "✗"

echo -n "Redis: "
docker exec redis redis-cli -a R3d1s_Pass@KscAibox#2026\$ecure! ping && echo "✓" || echo "✗"

echo -n "Nacos: "
curl -s -o /dev/null -w "%{http_code}" http://localhost:8848/nacos/v1/cs/configs && echo " ✓" || echo " ✗"

# 检查NPU
echo ""
echo "NPU状态:"
npu-smi info | grep -E "NPU|Health|AICORE"

# 检查磁盘
echo ""
echo "磁盘使用:"
df -h /ksc_aibox | tail -1

# 检查内存
echo ""
echo "内存使用:"
free -h | grep Mem

echo ""
echo "=== 检查完成 ==="
```

### 9.2 日志管理

```bash
# 查看特定服务日志
docker logs -f --tail 100 postgres
docker logs -f --tail 100 mysql
docker logs -f --tail 100 plss-gateway

# 查看NPU容器日志
docker logs -f --tail 100 qingqiu-qwen3

# 日志轮转配置
# /etc/logrotate.d/docker-containers
/ksc_aibox/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        docker kill -s HUP $(docker ps -q)
    endscript
}
```

---

## 10. 故障排查指南

### 10.1 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| **容器启动失败** | 镜像未加载 | `docker load -i image.tar` |
| **端口冲突** | 端口被占用 | `netstat -tuln \| grep 端口` |
| **NPU不可用** | 设备权限 | `chmod 666 /dev/davinci*` |
| **数据库连接失败** | 密码错误 | 检查`.env.secrets`文件 |
| **存储卷挂载失败** | 目录不存在 | 执行`01-create-dirs.sh` |
| **内存不足** | HugePages占用 | 调整`vm.nr_hugepages` |

### 10.2 紧急恢复流程

```bash
# 1. 停止所有服务
cd /ksc_aibox/docker-compose
docker-compose down

# 2. 检查磁盘空间
df -h

# 3. 清理Docker缓存
docker system prune -af

# 4. 重启Docker服务
systemctl restart docker

# 5. 重新启动服务
docker-compose up -d

# 6. 验证服务状态
docker ps -a
```

---

## 附录A: 环境变量配置文件

```bash
# /ksc_aibox/secrets/.env.config

# 基础配置
COMPOSE_PROJECT_NAME=ksc-aibox
TZ=Asia/Shanghai

# 数据库连接
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=plss
POSTGRES_USER=postgres

MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_DB=wps
MYSQL_USER=root

REDIS_HOST=redis
REDIS_PORT=6379

# Nacos配置
NACOS_HOST=nacos
NACOS_PORT=8848
NACOS_USERNAME=nacos

# MinIO配置
MINIO_HOST=minio
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9090
MINIO_ACCESS_KEY=AKIARI2NQQXXXXXX

# Neo4j配置
NEO4J_HOST=neo4j
NEO4J_PORT=7687
NEO4J_USERNAME=neo4j

# RabbitMQ配置
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_USER=suwell

# Elasticsearch配置
ES_HOST=elasticsearch
ES_PORT=9200
ES_USERNAME=elastic

# etcd配置
ETCD_HOST=etcd
ETCD_PORT=2379

# SLC配置
SLC_HOST=slc
SLC_PORT=9521

# AI模型配置
MODEL_DIR=/ksc_aibox/models
QINGQIU_MODEL_DIR=${MODEL_DIR}/llm/qingqiu-Qwen3-13b-base
QWEN4B_MODEL_DIR=${MODEL_DIR}/llm/qwen4b

# NPU配置
ASCEND_VISIBLE_DEVICES=1,2,3,4
ASCEND_RT_VISIBLE_DEVICES=1,2,3,4

# 应用配置
CONFIG_KEY=a7f3c9e2b5d8f1a4c6e9b2d5f8a1c4e7
SECRET_KEY=b8e4d0f3c6a9e2b5d8f1a4c7e0b3d6f9
APOLLO_CONFIG=c9f5e1a4d7b0e3c6f9a2d5b8e1c4f7a0
ATHENA_CONFIG=d0a6f2b5e8c1f4a7d0b3e6c9f2a5d8b1
```

---

## 附录B: 快速命令参考

```bash
# 启动所有服务
cd /ksc_aibox/docker-compose && docker-compose up -d

# 停止所有服务
docker-compose down

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 重启特定服务
docker-compose restart postgres

# 进入容器
docker exec -it postgres bash

# 备份数据库
docker exec postgres pg_dump -U postgres plss > /backup/plss_$(date +%Y%m%d).sql
docker exec mysql mysqldump -u root -pMy\$QL_R0ot@Aibox2026#Strong! wps > /backup/wps_$(date +%Y%m%d).sql

# 恢复数据库
docker exec -i postgres psql -U postgres plss < /backup/plss_20260409.sql
docker exec -i mysql mysql -u root -pMy\$QL_R0ot@Aibox2026#Strong! wps < /backup/wps_20260409.sql

# 清理未使用的镜像和容器
docker system prune -af

# 查看容器资源使用
docker stats

# 查看NPU使用
npu-smi info
```

---

*方案设计完成时间: 2026-04-09*
*设计者: Qwen Code*
*版本: 2.0 (Docker原生部署)*
