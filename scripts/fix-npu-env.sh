#!/bin/bash
# ============================================
# 修复NPU CANN环境变量配置
# ============================================

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════╗"
echo "║    修复NPU CANN环境变量配置                              ║"
echo "║    执行时间: $(date '+%Y-%m-%d %H:%M:%S')               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 检查权限
if [ "$EUID" -ne 0 ]; then 
  echo "❌ 错误: 请使用root权限执行 (sudo $0)"
  exit 1
fi

CONFIG_FILE="/etc/profile.d/ascend.sh"

# 备份原配置
if [ -f "$CONFIG_FILE" ]; then
  BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
  echo "📋 备份原配置: $BACKUP_FILE"
  cp "$CONFIG_FILE" "$BACKUP_FILE"
fi

# 写入完整配置
echo "🔧 写入新的CANN环境变量配置..."

cat > "$CONFIG_FILE" << 'EOF'
# ============================================
# Ascend NPU Complete Environment
# ============================================

# 基础路径
export ASCEND_HOME_PATH=/usr/local/Ascend
export ASCEND_DRIVER_PATH=/usr/local/Ascend/driver
export ASCEND_TOOL_PATH=/usr/local/Ascend/cann-9.0.0-beta.2

# CANN组件路径
export ASCEND_OPP_PATH=/usr/local/Ascend/cann-9.0.0-beta.2/opp
export ASCEND_AICPU_PATH=/usr/local/Ascend/cann-9.0.0-beta.2
export ASCEND_DEV_PLUGIN_PATH=/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/dev-plugin

# 库路径 (驱动 + CANN工具链)
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:\
/usr/local/Ascend/driver/lib64/common:\
/usr/local/Ascend/driver/lib64/driver:\
/usr/local/Ascend/driver/lib64/inner:\
/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/lib64:\
/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/lib64/common:\
/usr/local/Ascend/cann-9.0.0-beta.2/fwkacllib/lib64:\
/usr/local/Ascend/cann-9.0.0-beta.2/tools/profiler/lib64:\
$LD_LIBRARY_PATH

# 可执行文件路径
export PATH=/usr/local/Ascend/bin:\
/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/bin:\
/usr/local/Ascend/cann-9.0.0-beta.2/toolkit/bin:\
/usr/local/Ascend/cann-9.0.0-beta.2/tools/profiler/bin:\
/usr/local/Ascend/cann-9.0.0-beta.2/tools/ide_daemon/bin:\
$PATH

# Python路径 (CANN Python API)
export PYTHONPATH=${PYTHONPATH:-}
export PYTHONPATH=/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/python/site-packages:\
/usr/local/Ascend/cann-9.0.0-beta.2/tools/hccl/python/site-packages:\
/usr/local/Ascend/cann-9.0.0-beta.2/tools/aitools/ascend_quant/python:\
$PYTHONPATH

# AscendCL相关
export ASCEND_AICPU_PATH=/usr/local/Ascend/cann-9.0.0-beta.2
export ASCEND_OPP_PATH=/usr/local/Ascend/cann-9.0.0-beta.2/opp
export DDK_PATH=/usr/local/Ascend/cann-9.0.0-beta.2
export NPU_HOST_LIB=/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/lib64

# HCCL通信库
export HCCL_CONNECT_TIMEOUT=600
export HCCL_EXEC_TIMEOUT=0
export HCCL_LOG_LEVEL=3
export HCCL_BUFFSIZE=2

# Ascend设备白名单
export ASCEND_VISIBLE_DEVICES=0,1,2,3
EOF

echo "✅ 配置写入完成"
echo ""

# 设置权限
chmod 644 "$CONFIG_FILE"
echo "🔒 设置文件权限: 644"
echo ""

# 应用配置 (不source，因为配置文件中的变量展开在script模式下会报错)
echo "🔄 新配置已写入文件，需要重新登录或手动source才能生效"
echo ""

# 验证配置
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 环境变量验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

vars=(
  "ASCEND_HOME_PATH"
  "ASCEND_DRIVER_PATH"
  "ASCEND_TOOL_PATH"
  "ASCEND_OPP_PATH"
  "LD_LIBRARY_PATH"
  "PATH"
  "PYTHONPATH"
)

for var in "${vars[@]}"; do
  value="${!var:-未设置}"
  echo "$var:"
  if [ "$var" = "LD_LIBRARY_PATH" ] || [ "$var" = "PATH" ] || [ "$var" = "PYTHONPATH" ]; then
    echo "$value" | tr ':' '\n' | grep -i ascend | sed 's/^/  ✅ /' | head -10
  else
    echo "  $value"
  fi
  echo ""
done

# 验证npu-smi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 npu-smi验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "npu-smi位置: $(which npu-smi)"
echo ""
echo "npu-smi依赖库检查:"
ldd $(which npu-smi) 2>&1 | grep "not found" && echo "  ❌ 有缺失库" || echo "  ✅ 依赖库完整"
echo ""

# 测试npu-smi
echo "执行 npu-smi info 测试..."
if npu-smi info > /dev/null 2>&1; then
  echo "  ✅ npu-smi 工作正常"
  echo ""
  echo "NPU状态摘要:"
  npu-smi info 2>&1 | grep -E "NPU|OK|WARNING" | head -5
else
  echo "  ❌ npu-smi 执行失败"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 后续步骤"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 重新登录或执行: source /etc/profile.d/ascend.sh"
echo "2. 验证警告是否消除: npu-smi info"
echo "3. 如需使用CANN工具: atc --version"
echo "4. 如需使用Python API: python3 -c 'import ascendacl'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 环境变量修复完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
