#!/usr/bin/env python3
# ============================================================================
# match-skills.py — 根据场景/任务自动匹配 AI Agent Skills
#
# 用途: 根据输入的场景描述或任务类型，自动搜索并推荐匹配的技能
#
# 用法:
#   python3 scripts/match-skills.py "安装NPU驱动"
#   python3 scripts/match-skills.py --task "部署vLLM推理服务"
#   python3 scripts/match-skills.py --list    # 列出所有场景映射
# ============================================================================

import re
import sys
import os
from dataclasses import dataclass, field
from typing import List

# 项目根目录
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILLS_DIR = os.path.join(PROJECT_ROOT, "src", "agent-skills")


@dataclass
class SkillMatch:
    """技能匹配结果"""
    scene_name: str
    pattern: str
    skills: List[str]
    reason: str
    match_score: int = 0


# ============================================================================
# 场景→技能映射定义
# ============================================================================

SCENES = [
    # --- 1. 服务器维护场景 ---
    {
        "name": "install_npu_driver",
        "pattern": r"安装.*驱动|npu.*driver|驱动.*安装|firmware.*install|昇腾.*驱动|ascend.*driver|驱动.*昇腾",
        "skills": ["ascend-npu-driver-install"],
        "reason": "端到端 NPU 驱动安装，自动提取包+校验+安装"
    },
    {
        "name": "check_npu_status",
        "pattern": r"npu.*状态|npu.*检查|设备.*查询|npu-smi|设备.*健康|health.*check|设备.*温度|功耗.*查询",
        "skills": ["npu-smi"],
        "reason": "npu-smi 设备查询：温度/功耗/内存/进程/ECC"
    },
    {
        "name": "npu_docker",
        "pattern": r"npu.*docker|容器.*昇腾|docker.*ascend|容器.*npu|docker.*device|npu.*容器",
        "skills": ["ascend-docker"],
        "reason": "创建 Ascend NPU 开发 Docker 容器，支持 Privileged/Basic/Full 三种模式"
    },
    {
        "name": "cann_install",
        "pattern": r"安装.*cann|cann.*安装|cann.*配置|cann.*env|环境.*配置|cann.*toolkit",
        "skills": ["cann-operator-env-config"],
        "reason": "CANN 环境配置，支持离线/Conda/Yum 三种安装方式"
    },
    {
        "name": "model_convert",
        "pattern": r"模型.*转换|model.*convert|onnx.*om|atc|om.*生成|精度.*对比|模型.*推理",
        "skills": ["atc-model-converter"],
        "reason": "ATC 模型转换 ONNX→OM，支持精度对比和 AIPP 配置"
    },
    {
        "name": "hccl_test",
        "pattern": r"hccl|集合.*通信|allreduce|allgather|多机.*测试|打流|通信.*测试|集合通信",
        "skills": ["hccl-test"],
        "reason": "HCCL 集合通信性能测试，支持 AllReduce/AllGather 等 10 种算子"
    },
    {
        "name": "npu_adapter",
        "pattern": r"gpu.*npu|npu.*适配|cuda.*ascend|gpu.*迁移|cann.*迁移|gpu.*转.*npu",
        "skills": ["npu-adapter-reviewer"],
        "reason": "GPU→NPU 适配审查，5 阶段工作流"
    },
    {
        "name": "profiling_anomaly",
        "pattern": r"profiling|性能.*异常|bubble|wait.*anchor|aicpu.*暴露|性能.*分析|profiling.*分析",
        "skills": ["ascend-profiling-anomaly"],
        "reason": "Ascend profiling 异常分析，发现隐藏性能问题并生成架构报告"
    },
    {
        "name": "inference_copilot",
        "pattern": r"vllm.*ascend|mindie|推理.*生态|vllm.*问题|推理.*问答|mindie.*llm",
        "skills": ["ascend-inference-repos-copilot"],
        "reason": "昇腾推理生态智能问答，覆盖 vLLM/MindIE 生态仓库"
    },

    # --- 2. AscendC 算子开发场景 ---
    {
        "name": "ascendc_new_op",
        "pattern": r"ascendc.*新建|新建.*算子|新.*算子|operator.*new|算子.*初始化|创建.*算子|ascend.*kernel",
        "skills": ["ascendc-operator-project-init"],
        "reason": "ascend-kernel 工程初始化，生成算子骨架目录"
    },
    {
        "name": "ascendc_design",
        "pattern": r"算子.*设计|design.*operator|tiling.*策略|ub.*分配|算子.*架构|两级.*tiling",
        "skills": ["ascendc-operator-design", "ascendc-operator-testcase-gen"],
        "reason": "算子需求分析→设计文档（含 Tiling 策略）+ 测试用例生成"
    },
    {
        "name": "ascendc_code_gen",
        "pattern": r"算子.*代码|code.*gen|op_host|op_kernel|算子.*实现|kernel.*代码|算子.*生成",
        "skills": ["ascendc-operator-code-gen"],
        "reason": "根据设计文档生成 op_host/op_kernel 代码和框架适配"
    },
    {
        "name": "ascendc_compile",
        "pattern": r"算子.*编译|compile|build.*sh|whl.*安装|编译.*错误|ascendc.*编译",
        "skills": ["ascendc-operator-compile-debug"],
        "reason": "编译安装+精度测试，排错循环最多 3 次"
    },
    {
        "name": "ascendc_precision",
        "pattern": r"算子.*精度|precision|accuracy|精度.*测试|精度.*评估|误差.*分析|结果.*不一致",
        "skills": ["ascendc-operator-precision-eval", "ascendc-operator-precision-debug"],
        "reason": "生成≥30例精度测试，失败时自动排查根因（误差分析→代码审查→实验隔离→插桩定位）"
    },
    {
        "name": "ascendc_performance",
        "pattern": r"算子.*性能|performance|profiler|benchmark|性能.*评估|性能.*测试|ascendc.*性能",
        "skills": ["ascendc-operator-performance-eval"],
        "reason": "torch_npu.profiler 性能评测，warmup=5 active=5"
    },
    {
        "name": "ascendc_optim",
        "pattern": r"算子.*优化|optim|tiling.*优化|流水.*优化|内存.*优化|性能.*调优|ascendc.*优化",
        "skills": ["ascendc-operator-performance-optim"],
        "reason": "五阶段排查: Tiling/搬运/API/内存/流水"
    },
    {
        "name": "ascendc_review",
        "pattern": r"算子.*审查|code.*review|代码.*检视|安全.*检视|Ascend.*C.*review|算子.*review",
        "skills": ["ascendc-operator-code-review"],
        "reason": "基于假设检验论的安全规范检视（7 个检查维度）"
    },
    {
        "name": "ascendc_full",
        "pattern": r"ascendc.*开发|算子.*全流程|端到端.*算子|完整.*算子|从需求.*测试|ascendc.*全流程",
        "skills": ["ascendc-operator-dev"],
        "reason": "七阶段端到端 AscendC 算子开发工作流编排"
    },
    {
        "name": "ascendc_doc",
        "pattern": r"算子.*文档|ascendc.*文档|算子.*api|算子.*接口|生成.*README",
        "skills": ["ascendc-operator-doc-gen"],
        "reason": "从源码提取接口信息，生成 PyTorch 风格中文 API 文档"
    },

    # --- 3. CATLASS 算子开发场景 ---
    {
        "name": "catlass_design",
        "pattern": r"catlass.*设计|矩阵.*算子.*设计|matmul.*设计|catlass.*需求",
        "skills": ["catlass-operator-design"],
        "reason": "CATLASS 矩阵算子设计，含组件选型表格"
    },
    {
        "name": "catlass_code",
        "pattern": r"catlass.*代码|catlass.*实现|矩阵.*代码|catlass.*生成",
        "skills": ["catlass-operator-code-gen"],
        "reason": "CATLASS op_host/op_kernel/test_aclnn 代码生成"
    },
    {
        "name": "catlass_optim",
        "pattern": r"catlass.*优化|矩阵.*性能|tiling.*catlass|swizzle|catlass.*性能",
        "skills": ["catlass-operator-performance-optim"],
        "reason": "Catlass tiling/DispatchPolicy/Swizzle 性能调优"
    },
    {
        "name": "catlass_full",
        "pattern": r"catlass.*开发|catlass.*全流程|矩阵.*端到端|catlass.*端到端",
        "skills": ["catlass-operator-dev"],
        "reason": "六阶段 CATLASS 算子开发工作流编排"
    },

    # --- 4. Triton 算子开发场景 ---
    {
        "name": "triton_design",
        "pattern": r"triton.*设计|triton.*需求|grid.*配置|triton.*架构|triton.*tiling",
        "skills": ["triton-operator-design"],
        "reason": "生成 Ascend NPU 的 Triton 算子需求文档"
    },
    {
        "name": "triton_code",
        "pattern": r"triton.*代码|triton.*实现|kernel.*triton|triton.*kernel|triton.*生成",
        "skills": ["triton-operator-code-gen"],
        "reason": "根据设计文档生成 Ascend NPU Triton kernel 代码"
    },
    {
        "name": "triton_compile",
        "pattern": r"triton.*编译|triton.*调试|triton.*开发|triton.*运行",
        "skills": ["triton-operator-dev"],
        "reason": "Triton 算子全流程开发任务编排"
    },
    {
        "name": "triton_doc",
        "pattern": r"triton.*文档|triton.*接口|triton.*api|triton.*说明",
        "skills": ["triton-operator-doc-gen"],
        "reason": "生成昇腾 NPU Triton 算子接口文档"
    },
    {
        "name": "triton_precision",
        "pattern": r"triton.*精度|triton.*accuracy|triton.*precision|triton.*精度.*比对",
        "skills": ["triton-operator-precision-eval"],
        "reason": "Torch 小算子精度比对，生成精度报告"
    },
    {
        "name": "triton_perf",
        "pattern": r"triton.*性能|triton.*performance|triton.*profiler|triton.*benchmark",
        "skills": ["triton-operator-performance-eval"],
        "reason": "评估 Ascend NPU 上 Triton 算子性能表现"
    },
    {
        "name": "triton_optim",
        "pattern": r"triton.*优化|triton.*optim|triton.*调优|triton.*性能.*优化",
        "skills": ["triton-operator-performance-optim", "vector-triton-ascend-ops-optimizer"],
        "reason": "Triton 算子性能优化 + Ascend OPS 深度优化"
    },
    {
        "name": "triton_review",
        "pattern": r"triton.*审查|triton.*review|triton.*代码.*质量",
        "skills": ["triton-operator-code-review"],
        "reason": "Triton 算子代码静态检视（Host+Device 侧）"
    },
    {
        "name": "triton_env",
        "pattern": r"triton.*环境|triton.*env|triton.*配置|triton.*搭建",
        "skills": ["triton-operator-env-config"],
        "reason": "校验并构建 Triton 算子开发所需环境"
    },
    {
        "name": "triton_gpu_npu",
        "pattern": r"triton.*gpu.*npu|triton.*迁移|gpu.*triton.*npu|vector.*triton|gpu.*转.*triton",
        "skills": ["simple-vector-triton-gpu-to-npu"],
        "reason": "Vector 类型 Triton 算子 GPU→NPU 迁移，5 步流程"
    },

    # --- 5. Megatron 迁移场景 ---
    {
        "name": "megatron_change",
        "pattern": r"megatron.*变更|megatron.*change|功能.*演进|breaking.*risk|megatron.*分析",
        "skills": ["megatron-change-analyzer"],
        "reason": "Megatron 变更分析，结构化事件输出"
    },
    {
        "name": "megatron_commit",
        "pattern": r"megatron.*提交|megatron.*commit|megatron.*track|变更.*跟踪",
        "skills": ["megatron-commit-tracker"],
        "reason": "Megatron 提交跟踪，输出标准化 change-set"
    },
    {
        "name": "megatron_impact",
        "pattern": r"megatron.*影响|megatron.*impact|mind.*映射|mindspeed.*映射|影响.*分析",
        "skills": ["megatron-impact-mapper"],
        "reason": "将 Megatron 变更映射到 MindSpeed，输出 impact_report"
    },
    {
        "name": "megatron_migrate",
        "pattern": r"megatron.*迁移|megatron.*migrate|mind.*迁移|megatron.*移植",
        "skills": ["megatron-migration-generator"],
        "reason": "生成迁移 deliverables，支持 report/patch/apply/commit 四种模式"
    },

    # --- 6. 测试场景 ---
    {
        "name": "test_gen",
        "pattern": r"生成.*测试|测试.*生成|unit.*test|测试.*补全|test.*gen|自动.*测试",
        "skills": ["auto-develop-test-gen", "generate-unit-test", "pytest-writer"],
        "reason": "自动生成高质量单元测试，覆盖正常/边界/异常场景"
    },
    {
        "name": "coverage",
        "pattern": r"覆盖.*分析|coverage|覆盖率.*报告|覆盖率.*盲区|coverage.*report",
        "skills": ["analyse-coverage", "coverage"],
        "reason": "分析覆盖率盲区，生成覆盖率报告"
    },
    {
        "name": "code_understand",
        "pattern": r"理解.*代码|代码.*理解|代码.*摘要|code.*comprehension|分析.*代码|代码.*解读",
        "skills": ["code-comprehension"],
        "reason": "函数/类/模块/系统级代码理解"
    },
    {
        "name": "run_test",
        "pattern": r"运行.*测试|run.*test|执行.*测试|test.*run|mindspeed.*test",
        "skills": ["run-mindspeed-llm-test"],
        "reason": "运行 MindSpeed-LLM 测试用例"
    },
    {
        "name": "regression",
        "pattern": r"回归.*分析|regression|msverl|每日.*回归|回归.*triage",
        "skills": ["msverl-daily-regression-triage"],
        "reason": "MSVerl 每日回归分类，解析对比日志排名嫌疑 commits"
    },

    # --- 7. 通用编程场景 ---
    {
        "name": "bug_fix",
        "pattern": r"bug.*修复|fix.*bug|错误.*分析|test.*fail|编译.*失败|异常.*修复|代码.*bug",
        "skills": ["auto-bug-fixer"],
        "reason": "自动修复代码 bug，分析错误日志和堆栈跟踪"
    },
    {
        "name": "refactor",
        "pattern": r"重构|refactor|code.*smell|坏味道|优化.*代码|clean.*code|代码.*审查|重构.*python",
        "skills": ["python-refactoring"],
        "reason": "Python 代码重构，坏味道识别+设计模式+可读性改进"
    },
    {
        "name": "skill_audit",
        "pattern": r"技能.*审计|skill.*audit|agent.*审计|安全.*审计|skill.*security",
        "skills": ["skill-auditor"],
        "reason": "AI Agent 技能安全审计，6 步协议"
    },
    {
        "name": "vllm_faq",
        "pattern": r"vllm.*faq|vllm.*debug|debug.*faq|issue.*faq|vllm.*问题.*总结",
        "skills": ["vLLM-ascend_FAQ_Generator"],
        "reason": "vLLM-ascend Debug FAQ 自动生成"
    },

    # --- 8. 系统维护场景 ---
    {
        "name": "system_maint",
        "pattern": r"系统.*维护|system.*maint|内核.*优化|hugepage|tuned|系统.*优化",
        "skills": [],
        "reason": "系统内核优化：HugePages 240GB, tuned 性能配置（见 docs/SKILL.md）"
    },
    {
        "name": "deploy",
        "pattern": r"部署|deploy|ansible|playbook|一键.*部署|ansible.*playbook",
        "skills": [],
        "reason": "Ansible 自动化部署，见 QWEN.md 部署命令（./scripts/deploy.sh）"
    },
]


# ============================================================================
# 匹配引擎
# ============================================================================

def match_skills(input_text: str) -> List[SkillMatch]:
    """根据输入文本匹配场景"""
    matches = []
    input_lower = input_text.lower()

    for scene in SCENES:
        pattern = scene["pattern"]
        try:
            if re.search(pattern, input_lower, re.IGNORECASE):
                match = SkillMatch(
                    scene_name=scene["name"],
                    pattern=scene["pattern"],
                    skills=scene["skills"],
                    reason=scene["reason"],
                    match_score=len(scene["skills"])
                )
                matches.append(match)
        except re.error:
            continue

    # 按技能数量排序（技能越多越具体）
    matches.sort(key=lambda m: m.match_score, reverse=True)
    return matches


def format_match_result(match: SkillMatch, index: int) -> str:
    """格式化单个匹配结果"""
    lines = []
    lines.append(f"\033[0;32m✅ 匹配场景 #{index}: {match.scene_name}\033[0m")
    lines.append(f"   \033[1;33m匹配模式:\033[0m {match.pattern}")

    if match.skills:
        lines.append(f"   \033[1;33m推荐技能:\033[0m")
        for skill in match.skills:
            skill_path = os.path.join(SKILLS_DIR, skill)
            lines.append(f"     • \033[0;36m{skill}\033[0m")
            if os.path.isdir(skill_path):
                lines.append(f"       路径: src/agent-skills/{skill}/")
                # 列出可用的参考文件
                for sub in ["SKILL.md", "references/", "scripts/", "templates/"]:
                    sub_path = os.path.join(skill_path, sub)
                    if os.path.exists(sub_path):
                        lines.append(f"       可用: {sub}")
    else:
        lines.append(f"   \033[1;33m推荐:\033[0m 见项目文档")

    lines.append(f"   \033[1;33m推荐理由:\033[0m {match.reason}")
    return "\n".join(lines)


def format_all_matches(input_text: str, matches: List[SkillMatch]) -> str:
    """格式化所有匹配结果"""
    lines = []
    lines.append("\033[0;34m" + "═" * 60 + "\033[0m")
    lines.append("\033[0;34m  场景分析结果\033[0m")
    lines.append("\033[0;34m" + "═" * 60 + "\033[0m")
    lines.append("")
    lines.append(f"输入任务: \033[0;36m{input_text}\033[0m")
    lines.append("")

    if not matches:
        lines.append("\033[0;31m❌ 未匹配到预定义场景\033[0m")
        lines.append("")
        lines.append("建议：")
        lines.append("1. 使用更具体的关键词（如'安装NPU驱动'、'开发AscendC算子'）")
        lines.append("2. 运行 python3 scripts/match-skills.py --list 查看所有支持场景")
        lines.append("3. 手动浏览 src/agent-skills/ 目录查找技能")
        lines.append("4. 直接读取 AGENTS.md 获取完整技能索引")
    else:
        for i, match in enumerate(matches, 1):
            lines.append(format_match_result(match, i))
            lines.append("")

        lines.append("\033[0;32m" + "═" * 60 + "\033[0m")
        lines.append(f"\033[0;32m  共匹配 {len(matches)} 个场景\033[0m")
        lines.append("\033[0;32m" + "═" * 60 + "\033[0m")

    return "\n".join(lines)


def list_all_scenes() -> str:
    """列出所有支持的场景"""
    lines = []
    lines.append("\033[0;34m" + "═" * 80 + "\033[0m")
    lines.append("\033[0;34m  所有支持的场景列表\033[0m")
    lines.append("\033[0;34m" + "═" * 80 + "\033[0m")
    lines.append("")
    lines.append(f"{'场景名':<35} | {'匹配模式示例':<40}")
    lines.append("-" * 35 + "-+-" + "-" * 40)

    for scene in sorted(SCENES, key=lambda s: s["name"]):
        pattern_short = scene["pattern"][:38] + ".." if len(scene["pattern"]) > 40 else scene["pattern"]
        lines.append(f"{scene['name']:<35} | {pattern_short:<40}")

    lines.append("")
    lines.append(f"总计: {len(SCENES)} 个场景")
    return "\n".join(lines)


# ============================================================================
# 主流程
# ============================================================================

def main():
    if len(sys.argv) < 2:
        print("用法: python3 scripts/match-skills.py [选项] <场景描述>")
        print("")
        print("选项:")
        print("  --list     列出所有支持的场景")
        print("  --task     任务模式（与直接输入等效）")
        print("  --help     显示帮助")
        print("")
        print("示例:")
        print("  python3 scripts/match-skills.py '安装NPU驱动'")
        print("  python3 scripts/match-skills.py --task '开发AscendC算子'")
        print("  python3 scripts/match-skills.py --list")
        print("  python3 scripts/match-skills.py 'triton算子从GPU迁移到NPU'")
        print("  python3 scripts/match-skills.py 'HCCL多机通信测试'")
        sys.exit(0)

    if sys.argv[1] == "--list":
        print(list_all_scenes())
        sys.exit(0)

    if sys.argv[1] == "--help":
        print("用法: python3 scripts/match-skills.py [选项] <场景描述>")
        print("")
        print("场景匹配引擎会根据自然语言描述自动匹配对应的 AI Agent Skills。")
        print("覆盖以下场景:")
        print("  • 服务器维护（NPU驱动/设备查询/Docker/CANN/模型转换）")
        print("  • AscendC 算子开发（设计→代码→编译→精度→性能→优化）")
        print("  • Triton 算子开发（设计→代码→精度/性能评估）")
        print("  • CATLASS 矩阵算子开发")
        print("  • Megatron 迁移分析")
        print("  • 测试生成和覆盖率分析")
        print("  • 通用编程（Bug修复/重构/审计）")
        sys.exit(0)

    if sys.argv[1] == "--task":
        input_text = " ".join(sys.argv[2:])
    else:
        input_text = " ".join(sys.argv[1:])

    matches = match_skills(input_text)
    print(format_all_matches(input_text, matches))


if __name__ == "__main__":
    main()
