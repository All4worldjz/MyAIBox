# vLLM for Ascend NPU 安装状态报告

## 日期：2026年4月8日

## 服务器信息

| 项目 | 值 |
|------|-----|
| IP地址 | 10.212.128.192 |
| 主机名 | ksc-aibox-node01 |
| 操作系统 | openEuler 24.03 LTS-SP3 |
| CPU架构 | ARM64 |
| SSH用户 | root |
| SSH密码 | a11223344! |

## NPU 状态

| 项目 | 状态 |
|------|------|
| 驱动版本 | 25.5.1 |
| 固件版本 | 7.8.0.6.201 |
| CANN版本 | 9.0.0-beta.2 |
| NPU数量 | 4张 Ascend 910B |
| NPU状态 | 健康运行 |

## Docker 状态

| 项目 | 值 |
|------|-----|
| 版本 | 18.09.0 |
| 数据目录 | /ksc_aibox/docker/data |
| 存储驱动 | overlay2 |

## 模型下载进度

### 已完成
| 模型 | 大小 | 状态 |
|------|------|------|
| Qwen2.5-7B-Instruct | 15GB | ✅ 已完成 |

### 进行中（后台下载）
| 模型 | 预计大小 | 状态 |
|------|----------|------|
| Qwen2.5-14B-Instruct | ~28GB | 🔄 进行中 (约20GB已下载) |
| Qwen2.5-32B-Instruct | ~60GB | ⏳ 待下载 |
| DeepSeek-R1 | ~70GB | ⏳ 待下载 |
| Qwen2-VL-7B-Instruct | ~15GB | ⏳ 待下载 |
| bge-m3 | ~2GB | ⏳ 待下载 |
| bge-large-zh-v1.5 | ~1GB | ⏳ 待下载 |

**总预计下载时间**: ~5-6小时

## 已创建的脚本

```
/ksc_aibox/scripts/vllm/
├── start-vllm.sh              # vLLM启动脚本
├── manage-vllm.sh             # vLLM管理脚本 (start/stop/status/logs)
├── download-models-bg.sh      # 后台模型下载脚本
├── test-vllm.sh               # 测试脚本
├── vllm.env                   # 环境配置
├── Dockerfile.vllm-ascend     # Docker镜像模板
└── Dockerfile.vllm            # Docker镜像模板
```

## 待完成任务

### 1. vLLM安装问题
- **问题**: 服务器无法访问国外站点（HuggingFace、PyPI官方源）
- **尝试的镜像**: 
  - 阿里云镜像: 连接超时
  - 清华镜像: 编译错误
- **解决方案**: 
  - 使用华为昇腾官方提供的vLLM镜像
  - 或从ModelScope下载预编译的vLLM wheel包

### 2. 华为昇腾vLLM
华为昇腾社区提供专门的vLLM适配版本：
- GitHub: https://github.com/Ascend/vllm
- 文档: https://www.hiascend.com/document

### 3. Docker镜像构建
需要构建包含CANN环境的vLLM Docker镜像：
```bash
cd /ksc_aibox/scripts/vllm
docker build -t vllm-ascend -f Dockerfile.vllm-ascend .
```

## SSH配置

已修改SSH配置支持密码登录：
```
PermitRootLogin yes
PasswordAuthentication yes
```

## Ansible Playbooks

已创建的Playbook：
- `01-install-npu-full-stack.yml` - NPU驱动安装
- `02-install-vllm.yml` - vLLM安装配置

## 下一步操作

1. 检查华为昇腾官方vLLM资源
2. 使用华为提供的Docker镜像或预编译包
3. 等待模型下载完成
4. 构建vLLM Docker镜像
5. 测试推理服务

## 参考链接

- 华为昇腾社区: https://www.hiascend.com
- ModelScope: https://modelscope.cn
- vLLM Ascend: https://github.com/Ascend/vllm