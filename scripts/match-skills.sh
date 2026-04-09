#!/usr/bin/env bash
# ============================================================================
# match-skills.sh — 根据场景/任务自动匹配 AI Agent Skills
#
# 用途: 根据输入的场景描述或任务类型，自动搜索并推荐匹配的技能
#
# 用法:
#   ./scripts/match-skills.sh "安装NPU驱动"
#   ./scripts/match-skills.sh "开发AscendC算子"
#   ./scripts/match-skills.sh --task "部署vLLM推理服务"
#   ./scripts/match-skills.sh --list    # 列出所有场景映射
# ============================================================================

set -euo pipefail

SKILLS_DIR="src/agent-skills"

# --- 颜色 ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# 场景→技能映射引擎
# ============================================================================
#
# 每个场景定义:
#   - pattern: 匹配的用户输入模式（正则）
#   - skills: 匹配的技能列表（按优先级排序）
#   - reason: 推荐理由
#
# ============================================================================

declare -A SCENE_MAP

# --- 1. 服务器维护场景 ---

# NPU 驱动/固件
SCENE_MAP["install_npu_driver"]="安装.*驱动|npu.*driver|驱动.*安装|firmware.*install|昇腾.*驱动|ascend.*driver"
SCENE_MAP["install_npu_driver_skills"]="ascend-npu-driver-install"
SCENE_MAP["install_npu_driver_reason"]="端到端 NPU 驱动安装，自动提取包+校验+安装"

SCENE_MAP["check_npu_status"]="npu.*状态|npu.*检查|设备.*查询|npu-smi|设备.*健康|health.*check"
SCENE_MAP["check_npu_status_skills"]="npu-smi"
SCENE_MAP["check_npu_status_reason"]="npu-smi 设备查询：温度/功耗/内存/进程/ECC"

SCENE_MAP["npu_docker"]="npu.*docker|容器.*昇腾|docker.*ascend|容器.*npu|docker.*device"
SCENE_MAP["npu_docker_skills"]="ascend-docker"
SCENE_MAP["npu_docker_reason"]="创建 Ascend NPU 开发 Docker 容器"

SCENE_MAP["cann_install"]="安装.*cann|cann.*安装|cann.*配置|cann.*env|环境.*配置"
SCENE_MAP["cann_install_skills"]="cann-operator-env-config"
SCENE_MAP["cann_install_reason"]="CANN 环境配置，支持离线/Conda/Yum 三种方式"

SCENE_MAP["model_convert"]="模型.*转换|model.*convert|onnx.*om|atc|om.*生成|精度.*对比"
SCENE_MAP["model_convert_skills"]="atc-model-converter"
SCENE_MAP["model_convert_reason"]="ATC 模型转换 ONNX→OM，支持精度对比和 AIPP"

SCENE_MAP["hccl_test"]="hccl|集合.*通信|allreduce|allgather|多机.*测试|打流|通信.*测试"
SCENE_MAP["hccl_test_skills"]="hccl-test"
SCENE_MAP["hccl_test_reason"]="HCCL 集合通信性能测试，支持 10 种算子"

SCENE_MAP["npu_adapter"]="gpu.*npu|npu.*适配|cuda.*ascend|gpu.*迁移|cann.*迁移"
SCENE_MAP["npu_adapter_skills"]="npu-adapter-reviewer"
SCENE_MAP["npu_adapter_reason"]="GPU→NPU 适配审查，5 阶段工作流"

SCENE_MAP["profiling_anomaly"]="profiling|性能.*异常|bubble|wait.*anchor|aicpu.*暴露|性能.*分析"
SCENE_MAP["profiling_anomaly_skills"]="ascend-profiling-anomaly"
SCENE_MAP["profiling_anomaly_reason"]="Ascend profiling 异常分析，发现隐藏性能问题"

SCENE_MAP["inference_copilot"]="vllm.*ascend|mindie|推理.*生态|vllm.*问题|推理.*问答"
SCENE_MAP["inference_copilot_skills"]="ascend-inference-repos-copilot"
SCENE_MAP["inference_copilot_reason"]="昇腾推理生态智能问答，覆盖 vLLM/MindIE"

# --- 2. AscendC 算子开发场景 ---

SCENE_MAP["ascendc_new_op"]="ascendc.*新建|新建.*算子|新.*算子|operator.*new|算子.*初始化|创建.*算子"
SCENE_MAP["ascendc_new_op_skills"]="ascendc-operator-project-init"
SCENE_MAP["ascendc_new_op_reason"]="ascend-kernel 工程初始化，生成算子骨架"

SCENE_MAP["ascendc_design"]="算子.*设计|design.*operator|tiling.*策略|ub.*分配|算子.*架构"
SCENE_MAP["ascendc_design_skills"]="ascendc-operator-design,ascendc-operator-testcase-gen"
SCENE_MAP["ascendc_design_reason"]="算子需求分析→设计文档+测试用例生成"

SCENE_MAP["ascendc_code_gen"]="算子.*代码|code.*gen|op_host|op_kernel|算子.*实现|kernel.*代码"
SCENE_MAP["ascendc_code_gen_skills"]="ascendc-operator-code-gen"
SCENE_MAP["ascendc_code_gen_reason"]="根据设计文档生成 op_host/op_kernel 代码"

SCENE_MAP["ascendc_compile"]="算子.*编译|compile|build.*sh|whl.*安装|编译.*错误"
SCENE_MAP["ascendc_compile_skills"]="ascendc-operator-compile-debug"
SCENE_MAP["ascendc_compile_reason"]="编译安装+精度测试，排错循环最多 3 次"

SCENE_MAP["ascendc_precision"]="算子.*精度|precision|accuracy|精度.*测试|精度.*评估|误差"
SCENE_MAP["ascendc_precision_skills"]="ascendc-operator-precision-eval,ascendc-operator-precision-debug"
SCENE_MAP["ascendc_precision_reason"]="生成≥30例精度测试，失败时自动排查根因"

SCENE_MAP["ascendc_performance"]="算子.*性能|performance|profiler|benchmark|性能.*评估|性能.*测试"
SCENE_MAP["ascendc_performance_skills"]="ascendc-operator-performance-eval"
SCENE_MAP["ascendc_performance_reason"]="torch_npu.profiler 性能评测，warmup=5 active=5"

SCENE_MAP["ascendc_optim"]="算子.*优化|optim|tiling.*优化|流水.*优化|内存.*优化|性能.*调优"
SCENE_MAP["ascendc_optim_skills"]="ascendc-operator-performance-optim"
SCENE_MAP["ascendc_optim_reason"]="五阶段排查: Tiling/搬运/API/内存/流水"

SCENE_MAP["ascendc_review"]="算子.*审查|code.*review|代码.*检视|安全.*检视|Ascend.*C.*review"
SCENE_MAP["ascendc_review_skills"]="ascendc-operator-code-review"
SCENE_MAP["ascendc_review_reason"]="基于假设检验论的安全规范检视"

SCENE_MAP["ascendc_full"]="ascendc.*开发|算子.*全流程|端到端.*算子|完整.*算子|从需求.*测试"
SCENE_MAP["ascendc_full_skills"]="ascendc-operator-dev"
SCENE_MAP["ascendc_full_reason"]="七阶段端到端 AscendC 算子开发工作流编排"

# --- 3. CATLASS 算子开发场景 ---

SCENE_MAP["catlass_design"]="catlass.*设计|矩阵.*算子.*设计|matmul.*设计"
SCENE_MAP["catlass_design_skills"]="catlass-operator-design"
SCENE_MAP["catlass_design_reason"]="CATLASS 矩阵算子设计，含组件选型表格"

SCENE_MAP["catlass_code"]="catlass.*代码|catlass.*实现|矩阵.*代码"
SCENE_MAP["catlass_code_skills"]="catlass-operator-code-gen"
SCENE_MAP["catlass_code_reason"]="CATLASS op_host/op_kernel/test_aclnn 代码生成"

SCENE_MAP["catlass_optim"]="catlass.*优化|矩阵.*性能|tiling.*catlass|swizzle"
SCENE_MAP["catlass_optim_skills"]="catlass-operator-performance-optim"
SCENE_MAP["catlass_optim_reason"]="Catlass tiling/DispatchPolicy/Swizzle 性能调优"

SCENE_MAP["catlass_full"]="catlass.*开发|catlass.*全流程|矩阵.*端到端"
SCENE_MAP["catlass_full_skills"]="catlass-operator-dev"
SCENE_MAP["catlass_full_reason"]="六阶段 CATLASS 算子开发工作流编排"

# --- 4. Triton 算子开发场景 ---

SCENE_MAP["triton_design"]="triton.*设计|triton.*需求|grid.*配置|triton.*架构"
SCENE_MAP["triton_design_skills"]="triton-operator-design"
SCENE_MAP["triton_design_reason"]="生成 Ascend NPU 的 Triton 算子需求文档"

SCENE_MAP["triton_code"]="triton.*代码|triton.*实现|kernel.*triton|triton.*kernel"
SCENE_MAP["triton_code_skills"]="triton-operator-code-gen"
SCENE_MAP["triton_code_reason"]="根据设计文档生成 Ascend NPU Triton kernel 代码"

SCENE_MAP["triton_compile"]="triton.*编译|triton.*调试|triton.*开发"
SCENE_MAP["triton_compile_skills"]="triton-operator-dev"
SCENE_MAP["triton_compile_reason"]="Triton 算子全流程开发任务编排"

SCENE_MAP["triton_doc"]="triton.*文档|triton.*接口|triton.*api"
SCENE_MAP["triton_doc_skills"]="triton-operator-doc-gen"
SCENE_MAP["triton_doc_reason"]="生成昇腾 NPU Triton 算子接口文档"

SCENE_MAP["triton_precision"]="triton.*精度|triton.*accuracy|triton.*precision"
SCENE_MAP["triton_precision_skills"]="triton-operator-precision-eval"
SCENE_MAP["triton_precision_reason"]="Torch 小算子精度比对，生成精度报告"

SCENE_MAP["triton_perf"]="triton.*性能|triton.*performance|triton.*profiler|triton.*benchmark"
SCENE_MAP["triton_perf_skills"]="triton-operator-performance-eval"
SCENE_MAP["triton_perf_reason"]="评估 Ascend NPU 上 Triton 算子性能"

SCENE_MAP["triton_optim"]="triton.*优化|triton.*optim|triton.*调优"
SCENE_MAP["triton_optim_skills"]="triton-operator-performance-optim,vector-triton-ascend-ops-optimizer"
SCENE_MAP["triton_optim_reason"]="Triton 算子性能优化 + Ascend OPS 深度优化"

SCENE_MAP["triton_review"]="triton.*审查|triton.*review|triton.*代码.*质量"
SCENE_MAP["triton_review_skills"]="triton-operator-code-review"
SCENE_MAP["triton_review_reason"]="Triton 算子代码静态检视（Host+Device）"

SCENE_MAP["triton_env"]="triton.*环境|triton.*env|triton.*配置"
SCENE_MAP["triton_env_skills"]="triton-operator-env-config"
SCENE_MAP["triton_env_reason"]="校验并构建 Triton 算子开发环境"

SCENE_MAP["triton_gpu_npu"]="triton.*gpu.*npu|triton.*迁移|gpu.*triton.*npu|vector.*triton"
SCENE_MAP["triton_gpu_npu_skills"]="simple-vector-triton-gpu-to-npu"
SCENE_MAP["triton_gpu_npu_reason"]="Vector 类型 Triton 算子 GPU→NPU 迁移，5 步流程"

SCENE_MAP["triton_full"]="triton.*开发|triton.*全流程|triton.*端到端|完整.*triton"
SCENE_MAP["triton_full_skills"]="triton-operator-dev"
SCENE_MAP["triton_full_reason"]="Triton 算子全流程开发编排"

# --- 5. Megatron 迁移场景 ---

SCENE_MAP["megatron_change"]="megatron.*变更|megatron.*change|功能.*演进|breaking.*risk"
SCENE_MAP["megatron_change_skills"]="megatron-change-analyzer"
SCENE_MAP["megatron_change_reason"]="Megatron 变更分析，结构化事件输出"

SCENE_MAP["megatron_commit"]="megatron.*提交|megatron.*commit|megatron.*track|变更.*跟踪"
SCENE_MAP["megatron_commit_skills"]="megatron-commit-tracker"
SCENE_MAP["megatron_commit_reason"]="Megatron 提交跟踪，输出标准化 change-set"

SCENE_MAP["megatron_impact"]="megatron.*影响|megatron.*impact|mind.*映射|mindspeed.*映射"
SCENE_MAP["megatron_impact_skills"]="megatron-impact-mapper"
SCENE_MAP["megatron_impact_reason"]="将 Megatron 变更映射到 MindSpeed"

SCENE_MAP["megatron_migrate"]="megatron.*迁移|megatron.*migrate|mind.*迁移"
SCENE_MAP["megatron_migrate_skills"]="megatron-migration-generator"
SCENE_MAP["megatron_migrate_reason"]="生成迁移 deliverables，支持 4 种模式"

# --- 6. 测试场景 ---

SCENE_MAP["test_gen"]="生成.*测试|测试.*生成|unit.*test|测试.*补全|test.*gen"
SCENE_MAP["test_gen_skills"]="auto-develop-test-gen,generate-unit-test,pytest-writer"
SCENE_MAP["test_gen_reason"]="自动生成高质量单元测试，覆盖正常/边界/异常场景"

SCENE_MAP["coverage"]="覆盖.*分析|coverage|覆盖率.*报告|覆盖率.*盲区"
SCENE_MAP["coverage_skills"]="analyse-coverage,coverage"
SCENE_MAP["coverage_reason"]="分析覆盖率盲区，生成覆盖率报告"

SCENE_MAP["code_understand"]="理解.*代码|代码.*理解|代码.*摘要|code.*comprehension|分析.*代码"
SCENE_MAP["code_understand_skills"]="code-comprehension"
SCENE_MAP["code_understand_reason"]="函数/类/模块/系统级代码理解"

SCENE_MAP["run_test"]="运行.*测试|run.*test|执行.*测试|test.*run"
SCENE_MAP["run_test_skills"]="run-mindspeed-llm-test"
SCENE_MAP["run_test_reason"]="运行 MindSpeed-LLM 测试用例"

SCENE_MAP["regression"]="回归.*分析|regression|msverl|每日.*回归|回归.*triage"
SCENE_MAP["regression_skills"]="msverl-daily-regression-triage"
SCENE_MAP["regression_reason"]="MSVerl 每日回归分类，排名嫌疑 commits"

# --- 7. 通用编程场景 ---

SCENE_MAP["bug_fix"]="bug.*修复|fix.*bug|错误.*分析|test.*fail|编译.*失败|异常.*修复"
SCENE_MAP["bug_fix_skills"]="auto-bug-fixer"
SCENE_MAP["bug_fix_reason"]="自动修复代码 bug，分析错误日志和堆栈跟踪"

SCENE_MAP["refactor"]="重构|refactor|code.*smell|坏味道|优化.*代码|clean.*code|代码.*审查"
SCENE_MAP["refactor_skills"]="python-refactoring"
SCENE_MAP["refactor_reason"]="Python 代码重构，坏味道识别+设计模式+可读性改进"

SCENE_MAP["skill_audit"]="技能.*审计|skill.*audit|agent.*审计|安全.*审计"
SCENE_MAP["skill_audit_skills"]="skill-auditor"
SCENE_MAP["skill_audit_reason"]="AI Agent 技能安全审计，6 步协议"

SCENE_MAP["vllm_faq"]="vllm.*faq|vllm.*debug|debug.*faq|issue.*faq"
SCENE_MAP["vllm_faq_skills"]="vLLM-ascend_FAQ_Generator"
SCENE_MAP["vllm_faq_reason"]="vLLM-ascend Debug FAQ 自动生成"

# --- 8. 系统维护场景 ---

SCENE_MAP["system_maint"]="系统.*维护|system.*maint|内核.*优化|hugepage|tuned"
SCENE_MAP["system_maint_reason"]="系统内核优化：HugePages 240GB, tuned 性能配置（见 docs/SKILL.md）"

SCENE_MAP["deploy"]="部署|deploy|ansible|playbook|一键.*部署"
SCENE_MAP["deploy_reason"]="Ansible 自动化部署，见 QWEN.md 部署命令（./scripts/deploy.sh）"

# ============================================================================
# 匹配引擎
# ============================================================================

match_skills() {
    local input="$1"
    local matched=0
    local input_lower
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')

    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  场景分析结果${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "输入任务: ${CYAN}${input}${NC}"
    echo ""

    for key in "${!SCENE_MAP[@]}"; do
        # 跳过非 pattern 的 key
        if [[ ! "$key" =~ _skills$ ]]; then
            continue
        fi

        local scene_name="${key%_skills}"
        local pattern="${SCENE_MAP[$key]#*=}"

        # 获取实际 pattern（去掉赋值部分）
        local real_key="${key/_skills/}"
        local real_pattern="${SCENE_MAP[$real_key]}"

        if echo "$input_lower" | grep -qiE "$real_pattern" 2>/dev/null; then
            local skills="${SCENE_MAP[${scene_name}_skills]#*=}"
            local reason="${SCENE_MAP[${scene_name}_reason]#*=}"

            matched=$((matched + 1))

            echo -e "${GREEN}✅ 匹配场景 #${matched}: ${scene_name}${NC}"
            echo -e "   ${YELLOW}匹配模式:${NC} $real_pattern"
            echo -e "   ${YELLOW}推荐技能:${NC}"

            IFS=',' read -ra skill_arr <<< "$skills"
            for skill in "${skill_arr[@]}"; do
                echo -e "     • ${CYAN}${skill}${NC}"
                if [[ -d "$SKILLS_DIR/$skill" ]]; then
                    echo -e "       路径: src/agent-skills/${skill}/"
                fi
            done

            echo -e "   ${YELLOW}推荐理由:${NC} $reason"
            echo ""
        fi
    done

    if [[ $matched -eq 0 ]]; then
        echo -e "${RED}❌ 未匹配到预定义场景${NC}"
        echo ""
        echo "建议："
        echo "1. 使用更具体的关键词（如'安装NPU驱动'、'开发AscendC算子'）"
        echo "2. 运行 $(basename "$0") --list 查看所有支持场景"
        echo "3. 手动浏览 src/agent-skills/ 目录查找技能"
        echo ""
    else
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  共匹配 ${matched} 个场景${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    fi
}

# ============================================================================
# 列出所有场景
# ============================================================================

list_all_scenes() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  所有支持的场景列表${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    printf "%-30s | %-50s | %s\n" "场景名" "匹配模式示例" "推荐技能"
    printf "%-30s-+-%-50s-+-%s\n" "------------------------------" "----------------------------------------------------" "----------------"

    for key in "${!SCENE_MAP[@]}"; do
        if [[ ! "$key" =~ _skills$ ]]; then
            continue
        fi
        local scene_name="${key%_skills}"
        local pattern="${SCENE_MAP[$key]#*=}"
        local skills="${SCENE_MAP[${scene_name}_skills]#*=}"
        local reason="${SCENE_MAP[${scene_name}_reason]#*=}"

        printf "%-30s | %-50s | %s\n" "$scene_name" "$pattern" "$skills"
    done | sort
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    if [[ $# -eq 0 ]]; then
        echo "用法: $(basename "$0") [选项] <场景描述>"
        echo ""
        echo "选项:"
        echo "  --list     列出所有支持的场景"
        echo "  --task     任务模式（与直接输入等效）"
        echo "  --help     显示帮助"
        echo ""
        echo "示例:"
        echo "  $(basename "$0") '安装NPU驱动'"
        echo "  $(basename "$0") --task '开发AscendC算子'"
        echo "  $(basename "$0") --list"
        exit 0
    fi

    if [[ "$1" == "--list" ]]; then
        list_all_scenes
        exit 0
    fi

    if [[ "$1" == "--task" ]]; then
        shift
    fi

    local input="$*"
    match_skills "$input"
}

main "$@"
