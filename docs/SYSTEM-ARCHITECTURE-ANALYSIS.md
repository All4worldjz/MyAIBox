# KSC AIBox 金山政务AI一体机 - 完整系统架构分析

> 本文档全面梳理系统运行原理、架构设计、服务依赖关系、模型服务调用链路、K3s配置要求和持久化存储方案。

---

## 目录

1. [系统整体架构](#1-系统整体架构)
2. [服务依赖关系图](#2-服务依赖关系图)
3. [模型服务清单](#3-模型服务清单)
4. [应用服务清单](#4-应用服务清单)
5. [服务调用关系详解](#5-服务调用关系详解)
6. [K3s容器编排平台配置要求](#6-k3s容器编排平台配置要求)
7. [持久化存储配置方案](#7-持久化存储配置方案)
8. [NUMA拓扑与资源分配](#8-numa拓扑与资源分配)
9. [数据流向图](#9-数据流向图)
10. [部署顺序和依赖检查](#10-部署顺序和依赖检查)

---

## 1. 系统整体架构

### 1.1 架构分层设计

```
┌─────────────────────────────────────────────────────────────────────┐
│                        用户访问层 (User Layer)                       │
├─────────────────────────────────────────────────────────────────────┤
│  WPS Office Web  │  黑马校对Web  │  AI对话Web  │  管理后台Web        │
│  端口: 30080     │  端口: 8733   │  端口: 8122 │  端口: 9001        │
└─────────────────────────────────────────────────────────────────────┘
                              ↓ HTTP/HTTPS
┌─────────────────────────────────────────────────────────────────────┐
│                      应用服务层 (Application Layer)                  │
├─────────────────────────────────────────────────────────────────────┤
│  AI Service      │  WPS Backend  │  黑马校对     │  Lynx测试        │
│  端口: 8122      │  端口: 39521  │  端口: 8733   │  测试容器         │
│  (Flask/FastAPI) │  (Java)       │  (PHP)       │                   │
└─────────────────────────────────────────────────────────────────────┘
         ↓ HTTP              ↓ SQL           ↓ Vector        ↓ Graph
┌─────────────────────────────────────────────────────────────────────┐
│                      技术底座层 (Infrastructure Layer)               │
├─────────────────────────────────────────────────────────────────────┤
│  vLLM推理服务    │  MySQL       │  PostgreSQL  │  Redis            │
│  端口: 8102      │  端口: 3306  │  端口: 5432  │  端口: 6379        │
│  (NPU加速)       │  (业务数据)  │  (文档数据)  │  (缓存/会话)       │
├─────────────────────────────────────────────────────────────────────┤
│  Milvus向量库    │  Neo4j图数据库│  MinIO对象存储│  K3s编排          │
│  端口: 19530     │  端口: 7687  │  端口: 9000  │  端口: 6443        │
│  (向量检索)      │  (知识图谱)  │  (文件存储)  │  (容器管理)        │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      硬件加速层 (Hardware Layer)                     │
├─────────────────────────────────────────────────────────────────────┤
│  NPU0-1 (NUMA节点0)  │  NPU2-3 (NUMA节点1)  │  256GB HBM总计       │
│  vLLM推理加速        │  vLLM推理加速        │  64GB/NPU            │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 技术栈组成

| 层级 | 技术 | 用途 |
|------|------|------|
| **容器编排** | K3s v1.31.4+k3s1 | 轻量级Kubernetes，容器编排管理 |
| **推理引擎** | vLLM (Ascend NPU版) | 大模型推理服务，支持多模型 |
| **关系数据库** | MySQL 8.0 | 业务数据、用户信息、配置 |
| **关系数据库** | PostgreSQL 15 | 文档数据、日志、审计 |
| **缓存** | Redis 7 | 会话管理、缓存、消息队列 |
| **向量数据库** | Milvus | 向量存储和相似度检索 |
| **图数据库** | Neo4j | 知识图谱、关系网络 |
| **对象存储** | MinIO | 文件、模型、备份存储 |
| **监控** | Prometheus + Grafana | 系统监控和可视化 |

---

## 2. 服务依赖关系图

### 2.1 核心依赖关系

```
用户请求
  ↓
┌──────────────────────────────────────────────────────────┐
│                    WPS Office Web (30080)                 │
│  依赖: WPS Backend, MinIO, Redis, MySQL                  │
└──────────────────────────────────────────────────────────┘
  ↓ HTTP                    ↓ SQL           ↓ 文件
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ WPS Backend  │    │    MySQL     │    │    MinIO     │
│  (39521)     │    │   (3306)     │    │   (9000)     │
│ 依赖: MySQL, │    │              │    │              │
│  Redis,MinIO │    │              │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
  ↓
┌──────────────┐
│    Redis     │
│   (6379)     │
│ 缓存/会话    │
└──────────────┘


用户AI对话请求
  ↓
┌──────────────────────────────────────────────────────────┐
│                  AI Service Web (8122)                    │
│  依赖: vLLM, Milvus, Neo4j, Redis, MySQL                 │
└──────────────────────────────────────────────────────────┘
  ↓ HTTP              ↓ Vector         ↓ Graph      ↓ SQL
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   vLLM       │    │   Milvus     │    │    Neo4j     │
│  (8102)      │    │  (19530)     │    │   (7687)     │
│ 依赖: NPU,   │    │ 依赖: MinIO  │    │ 依赖: MySQL  │
│  模型文件    │    │  (持久化)    │    │  (元数据)    │
└──────────────┘    └──────────────┘    └──────────────┘
  ↓ NPU调用          ↓                    ↓
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  NPU 0-3     │    │    MinIO     │    │    MySQL     │
│  (256GB HBM) │    │   (9000)     │    │   (3306)     │
└──────────────┘    └──────────────┘    └──────────────┘


文档校对请求
  ↓
┌──────────────────────────────────────────────────────────┐
│                黑马校对系统 (8733)                        │
│  依赖: MySQL, WPS Backend, AI Service                    │
└──────────────────────────────────────────────────────────┘
  ↓ SQL              ↓ HTTP              ↓ HTTP
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│    MySQL     │    │ WPS Backend  │    │ AI Service   │
│  (3306)      │    │  (39521)     │    │  (8122)      │
└──────────────┘    └──────────────┘    └──────────────┘
```

### 2.2 依赖优先级矩阵

| 服务 | 依赖服务 | 依赖类型 | 优先级 | 说明 |
|------|----------|----------|--------|------|
| **AI Service** | vLLM | 强依赖 | P0 | 无vLLM无法提供AI服务 |
| **AI Service** | Milvus | 强依赖 | P0 | 向量检索必需 |
| **AI Service** | Neo4j | 强依赖 | P1 | 知识图谱查询 |
| **AI Service** | Redis | 强依赖 | P1 | 会话和缓存 |
| **AI Service** | MySQL | 强依赖 | P1 | 业务数据 |
| **vLLM** | NPU驱动 | 强依赖 | P0 | 硬件依赖 |
| **vLLM** | 模型文件 | 强依赖 | P0 | 无模型无法推理 |
| **WPS Backend** | MySQL | 强依赖 | P0 | 业务数据 |
| **WPS Backend** | Redis | 强依赖 | P1 | 缓存 |
| **WPS Backend** | MinIO | 强依赖 | P1 | 文件存储 |
| **黑马校对** | MySQL | 强依赖 | P0 | 业务数据 |
| **黑马校对** | WPS Backend | 强依赖 | P1 | 文档处理 |
| **Milvus** | MinIO | 强依赖 | P1 | 向量持久化 |
| **Neo4j** | MySQL | 弱依赖 | P2 | 元数据备份 |
| **K3s** | 无 | 基础 | P0 | 所有容器依赖K3s |

---

## 3. 模型服务清单

### 3.1 大语言模型 (LLM)

| 模型名称 | 参数量 | 用途 | 部署位置 | NPU需求 | 内存需求 |
|----------|--------|------|----------|---------|----------|
| **DeepSeek-R1** | 70B | 推理/对话 | vLLM容器 | NPU0-3 (4卡) | ~140GB HBM |
| **DeepSeek-V2** | 21B | 推理/对话 | vLLM容器 | NPU0-1 (2卡) | ~42GB HBM |
| **Qwen2.5-72B** | 72B | 推理/对话 | vLLM容器 | NPU0-3 (4卡) | ~144GB HBM |
| **Qwen2.5-32B** | 32B | 推理/对话 | vLLM容器 | NPU0-1 (2卡) | ~64GB HBM |
| **Qwen2.5-14B** | 14B | 推理/对话 | vLLM容器 | NPU0 (1卡) | ~28GB HBM |
| **Qwen2.5-7B** | 7B | 推理/对话 | vLLM容器 | NPU0 (1卡) | ~14GB HBM |
| **Qwen3-32B** | 32B | 推理/对话 | vLLM容器 | NPU0-1 (2卡) | ~64GB HBM |
| **Qwen3-32B-FP8** | 32B | 推理/对话(量化) | vLLM容器 | NPU0 (1卡) | ~32GB HBM |

### 3.2 Embedding模型

| 模型名称 | 维度 | 用途 | 部署位置 | 内存需求 |
|----------|------|------|----------|----------|
| **bge-m3** | 1024 | 文本向量化 | vLLM容器 | ~2GB |
| **bge-large-zh-v1.5** | 1024 | 中文向量化 | vLLM容器 | ~1.5GB |
| **Qwen3-Embedding-8B** | 4096 | 高质量向量化 | vLLM容器 | ~16GB |

### 3.3 视觉语言模型 (VL)

| 模型名称 | 参数量 | 用途 | 部署位置 | NPU需求 |
|----------|--------|------|----------|---------|
| **Qwen2-VL-72B** | 72B | 图像理解 | vLLM容器 | NPU0-3 (4卡) |
| **Qwen2-VL-7B** | 7B | 图像理解 | vLLM容器 | NPU0 (1卡) |
| **Qwen3-VL-32B** | 32B | 图像理解 | vLLM容器 | NPU0-1 (2卡) |

### 3.4 其他模型

| 模型名称 | 用途 | 部署位置 | 说明 |
|----------|------|----------|------|
| **MinerU2.5-1.2B** | 文档解析 | 独立容器 | PDF/Word解析 |
| **Qwen3-14B-speculator** | 预测加速 | vLLM插件 | Speculative Decoding |

### 3.5 模型存储结构

```
/ksc_aibox/models/
├── llm/                          # 大语言模型
│   ├── qwen332b/                 # Qwen3-32B
│   ├── qwen332bfp8/              # Qwen3-32B FP8量化
│   ├── Qwen3-14B/                # Qwen3-14B
│   ├── deepseek70b/              # DeepSeek-70B
│   └── Qwen3-14B-speculator.eagle3/  # 预测加速模型
├── embedding/                    # Embedding模型
│   └── Qwen3-Embedding-8B/
├── vl/                           # 视觉语言模型
│   └── Qwen3-VL-32B-Instruct/
├── rerank/                       # 重排序模型 (待安装)
└── mineru/                       # 文档解析模型
    └── MinerU2.5-2509-1.2B/
```

---

## 4. 应用服务清单

### 4.1 核心应用服务

| 服务名称 | 端口 | 技术栈 | 依赖 | 说明 |
|----------|------|--------|------|------|
| **AI Service** | 8122 | Flask/FastAPI | vLLM, Milvus, Neo4j, Redis, MySQL | AI对话和业务逻辑 |
| **vLLM推理服务** | 8102 | Python+vLLM | NPU驱动, 模型文件 | 大模型推理引擎 |
| **WPS Backend** | 39521 | Java | MySQL, Redis, MinIO | WPS Office后端 |
| **黑马校对** | 8733 | PHP | MySQL, WPS Backend | 文档校对系统 |

### 4.2 基础设施服务

| 服务名称 | 端口 | 技术栈 | 依赖 | 说明 |
|----------|------|--------|------|------|
| **K3s API** | 6443 | Kubernetes | 无 | 容器编排API |
| **MySQL** | 3306 | MySQL 8.0 | 无 | 关系型数据库 |
| **PostgreSQL** | 5432 | PostgreSQL 15 | 无 | 关系型数据库 |
| **Redis** | 6379 | Redis 7 | 无 | 缓存和会话 |
| **Milvus** | 19530 | Milvus | MinIO, MySQL | 向量数据库 |
| **Neo4j** | 7687 | Neo4j | 无 | 图数据库 |
| **MinIO API** | 9000 | MinIO | 无 | 对象存储API |
| **MinIO Console** | 9001 | MinIO | 无 | 对象存储控制台 |

### 4.3 监控和运维服务

| 服务名称 | 端口 | 说明 |
|----------|------|------|
| **Prometheus** | 9090 | 指标采集和存储 |
| **Grafana** | 3000 | 监控可视化 |
| **Health Check** | - | 每5分钟系统健康检查 |
| **Self-Healing** | - | 每10分钟自愈服务 |

---

## 5. 服务调用关系详解

### 5.1 AI对话完整调用链路

```
用户请求
  ↓
[1] 浏览器 → AI Service Web (http://server:8122/chat)
  ↓
[2] AI Service 接收请求
  ├── 查询Redis: 检查会话缓存和限流
  ├── 查询MySQL: 获取用户配置和历史
  └── 准备Prompt
  ↓
[3] AI Service → Milvus (http://server:19530)
  ├── 将用户问题向量化 (调用Embedding模型)
  ├── 向量相似度检索，获取Top-K相关知识
  └── 返回相关文档片段
  ↓
[4] AI Service → Neo4j (bolt://server:7687)
  ├── 查询知识图谱，获取实体关系
  └── 返回图谱关联信息
  ↓
[5] AI Service 组装Prompt
  ├── System Prompt + 用户问题
  ├── Milvus返回的相关知识片段
  ├── Neo4j返回的图谱信息
  └── 上下文窗口管理
  ↓
[6] AI Service → vLLM (http://server:8102/v1/chat/completions)
  ├── POST请求，包含完整Prompt
  ├── 流式响应 (SSE)
  └── vLLM调用NPU进行推理
  ↓
[7] vLLM → NPU硬件
  ├── 加载模型到NPU HBM
  ├── 执行前向传播
  └── 返回生成Token
  ↓
[8] vLLM → AI Service (流式返回)
  ↓
[9] AI Service → 浏览器 (SSE流式响应)
  ↓
[10] AI Service 异步保存
  ├── 对话历史写入MySQL
  └── 更新Redis会话缓存
```

### 5.2 文档处理调用链路

```
用户上传文档
  ↓
[1] WPS Web → WPS Backend (http://server:39521/upload)
  ↓
[2] WPS Backend
  ├── 文档格式校验
  ├── 文件上传到MinIO (http://server:9000)
  └── 元数据写入MySQL
  ↓
[3] 黑马校对 → WPS Backend (http://server:8733/check)
  ↓
[4] WPS Backend
  ├── 从MinIO下载文档
  ├── 调用MinerU解析文档结构
  └── 提取文本内容
  ↓
[5] WPS Backend → AI Service (可选)
  ├── 调用AI进行语义分析
  └── 获取AI建议
  ↓
[6] 黑马校对
  ├── 规则引擎校对
  ├── AI辅助校对
  └── 生成校对报告
  ↓
[7] 黑马校对 Web → WPS Backend
  ├── 获取校对结果
  └── 展示给用户
```

### 5.3 向量检索调用链路

```
AI Service需要检索相关知识
  ↓
[1] AI Service → Embedding模型 (vLLM)
  ├── 将文本转换为向量
  └── 返回1024/4096维向量
  ↓
[2] AI Service → Milvus
  ├── 插入向量 (写入场景)
  └── 相似度检索 (查询场景)
  ↓
[3] Milvus → MinIO
  ├── 读取持久化的向量数据
  └── 返回查询结果
  ↓
[4] Milvus → AI Service
  └── 返回Top-K相似文档片段
```

---

## 6. K3s容器编排平台配置要求

### 6.1 K3s安装配置

```yaml
# K3s基本配置
k3s_version: v1.31.4+k3s1
k3s_token: "ksc-aibox-k3s-token"  # 集群共享密钥
k3s_data_dir: /ksc_aibox/k3s/data
k3s_storage_dir: /ksc_aibox/k3s/storage

# 安装参数
INSTALL_K3S_EXEC: >
  --cluster-init
  --data-dir /ksc_aibox/k3s/data
  --kubelet-arg=eviction-hard=imagefs.available<10%,nodefs.available<10%
  --kubelet-arg=eviction-minimum-reclaim=imagefs.available=15%,nodefs.available=15%
  --disable traefik
  --disable servicelb
  --disable local-storage
  --write-kubeconfig-mode 644
  --node-name ksc-aibox-node01
  --tls-san 10.212.128.192
  --kube-apiserver-arg=default-storage-class=local-path
  --kube-controller-manager-arg=terminated-pod-gc-threshold=100
```

### 6.2 K3s StorageClass配置

```yaml
# Local Path StorageClass (默认)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
parameters:
  type: directory
  nodePath: /ksc_aibox/k3s/storage
```

### 6.3 K3s资源限制配置

```yaml
# Kubelet资源配置
kubelet-arg:
  - eviction-hard=imagefs.available<10%,nodefs.available<10%,memory.available<500Mi
  - eviction-minimum-reclaim=imagefs.available=15%,nodefs.available=15%,memory.available<1Gi
  - system-reserved=cpu=4,memory=8Gi
  - kube-reserved=cpu=2,memory=4Gi
```

### 6.4 K3s Namespace规划

```yaml
namespaces:
  - name: middle          # 中间件 (MySQL, PostgreSQL, Redis, Milvus, Neo4j, MinIO)
  - name: ai-service      # AI服务 (AI Service, vLLM)
  - name: wps-office      # WPS Office
  - name: hmjd            # 黑马校对
  - name: monitoring      # 监控 (Prometheus, Grafana)
  - name: lynx            # 测试环境
```

### 6.5 K3s Pod资源配置要求

#### vLLM Pod资源需求

```yaml
# vLLM Pod资源配置 (以Qwen2.5-72B为例)
apiVersion: v1
kind: Pod
metadata:
  name: vllm-qwen25-72b
  namespace: ai-service
spec:
  containers:
  - name: vllm
    image: vllm-ascend:latest
    resources:
      requests:
        cpu: "16"
        memory: "64Gi"
        hugepages-2Mi: "128Gi"
        huawei.com/Ascend910: "4"  # NPU资源
      limits:
        cpu: "32"
        memory: "128Gi"
        hugepages-2Mi: "144Gi"
        huawei.com/Ascend910: "4"
    volumeMounts:
    - name: model-storage
      mountPath: /ksc_aibox/models
    - name: ascend-driver
      mountPath: /usr/local/Ascend/driver
      readOnly: true
    - name: hugepage
      mountPath: /dev/hugepages
  volumes:
  - name: model-storage
    hostPath:
      path: /ksc_aibox/models
      type: Directory
  - name: ascend-driver
    hostPath:
      path: /usr/local/Ascend/driver
      type: Directory
  - name: hugepage
    emptyDir:
      medium: HugePages
```

#### 数据库Pod资源需求

```yaml
# MySQL Pod
resources:
  requests:
    cpu: "4"
    memory: "8Gi"
  limits:
    cpu: "8"
    memory: "16Gi"

# PostgreSQL Pod
resources:
  requests:
    cpu: "4"
    memory: "8Gi"
  limits:
    cpu: "8"
    memory: "16Gi"

# Redis Pod
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
  limits:
    cpu: "4"
    memory: "8Gi"

# Milvus Pod
resources:
  requests:
    cpu: "8"
    memory: "16Gi"
  limits:
    cpu: "16"
    memory: "32Gi"

# Neo4j Pod
resources:
  requests:
    cpu: "4"
    memory: "8Gi"
  limits:
    cpu: "8"
    memory: "16Gi"

# MinIO Pod
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
  limits:
    cpu: "4"
    memory: "8Gi"
```

### 6.6 K3s网络策略

```yaml
# NetworkPolicy示例 - AI Service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ai-service-network
  namespace: ai-service
spec:
  podSelector:
    matchLabels:
      app: ai-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: wps-office
    - namespaceSelector:
        matchLabels:
          name: hmjd
    ports:
    - protocol: TCP
      port: 8122
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: ai-service
    ports:
    - protocol: TCP
      port: 8102  # vLLM
  - to:
    - namespaceSelector:
        matchLabels:
          name: middle
    ports:
    - protocol: TCP
      port: 19530  # Milvus
    - protocol: TCP
      port: 7687   # Neo4j
    - protocol: TCP
      port: 6379   # Redis
    - protocol: TCP
      port: 3306   # MySQL
```

---

## 7. 持久化存储配置方案

### 7.1 存储架构总览

```
/ksc_aibox/                          # 主工作分区 (361GB可用)
├── k3s/
│   ├── data/                        # K3s运行时数据 (~10GB)
│   │   ├── server/                  # K3s server数据
│   │   └── agent/                   # K3s agent数据
│   ├── storage/                     # K3s动态存储卷 (~50GB)
│   │   ├── middle/                  # 中间件PVC
│   │   ├── ai-service/              # AI服务PVC
│   │   └── monitoring/              # 监控PVC
│   ├── manifests/                   # K3s静态Manifests
│   └── helm/                        # Helm Charts
│
├── data/                            # 数据库持久化数据 (~100GB)
│   ├── mysql/                       # MySQL数据目录
│   │   ├── data/                    # 数据库文件
│   │   ├── binlog/                  # 二进制日志
│   │   └── backup/                  # 备份
│   ├── postgres/                    # PostgreSQL数据目录
│   │   ├── data/                    # 数据库文件
│   │   ├── wal/                     # WAL日志
│   │   └── backup/                  # 备份
│   ├── redis/                       # Redis数据目录
│   │   ├── dump.rdb                 # RDB快照
│   │   └── appendonly.aof           # AOF日志
│   ├── milvus/                      # Milvus数据目录
│   │   ├── wal/                     # WAL日志
│   │   └── index/                   # 索引文件
│   ├── neo4j/                       # Neo4j数据目录
│   │   ├── data/                    # 图数据
│   │   └── logs/                    # 日志
│   └── minio/                       # MinIO数据目录
│       ├── bucket1/                 # 存储桶1
│       └── bucket2/                 # 存储桶2
│
├── models/                          # 模型文件 (333GB)
│   ├── llm/                         # 大语言模型 (~300GB)
│   ├── embedding/                   # Embedding模型 (~5GB)
│   ├── vl/                          # 视觉语言模型 (~20GB)
│   ├── rerank/                      # 重排序模型 (~5GB)
│   └── mineru/                      # 文档解析模型 (~3GB)
│
├── docker/                          # Docker数据 (已迁移24GB)
│   └── data/                        # Docker数据目录
│
└── logs/                            # 日志目录 (~10GB)
    ├── k3s/                         # K3s日志
    ├── middle/                      # 中间件日志
    ├── ai-service/                  # AI服务日志
    └── monitoring/                  # 监控日志
```

### 7.2 PersistentVolume配置

#### MySQL PV

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /ksc_aibox/data/mysql
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ksc-aibox-node01
```

#### PostgreSQL PV

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /ksc_aibox/data/postgres
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ksc-aibox-node01
```

#### Milvus PV

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: milvus-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /ksc_aibox/data/milvus
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ksc-aibox-node01
```

#### MinIO PV

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv
spec:
  capacity:
    storage: 200Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /ksc_aibox/data/minio
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ksc-aibox-node01
```

### 7.3 PersistentVolumeClaim配置

```yaml
# MySQL PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: middle
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 50Gi

# Milvus PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: milvus-pvc
  namespace: middle
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 100Gi

# MinIO PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: middle
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 200Gi
```

### 7.4 存储容量规划

| 存储路径 | 用途 | 当前大小 | 预估增长 | 总容量 | 使用率 |
|----------|------|----------|----------|--------|--------|
| `/ksc_aibox/data/mysql` | MySQL数据 | 1GB | 10GB/年 | 50GB | 2% |
| `/ksc_aibox/data/postgres` | PostgreSQL数据 | 1GB | 20GB/年 | 50GB | 2% |
| `/ksc_aibox/data/redis` | Redis数据 | 500MB | 2GB/年 | 10GB | 5% |
| `/ksc_aibox/data/milvus` | Milvus向量数据 | 5GB | 50GB/年 | 100GB | 5% |
| `/ksc_aibox/data/neo4j` | Neo4j图数据 | 2GB | 20GB/年 | 50GB | 4% |
| `/ksc_aibox/data/minio` | MinIO对象存储 | 10GB | 100GB/年 | 200GB | 5% |
| `/ksc_aibox/models` | 模型文件 | 333GB | 50GB/年 | 400GB | 83% |
| `/ksc_aibox/k3s/data` | K3s运行时 | 2GB | 5GB/年 | 20GB | 10% |
| `/ksc_aibox/k3s/storage` | K3s动态存储 | 1GB | 20GB/年 | 50GB | 2% |
| `/ksc_aibox/logs` | 日志文件 | 500MB | 5GB/年 | 20GB | 2.5% |
| **总计** | | **~355GB** | **~282GB/年** | **~950GB** | **37%** |

### 7.5 备份策略

```yaml
# 备份配置
backup:
  root: /backup
  
  # 系统配置备份
  system:
    path: /backup/system
    schedule: "0 2 * * *"  # 每天凌晨2点
    retention: 7d          # 保留7天
    includes:
      - /etc/sysctl.d/
      - /etc/security/
      - /etc/udev/rules.d/
      - /etc/profile.d/
      - /etc/docker/
  
  # 应用数据备份
  application:
    path: /backup/application
    schedule: "0 3 * * 0"  # 每周日凌晨3点
    retention: 30d         # 保留30天
    includes:
      - /ksc_aibox/data/mysql
      - /ksc_aibox/data/postgres
      - /ksc_aibox/data/redis
      - /ksc_aibox/data/milvus
      - /ksc_aibox/data/neo4j
  
  # 模型文件备份 (只读，不频繁备份)
  models:
    path: /backup/models
    schedule: "0 4 1 * *"  # 每月1号凌晨4点
    retention: 90d         # 保留90天
    includes:
      - /ksc_aibox/models
  
  # 归档备份
  archive:
    path: /backup/archive
    schedule: "0 5 1 1 *"  # 每年1月1号凌晨5点
    retention: 365d        # 保留1年
    includes:
      - /ksc_aibox/
```

---

## 8. NUMA拓扑与资源分配

### 8.1 NUMA节点划分

```
┌─────────────────────────────────────────────────────────────────┐
│                    NUMA节点0 (CPU 0-31, 128GB)                   │
├─────────────────────────────────────────────────────────────────┤
│  系统服务: 8GB                                                   │
│  MySQL: 16GB (绑定到NUMA节点0)                                   │
│  Redis: 4GB (绑定到NUMA节点0)                                    │
│  Neo4j: 8GB (绑定到NUMA节点0)                                    │
│  NPU0推理: 32GB HugePages (NPU0绑定NUMA节点0)                   │
│  NPU1推理: 32GB HugePages (NPU1绑定NUMA节点0)                   │
│  剩余缓冲: 28GB                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    NUMA节点1 (CPU 32-63, 128GB)                  │
├─────────────────────────────────────────────────────────────────┤
│  PostgreSQL: 16GB (绑定到NUMA节点1)                              │
│  Milvus: 32GB (绑定到NUMA节点1)                                  │
│  WPS Office: 4GB (绑定到NUMA节点1)                               │
│  NPU2推理: 32GB HugePages (NPU2绑定NUMA节点1)                   │
│  NPU3推理: 32GB HugePages (NPU3绑定NUMA节点1)                   │
│  剩余缓冲: 12GB                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 NUMA绑定配置

```bash
# MySQL绑定到NUMA节点0
numactl --cpunodebind=0 --membind=0 mysqld

# PostgreSQL绑定到NUMA节点1
numactl --cpunodebind=1 --membind=1 postgres

# Milvus绑定到NUMA节点1
numactl --cpunodebind=1 --membind=1 milvus

# Redis绑定到NUMA节点0
numactl --cpunodebind=0 --membind=0 redis-server

# Neo4j绑定到NUMA节点0
numactl --cpunodebind=0 --membind=0 neo4j
```

### 8.3 NPU与NUMA亲和性

```yaml
# NPU NUMA映射配置
npu_numa_mapping:
  npu0:
    numa_node: 0
    hugepages: 16000  # 32GB
    cpu_affinity: "0-31"
    pcie_address: "01:00.0"
    connected_to: "npu1 (PHB)"
    
  npu1:
    numa_node: 0
    hugepages: 16000  # 32GB
    cpu_affinity: "0-31"
    pcie_address: "02:00.0"
    connected_to: "npu0 (PHB)"
    
  npu2:
    numa_node: 1
    hugepages: 16000  # 32GB
    cpu_affinity: "32-63"
    pcie_address: "81:00.0"
    connected_to: "npu3 (PHB)"
    
  npu3:
    numa_node: 1
    hugepages: 16000  # 32GB
    cpu_affinity: "32-63"
    pcie_address: "82:00.0"
    connected_to: "npu2 (PHB)"
```

---

## 9. 数据流向图

### 9.1 用户请求数据流

```
用户浏览器
  ↓ HTTP请求
[AI Service Web: 8122]
  ↓ 查询会话
[Redis: 6379] ← 会话数据
  ↓ 查询用户信息
[MySQL: 3306] ← 用户数据
  ↓ 向量检索
[Milvus: 19530]
  ↓ 查询向量
[MinIO: 9000] ← 向量持久化数据
  ↓ 返回Top-K结果
[AI Service] 组装Prompt
  ↓ 知识图谱查询
[Neo4j: 7687] ← 图谱数据
  ↓ 完整Prompt
[vLLM: 8102]
  ↓ 调用NPU
[NPU 0-3] ← 模型文件 (/ksc_aibox/models)
  ↓ 推理结果
[vLLM] → [AI Service] → [用户浏览器]
  ↓ 异步保存
[MySQL] ← 对话历史
```

### 9.2 文档处理数据流

```
用户上传文档
  ↓
[WPS Web: 30080]
  ↓
[WPS Backend: 39521]
  ↓ 存储文档
[MinIO: 9000] ← 文档文件
  ↓ 记录元数据
[MySQL: 3306] ← 文档元数据
  ↓
[黑马校对: 8733]
  ↓ 获取文档
[WPS Backend] → [MinIO]
  ↓ 解析文档
[MinerU] ← 文档解析
  ↓ 校对处理
[AI Service: 8122] (可选)
  ↓ 保存结果
[MySQL: 3306] ← 校对结果
  ↓
[黑马校对 Web] 展示结果
```

---

## 10. 部署顺序和依赖检查

### 10.1 推荐部署顺序

```
阶段1: 基础设施准备 (P0)
├── 1.1 K3s容器编排平台
│   ├── 检查: NPU驱动状态
│   ├── 检查: 目录结构
│   └── 检查: 网络配置
│
├── 1.2 数据库服务 (并行部署)
│   ├── MySQL
│   ├── PostgreSQL
│   └── Redis
│
└── 1.3 存储和中间件 (并行部署)
    ├── MinIO
    ├── Milvus
    └── Neo4j

阶段2: AI服务部署 (P0)
├── 2.1 vLLM推理服务
│   ├── 检查: NPU设备
│   ├── 检查: 模型文件
│   ├── 检查: CANN环境
│   └── 启动vLLM容器
│
└── 2.2 AI Service
    ├── 检查: vLLM服务
    ├── 检查: 数据库连接
    ├── 检查: Milvus连接
    ├── 检查: Neo4j连接
    └── 启动AI Service容器

阶段3: 应用部署 (P1)
├── 3.1 WPS Office
│   ├── 检查: MySQL
│   ├── 检查: Redis
│   ├── 检查: MinIO
│   └── 启动WPS服务
│
└── 3.2 黑马校对
    ├── 检查: MySQL
    ├── 检查: WPS Backend
    └── 启动黑马校对服务

阶段4: 监控和测试 (P2)
├── 4.1 Prometheus + Grafana
├── 4.2 冒烟测试
└── 4.3 回归测试
```

### 10.2 依赖检查清单

#### K3s部署前检查

```bash
#!/bin/bash
# K3s部署前检查清单

echo "=== K3s部署前检查 ==="

# 1. 检查NPU驱动
echo "1. NPU驱动检查..."
npu-smi info -l || { echo "❌ NPU驱动异常"; exit 1; }
echo "✅ NPU驱动正常"

# 2. 检查目录结构
echo "2. 目录结构检查..."
for dir in /ksc_aibox/k3s/data /ksc_aibox/k3s/storage /ksc_aibox/data; do
  [ -d "$dir" ] || { echo "❌ 目录不存在: $dir"; exit 1; }
done
echo "✅ 目录结构完整"

# 3. 检查网络
echo "3. 网络检查..."
ping -c 1 10.212.128.1 || { echo "❌ 网络不通"; exit 1; }
echo "✅ 网络正常"

# 4. 检查端口占用
echo "4. 端口检查..."
for port in 6443 3306 5432 6379 9000 9001 19530 7687 8102 8122; do
  ss -tlnp | grep -q ":$port " && { echo "❌ 端口 $port 已被占用"; exit 1; }
done
echo "✅ 端口未被占用"

# 5. 检查内存
echo "5. 内存检查..."
free -h | awk '/^Mem:/{if ($7 < "50G") exit 1}'
echo "✅ 内存充足"

# 6. 检查磁盘空间
echo "6. 磁盘检查..."
df -h /ksc_aibox | awk 'NR==2{if ($4 < "100G") exit 1}'
echo "✅ 磁盘空间充足"

echo ""
echo "=== 所有检查通过，可以部署K3s ==="
```

#### AI Service部署前检查

```bash
#!/bin/bash
# AI Service部署前检查

echo "=== AI Service部署前检查 ==="

# 1. 检查vLLM
echo "1. vLLM服务检查..."
curl -s http://localhost:8102/v1/models | grep -q "data" || { echo "❌ vLLM未启动"; exit 1; }
echo "✅ vLLM服务正常"

# 2. 检查MySQL
echo "2. MySQL检查..."
mysql -h localhost -u root -e "SELECT 1" || { echo "❌ MySQL连接失败"; exit 1; }
echo "✅ MySQL连接正常"

# 3. 检查Milvus
echo "3. Milvus检查..."
curl -s http://localhost:19530/v1/vector/collections | grep -q "code" || { echo "❌ Milvus未启动"; exit 1; }
echo "✅ Milvus服务正常"

# 4. 检查Neo4j
echo "4. Neo4j检查..."
curl -s http://localhost:7474 || { echo "❌ Neo4j未启动"; exit 1; }
echo "✅ Neo4j服务正常"

# 5. 检查Redis
echo "5. Redis检查..."
redis-cli ping | grep -q "PONG" || { echo "❌ Redis未启动"; exit 1; }
echo "✅ Redis服务正常"

# 6. 检查模型文件
echo "6. 模型文件检查..."
ls -d /ksc_aibox/models/llm/* | head -1 || { echo "❌ 无模型文件"; exit 1; }
echo "✅ 模型文件存在"

echo ""
echo "=== 所有检查通过，可以部署AI Service ==="
```

---

## 附录: 关键配置文件位置

### 本地配置文件

| 文件 | 说明 |
|------|------|
| `ansible/group_vars/all.yml` | 全局变量配置 |
| `ansible/group_vars/npu_servers.yml` | NPU服务器变量 |
| `ansible/inventory/hosts` | 主机清单 |
| `ansible/ansible.cfg` | Ansible配置 |

### 远程服务器配置

| 文件 | 说明 |
|------|------|
| `/etc/sysctl.d/99-ksc-aibox-optimization.conf` | 内核参数 |
| `/etc/sysctl.d/99-ksc-aibox-hugepages.conf` | HugePages |
| `/etc/security/limits.d/99-ksc-aibox.conf` | 资源限制 |
| `/etc/udev/rules.d/99-npu.rules` | NPU设备权限 |
| `/etc/profile.d/ksc-aibox-npu.sh` | NPU环境变量 |
| `/etc/docker/daemon.json` | Docker配置 |
| `/etc/audit/rules.d/ksc-aibox.rules` | 审计规则 |
| `/etc/systemd/system/ksc-aibox-*.service` | HCI服务 |

---

*文档生成时间: 2026-04-09*
*基于完整代码和文档分析生成*
*维护团队: KSC AIBox Team*
