#!/bin/bash
# ============================================================================
# startup-sync.sh — AI Agent 启动时标准同步脚本
#
# 用途: 任何AI Agent启动时执行，快速同步最新项目状态
# 用法: ./scripts/startup-sync.sh
# 退出码:
#   0 — 同步成功
#   1 — 同步失败
# ============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║   🤖 AI Agent 启动同步 — KSC AIBox                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Step 1: 检查Git状态
log_info "Step 1/5: 检查Git仓库状态..."
git status --short
echo ""
git log --oneline -3
log_success "Git状态检查完成"
echo ""

# Step 2: 读取协同指挥文档（关键）
log_info "Step 2/5: 检查协同指挥文档..."
if [[ -f "docs/MULTI-AGENT-COMMAND-CENTER.md" ]]; then
    log_success "✅ 协同指挥文档存在"
    
    # 提取最后更新时间
    last_update=$(grep -o "最后完整更新:.*" "docs/MULTI-AGENT-COMMAND-CENTER.md" | head -1 || echo "未找到")
    log_info "最后更新: ${last_update}"
    
    # 提取活跃问题数
    active_issues=$(grep -A1 "活跃问题数" "docs/MULTI-AGENT-COMMAND-CENTER.md" | tail -1 | grep -o "[0-9]*" || echo "0")
    log_warn "活跃问题: ${active_issues}个"
    
    # 提取待办任务数
    pending_tasks=$(grep -A1 "待办任务数" "docs/MULTI-AGENT-COMMAND-CENTER.md" | tail -1 | grep -o "[0-9]*" || echo "0")
    log_info "待办任务: ${pending_tasks}个"
else
    log_error "❌ 协同指挥文档不存在！"
    exit 1
fi
echo ""

# Step 3: 读取项目上下文
log_info "Step 3/5: 检查项目上下文..."
if [[ -f "QWEN.md" ]]; then
    log_success "✅ QWEN.md 存在"
else
    log_warn "⚠️  QWEN.md 不存在"
fi

if [[ -f "AGENTS.md" ]]; then
    log_success "✅ AGENTS.md 存在（54个AI Agent技能）"
else
    log_warn "⚠️  AGENTS.md 不存在"
fi
echo ""

# Step 4: 检查待办任务
log_info "Step 4/5: 提取待办任务看板..."
if grep -q "## 📋 待办任务看板" "docs/MULTI-AGENT-COMMAND-CENTER.md"; then
    log_success "✅ 待办任务看板存在"
    
    # 提取P0任务
    p0_tasks=$(grep "🔴 紧急" "docs/MULTI-AGENT-COMMAND-CENTER.md" | wc -l || echo "0")
    if [[ ${p0_tasks} -gt 0 ]]; then
        log_warn "🔴 P0紧急任务: ${p0_tasks}个"
    fi
    
    # 提取P1任务
    p1_tasks=$(grep "🟡 进行中\|🟡 重要" "docs/MULTI-AGENT-COMMAND-CENTER.md" | wc -l || echo "0")
    if [[ ${p1_tasks} -gt 0 ]]; then
        log_info "🟡 P1重要任务: ${p1_tasks}个"
    fi
else
    log_warn "⚠️  未找到待办任务看板"
fi
echo ""

# Step 5: 检查活跃问题
log_info "Step 5/5: 提取活跃问题..."
if grep -q "## 🐛 问题与阻塞" "docs/MULTI-AGENT-COMMAND-CENTER.md"; then
    log_success "✅ 问题与阻塞章节存在"
    
    # 提取活跃问题列表
    echo ""
    log_info "活跃问题列表:"
    grep "BUG-\|WARN-" "docs/MULTI-AGENT-COMMAND-CENTER.md" | head -5 | while read line; do
        echo "  - ${line}"
    done
else
    log_warn "⚠️  未找到问题与阻塞章节"
fi
echo ""

# 总结
echo "╔════════════════════════════════════════════════════════╗"
echo "║   ✅ 启动同步完成                                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
log_info "下一步:"
echo "  1. 仔细阅读 docs/MULTI-AGENT-COMMAND-CENTER.md"
echo "  2. 查看「待办任务看板」认领任务"
echo "  3. 查看「问题与阻塞」确认是否有需要处理的问题"
echo "  4. 开始工作后，记得更新协同指挥文档的操作日志"
echo ""
log_success "准备好开始工作了！🚀"
echo ""

exit 0
