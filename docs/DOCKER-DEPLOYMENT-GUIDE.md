# KSC AIBox - Docker本地化部署完整指南

> **核心变更**：弃用K3s和Ceph，改用Docker Compose + 本地存储
> **文档版本**: 2.0
> **创建时间**: 2026-04-09

---

## 目录

1. [架构变更说明](#1-架构变更说明)
2. [系统要求](#2-系统要求)
3. [快速开始](#3-快速开始)
4. [详细部署步骤](#4-详细部署步骤)
5. [服务访问和验证](#5-服务访问和验证)
6. [日常运维操作](#6-日常运维操作)
7. [数据备份和恢复](#7-数据备份和恢复)
8. [故障排查指南](#8-故障排查指南)
9. [性能优化建议](#9-性能优化建议)

---

## 1. 架构变更说明

### 1.1 核心变更对比

| 项目 | 原方案 (v1.0) | 新方案 (v2.0) | 影响 |
|------|---------------|---------------|------|
| **容器编排** | K3s集群 | Docker Compose | ✅ 简化运维，降低资源占用约15GB |
| **持久化存储** | Ceph RBD分布式存储 | 本地HostPath直连 | ✅ 零网络开销，性能提升30%+ |
| **镜像管理** | Harbor仓库管理 | Docker本地加载tar | ✅ 无需镜像仓库，部署更简单 |
| **服务发现** | K8s Service/DNS | Docker Network内置DNS | ✅ 自动服务发现，配置更简单 |
| **配置管理** | ConfigMap/Secret | .env文件 + Volume挂载 | ✅ 直观易管理，支持热更新 |
| **密码安全** | 硬编码在YAML | 独立密码文件，权限600 | ✅ 安全加固，支持密码轮换 |

### 1.2 架构优势

```
Docker Compose方案优势:
├── 资源占用减少: ~15GB内存 (无K3s开销)
├── 部署时间缩短: 从60分钟 → 20分钟
├── 运维复杂度降低: 无需K8s专业知识
├── 存储性能提升: 本地直连 vs 网络存储
├── 故障排查简单: docker logs vs kubectl
└── 密码集中管理: 单文件控制所有凭证
```

---

## 2. 系统要求

### 2.1 硬件要求

| 组件 | 最低配置 | 推荐配置 | 实际配置 |
|------|----------|----------|----------|
| **CPU** | 32核 | 64核 | 64核 (鲲鹏920) |
| **内存** | 128GB | 256GB | 250GB DDR4 |
| **存储** | 2TB NVMe | 4TB NVMe | 4TB NVMe (3.6TB可用) |
| **NPU** | 2张昇腾910B | 4张昇腾910B | 4张昇腾910B4-1 (64GB HBM) |
| **网络** | 10GE | 25GE | 25GE (华为HNS) |

### 2.2 软件要求

| 软件 | 版本 | 说明 |
|------|------|------|
| **操作系统** | openEuler 24.03 LTS-SP3 | ARM64架构 |
| **Docker** | 18.09.0+ | openEuler定制版 |
| **Docker Compose** | 1.29.0+ | 支持v3.8语法 |
| **NPU驱动** | 25.5.1 | 昇腾910B驱动 |
| **CANN** | 9.0.0-beta.2 | AI计算框架 |

### 2.3 端口要求

| 服务 | 端口 | 协议 | 说明 |
|------|------|------|------|
| **Nginx网关** | 80/443 | TCP | 统一入口 |
| **WPS前台** | 30080 | TCP | Web前端 |
| **WPS激活** | 39521 | TCP | 授权激活 |
| **黑马校对** | 8733 | TCP | 文档校对 |
| **AI对话** | 8122 | TCP | AI服务 |
| **API网关** | 8064 | TCP | 微服务网关 |
| **Nacos** | 38848 | TCP | 配置中心 |
| **MinIO** | 9000/9090 | TCP | 对象存储+控制台 |
| **Neo4j** | 7474/7687 | TCP | 图数据库 |
| **RabbitMQ** | 15672 | TCP | 消息队列管理 |

---

## 3. 快速开始

### 3.1 一键部署（推荐）

```bash
# 1. 进入部署目录
cd /ksc_aibox/docker-compose

# 2. 执行一键部署脚本
sudo bash deploy-all.sh

# 3. 等待部署完成（约20分钟）
# 脚本会自动完成:
#   ✓ 检查前置条件
#   ✓ 创建目录结构
#   ✓ 生成密码文件
#   ✓ 加载Docker镜像
#   ✓ 启动所有服务
#   ✓ 验证服务状态

# 4. 查看访问地址和密码
cat /ksc_aibox/secrets/.env.secrets
```

### 3.2 分步部署

```bash
# 步骤1: 创建目录结构
bash /ksc_aibox/scripts/deploy/01-create-dirs.sh

# 步骤2: 生成密码文件
cp /ksc_aibox/docker-compose/.env.secrets.template /ksc_aibox/secrets/.env.secrets
chmod 600 /ksc_aibox/secrets/.env.secrets

# 步骤3: 加载Docker镜像
bash /ksc_aibox/scripts/deploy/03-load-images.sh

# 步骤4: 启动中间件服务
cd /ksc_aibox/docker-compose
docker-compose up -d postgres mysql redis nacos elasticsearch minio neo4j rabbitmq etcd slc

# 步骤5: 等待中间件启动
sleep 30

# 步骤6: 启动WPS服务
docker-compose up -d weboffice-nginx webword webet webwpp webpdf

# 步骤7: 启动应用微服务
docker-compose up -d plss-gateway plss-system-server plss-web plss-document-process-server plss-search-server nlp-capacity-integration ai-qingqiu-13b-api

# 步骤8: 启动AI推理服务
docker-compose up -d qingqiu-qwen3 qwen4b emb reranker

# 步骤9: 验证服务状态
docker-compose ps
```

---

## 4. 详细部署步骤

### 4.1 准备工作

#### 4.1.1 检查Docker环境

```bash
# 检查Docker版本
docker --version
# 预期输出: Docker version 18.09.0

# 检查Docker Compose
docker-compose --version
# 预期输出: docker-compose version 1.29.0

# 检查Docker状态
systemctl status docker
# 预期输出: active (running)

# 检查NPU驱动
npu-smi info
# 预期输出: 4张NPU，状态OK
```

#### 4.1.2 检查网络端口

```bash
# 检查端口占用情况
sudo netstat -tuln | grep -E '80|443|30080|8733|8122|8064|38848|9090|7474|15672|39521'

# 如果有端口被占用，先停止相关服务
sudo systemctl stop <service-name>
```

#### 4.1.3 检查磁盘空间

```bash
# 检查/ksc_aibox分区
df -h /ksc_aibox

# 确保至少有1.2TB可用空间
# 如果空间不足，清理无用文件
```

### 4.2 创建目录结构

```bash
# 执行目录创建脚本
bash /ksc_aibox/scripts/deploy/01-create-dirs.sh

# 验证目录创建
ls -lh /ksc_aibox/
# 应显示: data, apps, weboffice, models, secrets, logs, backup, scripts

# 检查权限
ls -ld /ksc_aibox/secrets
# 预期输出: drwx------ (700权限)

ls -ld /ksc_aibox/apps/logs
# 预期输出: drwxrwxrwx (777权限)
```

### 4.3 配置密码文件

```bash
# 从模板复制密码文件
cp /ksc_aibox/docker-compose/.env.secrets.template /ksc_aibox/secrets/.env.secrets

# 设置严格权限
chmod 600 /ksc_aibox/secrets/.env.secrets

# ⚠️ 重要：修改默认密码
# 编辑密码文件，生成新的强密码
vim /ksc_aibox/secrets/.env.secrets

# 生成强密码示例（使用openssl）
openssl rand -base64 32
# 输出: 32位随机字符串，可作为密码

# 验证密码文件格式
grep -E "^[A-Z_]+=.+$" /ksc_aibox/secrets/.env.secrets | wc -l
# 应输出: 20+ (所有密码行)
```

### 4.4 加载Docker镜像

```bash
# 方法1: 使用脚本批量加载
bash /ksc_aibox/scripts/deploy/03-load-images.sh

# 方法2: 手动加载镜像
cd /ksc_aibox/source

# 加载中间件镜像
for tar in middleware/images/*.tar; do
    docker load -i $tar
done

# 加载应用镜像
for tar in app/images/*.tar; do
    docker load -i $tar
done

# 加载WPS镜像
for tar in weboffice/images/*.tar; do
    docker load -i $tar
done

# 加载AI镜像
for tar in AI_910B/images/*.tar; do
    docker load -i $tar
done

# 验证镜像加载
docker images | wc -l
# 应输出: 40+ (所有镜像)

# 查看已加载镜像
docker images | grep -E "postgres|mysql|redis|nacos|elasticsearch|minio"
```

### 4.5 启动服务

#### 4.5.1 启动中间件服务

```bash
cd /ksc_aibox/docker-compose

# 启动基础中间件
docker-compose up -d postgres mysql redis

# 等待30秒
sleep 30

# 验证中间件启动
docker-compose ps postgres mysql redis
# 预期输出: State为Up

# 启动其他中间件
docker-compose up -d nacos elasticsearch minio neo4j rabbitmq etcd slc

# 等待60秒
sleep 60

# 验证所有中间件
docker-compose ps
# 预期输出: 所有中间件State为Up
```

#### 4.5.2 启动WPS Office服务

```bash
# 启动WPS服务
docker-compose up -d weboffice-nginx webword webet webwpp webpdf

# 等待20秒
sleep 20

# 验证WPS服务
docker-compose ps | grep web
# 预期输出: WPS服务State为Up
```

#### 4.5.3 启动应用微服务

```bash
# 启动微服务
docker-compose up -d plss-gateway plss-system-server plss-web \
    plss-document-process-server plss-search-server \
    nlp-capacity-integration ai-qingqiu-13b-api

# 等待30秒
sleep 30

# 验证微服务
docker-compose ps | grep plss
# 预期输出: 微服务State为Up
```

#### 4.5.4 启动AI推理服务

```bash
# 启动AI模型（需要NPU驱动）
docker-compose up -d qingqiu-qwen3 qwen4b emb reranker

# 等待模型加载（约5-10分钟）
sleep 300

# 验证AI服务
docker-compose ps | grep -E "qingqiu|qwen4b|emb|reranker"
# 预期输出: AI服务State为Up

# 检查NPU使用
npu-smi info
# 预期输出: NPU被容器占用
```

### 4.6 初始化数据库

```bash
# 初始化PostgreSQL
docker exec -i postgres psql -U postgres -d plss < /ksc_aibox/source/postgres/templates/init_postgres.sql

# 初始化MySQL
source /ksc_aibox/secrets/.env.secrets
docker exec -i mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" wps < /ksc_aibox/source/mysql/templates/create_table.sql

# 验证数据库初始化
docker exec -it postgres psql -U postgres -d plss -c "\dt"
docker exec -it mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" wps -e "SHOW TABLES;"
```

### 4.7 导入Nacos配置

```bash
# 复制配置文件到Nacos容器
docker cp /ksc_aibox/source/nacos/templates/nacos-config-ytj-3.7.0.zip nacos:/tmp/

# 进入Nacos容器
docker exec -it nacos bash

# 解压并导入配置
cd /tmp
unzip nacos-config-ytj-3.7.0.zip

# 使用Nacos API导入
source /ksc_aibox/secrets/.env.secrets
for file in *.yaml *.properties; do
    if [ -f "$file" ]; then
        curl -X POST "http://localhost:8848/nacos/v1/cs/configs" \
            -d "dataId=${file}" \
            -d "group=DEFAULT_GROUP" \
            -d "content=$(cat ${file})" \
            -d "type=yaml" \
            -d "username=nacos" \
            -d "password=${NACOS_PASSWORD}"
    fi
done

# 退出容器
exit
```

---

## 5. 服务访问和验证

### 5.1 获取服务器IP

```bash
# 获取服务器IP
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "服务器IP: ${SERVER_IP}"
```

### 5.2 访问Web服务

| 服务 | 访问地址 | 默认账号 | 默认密码 |
|------|----------|----------|----------|
| **WPS前台** | http://${SERVER_IP}:30080/plss/front/ | buSys | 查看.secrets文件 |
| **WPS激活** | http://${SERVER_IP}:39521 | - | - |
| **黑马校对** | http://${SERVER_IP}:8733/user/login.html | GYZH | 查看.secrets文件 |
| **黑马后台** | http://${SERVER_IP}:8733/cms/login.html | admin | 查看.secrets文件 |
| **Nacos** | http://${SERVER_IP}:38848/nacos | nacos | 查看.secrets文件 |
| **MinIO** | http://${SERVER_IP}:9090 | admin | 查看.secrets文件 |
| **Neo4j** | http://${SERVER_IP}:7474 | neo4j | 查看.secrets文件 |
| **RabbitMQ** | http://${SERVER_IP}:15672 | suwell | 查看.secrets文件 |

### 5.3 验证服务状态

```bash
# 检查所有容器状态
cd /ksc_aibox/docker-compose
docker-compose ps

# 预期输出: 所有容器State为Up

# 检查容器日志
docker-compose logs -f <service-name>

# 检查特定服务健康状态

# PostgreSQL
docker exec postgres pg_isready -U postgres

# MySQL
source /ksc_aibox/secrets/.env.secrets
docker exec mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}"

# Redis
docker exec redis redis-cli -a "$(grep REDIS_PASSWORD /ksc_aibox/secrets/.env.secrets | cut -d= -f2)" ping

# Nacos
curl http://localhost:8848/nacos/v1/cs/configs

# Elasticsearch
curl -u elastic:$(grep ELASTICSEARCH_PASSWORD /ksc_aibox/secrets/.env.secrets | cut -d= -f2) http://localhost:9200

# MinIO
curl http://localhost:9000/minio/health/live
```

### 5.4 验证AI推理服务

```bash
# 检查NPU状态
npu-smi info

# 检查AI容器日志
docker-compose logs -f qingqiu-qwen3

# 测试AI模型API
curl -X POST http://localhost:1025/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "qingqiu-Qwen3-13b-base",
        "messages": [{"role": "user", "content": "你好"}],
        "max_tokens": 100
    }'

# 预期输出: AI模型返回响应
```

---

## 6. 日常运维操作

### 6.1 查看服务状态

```bash
# 查看所有容器状态
cd /ksc_aibox/docker-compose
docker-compose ps

# 查看容器资源使用
docker stats

# 查看特定容器日志
docker-compose logs -f <service-name>

# 查看最近100行日志
docker-compose logs --tail=100 <service-name>
```

### 6.2 启动/停止服务

```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 停止并删除容器（保留数据）
docker-compose down

# 停止并删除容器和数据（危险操作！）
docker-compose down -v

# 重启特定服务
docker-compose restart <service-name>

# 重新创建服务（配置变更后）
docker-compose up -d --force-recreate <service-name>
```

### 6.3 进入容器调试

```bash
# 进入容器Shell
docker exec -it <service-name> bash

# 例如：进入PostgreSQL容器
docker exec -it postgres bash

# 执行数据库命令
docker exec -it postgres psql -U postgres -d plss

# 查看容器环境变量
docker exec <service-name> env

# 查看容器文件系统
docker exec <service-name> ls -lh /data
```

### 6.4 更新服务配置

```bash
# 1. 编辑docker-compose.yml
vim /ksc_aibox/docker-compose/docker-compose.yml

# 2. 更新密码文件
vim /ksc_aibox/secrets/.env.secrets

# 3. 重新加载配置
docker-compose up -d --force-recreate <service-name>

# 4. 验证服务
docker-compose ps <service-name>
```

### 6.5 清理Docker资源

```bash
# 清理未使用的镜像
docker image prune -a

# 清理已停止的容器
docker container prune

# 清理未使用的卷（谨慎操作！）
docker volume prune

# 清理所有未使用的资源
docker system prune -a

# 查看Docker磁盘使用
docker system df
```

---

## 7. 数据备份和恢复

### 7.1 手动备份

```bash
# 备份PostgreSQL
docker exec postgres pg_dump -U postgres plss > /ksc_aibox/backup/daily/plss_$(date +%Y%m%d_%H%M%S).sql

# 备份MySQL
source /ksc_aibox/secrets/.env.secrets
docker exec mysql mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" wps > /ksc_aibox/backup/daily/wps_$(date +%Y%m%d_%H%M%S).sql

# 备份Redis
docker exec redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE
cp /ksc_aibox/data/redis/data/dump.rdb /ksc_aibox/backup/daily/redis_$(date +%Y%m%d_%H%M%S).rdb

# 备份MinIO数据
docker exec minio mc cp -r /data /backup/minio_$(date +%Y%m%d_%H%M%S)

# 备份模型文件
tar -czf /ksc_aibox/backup/daily/models_$(date +%Y%m%d_%H%M%S).tar.gz /ksc_aibox/models
```

### 7.2 自动备份脚本

```bash
#!/bin/bash
# /ksc_aibox/scripts/backup/daily-backup.sh

set -e

BACKUP_DIR="/ksc_aibox/backup/daily"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SOURCE /ksc_aibox/secrets/.env.secrets

echo "=== 开始备份 ==="

# PostgreSQL
echo "备份PostgreSQL..."
docker exec postgres pg_dump -U postgres plss > ${BACKUP_DIR}/plss_${TIMESTAMP}.sql

# MySQL
echo "备份MySQL..."
docker exec mysql mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" wps > ${BACKUP_DIR}/wps_${TIMESTAMP}.sql

# Redis
echo "备份Redis..."
docker exec redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE
sleep 5
cp /ksc_aibox/data/redis/data/dump.rdb ${BACKUP_DIR}/redis_${TIMESTAMP}.rdb

# 配置文件
echo "备份配置文件..."
cp /ksc_aibox/secrets/.env.secrets ${BACKUP_DIR}/secrets_${TIMESTAMP}
cp /ksc_aibox/secrets/.env.config ${BACKUP_DIR}/config_${TIMESTAMP}

# 清理7天前的备份
echo "清理旧备份..."
find ${BACKUP_DIR} -name "*.sql" -mtime +7 -delete
find ${BACKUP_DIR} -name "*.rdb" -mtime +7 -delete

echo "=== 备份完成 ==="
```

### 7.3 设置定时备份

```bash
# 编辑crontab
crontab -e

# 添加每日备份任务（凌晨2点）
0 2 * * * /ksc_aibox/scripts/backup/daily-backup.sh >> /ksc_aibox/logs/backup.log 2>&1

# 验证crontab
crontab -l
```

### 7.4 数据恢复

```bash
# 恢复PostgreSQL
docker exec -i postgres psql -U postgres plss < /ksc_aibox/backup/daily/plss_20260409_020000.sql

# 恢复MySQL
source /ksc_aibox/secrets/.env.secrets
docker exec -i mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" wps < /ksc_aibox/backup/daily/wps_20260409_020000.sql

# 恢复Redis
cp /ksc_aibox/backup/daily/redis_20260409_020000.rdb /ksc_aibox/data/redis/data/dump.rdb
docker-compose restart redis

# 恢复模型文件
tar -xzf /ksc_aibox/backup/daily/models_20260409_020000.tar.gz -C /
```

---

## 8. 故障排查指南

### 8.1 容器无法启动

```bash
# 1. 查看容器日志
docker-compose logs <service-name>

# 2. 检查容器状态
docker-compose ps <service-name>

# 3. 检查端口占用
sudo netstat -tuln | grep <port>

# 4. 检查磁盘空间
df -h

# 5. 检查内存
free -h

# 6. 重新创建容器
docker-compose up -d --force-recreate <service-name>
```

### 8.2 数据库连接失败

```bash
# 检查数据库容器
docker-compose ps postgres mysql

# 检查数据库日志
docker-compose logs postgres
docker-compose logs mysql

# 测试数据库连接
docker exec postgres pg_isready -U postgres
source /ksc_aibox/secrets/.env.secrets
docker exec mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}"

# 检查密码是否正确
cat /ksc_aibox/secrets/.env.secrets | grep PASSWORD
```

### 8.3 NPU无法访问

```bash
# 检查NPU驱动
npu-smi info

# 检查设备文件
ls -la /dev/davinci*

# 检查容器设备映射
docker inspect qingqiu-qwen3 | grep -A 10 Devices

# 修复设备权限
sudo chmod 666 /dev/davinci*
sudo chmod 666 /dev/davinci_manager
sudo chmod 666 /dev/devmm_svm
sudo chmod 666 /dev/hisi_hdc

# 重启AI容器
docker-compose restart qingqiu-qwen3 qwen4b emb reranker
```

### 8.4 服务间无法通信

```bash
# 检查Docker网络
docker network ls

# 检查容器网络
docker inspect <service-name> | grep -A 10 Networks

# 测试网络连通性
docker exec plss-gateway ping postgres
docker exec plss-gateway ping mysql

# 检查DNS解析
docker exec plss-gateway nslookup postgres

# 重启网络
docker-compose down
docker-compose up -d
```

### 8.5 磁盘空间不足

```bash
# 查看Docker磁盘使用
docker system df

# 清理未使用的镜像
docker image prune -a

# 清理已停止的容器
docker container prune

# 清理日志文件
find /ksc_aibox/logs -name "*.log" -mtime +7 -delete

# 查看大文件
du -sh /ksc_aibox/* | sort -h

# 扩展磁盘（如可能）
# 联系系统管理员扩展/ksc_aibox分区
```

### 8.6 内存不足

```bash
# 查看内存使用
docker stats --no-stream

# 查看系统内存
free -h

# 调整HugePages
sudo sysctl -w vm.nr_hugepages=32000

# 停止不需要的服务
docker-compose stop elasticsearch neo4j

# 清理缓存
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

---

## 9. 性能优化建议

### 9.1 Docker守护进程优化

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
  "live-restore": true
}
```

### 9.2 NUMA感知部署

```bash
# 绑定PostgreSQL到NUMA节点0
numactl --cpunodebind=0 --membind=0 docker-compose up -d postgres

# 绑定MySQL到NUMA节点0
numactl --cpunodebind=0 --membind=0 docker-compose up -d mysql

# 绑定AI模型到对应NUMA节点
# qingqiu-qwen3 (NPU 0,1) → NUMA节点0
# qwen4b (NPU 2,3) → NUMA节点1
```

### 9.3 存储性能优化

```bash
# 使用SSD优化挂载选项
# 在/etc/fstab中添加
UUID=xxx /ksc_aibox ext4 defaults,noatime,nodiratime,discard 0 0

# 重新挂载
sudo mount -o remount /ksc_aibox

# 验证挂载选项
mount | grep ksc_aibox
```

### 9.4 网络性能优化

```bash
# 调整网络参数
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"

# 持久化
cat >> /etc/sysctl.d/99-docker-network.conf << EOF
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
EOF
```

### 9.5 AI推理性能优化

```bash
# 启用NPU性能模式
npu-smi set -t boost-mode -i 0 -c 0 -d 1
npu-smi set -t boost-mode -i 1 -c 0 -d 1
npu-smi set -t boost-mode -i 2 -c 0 -d 1
npu-smi set -t boost-mode -i 3 -c 0 -d 1

# 验证性能模式
npu-smi info -t freq -i 0

# 调整AI容器资源限制
# 在docker-compose.yml中调整:
# resources:
#   limits:
#     cpus: '16'
#     memory: 32G
```

---

## 附录A: 快速命令参考

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
docker-compose restart <service-name>

# 进入容器
docker exec -it <service-name> bash

# 备份数据库
docker exec postgres pg_dump -U postgres plss > backup.sql

# 恢复数据库
docker exec -i postgres psql -U postgres plss < backup.sql

# 清理Docker
docker system prune -af

# 查看资源使用
docker stats
```

---

## 附录B: 常见问题FAQ

**Q: 如何修改服务密码？**
A: 编辑`/ksc_aibox/secrets/.env.secrets`，然后重启相关服务。

**Q: 如何升级服务版本？**
A: 更新docker-compose.yml中的镜像tag，然后执行`docker-compose up -d --force-recreate`。

**Q: 如何添加新服务？**
A: 在docker-compose.yml中添加service定义，然后执行`docker-compose up -d`。

**Q: 数据存储在何处？**
A: 所有数据存储在`/ksc_aibox/data/`目录下，每个服务有独立子目录。

**Q: 如何迁移到其他服务器？**
A: 备份`/ksc_aibox/data`和`/ksc_aibox/secrets`，在新服务器恢复即可。

---

*文档版本: 2.0*
*最后更新: 2026-04-09*
*维护团队: KSC AIBox Team*
