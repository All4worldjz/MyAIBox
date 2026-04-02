#!/bin/bash
# KSC AIBox 一键部署脚本
# 用法: ./deploy.sh [playbook]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${PROJECT_DIR}/ansible"

# Ansible命令
ANSIBLE_PLAYBOOK="/Library/Frameworks/Python.framework/Versions/3.11/bin/ansible-playbook"

# 帮助信息
show_help() {
    echo "KSC AIBox 部署脚本"
    echo ""
    echo "用法: $0 [选项|playbook]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -l, --list     列出所有可用Playbook"
    echo "  -c, --check    检查模式 (不实际执行)"
    echo "  -v, --verbose  详细输出"
    echo ""
    echo "Playbook:"
    echo "  01             01-prepare-dirs.yml (目录结构创建)"
    echo "  02             02-migrate-data.yml (数据迁移)"
    echo "  03             03-system-optimization.yml (系统优化)"
    echo "  04             04-health-check-and-best-practices.yml (健康检查)"
    echo "  all            执行所有Playbook"
    echo ""
    echo "示例:"
    echo "  $0 01          执行目录创建Playbook"
    echo "  $0 all         执行所有Playbook"
    echo "  $0 -c 03       检查模式执行系统优化"
}

# 列出Playbook
list_playbooks() {
    echo "可用Playbook:"
    echo ""
    ls -1 "${ANSIBLE_DIR}/playbooks/"*.yml | while read f; do
        name=$(basename "$f")
        echo "  - $name"
    done
}

# 执行Playbook
run_playbook() {
    local playbook=$1
    local extra_args=$2
    
    local playbook_file="${ANSIBLE_DIR}/playbooks/${playbook}"
    
    if [[ ! -f "$playbook_file" ]]; then
        echo -e "${RED}错误: Playbook不存在: $playbook${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}执行Playbook: $playbook${NC}"
    echo ""
    
    cd "${ANSIBLE_DIR}"
    ${ANSIBLE_PLAYBOOK} -i inventory/hosts "${playbook_file}" ${extra_args}
    
    echo ""
    echo -e "${GREEN}完成: $playbook${NC}"
}

# 执行所有Playbook
run_all() {
    local extra_args=$1
    
    echo -e "${YELLOW}执行所有Playbook...${NC}"
    echo ""
    
    for playbook in 01-prepare-dirs.yml 02-migrate-data.yml 03-system-optimization.yml 04-health-check-and-best-practices.yml; do
        run_playbook "$playbook" "$extra_args"
        echo ""
    done
    
    echo -e "${GREEN}所有Playbook执行完成!${NC}"
}

# 主逻辑
main() {
    local check_mode=""
    local verbose=""
    local playbook=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                list_playbooks
                exit 0
                ;;
            -c|--check)
                check_mode="--check"
                shift
                ;;
            -v|--verbose)
                verbose="-v"
                shift
                ;;
            01)
                playbook="01-prepare-dirs.yml"
                shift
                ;;
            02)
                playbook="02-migrate-data.yml"
                shift
                ;;
            03)
                playbook="03-system-optimization.yml"
                shift
                ;;
            04)
                playbook="04-health-check-and-best-practices.yml"
                shift
                ;;
            all)
                run_all "${check_mode} ${verbose}"
                exit 0
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$playbook" ]]; then
        show_help
        exit 0
    fi
    
    run_playbook "$playbook" "${check_mode} ${verbose}"
}

main "$@"