# KSC AIBox 一体机 - 最终完整系统配置文档

> 基于服务器 `/ksc_aibox/source` 目录169GB完全解压后的深度分析
> 分析时间: 2026-04-09
> 版本: ytj-install-3.7.0-arm64-AI_910B-20260408-126
> 配置文件: 83个YAML + 19个其他配置文件

---

## 目录

1. [系统架构总览](#1-系统架构总览)
2. [中间件完整配置](#2-中间件完整配置)
3. [应用服务完整配置](#3-应用服务完整配置)
4. [AI模型完整配置](#4-ai模型完整配置)
5. [WPS Office完整配置](#5-wps-office完整配置)
6. [存储配置方案](#6-存储配置方案)
7. [网络和端口汇总](#7-网络和端口汇总)
8. [密钥和凭证汇总](#8-密钥和凭证汇总)
9. [安装执行步骤](#9-安装执行步骤)
10. [Ansible自动化记录方案](#10-ansible自动化记录方案)

---

## 1. 系统架构总览

### 1.1 技术栈

```
K3s容器编排 (已运行)
  ├── Harbor镜像仓库 (hub.ai.aio.cloud)
  ├── StorageClass: csi-rbd-sc (Ceph RBD)
  └── Namespace: middle
       ├── 中间件层 (10个服务)
       ├── 应用层 (15个微服务)
       ├── WPS Office (11个服务)
       └── AI模型 (4个模型)
```

### 1.2 硬件资源

```
CPU: 64核 (鲲鹏920)
内存: 250GB DDR4
NPU: 4×昇腾910B4-1 (64GB HBM each)
存储: 4TB NVMe SSD (3.6TB可用)
```

---

## 2. 中间件完整配置

### 2.1 PostgreSQL

```yaml
镜像: hub.ai.aio.cloud/middleware/postgresql-arm64:15.3.0-debian-11-r85
端口: 5432
用户: postgres
密码: sw_1357924680
数据库: postgres
最大连接: 500
PVC: postgres-pvc (10Gi, csi-rbd-sc)
挂载: /bitnami/postgresql
资源: 256Mi-4Gi / 250m-4cpu
```

**SQL初始化**:
- `init_postgres.sql` - 初始数据库创建
- `set_config.sql` - 配置设置
- `anquan/` - 安全版DDL/DML
- `zhongtai/` - 众泰版DDL/DML
- `updatesql/` - 升级SQL (3.0.2-3.6.1, 3.5.0-3.6.1)

### 2.2 MySQL

```yaml
镜像: hub.ai.aio.cloud/middleware/mysql-arm64:8.3.0
端口: 3306
用户: root
密码: Wps+123
数据库: wps
ROOT_HOST: '%'
PVC: mysql-data-pvc (20Gi, csi-rbd-sc)
挂载: /var/lib/mysql
资源: 2Gi / 2cpu
```

**SQL初始化**:
- `create_table.sql` (35KB) - 创建WPS相关表

### 2.3 Redis

```yaml
镜像: hub.ai.aio.cloud/middleware/redis:7.4.0
端口: 6379
密码: suwell5394_redis
PVC: redis-pvc (10Gi, csi-rbd-sc)
挂载: /data
资源: 256Mi-1Gi / 1cpu
命令: redis-server --requirepass suwell5394_redis
```

### 2.4 Nacos配置中心

```yaml
镜像: hub.ai.aio.cloud/middleware/nacos-server:v2.3.2-slim
端口: 8848 (server), 9848 (client-rpc), 9849 (raft-rpc)
NodePort: 38848
用户: nacos
密码: nacos
模式: standalone
JVM: 256m-1024m
PVC: nacos-pvc-data (10Gi, csi-rbd-sc)
挂载: /home/nacos/data
资源: 256Mi-2Gi / 50m-2cpu
```

**配置导入**:
- `nacos-config-ytj-3.7.0.zip` (107KB)

**关键环境变量**:
```
NACOS_AUTH_ENABLE: true
NACOS_AUTH_TOKEN: 012345678901234567890123456789012345678901234567890123456666
```

### 2.5 Elasticsearch

```yaml
镜像: hub.ai.aio.cloud/middleware/elasticsearch:8.18.2-gwk-1
类型: StatefulSet (3副本)
端口: 9200 (http), 9300 (transport)
密码: h3bJ9GqD75Yz
集群名: docker-cluster
JVM: -Xms16G -Xmx16G
PVC: 100Gi × 3 (csi-rbd-sc)
挂载: /usr/share/elasticsearch/data
资源: 16Gi-32Gi / 1-2cpu (per pod)
```

**特殊配置**:
- 3节点集群
- 需要vm.max_map_count=262144
- initContainer设置权限和系统参数

### 2.6 MinIO

```yaml
镜像: hub.ai.aio.cloud/middleware/minio:RELEASE.2024-07-10T18-41-49Z-cpuv1-arm64
端口: 9000 (API), 9090 (Console)
用户: admin
密码: G5pJ2kUq3L8M
PVC: minio-pvc (10Gi, csi-rbd-sc)
挂载: /data
资源: 512Mi-1Gi / 500m-1cpu
命令: minio server --console-address :9090 /data
```

### 2.7 Neo4j

```yaml
镜像: hub.ai.aio.cloud/middleware/neo4j-arm64-gwk:5.7-2
端口: 7474 (HTTP), 7687 (Bolt)
用户: neo4j
密码: mkWcrFxXgTua
PVC: neo4j-pvc (5Gi, csi-rbd-sc)
挂载: /data
资源: 256Mi-2G / 250m-500cpu
```

**Neo4j配置 (ConfigMap)**:
```
dbms.default_database: plss-v1
dbms.security.auth_enabled: false
dbms.memory.pagecache.size: 512M
dbms.directories.data: /data
dbms.directories.logs: /logs
```

### 2.8 RabbitMQ

```yaml
镜像: hub.ai.aio.cloud/middleware/rabbitmq:3.12.14-management
端口: 5672 (AMQP), 15672 (Management), 1883 (MQTT)
用户: suwell
密码: 3jH5gF7A9B1k
PVC: rabbitmq-pvc (10Gi, csi-rbd-sc)
挂载: /var/lib/rabbitmq
资源: 256Mi-4Gi / 250m-2cpu
```

### 2.9 etcd

```yaml
镜像: hub.ai.aio.cloud/middleware/etcd:arm64
端口: 2379
PVC: etcd-data-pvc (20Gi, csi-rbd-sc)
挂载: /etcd-data
资源: default
```

**etcd配置 (ConfigMap脚本)**:
- WPS配置中心
- Redis连接配置
- MinIO存储配置
- 数据库代理配置
- JS插件配置
- 多语言配置

**关键配置项**:
```
Redis: redis-svc:6379 / suwell5394_redis
MySQL: mysql:3306 / root / Wps+123 / wps
MinIO: http://minio-service:9000 / admin / G5pJ2kUq3L8M
```

### 2.10 SLC授权服务

```yaml
镜像: hub.ai.aio.cloud/middleware/swslc-arm64:3007.1.1.24.0701.16.05
端口: 9521
NodePort: 39521
PVC: slc-data-pvc (10Gi, csi-rbd-sc)
挂载: /slc/data/
特殊: /dev/mem (CharDevice)
资源: 256Mi-1Gi / 250m-1cpu
```

**环境变量**:
```
SLC_ENABLE: false
SLC_SERVICE_PORT: 9521
SLC_URL: http://slc-svc:9521
SLC_CHECK_ON_BOOT: false
SLC_CHECK_PERIOD: 24h
```

---

## 3. 应用服务完整配置

### 3.1 微服务通用配置模式

所有微服务都遵循以下模式:
```yaml
namespace: middle
连接Nacos: nacos-svc:8848 / nacos / nacos
加密配置: ConfigMap (configkey/secretkey)
日志目录: /data/app/logs (HostPath, 777权限)
镜像: hub.ai.aio.cloud/plss/xxx-arm64:TAG
```

### 3.2 plss-gateway (API网关)

```yaml
镜像: hub.ai.aio.cloud/plss/plss-gateway-arm64:20251017-644-WPS
端口: 8064
资源: 2Gi-4Gi / 2-4cpu
ConfigMap: configkey, secretkey
```

### 3.3 plss-system-server (系统管理)

```yaml
镜像: hub.ai.aio.cloud/plss/plss-system-server-arm64:20251225-1067-WPS
端口: 8061
资源: 2Gi-4Gi / 2-4cpu
```

### 3.4 plss-open-server (开放API)

```yaml
端口: (待确认)
资源: (待确认)
```

### 3.5 plss-document-process-server (文档处理)

```yaml
端口: (待确认)
日志: /data/app/logs
```

### 3.6 plss-record-server (记录服务)

```yaml
端口: (待确认)
```

### 3.7 plss-search-server (搜索服务)

```yaml
端口: (待确认)
特殊: /data/app/ofd2json (解压ofd2json.tar)
```

### 3.8 plss-plugin-server (插件服务)

```yaml
端口: (待确认)
```

### 3.9 plss-web (前端UI)

```yaml
端口: 30080 (通过Service)
特殊: /data/app/html/aiPlatform (前端静态文件)
ConfigMap: 独立ConfigMap.yaml
```

### 3.10 plss-nlp-draft (NLP起草)

```yaml
端口: (待确认)
```

### 3.11 nlp-application (NLP应用)

```yaml
端口: (待确认)
```

### 3.12 nlp-capacity-integration (NLP集成)

```yaml
端口: (待确认)
特殊: /data/app/nlp-capacity-integration
```

### 3.13 ai-qingqiu-13b-api (AI API网关)

```yaml
镜像: hub.ai.aio.cloud/plss/ai-qingqiu-13b-api:v1-arm64
端口: 8000
资源: 1Gi-5Gi / 500m-5cpu
```

**关键环境变量**:
```
CATALOG_RECOG_HOST: http://nlp-capacity-integration-server:8086
PARA_RECOG_HOST: http://nlp-capacity-integration-server:8086
SERVER_PORT: 8000
workers: 4
JAEGER: 10.213.84.109:6831
```

**ConfigMap**:
- apollo-config: a63aed137197768cd5b509604c95984c
- athena-config: aef9a1f08fc83c75fd13f0975c3f6733

### 3.14 ocr-ss (OCR识别)

```yaml
端口: (待确认)
```

### 3.15 convert-edms (文档转换)

```yaml
端口: (待确认)
```

### 3.16 reader-svc (阅读服务)

```yaml
端口: (待确认)
特殊: 需要替换yaml中的http_address_ip
```

---

## 4. AI模型完整配置

### 4.1 qingqiu-qwen3 (13B模型)

```yaml
镜像: hub.ai.aio.cloud/plss-ai/ascend-qwen3-arm:2.1.RC1-800I-A2-py311-openeuler24.03-lts
NPU: 0 (ASCEND_RT_VISIBLE_DEVICES=0)
端口: 1025
模型: qingqiu-Qwen3-13b-base
模型路径: /home/models/qingqiu-Qwen3-13b-base
资源: NPU × 1, 8Gi dshm
PVC: qingqiu-qwen3-pvc (40Gi, csi-rbd-sc)
挂载: /home/models/qingqiu-Qwen3-13b-base
HostPath备份: /data/AI/qingqiu-Qwen3-13b-base
```

**环境变量**:
```
ASCEND_RT_VISIBLE_DEVICES: "0"
MODEL_DIR: qingqiu-Qwen3-13b-base
RESERVED_MEMORY_GB: "10"
```

**InitContainer**: 检查模型文件并从备份恢复

### 4.2 qwen4b (4B模型)

```yaml
NPU: (待确认，预计NPU 1)
端口: (待确认)
模型: qwen4b
```

### 4.3 emb (Embedding模型)

```yaml
NPU: (待确认，预计NPU 2)
端口: (待确认)
```

### 4.4 reranker (重排序模型)

```yaml
NPU: (待确认，预计NPU 3)
端口: (待确认)
```

---

## 5. WPS Office完整配置

### 5.1 WPS服务列表 (11个)

| 服务 | 端口 | 用途 |
|------|------|------|
| apiserver | - | API服务器 |
| webword | - | Word在线编辑 |
| webpdf | - | PDF查看器 |
| webwpp | - | PPT在线编辑 |
| webet | - | Excel在线编辑 |
| htmlserver | 8080 | HTML渲染 |
| transcoder | - | 文档转码 |
| certserver | - | 证书服务 |
| cloudprovider | - | 云服务 |
| editproxy | - | 编辑代理 |
| staticserver | 8080 | 静态资源 |
| weboffice-nginx | 80/443 | Nginx反向代理 |
| encs-server | - | 加密服务 |
| sqlserver | - | SQL Server (可选) |
| weboffice-conf | - | 配置服务 |

### 5.2 WPS数据存储

```
/data/weboffice/log/ - 日志目录 (777权限)
/data/weboffice/html/ - 插件文件 (777权限)
```

### 5.3 WPS配置要点

- 需要替换 `http_address_ip` 变量
- etcd中存储大量WPS配置
- JS插件配置 (plugin.js, player.wasm, player.js)

---

## 6. 存储配置方案

### 6.1 Ceph RBD PVC汇总

| 服务 | PVC名称 | 容量 | 用途 |
|------|---------|------|------|
| PostgreSQL | postgres-pvc | 10Gi | 数据库文件 |
| MySQL | mysql-data-pvc | 20Gi | 数据库文件 |
| Redis | redis-pvc | 10Gi | 缓存数据 |
| Nacos | nacos-pvc-data | 10Gi | 配置数据 |
| Elasticsearch | data (StatefulSet) | 100Gi × 3 | 索引数据 |
| MinIO | minio-pvc | 10Gi | 对象存储 |
| Neo4j | neo4j-pvc | 5Gi | 图数据 |
| RabbitMQ | rabbitmq-pvc | 10Gi | 消息数据 |
| etcd | etcd-data-pvc | 20Gi | KV存储 |
| SLC | slc-data-pvc | 10Gi | 授权数据 |
| qingqiu-qwen3 | qingqiu-qwen3-pvc | 40Gi | 模型缓存 |

**总PVC容量**: ~355Gi

### 6.2 HostPath存储

| 路径 | 权限 | 用途 |
|------|------|------|
| /data/app/logs | 777 | 应用日志 |
| /data/app/import | 777 | 数据导入 |
| /data/app/nlp-capacity-integration | 777 | NLP集成数据 |
| /data/app/ofd2json | 777 | OFD转换数据 |
| /data/app/html | 777 | 前端静态文件 |
| /data/weboffice/log | 777 | WPS日志 |
| /data/weboffice/html | 777 | WPS插件 |
| /data/AI/qingqiu-Qwen3-13b-base | - | AI模型备份 |

---

## 7. 网络和端口汇总

### 7.1 中间件端口

| 服务 | 端口 | 协议 | 访问方式 |
|------|------|------|----------|
| PostgreSQL | 5432 | TCP | ClusterIP |
| MySQL | 3306 | TCP | ClusterIP |
| Redis | 6379 | TCP | ClusterIP (redis-svc) |
| Nacos | 8848/9848/9849 | TCP | ClusterIP + NodePort 38848 |
| Elasticsearch | 9200/9300 | TCP | Headless Service |
| MinIO | 9000/9090 | TCP | ClusterIP |
| Neo4j | 7474/7687 | TCP | ClusterIP |
| RabbitMQ | 5672/15672/1883 | TCP | ClusterIP |
| etcd | 2379 | TCP | ClusterIP |
| SLC | 9521 | TCP | ClusterIP + NodePort 39521 |

### 7.2 应用端口

| 服务 | 端口 | 说明 |
|------|------|------|
| plss-gateway | 8064 | API网关 |
| plss-system-server | 8061 | 系统管理 |
| plss-web | 30080 | 前端UI (需确认NodePort) |
| ai-qingqiu-13b-api | 8000 | AI API |
| qingqiu-qwen3 | 1025 | AI推理 |
| nlp-capacity-integration | 8086 | NLP集成 |

### 7.3 WPS端口

| 服务 | 端口 |
|------|------|
| weboffice-nginx | 80/443 (NodePort待确认) |
| htmlserver | 8080 |
| staticserver | 8080 |

---

## 8. 密钥和凭证汇总

### 8.1 数据库凭证

| 服务 | 用户 | 密码 |
|------|------|------|
| PostgreSQL | postgres / suwell | sw_1357924680 |
| MySQL | root | Wps+123 |
| Redis | - | suwell5394_redis |
| Nacos | nacos | nacos |
| Elasticsearch | elastic | h3bJ9GqD75Yz |
| MinIO | admin | G5pJ2kUq3L8M |
| Neo4j | neo4j | mkWcrFxXgTua |
| RabbitMQ | suwell | 3jH5gF7A9B1k |

### 8.2 加密密钥

| 名称 | 值 | 用途 |
|------|-----|------|
| configkey | 2d61e84bdcb6ee93face3fe1993e04ba | Jasypt配置加密 |
| secretkey | 60f279755a1a4c983331eea37232ae05 | Jasypt密钥加密 |
| apollo | a63aed137197768cd5b509604c95984c | Apollo配置 |
| athena | aef9a1f08fc83c75fd13f0975c3f6733 | Athena配置 |
| jasypt.keyId | 8ef966a1a9194c49a5eafd74cf7d302d | Jasypt密钥ID |
| NACOS_AUTH_TOKEN | 0123456789...666 | Nacos认证令牌 |

### 8.3 WPS AccessKey

```
AccessKey: AKIARI2NQQXXXXXX (已隐藏)
SecretKey: (已隐藏)
```

---

## 9. 安装执行步骤

### 9.1 官方安装流程

```bash
cd /ksc_aibox/source

# 步骤1: 安装中间件 (30-60分钟)
bash install-middle.sh
# 输入: all

# 步骤2: 安装WPS Office (10-20分钟)
bash install-weboffice.sh
# 输入: http://10.212.128.192:30080

# 步骤3: 安装应用服务 (20-40分钟)
bash install-app.sh
# 输入: all

# 步骤4: 安装AI模型 (10-30分钟)
bash install-AI.sh
# 输入: AI_910B
# 输入: all
```

### 9.2 安装详细流程

#### install-middle.sh

```
1. create_harbor_project
   - middleware, plss, weboffice, plss-ai

2. 对每个中间件:
   a. import_image (ctr import + push to Harbor)
   b. install_kubectl (kubectl apply)
   c. check_pod_status (等待Running)
   d. 执行特定脚本:
      - postgres: exec_postgres (执行SQL)
      - mysql: exec_mysql (执行create_table.sql)
      - nacos: exec_nacos (导入配置zip)
      - etcd: exec_etcd (替换http_address_ip)
```

#### install-weboffice.sh

```
1. import_image
2. init_log_directory (/data/weboffice/log)
3. init_weboffice_plugin (/data/weboffice/html)
4. exec_plugin (替换plugin.js中的http_address_ip)
5. install_kubectl (kubectl apply -f weboffice/)
```

#### install-app.sh

```
1. kubectl apply -f app/cm/ (ConfigMap)

2. 对每个应用:
   a. init_log_directory (/data/app/logs)
   b. init_data_import_directory (/data/app/import)
   c. 特殊初始化:
      - nlp-capacity-integration
      - plss-web (/data/app/html)
      - reader-svc (替换http_address_ip)
      - plss-search-server (解压ofd2json.tar)
   d. import_image
   e. install_kubectl
   f. check_pod_status
```

#### install-AI.sh

```
1. install_model (解压模型tar到/data/AI)
2. import_image
3. start_AI (kubectl create)
4. check_pod_status
```

---

## 10. Ansible自动化记录方案

### 10.1 设计原则

由于官方使用Shell脚本安装，我们将:
1. **用Ansible记录手工操作** - 将执行步骤转化为Playbook
2. **补充自动化能力** - 增加健康检查、回滚机制
3. **版本控制配置** - 所有配置变更通过Git管理

### 10.2 Playbook规划

```
ansible/playbooks/
├── 06-install-middlewares.yml          # 中间件安装
├── 07-install-weboffice.yml           # WPS Office安装
├── 08-install-applications.yml        # 应用服务安装
├── 09-install-ai-models.yml           # AI模型安装
├── 10-configure-nacos.yml             # Nacos配置导入
├── 11-execute-sql-scripts.yml         # 数据库SQL执行
├── 12-verify-installation.yml         # 安装验证
└── 99-rollback.yml                    # 回滚脚本
```

### 10.3 关键Ansible Tasks示例

```yaml
# 导入镜像
- name: Import Docker image to containerd
  shell: |
    ctr -n k8s.io image import {{ item }}
  loop: "{{ image_files }}"

# 推送镜像到Harbor
- name: Push image to Harbor
  shell: |
    ctr -n k8s.io images push --skip-verify --user admin:{{ harbor_password }} {{ image }}

# 应用K8s资源
- name: Apply Kubernetes manifests
  shell: |
    kubectl apply -f {{ yaml_file }}

# 等待Pod就绪
- name: Wait for Pod to be Running
  shell: |
    kubectl wait --for=condition=ready pod/{{ pod_name }} -n middle --timeout=600s

# 执行SQL脚本
- name: Execute SQL script in PostgreSQL
  shell: |
    kubectl cp {{ sql_file }} -n middle {{ pod_name }}:/tmp/{{ sql_file }}
    kubectl exec -n middle {{ pod_name }} -- psql -U postgres -d postgres -f /tmp/{{ sql_file }}
```

---

## 附录: 文件清单

### YAML配置文件 (83个)

- 中间件: 20个
- 应用: 32个
- WPS: 15个
- AI模型: 16个

### 脚本文件 (6个)

- install-middle.sh
- install-weboffice.sh
- install-app.sh
- install-AI.sh
- update.sh
- download.sh

### SQL文件 (7个)

- postgres/templates/*.sql
- mysql/templates/*.sql

### 其他配置 (6个)

- README.md
- README_下载说明.md
- etcd/templates/etcd.sh
- nacos/templates/*.zip

---

*文档生成时间: 2026-04-09*
*基于169GB完全解压后的深度分析*
*配置文件总数: 102个*
*维护团队: KSC AIBox Team*
