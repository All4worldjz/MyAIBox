#!/usr/bin/env bash
# ============================================================================
# sync-agent-skills.sh — 自动同步 AI Agent Skills 从上游仓库
#
# 用途: 从 https://gitcode.com/Ascend/agent-skills 同步最新 SKILL 文件到本地
# 频率: 建议每周执行一次（通过 cron 或手动）
#
# 用法:
#   ./scripts/sync-agent-skills.sh          # 执行同步
#   ./scripts/sync-agent-skills.sh --check   # 仅检查是否有更新
#   ./scripts/sync-agent-skills.sh --help    # 显示帮助
#
# 退出码:
#   0 — 同步成功 / 无更新
#   1 — 同步失败
#   2 — 有可用更新（--check 模式）
# ============================================================================

set -euo pipefail

# --- 配置 ---
UPSTREAM_URL="https://gitcode.com/Ascend/agent-skills.git"
UPSTREAM_BRANCH="master"
SKILLS_DIR="src/agent-skills"
REMOTE_DIR="/tmp/agent-skills-remote-$$"
LOG_FILE="/tmp/sync-agent-skills-$(date +%Y%m%d-%H%M%S).log"
MODE="sync"  # sync | check

# --- 颜色输出 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

# --- 帮助 ---
show_help() {
    cat <<EOF
用法: $(basename "$0") [选项]

选项:
  --check     仅检查是否有更新，不实际同步
  --help      显示此帮助信息
  --dry-run   预演模式，显示将要执行的操作

示例:
  $(basename "$0")              # 执行同步
  $(basename "$0") --check       # 检查更新
  $(basename "$0") --dry-run     # 预演模式

上游仓库: $UPSTREAM_URL
本地目录: $SKILLS_DIR
EOF
    exit 0
}

# --- 参数解析 ---
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            MODE="check"
            shift
            ;;
        --help|-h)
            show_help
            ;;
        --dry-run)
            DRY_RUN=true
            MODE="check"
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            ;;
    esac
done

# --- 前置检查 ---
check_prerequisites() {
    # 检查 git 是否可用
    if ! command -v git &>/dev/null; then
        log_error "git 未安装，请先安装 git"
        exit 1
    fi

    # 检查本地技能目录是否存在
    if [[ ! -d "$SKILLS_DIR" ]]; then
        log_error "本地技能目录不存在: $SKILLS_DIR"
        exit 1
    fi

    # 检查是否在 git 仓库中
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "当前目录不是 git 仓库"
        exit 1
    fi

    log_info "前置检查通过"
}

# --- 克隆远程仓库 ---
clone_remote() {
    log_info "克隆上游仓库: $UPSTREAM_URL"

    if $DRY_RUN; then
        log_info "[预演] git clone --depth=1 --bare $UPSTREAM_URL $REMOTE_DIR"
        return 0
    fi

    if git clone --depth=1 --bare "$UPSTREAM_URL" "$REMOTE_DIR" 2>>"$LOG_FILE"; then
        log_success "远程仓库克隆成功"
    else
        log_error "远程仓库克隆失败，详见日志: $LOG_FILE"
        exit 1
    fi
}

# --- 对比文件差异 ---
compare_files() {
    local remote_file_list="/tmp/remote-files-$$"
    local local_file_list="/tmp/local-files-$$"
    local diff_output="/tmp/skill-diff-$$"

    # 获取远程文件列表（仅 skills/ 目录）
    GIT_DIR="$REMOTE_DIR" git ls-tree -r --name-only HEAD \
        | grep '^skills/' \
        | sed 's|^skills/||' \
        | sort > "$remote_file_list"

    # 获取本地文件列表（排除 .DS_Store）
    find "$SKILLS_DIR" -type f ! -name '.DS_Store' \
        | sed "s|^${SKILLS_DIR}/||" \
        | sort > "$local_file_list"

    # 对比文件列表
    local new_files missing_files
    new_files=$(comm -23 "$remote_file_list" "$local_file_list")
    missing_files=$(comm -13 "$remote_file_list" "$local_file_list")

    # 对比内容差异
    local changed_files=""
    local common_files
    common_files=$(comm -12 "$remote_file_list" "$local_file_list")

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local remote_content local_content
        remote_content=$(GIT_DIR="$REMOTE_DIR" git show HEAD:"skills/$file" 2>/dev/null || true)
        local_content=$(cat "$SKILLS_DIR/$file" 2>/dev/null || true)

        if [[ "$remote_content" != "$local_content" ]]; then
            changed_files="${changed_files}${file}\n"
        fi
    done <<< "$common_files"

    # 输出结果
    local has_changes=false

    if [[ -n "$new_files" ]]; then
        log_warn "发现 $(echo "$new_files" | wc -l | tr -d ' ') 个新文件:"
        echo "$new_files" | while IFS= read -r f; do
            log_warn "  + $f"
        done
        has_changes=true
    fi

    if [[ -n "$missing_files" ]]; then
        log_warn "发现 $(echo "$missing_files" | wc -l | tr -d ' ') 个本地独有文件:"
        echo "$missing_files" | while IFS= read -r f; do
            log_warn "  - $f"
        done
        has_changes=true
    fi

    if [[ -n "$changed_files" ]]; then
        log_warn "发现 $(echo -e "$changed_files" | grep -c .) 个文件内容变更:"
        echo -e "$changed_files" | grep . | while IFS= read -r f; do
            log_warn "  ~ $f"
        done
        has_changes=true
    fi

    if ! $has_changes; then
        log_success "本地技能文件与上游仓库完全一致，无需更新"
    fi

    # 清理临时文件
    rm -f "$remote_file_list" "$local_file_list" "$diff_output"

    # 返回状态
    if $has_changes; then
        return 2  # 有变更
    fi
    return 0
}

# --- 执行同步 ---
do_sync() {
    log_info "开始同步 AI Agent Skills..."

    # 使用 rsync 同步文件（仅更新新增/变更文件）
    local sync_count=0
    local remote_file_list="/tmp/remote-files-$$"

    GIT_DIR="$REMOTE_DIR" git ls-tree -r --name-only HEAD \
        | grep '^skills/' \
        | sed 's|^skills/||' \
        > "$remote_file_list"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local remote_content local_content
        remote_content=$(GIT_DIR="$REMOTE_DIR" git show HEAD:"skills/$file" 2>/dev/null || true)
        local_content=$(cat "$SKILLS_DIR/$file" 2>/dev/null || true)

        if [[ "$remote_content" != "$local_content" ]]; then
            local target_dir
            target_dir=$(dirname "$SKILLS_DIR/$file")
            mkdir -p "$target_dir"

            if $DRY_RUN; then
                log_info "[预演] 更新: $file"
            else
                GIT_DIR="$REMOTE_DIR" git show HEAD:"skills/$file" > "$SKILLS_DIR/$file"
                log_info "更新: $file"
            fi
            sync_count=$((sync_count + 1))
        fi
    done < "$remote_file_list"

    rm -f "$remote_file_list"

    if [[ $sync_count -gt 0 ]]; then
        log_success "同步完成: 更新 $sync_count 个文件"
    else
        log_success "所有文件均为最新，无需更新"
    fi
}

# --- 更新 AGENTS.md 时间戳 ---
update_timestamp() {
    if $DRY_RUN; then
        log_info "[预演] 更新 AGENTS.md 时间戳"
        return 0
    fi

    local agents_file="AGENTS.md"
    if [[ -f "$agents_file" ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        # 在文件末尾追加更新时间（如果还没有的话）
        if grep -q "最后更新时间" "$agents_file"; then
            sed -i '' "s/最后更新时间：.*/最后更新时间：${timestamp}/" "$agents_file" 2>/dev/null || true
        else
            echo "" >> "$agents_file"
            echo "*最后更新时间：$(date '+%Y-%m-%d %H:%M:%S')*" >> "$agents_file"
        fi
        log_info "AGENTS.md 时间戳已更新: $timestamp"
    fi
}

# --- 清理 ---
cleanup() {
    if [[ -d "$REMOTE_DIR" ]]; then
        rm -rf "$REMOTE_DIR"
    fi
}
trap cleanup EXIT

# --- 主流程 ---
main() {
    echo "============================================"
    echo "  AI Agent Skills 同步工具"
    echo "  上游: $UPSTREAM_URL"
    echo "  模式: $MODE"
    echo "  日志: $LOG_FILE"
    echo "============================================"
    echo ""

    check_prerequisites

    clone_remote

    if [[ "$MODE" == "check" ]]; then
        compare_files || true
        log_info "检查模式完成"
    else
        compare_files || true
        echo ""
        do_sync
        update_timestamp
        log_success "同步任务完成！"
    fi
}

main "$@"
