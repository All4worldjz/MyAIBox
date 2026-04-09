# vLLM在昇腾910B4上的部署和优化指南

**创建时间**: 2026-04-09  
**服务器**: ksc-aibox-node01 (10.212.128.192)  
**NPU**: 4张 昇腾910B4-1 (64GB HBM each)  
**CANN**: 9.0.0-beta.2  
**驱动**: 25.5.1

---

## 📋 目录

1. [环境概览](#环境概览)
2. [已找到的SKILL文档](#已找到的skill文档)
3. [当前状态](#当前状态)
4. [优化方案](#优化方案)
5. [部署步骤](#部署步骤)
6. [性能优化](#性能优化)
7. [故障排查](#故障排查)
8. [最佳实践](#最佳实践)

---

## 环境概览

### 硬件配置

| 组件 | 规格 |
|------|------|
| **CPU** | 华为鲲鹏920 5220, 64核 (2×32核) |
| **内存** | 250GB DDR4 |
| **NPU** | 4× 昇腾910B4-1, 64GB HBM each |
| **存储** | Samsung 990 PRO 4TB NVMe |
| **网络** | 华为HNS 25GE |

### NPU拓扑

```
NUMA节点0 (CPU 0-31):
  - NPU 3 (PCIe: 0000:02:00.0)
  - NPU 4 (PCIe: 0000:01:00.0)

NUMA节点1 (CPU 32-63):
  - NPU 1 (PCIe: 0000:82:00.0)
  - NPU 2 (PCIe: 0000:81:00.0)

跨NUMA延迟: 32 (相对值)
同NUMA延迟: 10 (相对值)
```

**⚠️ 关键**: NPU设备号是 **1-4**，不是0-3！

---

## 已找到的SKILL文档

### 1. vLLM-ascend_FAQ_Generator

**位置**: `src/agent-skills/vLLM-ascend_FAQ_Generator/SKILL.md`

**功能**: 
- 处理vllm-ascend项目已关闭Issue
- 生成Debug FAQ文档
- 分类归档问题

**用途**: 用于故障排查和知识库建设

### 2. Ansible vLLM部署Playbook

**位置**: `ansible/playbooks/02-install-vllm.yml`

**功能**:
- 模型下载
- vLLM Docker配置
- NPU设备权限配置
- 启动脚本生成

---

## 当前状态

### ✅ 已完成

| 项目 | 状态 | 详情 |
|------|------|------|
| **NPU驱动** | ✅ | 4张NPU健康，固件7.7.0.10.220 |
| **CANN环境** | ✅ | 9.0.0-beta.2，环境变量已完善 |
| **Docker** | ✅ | 18.09.0运行正常 |
| **模型目录** | ✅ | /ksc_aibox/models/llm 已创建 |
| **已下载模型** | ✅ | Qwen2.5-7B (15GB), Qwen2.5-14B (28GB) |
| **部署脚本** | ✅ | 已创建优化版本 |

### ⚠️ 待完成

| 项目 | 状态 | 说明 |
|------|------|------|
| **Docker镜像构建** | 🔄 | 后台构建中 |
| **vLLM服务启动** | ⏳ | 等待镜像完成 |
| **服务测试** | ⏳ | 等待服务启动 |
| **性能调优** | ⏳ | 需实际测试 |

---

## 优化方案

### 1. NPU设备号修复

**问题**: 原脚本使用`/dev/davinci0-3`，实际是`/dev/davinci1-4`

**修复**:
```bash
# 错误
--device /dev/davinci0,/dev/davinci1,/dev/davinci2,/dev/davinci3

# 正确
--device /dev/davinci1,/dev/davinci2,/dev/davinci3,/dev/davinci4
```

### 2. 内存优化

**问题**: 系统内存使用率98.3%，需降低vLLM内存占用

**优化配置**:
```bash
--gpu-memory-utilization 0.85  # 从0.9降到0.85
--max-model-len 4096           # 从8192降到4096
--shm-size 64g                 # 共享内存64GB
```

### 3. NUMA感知部署

**最优配置** (同NUMA节点配对):
```bash
# 方案A: 使用同NUMA节点的2张NPU (推荐)
export ASCEND_VISIBLE_DEVICES=3,4  # NUMA节点0
# 或
export ASCEND_VISIBLE_DEVICES=1,2  # NUMA节点1

# 方案B: 使用全部4张NPU (跨NUMA)
export ASCEND_VISIBLE_DEVICES=1,2,3,4  # 当前方案
```

### 4. Docker优化

**关键参数**:
```bash
--ulimit memlock=-1           # 解除内存锁定限制
--ulimit stack=67108864       # 栈大小64MB
--shm-size=64g                # 共享内存
--net host                    # 主机网络 (性能最优)
```

---

## 部署步骤

### 步骤1: 构建Docker镜像

```bash
# 已在后台执行
docker build -t vllm-ascend-optimized -f /ksc_aibox/scripts/vllm/Dockerfile.vllm-ascend-optimized /ksc_aibox/scripts/vllm/

# 查看构建日志
tail -f /ksc_aibox/logs/vllm-docker-build.log

# 检查镜像
docker images | grep vllm-ascend
```

### 步骤2: 启动vLLM服务

```bash
# 启动Qwen2.5-7B
/ksc_aibox/scripts/vllm/start-vllm-optimized.sh Qwen2.5-7B-Instruct 8000

# 或启动Qwen2.5-14B (需要更多内存)
/ksc_aibox/scripts/vllm/start-vllm-optimized.sh Qwen2.5-14B-Instruct 8001
```

### 步骤3: 测试服务

```bash
# 运行测试脚本
/ksc_aibox/scripts/vllm/test-vllm-optimized.sh 8000 Qwen2.5-7B-Instruct

# 手动测试
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-7B-Instruct",
    "prompt": "你好，请介绍一下自己",
    "max_tokens": 200
  }'
```

### 步骤4: 管理服务

```bash
# 查看状态
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh status

# 查看日志
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh logs Qwen2.5-7B-Instruct

# 停止服务
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh stop Qwen2.5-7B-Instruct

# 列出模型
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh list
```

---

## 性能优化

### 1. vLLM参数调优

```bash
# 基础配置
--tensor-parallel-size 4           # 4张NPU并行
--gpu-memory-utilization 0.85      # GPU内存利用率
--max-model-len 4096               # 最大序列长度
--max-num-batched-tokens 8192      # 批量token数
--max-num-seqs 256                 # 最大并发序列数

# 性能优化
--disable-log-requests             # 禁用请求日志 (生产环境)
--enforce-eager                    # 强制Eager模式 (避免编译开销)
--swap-space 8                     # CPU交换空间(GB)

# NPU特定
VLLM_NPU_ENABLE_CANN_ALLOCATOR=1   # 启用CANN内存分配器
VLLM_WORKER_MULTIPROC_METHOD=spawn # 多进程启动方法
```

### 2. NUMA绑定优化

**创建NUMA感知启动脚本**:
```bash
#!/bin/bash
# start-vllm-numa-aware.sh

# 绑定到NUMA节点0 (NPU 3,4)
numactl --cpunodebind=0 --membind=0 \
  docker run -d \
    --name vllm-numa-optimized \
    --device /dev/davinci3 \
    --device /dev/davinci4 \
    ...
```

### 3. 内存管理

**降低内存占用**:
```bash
# 1. 降低max-model-len
--max-model-len 2048  # 如果不需要长上下文

# 2. 限制并发
--max-num-seqs 128    # 限制并发请求数

# 3. 使用量化模型
# 如果有INT8/INT4量化模型，可大幅降低内存占用
```

### 4. 性能基准测试

```bash
# 安装benchmark工具
pip3 install vllm-benchmark

# 运行测试
python3 -m vllm.entrypoints.benchmark_serving \
    --model /model \
    --backend vllm \
    --dataset-name random \
    --num-prompts 1000 \
    --request-rate 10
```

---

## 故障排查

### 问题1: 容器启动失败

**症状**: `docker run`后立即退出

**排查**:
```bash
# 查看日志
docker logs vllm-Qwen2.5-7B-Instruct

# 常见问题:
# 1. 模型路径错误
# 2. NPU设备权限不足
# 3. 内存不足
# 4. CANN环境未正确加载
```

### 问题2: NPU不可用

**症状**: `No NPU devices found`

**解决**:
```bash
# 1. 检查设备文件
ls -la /dev/davinci*

# 2. 检查驱动
npu-smi info

# 3. 检查容器内设备
docker exec vllm-Qwen2.5-7B-Instruct ls -la /dev/davinci*

# 4. 修复权限
chmod 666 /dev/davinci*
```

### 问题3: 内存溢出 (OOM)

**症状**: 容器被kill，或`OutOfMemoryError`

**解决**:
```bash
# 1. 降低内存利用率
--gpu-memory-utilization 0.75

# 2. 减小max-model-len
--max-model-len 2048

# 3. 减少并发
--max-num-seqs 64

# 4. 使用更小模型
# 或启动单NPU模式
--tensor-parallel-size 1
```

### 问题4: 性能低下

**症状**: 推理速度慢，延迟高

**优化**:
```bash
# 1. 检查NPU使用率
npu-smi info  # 查看AICORE使用率

# 2. 使用同NUMA节点NPU
export ASCEND_VISIBLE_DEVICES=3,4  # 或 1,2

# 3. 启用CANN分配器
VLLM_NPU_ENABLE_CANN_ALLOCATOR=1

# 4. 禁用不必要的功能
--disable-log-requests
--disable-log-stats
```

---

## 最佳实践

### 1. 模型选择

| 模型 | 参数量 | 内存占用 | 推荐NPU数 | 适用场景 |
|------|--------|----------|-----------|----------|
| Qwen2.5-7B | 7B | ~15GB | 2张 | 快速响应，低延迟 |
| Qwen2.5-14B | 14B | ~28GB | 4张 | 平衡性能和质量 |
| Qwen2.5-32B | 32B | ~64GB | 4张 | 高质量生成 |
| DeepSeek-R1 | 70B+ | ~140GB | 需更多NPU | 当前不可用 |

### 2. 生产环境配置

```bash
# 生产环境推荐
--tensor-parallel-size 4
--gpu-memory-utilization 0.80
--max-model-len 4096
--max-num-seqs 256
--disable-log-requests
--enable-metrics  # 启用Prometheus指标
--metrics-port 8080
```

### 3. 监控和告警

```bash
# 监控NPU状态
watch -n 5 'npu-smi info | grep -E "NPU|Health|AICORE"'

# 监控容器
docker stats vllm-*

# 监控API
curl http://localhost:8000/metrics | grep vllm
```

### 4. 安全加固

```bash
# 1. 限制API访问
--host 127.0.0.1  # 仅本地访问

# 2. 使用反向代理 (Nginx)
# 3. 启用HTTPS
# 4. 添加认证
# 5. 限制请求大小
```

---

## 已创建的脚本

| 脚本 | 路径 | 功能 |
|------|------|------|
| **部署脚本** | `/scripts/deploy-vllm-ascend.sh` | 完整的部署和优化脚本 |
| **Dockerfile** | `/ksc_aibox/scripts/vllm/Dockerfile.vllm-ascend-optimized` | 优化版Dockerfile |
| **启动脚本** | `/ksc_aibox/scripts/vllm/start-vllm-optimized.sh` | vLLM启动脚本 |
| **管理脚本** | `/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh` | 服务管理脚本 |
| **测试脚本** | `/ksc_aibox/scripts/vllm/test-vllm-optimized.sh` | 服务测试脚本 |

---

## 下一步行动

1. ✅ **已完成**: 部署脚本创建
2. 🔄 **进行中**: Docker镜像构建 (后台执行)
3. ⏳ **待执行**: 启动vLLM服务
4. ⏳ **待执行**: 运行测试
5. ⏳ **待执行**: 性能调优
6. ⏳ **待执行**: 部署FAQ生成器 (使用vLLM-ascend_FAQ_Generator SKILL)

---

## 相关文档

- `/docs/npu-driver-troubleshooting-report.md` - NPU驱动排查报告
- `/docs/npu-driver-installation-final-report.md` - NPU驱动最终报告
- `/ansible/playbooks/02-install-vllm.yml` - Ansible vLLM部署Playbook
- `src/agent-skills/vLLM-ascend_FAQ_Generator/SKILL.md` - vLLM FAQ生成器SKILL

---

**文档维护**: AI Assistant  
**最后更新**: 2026-04-09 22:50
