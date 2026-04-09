#!/bin/bash
# ============================================
# vLLM在昇腾NPU上部署和优化脚本
# 基于本地SKILL文档和最佳实践
# ============================================

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════╗"
echo "║    vLLM Ascend NPU 部署和优化                            ║"
echo "║    执行时间: $(date '+%Y-%m-%d %H:%M:%S')               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ============================================
# 配置参数
# ============================================
VLLM_VERSION="0.7.3"  # 最新稳定版
PYTORCH_VERSION="2.4.0"  # 适配CANN 9.0
MODEL_NAME="Qwen2.5-7B-Instruct"
MODEL_PATH="/ksc_aibox/models/llm/${MODEL_NAME}"
VLLM_PORT=8000
TENSOR_PARALLEL=4  # 4张NPU
GPU_MEMORY_UTIL=0.85  # 降低到85%，避免OOM
MAX_MODEL_LEN=4096  # 降低到4096，节省内存

# ============================================
# 1. 环境检查
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 一、环境检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "【NPU状态】"
npu-smi info 2>&1 | grep -E "NPU|Health|OK" | head -6
echo ""

echo "【内存状态】"
free -h | grep Mem
echo ""

echo "【磁盘空间】"
df -h /ksc_aibox | tail -1
echo ""

echo "【Docker状态】"
docker info 2>/dev/null | grep -E "Server Version|Total Memory" || echo "Docker未运行"
echo ""

# ============================================
# 2. 修复NPU设备号
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 二、修复NPU设备号"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "当前设备文件:"
ls -la /dev/davinci* 2>/dev/null | sed 's/^/  /'
echo ""

# 注意：设备号是1-4，不是0-3
echo "⚠️  NPU设备号: 1-4 (不是0-3)"
echo ""

# ============================================
# 3. 优化Dockerfile
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 三、创建优化版Dockerfile"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DOCKERFILE="/ksc_aibox/scripts/vllm/Dockerfile.vllm-ascend-optimized"

cat > "$DOCKERFILE" << 'DOCKERFILE_END'
# vLLM for Ascend 910B4 - 优化版
# 基于openEuler 24.03 + CANN 9.0.0

FROM openeuler/openeuler:24.03

# 环境变量
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1

# 安装基础依赖
RUN dnf install -y \
    python3.11 \
    python3.11-devel \
    python3-pip \
    python3.11-setuptools \
    git \
    wget \
    curl \
    vim-minimal \
    tar \
    gzip \
    numactl \
    && dnf clean all \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3

# 安装PyTorch + torch-npu (昇腾适配版)
# 注意：需要从华为镜像安装
RUN pip3 install --no-cache-dir --trusted-host developer.huawei.com \
    torch==2.4.0 \
    torchvision \
    torchaudio \
    --index-url https://download.pytorch.org/whl/cpu

RUN pip3 install --no-cache-dir --trusted-host developer.huawei.com \
    https://developer.huawei.com/cn/ascend/sdk/910B/pytorch2.4.0/torch_npu-2.4.0.post3-cp311-cp311-linux_aarch64.whl

# 安装vLLM Ascend版本
RUN pip3 install --no-cache-dir \
    vllm==0.7.3 \
    vllm-ascend==0.7.3.post1 \
    transformers>=4.48.0 \
    accelerate \
    sentencepiece \
    tiktoken \
    protobuf \
    grpcio \
    packaging \
    fsspec \
    aiohttp \
    pyyaml \
    psutil \
    uvicorn \
    fastapi \
    sse-starlette \
    httpx \
    numpy \
    scipy \
    pydantic \
    prometheus-client

# CANN环境将从宿主机挂载
# 不复制到镜像中，节省空间并保持同步

# 环境变量
ENV ASCEND_INSTALL_PATH=/usr/local/Ascend \
    ASCEND_TOOLKIT_HOME=/usr/local/Ascend/cann \
    LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:/usr/local/Ascend/cann/lib64:$LD_LIBRARY_PATH \
    PYTHONPATH=/usr/local/Ascend/cann/python/site-packages:$PYTHONPATH \
    PATH=/usr/local/Ascend/bin:/usr/local/Ascend/cann/bin:$PATH \
    ASCEND_VISIBLE_DEVICES=1,2,3,4 \
    VLLM_NPU_ENABLE_CANN_ALLOCATOR=1 \
    VLLM_WORKER_MULTIPROC_METHOD=spawn \
    HSA_OVERRIDE_GFX_VERSION=9.4.2

# 工作目录
WORKDIR /workspace

# 暴露端口
EXPOSE 8000

# 启动命令
ENTRYPOINT ["/bin/bash"]
DOCKERFILE_END

echo "✅ Dockerfile已创建: $DOCKERFILE"
echo ""

# ============================================
# 4. 优化启动脚本
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 四、创建优化版启动脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

START_SCRIPT="/ksc_aibox/scripts/vllm/start-vllm-optimized.sh"

cat > "$START_SCRIPT" << STARTSCRIPT_END
#!/bin/bash
# vLLM for Ascend 910B4 - 优化启动脚本

set -euo pipefail

# 配置
MODEL_NAME=\${1:-"${MODEL_NAME}"}
MODEL_PATH="/ksc_aibox/models/llm/\${MODEL_NAME}"
PORT=\${2:-${VLLM_PORT}}
CONTAINER_NAME="vllm-\${MODEL_NAME//[^a-zA-Z0-9]/-}"

# NPU配置
NPU_DEVICES="--device /dev/davinci1 --device /dev/davinci2 --device /dev/davinci3 --device /dev/davinci4"

# 资源配置
TENSOR_PARALLEL=${TENSOR_PARALLEL}
GPU_MEMORY_UTIL=${GPU_MEMORY_UTIL}
MAX_MODEL_LEN=${MAX_MODEL_LEN}
SHM_SIZE="64g"  # 共享内存

echo "╔══════════════════════════════════════════════════════════╗"
echo "║    vLLM Ascend 910B4 启动                               ║"
echo "║    时间: \$(date '+%Y-%m-%d %H:%M:%S')                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "【配置信息】"
echo "  模型: \${MODEL_NAME}"
echo "  路径: \${MODEL_PATH}"
echo "  端口: \${PORT}"
echo "  容器: \${CONTAINER_NAME}"
echo "  NPU: 4张 (1-4)"
echo "  张量并行: \${TENSOR_PARALLEL}"
echo "  内存利用率: \${GPU_MEMORY_UTIL}"
echo "  最大长度: \${MAX_MODEL_LEN}"
echo ""

# 检查模型
if [ ! -d "\${MODEL_PATH}" ]; then
    echo "❌ 错误: 模型不存在 \${MODEL_PATH}"
    echo ""
    echo "可用模型:"
    ls -1 /ksc_aibox/models/llm/ 2>/dev/null || echo "  无模型"
    exit 1
fi

# 检查Docker镜像
if ! docker images --format '{{.Repository}}' | grep -q "vllm-ascend-optimized"; then
    echo "❌ 错误: Docker镜像不存在"
    echo "请先构建镜像: docker build -t vllm-ascend-optimized -f /ksc_aibox/scripts/vllm/Dockerfile.vllm-ascend-optimized /ksc_aibox/scripts/vllm/"
    exit 1
fi

# 停止旧容器
echo "🔄 停止旧容器..."
docker stop \${CONTAINER_NAME} 2>/dev/null || true
docker rm \${CONTAINER_NAME} 2>/dev/null || true
echo ""

# 启动vLLM
echo "🚀 启动vLLM..."
docker run -d \
    --name \${CONTAINER_NAME} \
    --net host \
    --shm-size=\${SHM_SIZE} \
    --ulimit memlock=-1 \
    --ulimit stack=67108864 \
    \${NPU_DEVICES} \
    -v \${MODEL_PATH}:/model:ro \
    -v /usr/local/Ascend:/usr/local/Ascend:ro \
    -v /ksc_aibox/logs:/workspace/logs \
    -e ASCEND_VISIBLE_DEVICES=1,2,3,4 \
    -e ASCEND_INSTALL_PATH=/usr/local/Ascend \
    -e LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:/usr/local/Ascend/cann/lib64 \
    -e PYTHONPATH=/usr/local/Ascend/cann/python/site-packages \
    -e VLLM_NPU_ENABLE_CANN_ALLOCATOR=1 \
    -e VLLM_WORKER_MULTIPROC_METHOD=spawn \
    -e VLLM_LOGGING_LEVEL=INFO \
    -e HF_HUB_DISABLE_TELEMETRY=1 \
    vllm-ascend-optimized \
    -m vllm.entrypoints.openai.api_server \
    --model /model \
    --tensor-parallel-size \${TENSOR_PARALLEL} \
    --gpu-memory-utilization \${GPU_MEMORY_UTIL} \
    --max-model-len \${MAX_MODEL_LEN} \
    --host 0.0.0.0 \
    --port \${PORT} \
    --served-model-name \${MODEL_NAME} \
    --disable-log-requests \
    2>&1 | tee /ksc_aibox/logs/vllm-\${MODEL_NAME}.log

echo ""
echo "✅ vLLM启动完成！"
echo ""
echo "【访问信息】"
echo "  API地址: http://localhost:\${PORT}/v1"
echo "  健康检查: http://localhost:\${PORT}/health"
echo "  模型列表: http://localhost:\${PORT}/v1/models"
echo ""
echo "【管理命令】"
echo "  查看日志: docker logs -f \${CONTAINER_NAME}"
echo "  停止服务: docker stop \${CONTAINER_NAME}"
echo "  重启服务: docker restart \${CONTAINER_NAME}"
echo ""
echo "【测试命令】"
echo "  curl http://localhost:\${PORT}/v1/completions \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"model\": \"\${MODEL_NAME}\", \"prompt\": \"你好\", \"max_tokens\": 100}'"
echo ""

# 等待启动
echo "⏳ 等待服务启动..."
sleep 5

# 检查状态
if docker ps --format '{{.Names}}' | grep -q "\${CONTAINER_NAME}"; then
    echo "✅ 容器运行正常"
    echo ""
    echo "【容器状态】"
    docker ps --filter "name=\${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "❌ 容器启动失败，查看日志:"
    docker logs \${CONTAINER_NAME} | tail -50
fi
STARTSCRIPT_END

chmod +x "$START_SCRIPT"
echo "✅ 启动脚本已创建: $START_SCRIPT"
echo ""

# ============================================
# 5. 创建管理脚本
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛠️  五、创建服务管理脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MANAGE_SCRIPT="/ksc_aibox/scripts/vllm/manage-vllm-optimized.sh"

cat > "$MANAGE_SCRIPT" << 'MANAGE_END'
#!/bin/bash
# vLLM服务管理脚本

CONTAINER_PREFIX="vllm"

usage() {
    echo "用法: $0 {start|stop|restart|status|logs|list} [模型名] [端口]"
    echo ""
    echo "命令:"
    echo "  start [模型] [端口]  - 启动vLLM服务"
    echo "  stop [模型]          - 停止vLLM服务"
    echo "  restart [模型] [端口] - 重启vLLM服务"
    echo "  status               - 查看运行状态"
    echo "  logs [模型]          - 查看日志"
    echo "  list                 - 列出可用模型"
    echo ""
    echo "示例:"
    echo "  $0 start Qwen2.5-7B-Instruct 8000"
    echo "  $0 stop Qwen2.5-7B-Instruct"
    echo "  $0 logs Qwen2.5-7B-Instruct"
    echo "  $0 list"
}

case "$1" in
    start)
        /ksc_aibox/scripts/vllm/start-vllm-optimized.sh "${2:-Qwen2.5-7B-Instruct}" "${3:-8000}"
        ;;
    stop)
        CONTAINER_NAME="vllm-${2:-Qwen2.5-7B-Instruct}"
        CONTAINER_NAME="${CONTAINER_NAME//[^a-zA-Z0-9-]/-}"
        echo "🛑 停止容器: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" 2>/dev/null && echo "✅ 已停止" || echo "❌ 容器不存在"
        ;;
    restart)
        $0 stop "$2"
        sleep 2
        $0 start "$2" "$3"
        ;;
    status)
        echo "【vLLM容器状态】"
        docker ps -a --filter "name=vllm-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "无vLLM容器"
        echo ""
        echo "【NPU使用率】"
        npu-smi info 2>/dev/null | grep -A 3 "NPU" | head -10 || echo "NPU信息不可用"
        ;;
    logs)
        CONTAINER_NAME="vllm-${2:-Qwen2.5-7B-Instruct}"
        CONTAINER_NAME="${CONTAINER_NAME//[^a-zA-Z0-9-]/-}"
        echo "【容器日志: $CONTAINER_NAME】"
        docker logs -f "$CONTAINER_NAME" 2>&1 | tail -100
        ;;
    list)
        echo "【可用模型】"
        ls -1 /ksc_aibox/models/llm/ 2>/dev/null | while read model; do
            size=$(du -sh "/ksc_aibox/models/llm/$model" 2>/dev/null | cut -f1)
            echo "  - $model ($size)"
        done || echo "  无可用模型"
        ;;
    *)
        usage
        exit 1
        ;;
esac
MANAGE_END

chmod +x "$MANAGE_SCRIPT"
echo "✅ 管理脚本已创建: $MANAGE_SCRIPT"
echo ""

# ============================================
# 6. 创建测试脚本
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 六、创建测试脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_SCRIPT="/ksc_aibox/scripts/vllm/test-vllm-optimized.sh"

cat > "$TEST_SCRIPT" << 'TEST_END'
#!/bin/bash
# vLLM服务测试脚本

PORT=${1:-8000}
MODEL_NAME=${2:-"Qwen2.5-7B-Instruct"}
BASE_URL="http://localhost:${PORT}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║    vLLM服务测试                                          ║"
echo "║    地址: ${BASE_URL}                                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 1. 健康检查
echo "【1. 健康检查】"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health")
if [ "$HTTP_CODE" = "200" ]; then
    echo "  ✅ 服务正常 (HTTP $HTTP_CODE)"
else
    echo "  ❌ 服务异常 (HTTP $HTTP_CODE)"
    exit 1
fi
echo ""

# 2. 模型列表
echo "【2. 模型列表】"
curl -s "${BASE_URL}/v1/models" | python3 -m json.tool 2>/dev/null | head -20 || echo "  获取失败"
echo ""

# 3. 文本生成测试
echo "【3. 文本生成测试】"
echo "提示: 你好，请介绍一下自己"
echo ""
RESPONSE=$(curl -s "${BASE_URL}/v1/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"${MODEL_NAME}\",
        \"prompt\": \"你好，请介绍一下自己\",
        \"max_tokens\": 200,
        \"temperature\": 0.7
    }")

echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'choices' in data:
    print('回复:', data['choices'][0]['text'])
    print('Token使用:', data.get('usage', {}))
else:
    print('响应:', json.dumps(data, indent=2, ensure_ascii=False))
" 2>/dev/null || echo "  生成失败"
echo ""

# 4. 对话API测试 (OpenAI兼容)
echo "【4. 对话API测试】"
RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"${MODEL_NAME}\",
        \"messages\": [
            {\"role\": \"user\", \"content\": \"用一句话解释什么是AI\"}
        ],
        \"max_tokens\": 100
    }")

echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'choices' in data:
    print('回复:', data['choices'][0]['message']['content'])
else:
    print('响应:', json.dumps(data, indent=2, ensure_ascii=False))
" 2>/dev/null || echo "  对话API调用失败"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 测试完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TEST_END

chmod +x "$TEST_SCRIPT"
echo "✅ 测试脚本已创建: $TEST_SCRIPT"
echo ""

# ============================================
# 7. 总结
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 七、部署准备总结"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ 已创建文件:"
echo "  1. $DOCKERFILE"
echo "  2. $START_SCRIPT"
echo "  3. $MANAGE_SCRIPT"
echo "  4. $TEST_SCRIPT"
echo ""
echo "📝 后续步骤:"
echo "  1. 构建Docker镜像:"
echo "     docker build -t vllm-ascend-optimized -f $DOCKERFILE /ksc_aibox/scripts/vllm/"
echo ""
echo "  2. 启动vLLM服务:"
echo "     $START_SCRIPT Qwen2.5-7B-Instruct 8000"
echo ""
echo "  3. 测试服务:"
echo "     $TEST_SCRIPT 8000 Qwen2.5-7B-Instruct"
echo ""
echo "  4. 管理服务:"
echo "     $MANAGE_SCRIPT list"
echo "     $MANAGE_SCRIPT status"
echo "     $MANAGE_SCRIPT logs Qwen2.5-7B-Instruct"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 部署脚本准备完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
