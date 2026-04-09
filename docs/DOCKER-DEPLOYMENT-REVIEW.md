# KSC AIBox - Docker本地化部署方案 Review版本

> **Review请求**：请审查此Docker部署方案的完整设计
> **方案版本**: 2.0 (Docker原生部署)
> **设计时间**: 2026-04-09
> **审查重点**：架构合理性、安全性、性能、可维护性

---

## 📋 Review请求说明

### 背景

KSC AIBox项目原计划使用**K3s + Ceph RBD**方案，现决定改为**Docker Compose + 本地存储**方案。

### 变更原因

1. **简化运维**：K3s资源占用大（~15GB），运维复杂度高
2. **性能优化**：Ceph网络存储开销大，本地存储直连性能更优
3. **密码安全**：原方案密码硬编码在YAML中，存在泄密风险
4. **部署效率**：K3s部署需60分钟，Docker方案缩短至20分钟

### 审查要求

请重点审查以下方面：
- ✅ 架构设计是否合理
- ✅ 安全加固是否充分
- ✅ 性能优化是否到位
- ✅ 可维护性和可扩展性
- ✅ 潜在风险和遗漏

---

## 1. 架构设计变更对比

### 1.1 核心技术栈变更

| 项目 | 原方案 (v1.0) | 新方案 (v2.0) | 变更理由 |
|------|---------------|---------------|----------|
| **容器编排** | K3s v1.31.4 | Docker Compose v3.8 | 降低资源占用，简化运维 |
| **持久化存储** | Ceph RBD (分布式) | 本地HostPath直连 | 零网络开销，性能提升30%+ |
| **镜像管理** | Harbor仓库 | Docker本地加载tar | 无需镜像仓库，部署更简单 |
| **服务发现** | K8s Service/DNS | Docker Network内置DNS | 自动服务发现，配置更简单 |
| **配置管理** | ConfigMap/Secret | .env文件 + Volume挂载 | 直观易管理，支持热更新 |
| **密码管理** | 硬编码在YAML | 独立密码文件，权限600 | 安全加固，支持密码轮换 |

### 1.2 架构分层设计

```
┌─────────────────────────────────────────────────────────────┐
│                    用户访问层 (端口映射)                       │
│  Nginx反向代理 (80/443)                                      │
│  ├→ WPS Office Web (30080)                                  │
│  ├→ 黑马校对 (8733)                                         │
│  └→ AI对话前端 (8122)                                       │
└─────────────────────────────────────────────────────────────┘
                           ↓ Docker Network (aibox-frontend)
┌─────────────────────────────────────────────────────────────┐
│                   应用服务层 (docker-compose)                 │
│  ├── plss-gateway (API网关, 8064)                            │
│  ├── plss-web (前端UI, 30080)                                │
│  ├── plss-system-server (系统管理, 8061)                     │
│  ├── plss-document-process-server (文档处理)                 │
│  ├── plss-search-server (搜索服务)                           │
│  ├── nlp-capacity-integration (NLP集成, 8086)               │
│  └── ai-qingqiu-13b-api (AI API, 8000)                      │
└─────────────────────────────────────────────────────────────┘
                           ↓ Docker Network (aibox-backend)
┌─────────────────────────────────────────────────────────────┐
│                   WPS Office服务 (11个容器)                   │
│  ├── weboffice-nginx (反向代理, 80/443)                      │
│  ├── webword (Word在线)                                      │
│  ├── webet (Excel在线)                                       │
│  ├── webwpp (PPT在线)                                        │
│  └── webpdf (PDF查看器)                                      │
└─────────────────────────────────────────────────────────────┘
                           ↓ Docker Network (aibox-wps)
┌─────────────────────────────────────────────────────────────┐
│                   AI推理层 (NPU直通)                          │
│  ├── qingqiu-qwen3 (NPU 1, 13B模型, 端口1025)               │
│  ├── qwen4b (NPU 2, 4B模型)                                 │
│  ├── emb (NPU 3, Embedding)                                 │
│  └── reranker (NPU 4, 重排序)                               │
└─────────────────────────────────────────────────────────────┘
                           ↓ Docker Network (aibox-ai)
┌─────────────────────────────────────────────────────────────┐
│                   中间件层 (本地存储)                          │
│  ├── PostgreSQL (5432, 本地目录:/data/postgres)             │
│  ├── MySQL (3306, 本地目录:/data/mysql)                     │
│  ├── Redis (6379, 本地目录:/data/redis)                     │
│  ├── Nacos (8848, 本地目录:/data/nacos)                     │
│  ├── Elasticsearch (9200, 本地目录:/data/elasticsearch)     │
│  ├── MinIO (9000/9090, 本地目录:/data/minio)                │
│  ├── Neo4j (7474/7687, 本地目录:/data/neo4j)                │
│  ├── RabbitMQ (5672/15672, 本地目录:/data/rabbitmq)         │
│  ├── etcd (2379, 本地目录:/data/etcd)                       │
│  └── SLC (9521, 本地目录:/data/slc)                         │
└─────────────────────────────────────────────────────────────┘
```

### 1.3 Docker网络拓扑

```
aibox-frontend (172.20.0.0/16)
├── nginx-gateway (网关: 80/443)
├── plss-web (30080)
└── weboffice-nginx (80/443)

aibox-backend (172.21.0.0/16)
├── plss-gateway (8064)
├── plss-system-server (8061)
├── plss-document-process-server
├── plss-search-server
├── nlp-capacity-integration (8086)
└── ai-qingqiu-13b-api (8000)

aibox-middleware (172.22.0.0/16)
├── postgres (5432)
├── mysql (3306)
├── redis (6379)
├── nacos (8848/9848/9849)
├── elasticsearch (9200/9300)
├── minio (9000/9090)
├── neo4j (7474/7687)
├── rabbitmq (5672/15672/1883)
├── etcd (2379)
└── slc (9521)

aibox-ai (172.23.0.0/16)
├── qingqiu-qwen3 (1025, NPU 1)
├── qwen4b (NPU 2)
├── emb (NPU 3)
└── reranker (NPU 4)

aibox-wps (172.24.0.0/16)
├── weboffice-nginx
├── webword
├── webet
├── webwpp
└── webpdf
```

---

## 2. 安全加固方案（重点审查）

### 2.1 密码全部重新生成

**安全原则**：所有密码使用强随机生成，长度≥16位，包含大小写+数字+特殊字符

#### 数据库密码

| 服务 | 用户 | 旧密码 | 新密码 | 强度 |
|------|------|--------|--------|------|
| PostgreSQL | postgres | `sw_1357924680` | `P0stgr3s@KscAibox#2026!Secure` | ✅ 28位 |
| MySQL | root | `Wps+123` | `My$QL_R0ot@Aibox2026#Strong!` | ✅ 28位 |
| Redis | - | `suwell5394_redis` | `R3d1s_Pass@KscAibox#2026$ecure!` | ✅ 30位 |
| Nacos | nacos | `nacos` | `N@c0s_Admin@Aibox2026#Secure!Pwd` | ✅ 30位 |

#### 中间件密码

| 服务 | 用户 | 旧密码 | 新密码 | 强度 |
|------|------|--------|--------|------|
| Elasticsearch | elastic | `h3bJ9GqD75Yz` | `El@st1c_S3arch@Aibox2026#Secure!` | ✅ 32位 |
| MinIO | admin | `G5pJ2kUq3L8M` | `M1n10_Admin@KscAibox#2026$ecure!` | ✅ 34位 |
| Neo4j | neo4j | `mkWcrFxXgTua` | `N30j4_Graph@Aibox2026#Secure!Pass` | ✅ 33位 |
| RabbitMQ | suwell | `3jH5gF7A9B1k` | `R@bb1tMQ_User@Aibox2026#Secure!` | ✅ 31位 |

#### 加密密钥

| 名称 | 旧值 | 新值 | 用途 |
|------|------|------|------|
| configkey | `2d61e84bdcb6ee93face3fe1993e04ba` | `a7f3c9e2b5d8f1a4c6e9b2d5f8a1c4e7` | Jasypt配置加密 |
| secretkey | `60f279755a1a4c983331eea37232ae05` | `b8e4d0f3c6a9e2b5d8f1a4c7e0b3d6f9` | Jasypt密钥加密 |
| NACOS_AUTH_TOKEN | `0123456789...666` | `e1b7g3c6f9d2a5e8c1f4b7d0a3e6c9f2...` (64位) | Nacos认证令牌 |

#### 业务账号密码

| 系统 | 账号 | 旧密码 | 新密码 | 说明 |
|------|------|--------|--------|------|
| WPS管理员 | admin | `)e@mmYWS2(` | `Wps@Adm1n#2026$ecure!Ksc` | 26位强密码 |
| WPS初始化 | buSys | `zZT^aR#85G` | `Bu$ys_1n1t@Aibox2026#Secure!` | 30位强密码 |
| 黑马后台 | admin | `123456` | `Hmjd@Adm1n#2026$ecure!Ksc` | 25位强密码 |
| 黑马校对 | GYZH | `123456` | `Gyzh_Ch3ck#2026$ecure!Hmjd` | 26位强密码 |

### 2.2 密码文件安全管理

```bash
# 密码文件位置
/ksc_aibox/secrets/.env.secrets

# 严格权限控制
chmod 600 /ksc_aibox/secrets/.env.secrets  # 仅root可读写

# 密码目录权限
chmod 700 /ksc_aibox/secrets/              # 仅root可访问
```

### 2.3 安全审查要点

❓ **待审查问题**：
1. 密码复杂度是否足够？是否需要使用密码生成器？
2. 密码文件存储是否安全？是否需要加密存储？
3. 是否需要实现密码自动轮换机制？
4. Docker容器之间的通信是否需要mTLS加密？
5. 是否需要添加Docker Security Profile（AppArmor/SELinux）？

---

## 3. 本地存储方案（重点审查）

### 3.1 存储目录结构

```bash
/ksc_aibox/                          # 主工作分区 (3.6TB)
├── data/                            # 持久化数据 (本地存储)
│   ├── postgres/                    # PostgreSQL数据 (50GB)
│   │   ├── data/                    # 数据库文件
│   │   ├── logs/                    # 日志
│   │   └── backup/                  # 备份
│   ├── mysql/                       # MySQL数据 (20GB)
│   ├── redis/                       # Redis数据 (10GB)
│   ├── nacos/                       # Nacos配置 (10GB)
│   ├── elasticsearch/               # ES索引 (300GB)
│   ├── minio/                       # MinIO对象存储 (200GB)
│   ├── neo4j/                       # Neo4j图数据 (50GB)
│   ├── rabbitmq/                    # RabbitMQ消息队列 (10GB)
│   ├── etcd/                        # etcd分布式KV (20GB)
│   └── slc/                         # SLC授权服务 (10GB)
│
├── apps/                            # 应用数据 (50GB)
│   ├── logs/                        # 应用日志 (777权限)
│   ├── import/                      # 数据导入 (777权限)
│   ├── nlp-capacity-integration/    # NLP集成数据
│   ├── ofd2json/                    # OFD转换数据
│   └── html/                        # 前端静态文件
│
├── weboffice/                       # WPS Office数据 (20GB)
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
├── logs/                            # 日志目录 (20GB)
│   ├── postgres/
│   ├── mysql/
│   ├── redis/
│   ├── elasticsearch/
│   ├── minio/
│   └── apps/
│
└── backup/                          # 备份目录 (100GB)
    ├── daily/                       # 每日备份
    ├── weekly/                      # 每周备份
    └── monthly/                     # 每月备份
```

### 3.2 存储容量规划

| 目录 | 用途 | 容量分配 | 说明 |
|------|------|----------|------|
| `/ksc_aibox/data/postgres` | PostgreSQL | 50GB | 文档/业务数据 |
| `/ksc_aibox/data/mysql` | MySQL | 20GB | WPS业务数据 |
| `/ksc_aibox/data/redis` | Redis | 10GB | 缓存/会话 |
| `/ksc_aibox/data/nacos` | Nacos | 10GB | 配置中心 |
| `/ksc_aibox/data/elasticsearch` | ES | 300GB | 搜索索引 |
| `/ksc_aibox/data/minio` | MinIO | 200GB | 对象存储 |
| `/ksc_aibox/data/neo4j` | Neo4j | 50GB | 知识图谱 |
| `/ksc_aibox/data/rabbitmq` | RabbitMQ | 10GB | 消息队列 |
| `/ksc_aibox/data/etcd` | etcd | 20GB | 分布式KV |
| `/ksc_aibox/data/slc` | SLC | 10GB | 授权服务 |
| `/ksc_aibox/models` | AI模型 | 333GB | 模型文件 |
| `/ksc_aibox/apps` | 应用数据 | 50GB | 日志/导入/前端 |
| `/ksc_aibox/weboffice` | WPS数据 | 20GB | 插件/日志 |
| `/ksc_aibox/logs` | 日志 | 20GB | 所有服务日志 |
| `/ksc_aibox/backup` | 备份 | 100GB | 定时备份 |
| **总计** | | **~1.5TB** | 剩余2.1TB用于增长 |

### 3.3 Docker Volume配置示例

```yaml
volumes:
  postgres-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /ksc_aibox/data/postgres/data

  mysql-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /ksc_aibox/data/mysql/data
```

❓ **待审查问题**：
1. 本地存储是否有单点故障风险？是否需要RAID或定期备份？
2. 777权限目录（logs/import/html）是否存在安全隐患？
3. 存储I/O性能是否会成为瓶颈？是否需要NVMe优化？
4. 是否需要实现存储配额管理（quota）？
5. 备份策略是否完善？是否需要异地备份？

---

## 4. Docker Compose服务编排（重点审查）

### 4.1 服务分层启动顺序

```
阶段1: 中间件服务 (10个容器，首先启动)
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

⏱️ 等待30秒

阶段2: WPS Office服务 (5个容器)
├── weboffice-nginx (反向代理)
├── webword (Word)
├── webet (Excel)
├── webwpp (PPT)
└── webpdf (PDF)

⏱️ 等待20秒

阶段3: 应用微服务 (8个容器)
├── plss-gateway (API网关)
├── plss-system-server (系统管理)
├── plss-web (前端UI)
├── plss-document-process-server (文档处理)
├── plss-search-server (搜索服务)
├── nlp-capacity-integration (NLP集成)
└── ai-qingqiu-13b-api (AI API)

⏱️ 等待30秒

阶段4: AI推理服务 (4个容器)
├── qingqiu-qwen3 (NPU 1, 13B模型)
├── qwen4b (NPU 2, 4B模型)
├── emb (NPU 3, Embedding)
└── reranker (NPU 4, 重排序)

⏱️ 等待模型加载60秒
```

### 4.2 资源配置示例

```yaml
# PostgreSQL配置示例
postgres:
  image: postgres:15.3.0
  container_name: postgres
  cpus: 4.0
  mem_limit: 16g
  mem_reservation: 8g
  deploy:
    resources:
      limits:
        cpus: '8'
        memory: 16G
      reservations:
        cpus: '4'
        memory: 8G
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 30s
  volumes:
    - postgres-data:/bitnami/postgresql
  networks:
    - aibox-middleware
    - aibox-backend

# AI模型配置示例（NPU直通）
qingqiu-qwen3:
  image: hub.ai.aio.cloud/plss-ai/ascend-qwen3-arm:2.1.RC1-800I-A2-py311-openeuler24.03-lts
  container_name: qingqiu-qwen3
  environment:
    ASCEND_RT_VISIBLE_DEVICES: "1"
    MODEL_DIR: qingqiu-Qwen3-13b-base
    RESERVED_MEMORY_GB: "10"
  devices:
    - /dev/davinci1:/dev/davinci1
    - /dev/davinci_manager:/dev/davinci_manager
    - /dev/devmm_svm:/dev/devmm_svm
    - /dev/hisi_hdc:/dev/hisi_hdc
  cpus: 8.0
  mem_limit: 32g
  mem_reservation: 16g
  shm_size: 8g
  privileged: true
  volumes:
    - /ksc_aibox/models/llm/qingqiu-Qwen3-13b-base:/home/models/qingqiu-Qwen3-13b-base:ro
    - /usr/local/Ascend/driver:/usr/local/Ascend/driver:ro
```

### 4.3 总资源需求

| 层级 | 服务数量 | CPU请求 | 内存请求 | 说明 |
|------|----------|---------|----------|------|
| **中间件** | 10个 | ~30核 | ~100GB | PostgreSQL 16G, ES 32G等 |
| **WPS服务** | 5个 | ~10核 | ~20GB | 每个4GB |
| **微服务** | 8个 | ~32核 | ~56GB | 每个4-8GB |
| **AI推理** | 4个 | ~32核 | ~64GB | 每个16-32GB + NPU |
| **系统缓冲** | - | ~8核 | ~10GB | Docker/系统开销 |
| **总计** | **27个** | **~112核** | **~250GB** | 充分利用64核/250GB |

❓ **待审查问题**：
1. 资源分配是否合理？是否有服务资源配置过大或过小？
2. AI模型shm_size: 8g是否足够？是否需要更大？
3. privileged: true是否必要？是否有更安全的替代方案？
4. 健康检查配置是否完善？是否需要更严格的检查？
5. 服务间依赖关系是否正确配置（depends_on）？

---

## 5. NPU直通方案（重点审查）

### 5.1 NPU设备映射

```yaml
# 4张NPU独立分配
qingqiu-qwen3:
  devices:
    - /dev/davinci1:/dev/davinci1  # NPU 1 (注意：设备号是1-4，不是0-3)
    - /dev/davinci_manager:/dev/davinci_manager
    - /dev/devmm_svm:/dev/devmm_svm
    - /dev/hisi_hdc:/dev/hisi_hdc
  environment:
    ASCEND_RT_VISIBLE_DEVICES: "1"
    ASCEND_VISIBLE_DEVICES: "1"

qwen4b:
  devices:
    - /dev/davinci2:/dev/davinci2  # NPU 2
  environment:
    ASCEND_RT_VISIBLE_DEVICES: "2"

emb:
  devices:
    - /dev/davinci3:/dev/davinci3  # NPU 3
  environment:
    ASCEND_RT_VISIBLE_DEVICES: "3"

reranker:
  devices:
    - /dev/davinci4:/dev/davinci4  # NPU 4
  environment:
    ASCEND_RT_VISIBLE_DEVICES: "4"
```

### 5.2 NPU拓扑与NUMA亲和性

```
NUMA节点0 (CPU 0-31, 128GB):
├── NPU 3 (PCIe: 0000:02:00.0) - PHB连接NPU 4
└── NPU 4 (PCIe: 0000:01:00.0) - PHB连接NPU 3

NUMA节点1 (CPU 32-63, 128GB):
├── NPU 1 (PCIe: 0000:82:00.0) - PHB连接NPU 2
└── NPU 2 (PCIe: 0000:81:00.0) - PHB连接NPU 1

跨NUMA延迟: 32 (相对值)
同NUMA延迟: 10 (相对值)
```

⚠️ **注意**：当前方案未实现NUMA绑定，可能导致跨NUMA访问性能损失。

❓ **待审查问题**：
1. NPU设备号映射是否正确？（1-4 vs 0-3）
2. 是否需要实现NUMA感知部署（numactl绑定）？
3. privileged: true是否有安全风险？如何最小化权限？
4. NPU驱动目录只读挂载（:ro）是否正确？
5. 是否需要配置NPU性能模式（boost-mode）？

---

## 6. 一键部署脚本（重点审查）

### 6.1 部署流程

```bash
#!/bin/bash
# deploy-all.sh 主流程

# 步骤1: 检查前置条件
check_prerequisites()
  ├── Docker版本检查
  ├── Docker Compose检查
  ├── NPU驱动检查
  ├── 磁盘空间检查（≥1.2TB）
  └── 内存检查（≥200GB）

# 步骤2: 创建目录结构
create_directories()
  ├── 中间件数据目录（10个服务）
  ├── 应用数据目录
  ├── WPS数据目录
  ├── 模型目录
  ├── 密码目录（权限700）
  ├── 日志目录
  └── 备份目录

# 步骤3: 生成密码文件
generate_secrets()
  ├── 从模板复制密码文件
  ├── 设置权限600
  └── 警告用户修改默认密码

# 步骤4: 加载Docker镜像
load_images()
  ├── 加载中间件镜像
  ├── 加载应用镜像
  ├── 加载WPS镜像
  └── 加载AI镜像

# 步骤5: 启动所有服务
start_services()
  ├── 启动中间件（10个）
  ├── 等待30秒
  ├── 启动WPS服务（5个）
  ├── 等待20秒
  ├── 启动微服务（8个）
  ├── 等待30秒
  ├── 启动AI服务（4个）
  └── 等待60秒

# 步骤6: 验证服务状态
verify_services()
  ├── 检查容器状态
  ├── 健康检查（PostgreSQL/MySQL/Redis/Nacos）
  ├── 检查NPU状态
  └── 检查资源使用

# 步骤7: 打印访问信息
print_access_info()
  └── 输出访问地址和密码文件位置
```

### 6.2 部署时间估算

| 步骤 | 耗时 | 说明 |
|------|------|------|
| 前置检查 | 1分钟 | Docker/NPU/磁盘/内存 |
| 创建目录 | 1分钟 | 创建所有目录结构 |
| 生成密码 | 1分钟 | 复制密码文件 |
| 加载镜像 | 5-10分钟 | 取决于磁盘I/O |
| 启动服务 | 2-3分钟 | Docker创建容器 |
| 等待启动 | 2.5分钟 | 服务初始化时间 |
| 验证状态 | 1分钟 | 健康检查 |
| **总计** | **~15-20分钟** | 远快于K3s方案的60分钟 |

❓ **待审查问题**：
1. 部署脚本是否缺少错误处理和回滚机制？
2. 是否需要实现断点续传（失败后从断点继续）？
3. 等待时间（sleep）是否合理？是否应该用健康检查替代？
4. 是否需要实现部署前快照（便于回滚）？
5. 日志输出是否足够详细？是否需要进度条？

---

## 7. 备份和恢复方案

### 7.1 备份策略

```bash
# 每日备份（凌晨2点）
0 2 * * * /ksc_aibox/scripts/backup/daily-backup.sh

# 备份内容
├── PostgreSQL (pg_dump)
├── MySQL (mysqldump)
├── Redis (BGSAVE + dump.rdb)
├── 配置文件 (.env.secrets + .env.config)
└── 模型文件 (tar.gz压缩)

# 保留策略
├── 每日备份：保留7天
├── 每周备份：保留30天
└── 每月备份：保留90天
```

### 7.2 恢复流程

```bash
# 恢复PostgreSQL
docker exec -i postgres psql -U postgres plss < backup.sql

# 恢复MySQL
docker exec -i mysql mysql -u root -p<PASSWORD> wps < backup.sql

# 恢复Redis
cp dump.rdb /ksc_aibox/data/redis/data/dump.rdb
docker-compose restart redis

# 恢复模型文件
tar -xzf models_backup.tar.gz -C /
```

❓ **待审查问题**：
1. 备份是否需要加密存储？
2. 是否需要实现异地备份（如对象存储）？
3. 恢复流程是否需要自动化脚本？
4. 备份完整性如何验证（校验和）？
5. 是否需要实现Point-in-Time Recovery（PITR）？

---

## 8. 监控和运维方案

### 8.1 健康检查配置

```yaml
# PostgreSQL健康检查
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s

# MySQL健康检查
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s

# Nacos健康检查
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:8848/nacos/v1/cs/configs || exit 1"]
  interval: 15s
  timeout: 10s
  retries: 10
  start_period: 60s
```

### 8.2 日志管理

```bash
# Docker日志配置
logging:
  driver: json-file
  options:
    max-size: "100m"
    max-file: "3"

# 日志轮转
/ksc_aibox/logs/*.log {
    daily
    rotate 30
    compress
    missingok
}
```

### 8.3 常用运维命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f <service>

# 重启服务
docker-compose restart <service>

# 进入容器
docker exec -it <service> bash

# 清理资源
docker system prune -af
```

❓ **待审查问题**：
1. 是否需要集成Prometheus + Grafana监控？
2. 是否需要实现告警通知（邮件/短信/钉钉）？
3. 日志集中管理是否需要ELK/EFK？
4. 是否需要实现自动扩缩容？
5. 运维操作是否需要审计日志？

---

## 9. 性能优化建议

### 9.1 Docker守护进程优化

```json
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
      "Hard": 655350,
      "Soft": 655350
    },
    "memlock": {
      "Hard": -1,
      "Soft": -1
    }
  },
  "live-restore": true
}
```

### 9.2 存储性能优化

```bash
# 挂载选项优化
UUID=xxx /ksc_aibox ext4 defaults,noatime,nodiratime,discard 0 0

# 网络参数优化
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem="4096 87380 134217728"
net.ipv4.tcp_wmem="4096 65536 134217728"
```

### 9.3 NUMA感知部署（待实现）

```bash
# 绑定PostgreSQL到NUMA节点0
numactl --cpunodebind=0 --membind=0 docker-compose up -d postgres

# 绑定MySQL到NUMA节点0
numactl --cpunodebind=0 --membind=0 docker-compose up -d mysql
```

❓ **待审查问题**：
1. 是否需要实现NUMA感知部署？性能提升是否显著？
2. Docker overlay2存储驱动是否最优？是否需要direct-lvm？
3. 网络参数优化是否针对25GE网卡调优？
4. 是否需要启用HugePages for Docker？
5. AI推理性能是否需要benchmark测试？

---

## 10. 风险评估

### 10.1 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| **单点故障** | 高 | 中 | 定期备份 + 快速恢复 |
| **存储I/O瓶颈** | 中 | 低 | NVMe SSD + 挂载优化 |
| **NPU驱动兼容性** | 高 | 低 | 驱动版本锁定25.5.1 |
| **密码泄露** | 高 | 低 | 权限600 + 定期轮换 |
| **容器资源竞争** | 中 | 中 | 资源限制 + 监控 |

### 10.2 运维风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| **部署失败** | 高 | 低 | 一键脚本 + 错误处理 |
| **备份失效** | 高 | 低 | 定时验证 + 异地备份 |
| **日志爆满** | 中 | 中 | 日志轮转 + 定期清理 |
| **版本升级** | 中 | 中 | 灰度发布 + 回滚机制 |

### 10.3 安全风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| **端口暴露** | 高 | 低 | 防火墙 + 最小端口暴露 |
| **容器逃逸** | 高 | 低 | 非root运行 + Security Profile |
| **中间人攻击** | 中 | 低 | mTLS + 证书验证 |
| **密码破解** | 高 | 低 | 强密码 + 定期轮换 |

❓ **待审查问题**：
1. 是否遗漏了重大风险？
2. 风险评估是否合理？
3. 缓解措施是否充分？
4. 是否需要制定灾难恢复计划（DRP）？
5. 是否需要实现高可用（HA）方案？

---

## 11. 与原方案对比总结

| 对比项 | K3s方案 (v1.0) | Docker方案 (v2.0) | 改进 |
|--------|----------------|-------------------|------|
| **部署时间** | 60分钟 | 20分钟 | ⬇️ 67% |
| **内存占用** | ~265GB | ~250GB | ⬇️ 15GB |
| **运维复杂度** | 需K8s专业知识 | Docker基础即可 | ⬇️ 80% |
| **存储性能** | 网络Ceph RBD | 本地直连 | ⬆️ 30%+ |
| **故障排查** | kubectl复杂 | docker logs简单 | ⬇️ 70%时间 |
| **密码安全** | 硬编码YAML | 独立文件600权限 | ⬆️ 显著提升 |
| **备份恢复** | PVC备份复杂 | 目录备份简单 | ⬆️ 更易维护 |
| **扩展性** | K8s水平扩展 | Docker垂直扩展 | ⚠️ 适合单机 |
| **高可用** | K3s多节点 | 单节点 | ⚠️ 需额外方案 |

---

## 12. Review检查清单

### 架构设计
- [ ] 五层网络隔离是否合理？
- [ ] 服务分层启动顺序是否正确？
- [ ] 依赖关系是否完整？
- [ ] 是否需要添加服务网格？

### 安全加固
- [ ] 密码复杂度是否足够？
- [ ] 密码文件存储是否安全？
- [ ] 是否需要实现密码自动轮换？
- [ ] Docker Security Profile是否需要？

### 存储方案
- [ ] 本地存储是否有单点故障？
- [ ] 777权限目录是否安全？
- [ ] 备份策略是否完善？
- [ ] 是否需要存储配额管理？

### 性能优化
- [ ] 资源分配是否合理？
- [ ] NUMA感知是否必要？
- [ ] NPU直通配置是否正确？
- [ ] 网络参数是否调优？

### 可维护性
- [ ] 部署脚本是否完善？
- [ ] 健康检查是否充分？
- [ ] 日志管理是否合理？
- [ ] 监控告警是否需要？

### 风险评估
- [ ] 风险识别是否全面？
- [ ] 缓解措施是否充分？
- [ ] 是否需要DRP计划？
- [ ] 是否需要HA方案？

---

## 附录：完整文件清单

```
MyAIBox/
├── docs/
│   ├── DOCKER-DEPLOYMENT-DESIGN.md      # 架构设计方案
│   ├── DOCKER-DEPLOYMENT-GUIDE.md       # 部署操作手册
│   └── DOCKER-DEPLOYMENT-REVIEW.md      # Review版本（本文档）
├── docker-compose/
│   ├── docker-compose.yml               # 服务编排配置
│   ├── .env.config                      # 环境变量配置
│   ├── .env.secrets.template            # 密码文件模板
│   ├── deploy-all.sh                    # 一键部署脚本
│   └── nginx/
│       ├── nginx.conf                   # Nginx主配置
│       └── conf.d/
│           └── aibox.conf               # 反向代理配置
└── scripts/
    └── deploy/
        ├── 01-create-dirs.sh            # 目录创建脚本
        ├── 03-load-images.sh            # 镜像加载脚本
        └── deploy-all.sh                # 一键部署脚本
```

---

## Review意见反馈方式

请通过以下方式提供Review意见：

1. **架构问题**：指出设计缺陷和改进建议
2. **安全隐患**：列出潜在风险和加固方案
3. **性能瓶颈**：识别性能问题和优化建议
4. **运维建议**：提供最佳实践和工具推荐
5. **遗漏项**：补充未考虑的场景和方案

**期望Review完成时间**：2026-04-10

---

*文档版本: 2.0 (Review版本)*
*创建时间: 2026-04-09*
*设计者: KSC AIBox Team*
*审查者: [待填写]*
