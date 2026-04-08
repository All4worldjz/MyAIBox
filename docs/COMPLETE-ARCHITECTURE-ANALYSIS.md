# KSC AIBox 一体机系统 - 完整架构深度解析

> 基于服务器 `/ksc_aibox/source` 目录下63GB安装包的完整逆向工程分析
> 分析时间: 2026-04-09
> 版本: ytj-install-3.7.0-arm64-AI_910B-20260408-126

---

## 目录

1. [系统整体设计哲学](#1-系统整体设计哲学)
2. [核心架构发现](#2-核心架构发现)
3. [完整服务清单和依赖关系](#3-完整服务清单和依赖关系)
4. [安装流程深度解析](#4-安装流程深度解析)
5. [K3s集群配置要求](#5-k3s集群配置要求)
6. [持久化存储方案](#6-持久化存储方案)
7. [数据流向和调用链](#7-数据流向和调用链)
8. [与之前理解的对比](#8-与之前理解的对比)
9. [关键配置参数汇总](#9-关键配置参数汇总)
10. [部署检查清单](#10-部署检查清单)

---

## 1. 系统整体设计哲学

### 1.1 设计模式

这是一个**基于K3s的离线一体机部署方案**，采用以下设计模式：

```
┌─────────────────────────────────────────────────────────────┐
│                    离线安装包模式                             │
│  63GB tar包 = 镜像tar + YAML配置 + SQL脚本 + 模型文件        │
└─────────────────────────────────────────────────────────────┘
         ↓ 解压
┌─────────────────────────────────────────────────────────────┐
│              Shell脚本顺序安装模式                            │
│  import_image → kubectl apply → check_pod → exec_script     │
└─────────────────────────────────────────────────────────────┘
         ↓ 执行
┌─────────────────────────────────────────────────────────────┐
│              K3s容器编排管理                                  │
│  所有服务运行在K3s集群中，使用namespace: middle               │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心设计理念

| 设计理念 | 说明 | 实现方式 |
|----------|------|----------|
| **离线部署** | 无需外网，所有依赖内置 | 镜像打包为tar，本地import |
| **一键安装** | Shell脚本自动化 | install-middle.sh / install-app.sh |
| **容器化** | 所有服务容器化运行 | K3s + Docker + ctr |
| **配置外置** | 配置与代码分离 | ConfigMap + 外部SQL |
| **版本管理** | 支持升级和回滚 | update.sh脚本 |
| **多版本支持** | 安全版/众泰版 | PostgreSQL模板分支 |

---

## 2. 核心架构发现

### 2.1 技术栈真相

**之前理解** vs **实际情况**：

| 项目 | 之前理解 | 实际情况 | 差异说明 |
|------|----------|----------|----------|
| **容器编排** | K3s待安装 | **已安装K3s + Harbor** | K3s和Harbor已运行 |
| **镜像仓库** | 无 | **Harbor (hub.ai.aio.cloud)** | 本地Harbor仓库 |
| **安装方式** | Ansible自动化 | **Shell脚本手动安装** | 官方提供Shell脚本 |
| **存储类** | local-path | **csi-rbd-sc (Ceph RBD)** | 使用Ceph分布式存储 |
| **AI推理** | vLLM | **自研Ascend容器** | 非vLLM，是定制镜像 |
| **应用数量** | 约10个 | **15个应用 + 10个中间件** | 更复杂的微服务架构 |

### 2.2 系统运行原理

```
用户访问 (http://server:30080)
  ↓
[Web前端层]
├── plss-web (前端UI)
├── weboffice (WPS Office Web)
└── 黑马校对Web
  ↓ HTTP
[API网关层]
└── plss-gateway (端口8064) - 统一入口
  ↓ 路由
[微服务层] (全部在namespace: middle)
├── plss-system-server - 系统管理
├── plss-open-server - 开放API
├── plss-document-process-server - 文档处理
├── plss-record-server - 记录服务
├── plss-search-server - 搜索服务
├── plss-plugin-server - 插件服务
├── plss-nlp-draft - NLP起草
├── nlp-application - NLP应用
├── nlp-capacity-integration - NLP容量集成
├── ai-qingqiu-13b-api - AI API网关
├── ocr-ss - OCR识别
├── convert-edms - 文档转换
└── reader-svc - 阅读服务
  ↓ 依赖
[AI推理层]
├── qingqiu-qwen3 (NPU 0, 端口1025) - 13B模型
├── qwen4b (NPU ?, 端口?) - 4B模型
├── emb - Embedding模型
└── reranker - 重排序模型
  ↓ 依赖
[中间件层]
├── PostgreSQL (plss数据库)
├── MySQL (wps数据库)
├── Redis (缓存)
├── Nacos (配置中心)
├── Elasticsearch (搜索索引)
├── MinIO (对象存储)
├── Neo4j (知识图谱)
├── RabbitMQ (消息队列)
├── etcd (分布式KV)
└── slc (授权服务)
```

### 2.3 关键发现

#### 发现1: Nacos配置中心是核心

```bash
# 所有微服务都连接Nacos
plss-gateway环境变量:
- nacos_server: "nacos-svc:8848"
- nacos_username: "nacos"
- nacos_password: "nacos"

# Nacos导入配置文件
nacos-config-ytj-3.7.0.zip (107KB)
```

**说明**: Nacos存储所有微服务的配置，包括数据库连接、密钥、功能开关等。

#### 发现2: 数据库双引擎架构

```
PostgreSQL (plss数据库):
├── 用户: postgres / suwell
├── 密码: sw_1357924680
├── 数据库: postgres / plss
├── 用途: 文档、业务数据
└── 模板: anquan(安全版) / zhongtai(众泰版)

MySQL (wps数据库):
├── 用户: root
├── 密码: Wps+123
├── 数据库: wps
└── 用途: WPS Office业务数据
```

#### 发现3: AI模型使用自研容器

```yaml
# 不是vLLM，是定制镜像
image: hub.ai.aio.cloud/plss-ai/ascend-qwen3-arm:2.1.RC1-800I-A2-py311-openeuler24.03-lts

# NPU配置
env:
  - name: ASCEND_RT_VISIBLE_DEVICES
    value: "0"  # 使用NPU 0
  - name: MODEL_DIR
    value: "qingqiu-Qwen3-13b-base"
  - name: RESERVED_MEMORY_GB
    value: "10"

resources:
  limits:
    huawei.com/Ascend910B: 1  # NPU资源
```

#### 发现4: 镜像推送到Harbor

```bash
# 安装流程
1. ctr -n k8s.io image import xxx.tar  # 导入到containerd
2. ctr -n k8s.io images push hub.ai.aio.cloud/xxx  # 推送到Harbor
3. kubectl apply -f xxx.yaml  # K3s从Harbor拉取镜像
```

**说明**: 镜像先导入本地containerd，再推送到Harbor，最后K3s从Harbor拉取。

---

## 3. 完整服务清单和依赖关系

### 3.1 中间件清单 (10个)

| 服务名 | 镜像 | 端口 | PVC | 用途 | 依赖 |
|--------|------|------|-----|------|------|
| **postgres** | postgresql-arm64:15.3.0 | 5432 | 10Gi (csi-rbd-sc) | plss数据库 | 无 |
| **mysql** | mysql-arm64:8.3.0 | 3306 | 20Gi (csi-rbd-sc) | wps数据库 | 无 |
| **redis** | redis-arm64:xxx | 6379 | - | 缓存 | 无 |
| **nacos** | nacos-server:v2.3.2-slim | 8848/9848/9849 | - (nacos-pvc-data) | 配置中心 | 无 |
| **elasticsearch** | elasticsearch-arm64:xxx | 9200 | - | 搜索索引 | 无 |
| **minio** | minio:xxx | 9000/9001 | - | 对象存储 | 无 |
| **neo4j** | neo4j:xxx | 7687 | - | 知识图谱 | 无 |
| **rabbitmq** | rabbitmq:xxx | 5672/15672 | - | 消息队列 | 无 |
| **etcd** | etcd:xxx | 2379/2380 | - | 分布式KV | 需配置地址 |
| **slc** | slc:xxx | - | - | 授权服务 | 无 |

### 3.2 应用服务清单 (15个)

| 服务名 | 镜像 | 端口 | 特殊配置 | 用途 |
|--------|------|------|----------|------|
| **plss-gateway** | plss-gateway-arm64:20251017-644-WPS | 8064 | ConfigMap(configkey/secretkey) | API网关 |
| **plss-system-server** | plss-system-server-arm64:xxx | - | - | 系统管理 |
| **plss-open-server** | plss-open-server-arm64:xxx | - | - | 开放API |
| **plss-document-process-server** | plss-document-process-server-arm64:xxx | - | /data/app/logs | 文档处理 |
| **plss-record-server** | plss-record-server-arm64:xxx | - | - | 记录服务 |
| **plss-search-server** | plss-search-server-arm64:xxx | - | /data/app/ofd2json | 搜索服务 |
| **plss-plugin-server** | plss-plugin-server-arm64:xxx | - | - | 插件服务 |
| **plss-web** | plss-web-arm64:xxx | 30080 | /data/app/html/aiPlatform | 前端UI |
| **plss-nlp-draft** | plss-nlp-draft-arm64:xxx | - | - | NLP起草 |
| **nlp-application** | nlp-application-arm64:xxx | - | - | NLP应用 |
| **nlp-capacity-integration** | nlp-capacity-integration-arm64:xxx | - | /data/app/nlp-capacity-integration | NLP集成 |
| **ai-qingqiu-13b-api** | ai-qingqiu-13b-api-arm64:xxx | - | - | AI API |
| **ocr-ss** | ocr-ss-arm64:xxx | - | - | OCR识别 |
| **convert-edms** | convert-edms-arm64:xxx | - | - | 文档转换 |
| **reader-svc** | reader-svc-arm64:xxx | - | 需替换http_address_ip | 阅读服务 |

### 3.3 WPS Office服务 (11个)

| 服务名 | 用途 |
|--------|------|
| **apiserver** | API服务器 |
| **webword** | Word Web版 |
| **webpdf** | PDF Web版 |
| **webwpp** | PPT Web版 |
| **webet** | Excel Web版 |
| **htmlserver** | HTML渲染 |
| **transcoder** | 转码服务 |
| **certserver** | 证书服务 |
| **cloudprovider** | 云服务 |
| **editproxy** | 编辑代理 |
| **staticserver** | 静态资源 |
| **sqlserver** | SQL Server (可选) |
| **weboffice-nginx** | Nginx反向代理 |
| **weboffice-conf** | 配置服务 |
| **encs-server** | 加密服务 |

### 3.4 AI模型服务 (4个)

| 模型名 | NPU | 端口 | 模型路径 | 用途 |
|--------|-----|------|----------|------|
| **qingqiu-qwen3** | NPU 0 | 1025 | /data/AI/qingqiu-Qwen3-13b-base | 13B对话模型 |
| **qwen4b** | NPU ? | ? | /data/AI/qwen4b | 4B对话模型 |
| **emb** | NPU ? | ? | - | Embedding模型 |
| **reranker** | NPU ? | ? | - | 重排序模型 |

### 3.5 完整依赖关系图

```
用户请求
  ↓
[plss-web: 30080] ────→ [weboffice-nginx: 80/443]
  ↓                        ↓
[plss-gateway: 8064] ←── [WPS Office服务集群]
  ↓                        ↓
[微服务集群] ──────────→ [MySQL: wps数据库]
  ↓                        ↓
[ai-qingqiu-13b-api] ──→ [PostgreSQL: plss数据库]
  ↓                        ↓
[qingqiu-qwen3: NPU0] ──→ [Nacos: 配置中心]
  ↓                        ↓
[NPU硬件] ──────────────→ [Redis: 缓存]
                           ↓
                        [MinIO: 对象存储]
                           ↓
                        [Elasticsearch: 搜索]
                           ↓
                        [Neo4j: 知识图谱]
                           ↓
                        [RabbitMQ: 消息队列]
```

---

## 4. 安装流程深度解析

### 4.1 官方安装步骤

```bash
# 步骤1: 安装中间件 (约30-60分钟)
bash install-middle.sh
# 输入: all (安装所有中间件)
# 或单独安装: postgres, mysql, redis, nacos, elasticsearch, minio, neo4j, rabbitmq, etcd, slc

# 步骤2: 安装WPS Office (约10-20分钟)
bash install-weboffice.sh
# 输入: 服务访问地址 (如 http://10.212.128.192:30080)

# 步骤3: 安装应用服务 (约20-40分钟)
bash install-app.sh
# 输入: all (安装所有应用)
# 或单独安装: plss-gateway, plss-web, plss-system-server等15个应用

# 步骤4: 安装AI模型 (约10-30分钟)
bash install-AI.sh
# 输入: 显卡类型 (AI_910B 或 AI_310P)
# 输入: 模型名称 (all 或 qingqiu-qwen3, qwen4b, emb, reranker)
```

### 4.2 每个步骤的详细流程

#### install-middle.sh 流程

```bash
1. create_harbor_project
   └── 创建Harbor项目: middleware, plss, weboffice, plss-ai

2. 对每个中间件执行:
   a. import_image
      ├── ctr -n k8s.io image import xxx.tar
      └── ctr -n k8s.io images push hub.ai.aio.cloud/middleware/xxx
   
   b. install_kubectl
      └── kubectl apply -f xxx/
   
   c. check_pod_status
      └── 等待Pod Running + Ready
   
   d. 执行特定脚本:
      ├── postgres: exec_postgres (执行SQL模板)
      ├── mysql: exec_mysql (执行create_table.sql)
      ├── nacos: exec_nacos (导入nacos-config-ytj-3.7.0.zip)
      └── etcd: exec_etcd (替换http_address_ip变量)
```

#### install-weboffice.sh 流程

```bash
1. import_image
   └── 导入WPS Office镜像并推送到Harbor

2. init_log_directory
   └── 创建 /data/weboffice/log (权限777)

3. init_weboffice_plugin
   └── 复制 weboffice/templates/plugins/* → /data/weboffice/html/

4. exec_plugin
   └── 替换 /data/weboffice/html/plugin.js 中的 http_address_ip

5. install_kubectl
   └── kubectl apply -f weboffice/ (11个YAML文件)
```

#### install-app.sh 流程

```bash
1. kubectl apply -f app/cm/  # 应用ConfigMap (configkey, secretkey)

2. 对每个应用执行:
   a. init_log_directory
      └── 创建 /data/app/logs (权限777)
   
   b. init_data_import_directory
      └── 创建 /data/app/import (权限777)
   
   c. 特殊初始化:
      ├── nlp-capacity-integration: 复制templates到/data/app/nlp-capacity-integration
      ├── plss-web: 复制templates/aiPlatform到/data/app/html
      ├── reader-svc: 替换yaml中的http_address_ip
      └── plss-search-server: 解压/data/app/ofd2json.tar
   
   d. import_image
      └── 导入应用镜像并推送到Harbor
   
   e. install_kubectl
      └── kubectl apply -f app/xxx/
   
   f. check_pod_status
      └── 等待Pod Running + Ready
```

#### install-AI.sh 流程

```bash
1. install_model (仅qingqiu-qwen3和qwen4b)
   └── tar xf AI_910B/models/xxx.tar -C /data/AI/

2. install_image
   ├── ctr -n k8s.io image import AI_910B/images/xxx.tar
   └── ctr -n k8s.io images push hub.ai.aio.cloud/plss-ai/xxx

3. start_AI
   └── kubectl create -f AI_910B/xxx/

4. check_pod_status
   └── 等待Pod Running + Ready
```

### 4.3 安装顺序依赖

```
install-middle.sh (必须先执行)
  ├── 创建namespace: middle
  ├── 创建Harbor项目
  ├── 启动数据库 (postgres, mysql)
  └── 启动配置中心 (nacos)
  ↓
install-weboffice.sh (依赖middle)
  ├── 需要MySQL运行 (sqlserver.yaml)
  └── 需要Harbor运行
  ↓
install-app.sh (依赖middle + weboffice)
  ├── 需要Nacos运行 (微服务配置)
  ├── 需要PostgreSQL运行 (业务数据)
  └── 需要MySQL运行 (WPS数据)
  ↓
install-AI.sh (依赖app)
  └── 需要ai-qingqiu-13b-api运行 (调用AI模型)
```

---

## 5. K3s集群配置要求

### 5.1 当前K3s环境

```bash
# 已安装的组件
K3s: ✓ 已运行
Harbor: ✓ 已运行 (hub.ai.aio.cloud)
Namespace: middle ✓ 已创建

# Harbor信息
Harbor地址: hub.ai.aio.cloud
Harbor用户: admin
Harbor密码: 从secret获取 (kubectl get secrets -n harbor harbor-core-envvars)
```

### 5.2 StorageClass配置

```yaml
# 使用Ceph RBD CSI存储
storageClassName: csi-rbd-sc

# 所有PVC都使用这个StorageClass
postgres-pvc: 10Gi
mysql-data-pvc: 20Gi
nacos-pvc-data: ?
qingqiu-qwen3-pvc: ?
```

**重要**: 需要确认Ceph集群是否已部署，以及`csi-rbd-sc` StorageClass是否存在。

### 5.3 资源需求汇总

| 服务类型 | CPU请求 | 内存请求 | CPU限制 | 内存限制 | 数量 |
|----------|---------|----------|---------|----------|------|
| **中间件** | 4-8核 | 8-16Gi | 8-16核 | 16-32Gi | 10 |
| **应用服务** | 30-60核 | 60-120Gi | 60-120核 | 120-240Gi | 15 |
| **WPS Office** | 10-20核 | 20-40Gi | 20-40核 | 40-80Gi | 11 |
| **AI模型** | 4-8核 | 8-16Gi + NPU | 8-16核 | 16-32Gi + NPU | 4 |
| **总计** | **48-96核** | **96-192Gi** | **96-192核** | **192-384Gi** | **40** |

**注意**: 服务器64核CPU + 250GB内存，资源紧张，需要合理配置。

### 5.4 NPU资源配置

```yaml
# NPU资源声明
resources:
  limits:
    huawei.com/Ascend910B: 1  # 每个AI模型容器使用1张NPU

# 当前4张NPU分配
NPU 0: qingqiu-qwen3 (13B模型)
NPU 1: qwen4b (4B模型)
NPU 2: emb (Embedding模型)
NPU 3: reranker (重排序模型)
```

---

## 6. 持久化存储方案

### 6.1 存储类型

| 存储类型 | 用途 | 容量 | StorageClass |
|----------|------|------|--------------|
| **Ceph RBD** | 数据库PVC | 30Gi+ | csi-rbd-sc |
| **HostPath** | AI模型文件 | /data/AI | 本地磁盘 |
| **HostPath** | 应用日志 | /data/app/logs | 本地磁盘 |
| **HostPath** | WPS文件 | /data/weboffice | 本地磁盘 |
| **HostPath** | NLP数据 | /data/app/nlp-capacity-integration | 本地磁盘 |
| **HostPath** | OFD转换 | /data/app/ofd2json | 本地磁盘 |
| **HostPath** | HTML前端 | /data/app/html | 本地磁盘 |

### 6.2 持久化目录结构

```
/data/                              # 应用数据根目录
├── AI/                             # AI模型文件 (HostPath)
│   ├── qingqiu-Qwen3-13b-base/    # 13B模型 (从backup恢复)
│   ├── qingqiu-Qwen3-13b-base-bak/ # 备份目录
│   └── ...
├── app/                            # 应用数据 (HostPath)
│   ├── logs/                      # 应用日志 (权限777)
│   ├── import/                    # 数据导入 (权限777)
│   ├── nlp-capacity-integration/  # NLP集成数据
│   ├── ofd2json/                  # OFD转换数据
│   └── html/                      # 前端静态文件
├── weboffice/                      # WPS Office数据 (HostPath)
│   ├── log/                       # WPS日志 (权限777)
│   └── html/                      # WPS插件文件
└── ...

# Ceph RBD存储 (通过PVC挂载)
/ksc_aibox/data/                   # 假设挂载点
├── postgres/                      # PostgreSQL数据 (10Gi PVC)
├── mysql/                         # MySQL数据 (20Gi PVC)
└── nacos/                         # Nacos数据 (PVC)
```

### 6.3 数据备份策略

```bash
# AI模型备份 (HostPath)
/data/AI/qingqiu-Qwen3-13b-base-bak/  # 模型备份目录

# 应用数据备份
/data/app/html-bak/                   # 前端备份
/data/app/nlp-capacity-integration-bak/ # NLP备份
/data/app/ofd2json-bak/               # OFD备份
/data/weboffice/html-bak/             # WPS备份

# 数据库备份 (需要手动执行)
kubectl exec -n middle postgres-pod -- pg_dump plss > plss_backup.sql
kubectl exec -n middle mysql-pod -- mysqldump wps > wps_backup.sql
```

---

## 7. 数据流向和调用链

### 7.1 用户文档处理流程

```
用户上传文档
  ↓
[plss-web: 30080] 前端界面
  ↓ HTTP
[plss-gateway: 8064] API网关
  ↓ 路由
[plss-document-process-server] 文档处理服务
  ↓ 
[plss-search-server] 搜索和索引
  ↓
[Elasticsearch] 全文检索
  ↓
[PostgreSQL: plss] 存储文档元数据
  ↓
[MinIO] 存储文档文件
  ↓
返回结果给用户
```

### 7.2 AI对话流程

```
用户输入问题
  ↓
[plss-web: 30080] 前端界面
  ↓ HTTP
[plss-gateway: 8064] API网关
  ↓ 路由
[ai-qingqiu-13b-api] AI API网关
  ↓ HTTP
[qingqiu-qwen3: 1025] AI推理服务
  ↓ 调用NPU 0
[NPU硬件] 模型推理
  ↓ 返回结果
[ai-qingqiu-13b-api] → [plss-gateway] → [plss-web] → 用户
  ↓ 异步
[PostgreSQL: plss] 保存对话历史
```

### 7.3 配置管理流程

```
Nacos配置中心 (hub.ai.aio.cloud/middleware/nacos-server)
  ├── 微服务配置 (plss-gateway, plss-system-server等)
  ├── 数据库连接 (PostgreSQL, MySQL, Redis)
  ├── 密钥管理 (configkey, secretkey)
  └── 功能开关
  
ConfigMap (K3s)
  ├── configkey: 2d61e84bdcb6ee93face3fe1993e04ba
  └── secretkey: 60f279755a1a4c983331eea37232ae05
```

---

## 8. 与之前理解的对比

### 8.1 重大差异

| 项目 | 之前理解 | 实际情况 | 影响 |
|------|----------|----------|------|
| **安装工具** | Ansible | Shell脚本 | 需要用Shell记录 |
| **AI推理** | vLLM | 自研Ascend容器 | 配置完全不同 |
| **存储** | local-path | Ceph RBD | 需要Ceph集群 |
| **镜像管理** | 无Harbor | Harbor仓库 | 镜像推送流程 |
| **配置中心** | 无 | Nacos | 核心依赖 |
| **应用数量** | ~10个 | 40+个 | 更复杂 |
| **数据库** | MySQL+PostgreSQL | +Nacos配置库 | 多一个配置库 |

### 8.2 需要调整的认知

1. **不再使用vLLM**: AI推理使用自研容器 `ascend-qwen3-arm:2.1.RC1-800I-A2-py311-openeuler24.03-lts`
2. **不再使用local-path**: 存储使用 `csi-rbd-sc` (Ceph RBD)
3. **不再单独安装数据库**: 数据库已打包在tar中，通过Shell脚本安装
4. **不再使用Docker Compose**: 全部使用K3s YAML文件
5. **Ansible角色变化**: 从"主要安装工具"变为"辅助配置工具"

---

## 9. 关键配置参数汇总

### 9.1 数据库配置

```yaml
PostgreSQL:
  用户: postgres / suwell
  密码: sw_1357924680
  数据库: postgres / plss
  最大连接: 500
  数据目录: /bitnami/postgresql (PVC: postgres-pvc, 10Gi)

MySQL:
  用户: root
  密码: Wps+123
  数据库: wps
  数据目录: /var/lib/mysql (PVC: mysql-data-pvc, 20Gi)
```

### 9.2 Nacos配置

```yaml
Nacos:
  用户: nacos
  密码: nacos
  端口: 8848/9848/9849
  模式: standalone
  配置导入: nacos-config-ytj-3.7.0.zip
```

### 9.3 AI模型配置

```yaml
qingqiu-qwen3:
  镜像: hub.ai.aio.cloud/plss-ai/ascend-qwen3-arm:2.1.RC1-800I-A2-py311-openeuler24.03-lts
  NPU: 0 (ASCEND_RT_VISIBLE_DEVICES=0)
  端口: 1025
  模型: qingqiu-Qwen3-13b-base
  模型路径: /data/AI/qingqiu-Qwen3-13b-base
  预留内存: 10GB
  NPU资源: huawei.com/Ascend910B: 1
```

### 9.4 密钥配置

```yaml
ConfigMap:
  configkey: 2d61e84bdcb6ee93face3fe1993e04ba
  secretkey: 60f279755a1a4c983331eea37232ae05

用途: 微服务加密解密 (jasypt)
```

---

## 10. 部署检查清单

### 10.1 安装前检查

```bash
# 1. 检查K3s状态
kubectl get nodes
kubectl get ns

# 2. 检查Harbor状态
kubectl get pods -n harbor

# 3. 检查StorageClass
kubectl get storageclass

# 4. 检查NPU状态
npu-smi info

# 5. 检查磁盘空间
df -h /ksc_aibox /data

# 6. 检查内存
free -h

# 7. 检查tar包完整性
ls -lh /ksc_aibox/source/ytj-install-3.7.0-arm64-AI_910B-20260408-126.tar
```

### 10.2 安装步骤检查

```bash
# 步骤1: 安装中间件
bash install-middle.sh
# 检查:
kubectl get pods -n middle | grep -E "postgres|mysql|redis|nacos|elasticsearch|minio|neo4j|rabbitmq|etcd|slc"

# 步骤2: 安装WPS Office
bash install-weboffice.sh
# 检查:
kubectl get pods -n middle | grep weboffice

# 步骤3: 安装应用
bash install-app.sh
# 检查:
kubectl get pods -n middle | grep plss

# 步骤4: 安装AI模型
bash install-AI.sh
# 检查:
kubectl get pods -n middle | grep qingqiu
npu-smi info
```

### 10.3 安装后验证

```bash
# 1. 检查所有Pod状态
kubectl get pods -n middle

# 2. 检查服务端口
kubectl get svc -n middle

# 3. 测试PostgreSQL连接
kubectl exec -n middle postgres-pod -- psql -U postgres -c "SELECT 1;"

# 4. 测试MySQL连接
kubectl exec -n middle mysql-pod -- mysql -uroot -pWps+123 -e "SELECT 1;"

# 5. 测试Nacos访问
curl http://nacos-svc:8848/nacos/v1/cs/configs

# 6. 测试AI模型
curl http://qingqiu-qwen3:1025/v1/chat/completions

# 7. 测试Web访问
curl http://localhost:30080
```

---

## 附录: 文件结构映射

```
/ksc_aibox/source/
├── install-middle.sh          # 中间件安装脚本
├── install-weboffice.sh       # WPS Office安装脚本
├── install-app.sh             # 应用安装脚本
├── install-AI.sh              # AI模型安装脚本
├── update.sh                  # 更新脚本
├── postgres/                  # PostgreSQL配置
│   ├── postgres.yaml
│   ├── pg-server.yaml
│   ├── images/
│   └── templates/
│       ├── init_postgres.sql
│       ├── set_config.sql
│       ├── anquan/
│       └── zhongtai/
├── mysql/                     # MySQL配置
│   ├── mysql.yaml
│   ├── images/
│   └── templates/
│       └── create_table.sql
├── nacos/                     # Nacos配置
│   ├── nacos.yaml
│   ├── nacos-server.yaml
│   ├── images/
│   └── templates/
│       └── nacos-config-ytj-3.7.0.zip
├── app/                       # 应用配置
│   ├── cm/                    # ConfigMap
│   │   ├── ck.yaml
│   │   └── sc.yaml
│   ├── plss-gateway/
│   ├── plss-web/
│   └── ... (15个应用)
├── weboffice/                 # WPS Office配置
│   ├── *.yaml (11个服务)
│   ├── images/
│   └── templates/
├── AI_910B/                   # AI模型配置
│   ├── qingqiu-qwen3/
│   ├── qwen4b/
│   ├── emb/
│   ├── reranker/
│   ├── images/
│   └── models/
├── redis/                     # Redis配置
├── elasticsearch/             # Elasticsearch配置
├── minio/                     # MinIO配置
├── neo4j/                     # Neo4j配置
├── rabbitmq/                  # RabbitMQ配置
├── etcd/                      # etcd配置
└── slc/                       # 授权服务配置
```

---

*文档生成时间: 2026-04-09*
*基于63GB安装包完整逆向分析*
*维护团队: KSC AIBox Team*
