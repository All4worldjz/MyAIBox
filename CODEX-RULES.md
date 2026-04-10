# Codex Rules — KSC AIBox

## 🚀 启动时标准动作（必读！）

> **任何AI Agent启动时，必须按以下顺序执行同步动作**

### Step 1: 加载协同指挥文档（最重要）
```
读取 docs/MULTI-AGENT-COMMAND-CENTER.md
```
**目的**: 获取最新项目状态、待办任务、活跃问题、其他Agent工作进展

### Step 2: 加载项目上下文
```
读取 QWEN.md — 项目概况、硬件配置、部署命令
读取 AGENTS.md — 54个AI Agent技能索引
```

### Step 3: 确认当前状态
```
运行: git status && git log --oneline -3
```
**目的**: 确认本地Git仓库状态，了解最近提交

### Step 4: 查看待办任务
```
在 docs/MULTI-AGENT-COMMAND-CENTER.md 中查找 "待办任务看板"
```
**目的**: 认领 P0/P1 优先级任务，标注自己为负责Agent

### Step 5: 检查活跃问题
```
在 docs/MULTI-AGENT-COMMAND-CENTER.md 中查找 "问题与阻塞"
```
**目的**: 确认是否有待解决的问题需要处理

---

## 状态更新规则

> **任何操作后，必须更新协同指挥文档**

| 场景 | 更新位置 | 更新格式 |
|------|----------|----------|
| **完成任务后** | 待办任务看板 | 标注 `[✅ 完成 by {Agent} @ {HH:MM}]` |
| **遇到阻塞** | 问题与阻塞 | 登记新问题 |
| **Git提交后** | 操作日志 | `[HH:MM] [Agent] 操作描述 → ✅ 提交ID` |
| **SSH操作后** | 容器状态 | 更新容器状态表格 |
| **会话结束后** | 操作日志 | 总结本次会话的主要操作 |

**更新文件**: `docs/MULTI-AGENT-COMMAND-CENTER.md`

---

## 项目上下文

本项目为 **KSC AIBox**（金山政务AI一体机），基于 Huawei Ascend 910B NPU + openEuler + Ansible 自动化部署。

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
| `/ksc_aibox/apps/` | 应用目录 |
| `/ksc_aibox/models/` | 模型文件 |
| `/ksc_aibox/data/` | 数据目录 |
| `/ksc_aibox/docker/` | Docker数据 |

---

## AI Agent Skills (54个)

本项目包含 54 个 AI Agent Skills，定义在 `src/agent-skills/` 目录下。

### 使用技能

当用户要求执行某项任务时：
1. 查阅 `AGENTS.md` 中的技能索引表，找到对应的技能目录
2. 读取 `src/agent-skills/<skill-name>/SKILL.md` 获取详细执行指南
3. 技能目录中可能包含 `references/`、`scripts/`、`templates/` 等辅助资源

---

## 编码规范

- **语言**: 始终用中文回复
- **Playbook**: YAML 格式, 2 空格缩进
- **脚本**: Bash, 遵循 `.editorconfig`
- **变量命名**: snake_case

## 安全规范

- 不提交敏感信息
- 先读后改
- 执行验证

## 技能更新

```bash
./scripts/sync-agent-skills.sh
```
