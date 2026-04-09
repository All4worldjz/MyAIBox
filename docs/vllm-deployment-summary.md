# vLLM在昇腾910B4上的部署和优化 - 执行总结

**执行时间**: 2026-04-09 22:50  
**执行人**: AI Assistant  
**基于SKILL**: vLLM-ascend_FAQ_Generator + Ansible Playbook 02-install-vllm

---

## 📊 执行总结

### ✅ 已完成的工作

| 任务 | 状态 | 详情 |
|------|------|------|
| **1. 搜索本地SKILL** | ✅ | 找到vLLM-ascend_FAQ_Generator |
| **2. 环境检查** | ✅ | NPU/Docker/模型状态确认 |
| **3. NPU设备号修复** | ✅ | 确认设备号为1-4 (非0-3) |
| **4. 优化脚本创建** | ✅ | 4个优化脚本已生成 |
| **5. 模型文件确认** | ✅ | Qwen2.5-7B (15GB) 和 14B (28GB) 已下载 |
| **6. 环境变量优化** | ✅ | CANN环境变量已完善 |
| **7. 部署文档** | ✅ | 完整部署指南已生成 |

### ⚠️ 待完成的工作

| 任务 | 原因 | 下一步 |
|------|------|--------|
| **Docker镜像构建** | torch-npu URL变化 | 使用官方镜像或手动安装 |
| **vLLM服务启动** | 依赖镜像 | 先解决镜像问题 |
| **服务测试** | 依赖服务启动 | 服务启动后执行 |

---

## 📁 已创建的文件

### 脚本文件

| 文件 | 路径 | 大小 | 功能 |
|------|------|------|------|
| **部署脚本** | `/scripts/deploy-vllm-ascend.sh` | 18KB | 完整的部署和优化脚本 |
| **Dockerfile优化版** | `/ksc_aibox/scripts/vllm/Dockerfile.vllm-ascend-optimized` | - | 优化的Dockerfile |
| **Dockerfile简化版** | `/ksc_aibox/scripts/vllm/Dockerfile.vllm-simple` | - | 简化版Dockerfile |
| **启动脚本** | `/ksc_aibox/scripts/vllm/start-vllm-optimized.sh` | - | vLLM启动脚本 |
| **管理脚本** | `/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh` | - | 服务管理脚本 |
| **测试脚本** | `/ksc_aibox/scripts/vllm/test-vllm-optimized.sh` | - | 服务测试脚本 |

### 文档文件

| 文件 | 路径 | 内容 |
|------|------|------|
| **部署指南** | `/docs/vllm-ascend-deployment-guide.md` | 完整的部署和优化指南 |
| **NPU驱动报告** | `/docs/npu-driver-troubleshooting-report.md` | NPU驱动排查报告 |
| **NPU最终报告** | `/docs/npu-driver-installation-final-report.md` | NPU驱动最终结论 |

---

## 🔍 发现的问题和优化点

### 1. ✅ NPU设备号修复

**问题**: 原脚本使用`/dev/davinci0-3`  
**实际**: 设备号是`/dev/davinci1-4`  
**修复**: 所有脚本已更新为正确的设备号

### 2. ✅ 内存优化

**问题**: 系统内存使用率98.3%  
**优化**:
- `--gpu-memory-utilization 0.85` (从0.9降低)
- `--max-model-len 4096` (从8192降低)
- `--shm-size 64g` (共享内存)

### 3. ✅ 环境变量完善

**新增**:
- `ASCEND_TOOL_PATH`
- `ASCEND_OPP_PATH`
- CANN库路径 (LD_LIBRARY_PATH)
- CANN工具路径 (PATH)
- Python API路径 (PYTHONPATH)

### 4. ⚠️ Docker镜像构建问题

**原因**: torch-npu的下载URL发生变化  
**解决方案**:
1. **方案A (推荐)**: 使用华为官方vLLM-ascend镜像
   ```bash
   docker pull swr.cn-south-1.myhuaweicloud.com/ascendhub/vllm-ascend:0.7.3
   ```

2. **方案B**: 从宿主机复制torch-npu
   ```bash
   # 在Dockerfile中添加
   COPY --from=host /usr/local/lib/python3.11/site-packages/torch_npu \
       /usr/local/lib/python3.11/site-packages/torch_npu
   ```

3. **方案C**: 手动下载正确的whl包
   ```bash
   # 查找正确URL
   pip3 install torch-npu --index-url https://developer.huawei.com/cn/ascend/sdk/910B/pytorch2.1.0
   ```

### 5. ✅ 模型文件状态

**已下载模型**:
```
✅ Qwen2.5-7B-Instruct (15GB)
   - model-00001-of-00004.safetensors (3.7GB)
   - model-00002-of-00004.safetensors (3.6GB)
   - model-00003-of-00004.safetensors (3.6GB)
   - model-00004-of-00004.safetensors (3.4GB)
   - config.json, tokenizer.json等

✅ Qwen2.5-14B-Instruct (28GB)
   - 8个safetensors文件

❌ DeepSeek-R1 (空目录)
❌ Qwen2.5-32B-Instruct (空目录)
```

---

## 🚀 后续执行步骤

### 步骤1: 解决Docker镜像问题

**推荐方案** (使用官方镜像):
```bash
# 1. 拉取官方镜像
docker pull swr.cn-south-1.myhuaweicloud.com/ascendhub/vllm-ascend:0.7.3

# 2. 打标签
docker tag swr.cn-south-1.myhuaweicloud.com/ascendhub/vllm-ascend:0.7.3 vllm-ascend-optimized
```

**备选方案** (手动构建):
```bash
# 1. 下载torch-npu whl包
wget https://developer.huawei.com/cn/ascend/sdk/910B/pytorch2.1.0/torch_npu-*.whl

# 2. 修改Dockerfile使用本地文件
COPY torch_npu-*.whl /tmp/
RUN pip3 install /tmp/torch_npu-*.whl

# 3. 构建镜像
docker build -t vllm-ascend-optimized -f /ksc_aibox/scripts/vllm/Dockerfile.vllm-optimized /ksc_aibox/scripts/vllm/
```

### 步骤2: 启动vLLM服务

```bash
# 启动Qwen2.5-7B (推荐先测试这个)
/ksc_aibox/scripts/vllm/start-vllm-optimized.sh Qwen2.5-7B-Instruct 8000

# 等待启动
sleep 10

# 查看状态
docker ps | grep vllm
docker logs vllm-Qwen2.5-7B-Instruct
```

### 步骤3: 测试服务

```bash
# 运行测试脚本
/ksc_aibox/scripts/vllm/test-vllm-optimized.sh 8000 Qwen2.5-7B-Instruct

# 或手动测试
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-7B-Instruct",
    "prompt": "你好，请介绍一下自己",
    "max_tokens": 200
  }'
```

### 步骤4: 性能优化

```bash
# 1. 监控NPU使用率
watch -n 2 'npu-smi info | grep -E "NPU|AICORE"'

# 2. 调整参数 (如果性能不佳)
# 编辑 start-vllm-optimized.sh，调整:
# --gpu-memory-utilization 0.75
# --max-model-len 2048
# --max-num-seqs 128

# 3. 运行基准测试
pip3 install vllm-benchmark
python3 -m vllm.entrypoints.benchmark_serving \
    --model /model \
    --backend vllm \
    --dataset-name random \
    --num-prompts 100
```

### 步骤5: 生成FAQ (使用SKILL)

```bash
# 使用vLLM-ascend_FAQ_Generator SKILL
# 处理已关闭的Issue，生成Debug FAQ
# (需要访问GitHub仓库)
```

---

## 📈 预期性能指标

### Qwen2.5-7B-Instruct (4张NPU)

| 指标 | 预期值 |
|------|--------|
| **首Token延迟** | <500ms |
| **生成速度** | 20-30 tokens/s |
| **并发请求** | 50-100 |
| **NPU内存使用** | ~15GB / 64GB (23%) |
| **AICORE使用率** | 60-80% (推理时) |

### Qwen2.5-14B-Instruct (4张NPU)

| 指标 | 预期值 |
|------|--------|
| **首Token延迟** | <1s |
| **生成速度** | 10-15 tokens/s |
| **并发请求** | 25-50 |
| **NPU内存使用** | ~28GB / 64GB (44%) |
| **AICORE使用率** | 70-90% (推理时) |

---

## 🛠️ 快速命令参考

```bash
# 启动服务
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh start Qwen2.5-7B-Instruct 8000

# 查看状态
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh status

# 查看日志
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh logs Qwen2.5-7B-Instruct

# 停止服务
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh stop Qwen2.5-7B-Instruct

# 列出模型
/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh list

# 测试服务
/ksc_aibox/scripts/vllm/test-vllm-optimized.sh 8000 Qwen2.5-7B-Instruct
```

---

## 📚 相关文档

- **完整部署指南**: `/docs/vllm-ascend-deployment-guide.md`
- **NPU驱动报告**: `/docs/npu-driver-troubleshooting-report.md`
- **NPU最终报告**: `/docs/npu-driver-installation-final-report.md`
- **Ansible Playbook**: `/ansible/playbooks/02-install-vllm.yml`
- **vLLM SKILL**: `/src/agent-skills/vLLM-ascend_FAQ_Generator/SKILL.md`

---

## ⚡ 关键发现

1. **NPU设备号是1-4**，不是0-3 (已修复)
2. **模型文件已下载**，Qwen2.5-7B和14B可用
3. **CANN环境变量已完善**，支持完整工具链
4. **Docker镜像需使用官方源**，在线构建URL已变化
5. **内存优化配置已生成**，避免OOM问题

---

**执行完成度**: 80% (待Docker镜像解决后即可100%完成)  
**预计剩余时间**: 10-15分钟 (拉取官方镜像 + 启动服务)  
**下次执行**: 解决Docker镜像问题后继续
