# AGENTS.md — AI Agent Skills Index

> 本文件为跨 AI 工具的标准技能索引。无论使用 Qwen Code、Claude、Cursor、Cline、GitHub Copilot、Windsurf 或其他 AI Coding 工具，均可通过此文件快速获取项目全部技能。

## 项目上下文

本项目为 **KSC AIBox**（金山政务AI一体机），基于 Huawei Ascend 910B NPU + openEuler + Ansible 自动化部署。

### 必读文件

开始工作前请阅读以下文件以加载项目上下文：

| 文件 | 用途 | 优先级 |
|------|------|--------|
| `QWEN.md` | 项目上下文（版本/硬件/部署命令） | 🔴 必读 |
| `docs/MULTI-AGENT-COMMAND-CENTER.md` | **多AI协同指挥中枢（最新状态+Codex工作记录）** | 🔴 **首先读取** |
| `AGENTS.md` | 本文件（技能索引） | 🔴 必读 |
| `docs/handoff.md` | 项目交接文档 | 🟡 建议 |
| `docs/SKILL.md` | 技能经验文档 | 🟡 建议 |

### 参与Agent

| Agent | 角色 | 证据 | 配置 |
|-------|------|------|------|
| **Qwen Code** | 主力执行 (77% Git提交) | Co-authored-by | `.qwen/settings.json` |
| **OpenAI Codex** | 架构规划 (117条会话) | `~/.codex/history.jsonl` | `~/.codex/config.toml` |
| **Claude Code** | 辅助调试 (40+ SSH) | SSH操作日志 | `.claude/settings.local.json` |
| **Gemini CLI** | 早期咨询 | 配置文件 | `GEMINI.md` |

### 关键路径

| 路径 | 用途 |
|------|------|
| `/ksc_aibox` | AI一体机根目录 |
| `/ksc_aibox/apps/` | 应用目录 (ascend/vllm/ai-service) |
| `/ksc_aibox/models/` | 模型文件 (llm/embedding/rerank/vl) |
| `/ksc_aibox/data/` | 数据目录 (mysql/postgres/redis/milvus/neo4j) |
| `/ksc_aibox/docker/` | Docker数据 |
| `/ksc_aibox/logs/` | 日志 |
| `/backup` | 备份根目录 |

---

## AI Agent Skills（54个技能）

所有技能定义位于 `src/agent-skills/` 目录下。每个技能目录包含 `SKILL.md` 定义文件，以及可选的 `references/`、`scripts/`、`templates/` 等辅助资源。

### 自动场景匹配 ⚡

当用户提出任务时，首先运行场景匹配引擎，自动推荐技能：

```bash
python3 scripts/match-skills.py "任务描述"
```

**示例场景**：
| 任务描述 | 匹配命令 |
|----------|----------|
| 安装NPU驱动 | `python3 scripts/match-skills.py "安装NPU驱动"` |
| 开发AscendC算子全流程 | `python3 scripts/match-skills.py "开发AscendC算子全流程"` |
| Triton算子GPU迁移到NPU | `python3 scripts/match-skills.py "triton算子从GPU迁移到NPU"` |
| HCCL多机通信测试 | `python3 scripts/match-skills.py "HCCL多机通信测试"` |
| 算子精度评估 | `python3 scripts/match-skills.py "算子精度评估"` |
| 生成单元测试 | `python3 scripts/match-skills.py "生成单元测试"` |
| Python代码重构 | `python3 scripts/match-skills.py "Python代码重构"` |

匹配引擎会输出：场景名称、推荐技能列表、技能路径和可用的参考文件（references/scripts/templates）。

### 手动技能加载

不同 AI 工具的技能加载方式：

| 工具 | 加载方式 |
|------|----------|
| **Qwen Code** | 通过 `skills` 工具直接调用，或读取 `src/agent-skills/<skill>/SKILL.md` |
| **Claude / Cline / Roo Code** | 读取 `.clinerules` 文件获取技能索引，然后按需加载具体技能 |
| **Cursor** | 读取 `.cursorrules` 文件获取技能索引 |
| **GitHub Copilot** | 读取 `.github/copilot-instructions.md` 获取技能索引 |
| **Windsurf** | 读取 `.windsurfrules` 文件获取技能索引 |
| **通用** | 直接读取本文件 `AGENTS.md` 下方的技能索引表 |

### 技能索引表

#### 1. 环境部署族 (5个)

| 技能目录 | 描述 | 触发关键词 |
|----------|------|-----------|
| `ascend-docker` | Ascend NPU 开发 Docker 容器创建，支持 Privileged/Basic/Full 三种模式 | ascend, docker, npu, 容器化 |
| `ascend-npu-driver-install` | NPU驱动和固件端到端安装，自动提取安装包、Python+Shell双重校验 | npu驱动, 驱动安装, firmware, Ascend310P/910A/910B |
| `cann-operator-env-config` | CANN 安装指导，支持离线/Conda/Yum 三种安装方式 | CANN安装, 环境配置, 昇腾环境 |
| `atc-model-converter` | ATC 模型转换工具，ONNX→OM 格式，支持精度对比和 AIPP 配置 | ATC, 模型转换, onnx, om, 精度对比 |
| `hccl-test` | HCCL 集合通信性能测试，支持 AllReduce/AllGather 等10种算子 | hccl, 集合通信, 多机测试, allreduce, allgather |

#### 2. AscendC 算子开发族 (12个)

| 技能目录 | 描述 | 触发关键词 |
|----------|------|-----------|
| `ascendc-operator-project-init` | 检测/创建 ascend-kernel 项目，生成算子骨架 | 新建算子, 算子初始化, 算子目录 |
| `ascendc-operator-design` | 算子需求分析，生成设计文档（含 Tiling 策略、UB 分配表） | 算子设计, tiling策略, 内存规划 |
| `ascendc-operator-testcase-gen` | 根据设计文档生成统一测试用例文档 | 用例设计, 泛化用例, UT用例, 精度用例 |
| `ascendc-operator-code-gen` | 根据设计文档生成 op_host/op_kernel 代码和框架适配 | 代码生成, op_host, op_kernel, tiling, kernel |
| `ascendc-operator-compile-debug` | 编译、安装 whl、运行功能/精度测试，排错循环最多3次 | build.sh, 编译, 安装, whl, pytest |
| `ascendc-operator-doc-gen` | 从源码提取接口信息，生成 PyTorch 风格中文 API 文档 | 生成算子文档, README, 算子文档 |
| `ascendc-operator-precision-eval` | 生成 ≥30 例精度测试、运行并输出精度验证报告 | 精度测试, accuracy, 误差分析 |
| `ascendc-operator-performance-eval` | 使用 torch_npu.profiler 对比自定义算子 vs 标杆性能 | 性能评估, profiler, benchmark |
| `ascendc-operator-performance-optim` | 排查并优化 AscendC 算子性能（Tiling/搬运/API/内存/流水五阶段） | 性能优化, tiling, 流水, 搬运, 内存优化 |
| `ascendc-operator-precision-debug` | 精度测试失败时排查根因（误差分析→代码审查→实验隔离→插桩定位） | 精度调试, 精度问题, 结果不一致, NaN |
| `ascendc-operator-code-review` | Ascend C 代码审查，基于假设检验论的安全规范检视 | 代码检视, 代码review, 安全规范, 内存, 指针 |
| `ascendc-operator-dev` | **编排器**：七阶段端到端工作流，编排以上所有子 skill | 算子开发, 端到端, 完整流程, 新建算子 |

#### 3. CATLASS 算子开发族 (4个)

| 技能目录 | 描述 | 触发关键词 |
|----------|------|-----------|
| `catlass-operator-design` | 将 CATLASS 算子需求转变为设计文档（含组件选型表格） | catlass设计, 矩阵算子, 组件选型 |
| `catlass-operator-code-gen` | 根据设计文档生成 op_host/op_kernel/test_aclnn | catlass代码生成, op_host, op_kernel |
| `catlass-operator-dev` | **编排器**：六阶段工作流，复用 ascendc 通用能力 + catlass 专属能力 | Catlass, 端到端, 算子开发 |
| `catlass-operator-performance-optim` | Catlass 算子性能调优（tiling/DispatchPolicy/Swizzle） | catlass性能优化, tiling, Swizzle |

#### 4. Triton 算子开发族 (9个)

| 技能目录 | 描述 | 触发关键词 |
|----------|------|-----------|
| `triton-operator-design` | 生成适用于 Ascend NPU 的 Triton 算子需求文档 | triton设计, 算子需求 |
| `triton-operator-code-gen` | 根据设计文档生成 Ascend NPU 的 Triton kernel 代码 | triton代码生成, kernel代码 |
| `triton-operator-dev` | 昇腾 Triton 算子全流程开发任务编排 | triton开发, 完整流程 |
| `triton-operator-doc-gen` | 生成昇腾 NPU 的 Triton 算子接口文档 | triton文档, 接口文档 |
| `triton-operator-env-config` | 校验并构建 triton 算子开发所需环境 | triton环境, 环境配置 |
| `triton-operator-precision-eval` | 自动调用 Torch 小算子进行精度比对，生成精度报告 | triton精度, 精度比对 |
| `triton-operator-performance-eval` | 评估 Ascend NPU 上 Triton 算子的性能表现 | triton性能, 性能评估 |
| `triton-operator-performance-optim` | 优化 Ascend NPU 亲和的 Triton 算子性能 | triton优化, 性能优化 |
| `triton-operator-code-review` | 静态检视 Triton 算子代码质量（Host 侧 + Device 侧） | triton代码审查, 代码质量 |

#### 5. Megatron 迁移族 (4个)

| 技能目录 | 描述 | 触发关键词 |
|----------|------|-----------|
| `megatron-change-analyzer` | 分析 Megatron-LM 变更集，识别功能演进和 breaking risk | megatron变更分析, 功能演进, breaking risk |
| `megatron-commit-tracker` | 跟踪 Megatron 官方提交，输出标准化 change-set | megatron提交跟踪, change-set |
| `megatron-impact-mapper` | 将 Megatron 变更映射到 MindSpeed，输出 impact_report | megatron影响映射, MindSpeed |
| `megatron-migration-generator` | 生成迁移 deliverables，支持 report/patch/apply/commit 四种模式 | megatron迁移, 迁移报告, patch |

#### 6. MindSpeed LLM 测试族 (7个)

| 技能目录 | 描述 | 触发关键词 |
|----------|------|-----------|
| `code-comprehension` | 在函数/类/模块/系统级别理解和总结代码 | 代码理解, 代码摘要, 分布式训练分析 |
| `generate-unit-test` | 为函数和类生成高质量单元测试 | 单元测试, 测试生成 |
| `pytest-writer` | 专业 pytest 测试用例编写助手 | pytest, fixtures, 参数化 |
| `unittest-writer` | Python unittest 框架的专业测试用例编写助手 | unittest, 测试用例 |
| `analyse-coverage` | 分析测试覆盖率盲区，生成覆盖率报告 | 覆盖率分析, coverage |
| `run-mindspeed-llm-test` | 运行 MindSpeed-LLM 项目的测试用例 | 运行测试, MindSpeed |
| `coverage` | 覆盖率相关工具技能 | coverage |

#### 7. NPU 运维族 (6个)

| 技能目录 | 描述 | 触发关键词 |
|----------|------|-----------|
| `npu-smi` | npu-smi 命令参考：设备查询/配置/固件升级/虚拟化/证书 | npu-smi, 设备管理, 温度, 功耗, 固件升级 |
| `npu-adapter-reviewer` | GPU代码到昇腾NPU适配审查专家 | NPU适配, 昇腾迁移, GPU转NPU, CANN |
| `ascend-profiling-anomaly` | 分析 Ascend NPU profiling 数据，发现性能异常 | profiling分析, 性能异常, bubble检测 |
| `ascend-inference-repos-copilot` | 昇腾推理生态开源代码仓库智能问答专家 | vLLM, MindIE, 推理生态, 问答 |
| `simple-vector-triton-gpu-to-npu` | 将简单 Vector 类型 Triton 算子从 GPU 迁移到 NPU | GPU迁移, Triton迁移, 向量算子 |
| `vector-triton-ascend-ops-optimizer` | 昇腾 NPU 上 Triton 算子深度性能优化 | 性能优化, 深度调优 |

#### 8. 通用工具族 (7个)

| 技能目录 | 描述 | 触发关键词 |
|----------|------|-----------|
| `auto-bug-fixer` | 自动修复代码中的 bug，分析错误日志和堆栈跟踪 | bug修复, 错误分析, 自动修复 |
| `auto-develop-test-gen` | 为函数和类生成高质量单元测试，分析覆盖率盲区 | 测试生成, 覆盖率分析 |
| `python-refactoring` | Python 代码重构，覆盖坏味道识别/设计模式/可读性改进 | 重构, refactor, code smell, 设计模式 |
| `skill-auditor` | AI Agent 技能安全审计，6步协议（元数据/权限/依赖/注入/网络/内容） | 安全审计, 技能审计, agent audit |
| `vLLM-ascend_FAQ_Generator` | 为 vLLM-ascend 项目构建自动化 Debug FAQ | vLLM FAQ, Debug FAQ |
| `msverl-daily-regression-triage` | MSVerl 每日回归分类，解析对比日志排名嫌疑 commits | 回归分析, triage, 嫌疑排名 |

---

## 工作模式

AI Agent 应遵循以下工作模式：

```
1. 接收任务 → 2. 加载上下文（读 QWEN.md + 相关 SKILL）→ 3. 制定计划
     ↓
4. 展示方案（人类确认）→ 5. 执行任务 → 6. 验证结果 → 7. 生成报告 → 8. 提交 Git
```

### 协作模式

| 模式 | 适用场景 | 行为 |
|------|----------|------|
| **主动执行** | 明确的代码修改/文件创建/配置更新 | 直接执行，完成后报告 |
| **建议确认** | 架构变更/大规模重构/数据库变更 | 提供方案，等待人类确认 |
| **请求指导** | 信息不足/多种可行方案/权限受限 | 向人类提出具体问题 |

### 安全规范

- **绝不** 提交 API Keys 或敏感信息
- **必须** 先读取现有代码再修改
- **必须** 遵循项目编码风格（2空格缩进、snake_case 变量名）
- **禁止** 删除已有功能代码，除非明确要求
- **必须** 执行验证命令确认变更正确

---

## 技能更新

本技能索引通过 `scripts/sync-agent-skills.sh` 脚本每周自动从上游仓库 `https://gitcode.com/Ascend/agent-skills` 同步更新。

手动更新命令：
```bash
./scripts/sync-agent-skills.sh
```

如需检查技能是否最新：
```bash
./scripts/sync-agent-skills.sh --check
```

---

*本文件由自动化工具生成，最后更新时间见下方元数据。请勿手动编辑技能索引部分。*
