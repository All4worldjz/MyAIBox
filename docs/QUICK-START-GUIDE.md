# 🚀 AI Agent 快速启动指南

> **任何AI Agent接手工作，只需5分钟完成同步！**

---

## ⚡ 30秒快速同步

### 方法1: 运行启动脚本（推荐）
```bash
./scripts/startup-sync.sh
```

### 方法2: 手动同步（5步）
```bash
# Step 1: 检查Git状态
git status && git log --oneline -3

# Step 2-3: 读取核心文档（按顺序）
# 1. docs/MULTI-AGENT-COMMAND-CENTER.md — 协同指挥文档（最重要！）
# 2. QWEN.md — 项目上下文
# 3. AGENTS.md — 技能索引
```

---

## 📋 必读文件清单（按优先级）

| 优先级 | 文件 | 用途 | 阅读时间 |
|--------|------|------|----------|
| 🔴 **必须** | `docs/MULTI-AGENT-COMMAND-CENTER.md` | **最新状态+任务+问题** | 3分钟 |
| 🔴 **必须** | `QWEN.md` | 项目概况、硬件配置、部署命令 | 2分钟 |
| 🔴 **必须** | `AGENTS.md` | 54个AI Agent技能索引 | 1分钟 |
| 🟡 建议 | `docs/handoff.md` | 项目交接文档 | 5分钟 |
| 🟡 建议 | `docs/SKILL.md` | 踩坑/排错经验 | 按需 |

---

## ✅ 启动检查清单

启动时逐项检查（约5分钟）：

- [ ] **Step 1**: 读取 `docs/MULTI-AGENT-COMMAND-CENTER.md`
  - 查看「当前现场状态快照」
  - 查看「待办任务看板」→ 认领P0/P1任务
  - 查看「问题与阻塞」→ 确认是否有待解决问题
  - 查看「操作日志」→ 了解最近24小时活动

- [ ] **Step 2**: 读取 `QWEN.md`
  - 了解项目概况
  - 熟悉硬件配置
  - 掌握部署命令

- [ ] **Step 3**: 读取 `AGENTS.md`
  - 了解54个AI Agent技能
  - 掌握技能加载方法

- [ ] **Step 4**: 运行 `git status && git log --oneline -3`
  - 确认本地Git状态
  - 了解最近提交历史

- [ ] **Step 5**: 认领任务
  - 在「待办任务看板」标注自己为负责Agent
  - 开始执行任务

---

## 📝 工作更新规则

**核心原则**: 任何操作后，立即更新 `docs/MULTI-AGENT-COMMAND-CENTER.md`

| 场景 | 更新位置 | 更新格式 | 示例 |
|------|----------|----------|------|
| **完成任务** | 待办任务看板 | `[✅ 完成 by {Agent} @ {HH:MM}]` | `[✅ 完成 by Qwen Code @ 10:30]` |
| **遇到阻塞** | 问题与阻塞 | 登记新问题 | `\| **BUG-003** \| 问题描述 \| ...` |
| **Git提交** | 操作日志 | `[HH:MM] [Agent] 操作 → ✅ ID` | `[10:30] [Qwen] 修复容器启动 → ✅ abc123` |
| **SSH操作** | 容器状态 | 更新状态表格 | `\| 容器 \| ✅ 正常 \| ...` |

---

## 🎯 当前紧急任务（实时更新）

> 从 `docs/MULTI-AGENT-COMMAND-CENTER.md` 提取

| ID | 任务 | 优先级 | 状态 | 负责 |
|----|------|--------|------|------|
| **T001** | 修复 qingqiu-qwen3-1 容器 | P0 | 🔍 排查中 | Claude |
| **T002** | 提交未commit的本地更改 | P0 | ⏳ 待处理 | Qwen |
| **T003** | 推送到origin/dev | P1 | ⏳ 待处理 | Qwen |
| **T004** | 确认NPU固件冷启动 | P1 | ⏳ 待确认 | Any |

---

## 🐛 活跃问题（实时更新）

> 从 `docs/MULTI-AGENT-COMMAND-CENTER.md` 提取

| ID | 问题 | 状态 | 负责 |
|----|------|------|------|
| **BUG-001** | qingqiu-qwen3-1 容器启动失败 | 🔍 排查中 | Claude |
| **BUG-002** | vLLM 容器配置错误 | ⏳ 待修复 | - |
| **WARN-001** | NPU固件未生效 | ⏳ 待决策 | - |
| **WARN-002** | SELinux Permissive | ⏳ 待评估 | - |

---

## 🤖 参与Agent

| Agent | 角色 | 贡献度 | 配置 |
|-------|------|--------|------|
| **Qwen Code** | 主力执行 | 70% | `.qwen/settings.json` |
| **OpenAI Codex** | 架构规划 | 15% | `~/.codex/config.toml` |
| **Claude Code** | 辅助调试 | 10% | `.claude/settings.local.json` |
| **Gemini CLI** | 早期咨询 | 5% | `GEMINI.md` |

---

## 🛠️ 常用命令速查

### Git操作
```bash
git status                    # 查看状态
git add -A && git commit -m "消息"  # 提交
git push origin dev          # 推送
git log --oneline -5         # 查看历史
```

### SSH到服务器
```bash
ssh root@10.212.128.192                    # 连接
ssh root@10.212.128.192 "npu-smi info"    # 查看NPU
ssh root@10.212.128.192 "docker ps -a"    # 查看容器
```

### Ansible操作
```bash
cd ansible
ansible-playbook -i inventory/hosts playbooks/<name>.yml
```

### Docker操作
```bash
cd docker-compose
./deploy-all.sh              # 部署所有服务
docker-compose ps            # 查看服务状态
docker-compose logs -f <服务> # 查看日志
```

---

## 📚 完整文档索引

| 文档 | 路径 | 用途 |
|------|------|------|
| **协同指挥中枢** | `docs/MULTI-AGENT-COMMAND-CENTER.md` | 🤖 **单一真相来源** |
| 项目上下文 | `QWEN.md` | 版本/硬件/部署命令 |
| 技能索引 | `AGENTS.md` | 54个AI Agent技能 |
| 交接文档 | `docs/handoff.md` | 已完成/待办事项 |
| 系统配置 | `docs/SYSTEM-CONFIGURATION.md` | 详细配置参数 |
| Docker部署 | `docs/DOCKER-DEPLOYMENT-GUIDE.md` | Docker操作手册 |
| 商业架构V2 | `docs/KSC-AIBOX-COMMERCIAL-ARCHITECTURE-V2.md` | V2设计文档 |
| AI工具历史 | `docs/AI-TOOLS-WORK-ALIGNMENT-REPORT.md` | 工具工作历史 |
| 技能经验 | `docs/SKILL.md` | 踩坑/排错经验 |
| Codex规则 | `CODEX-RULES.md` | Codex专用规则文档 |

---

## ⚠️ 重要提醒

1. **启动时必须读取协同指挥文档** — 这是获取最新状态的唯一途径
2. **操作后必须更新协同指挥文档** — 保持状态同步，避免信息断层
3. **遇到阻塞立即登记问题** — 让其他Agent知道需要协助
4. **遵循项目编码规范** — YAML 2空格缩进，Bash遵循.editorconfig
5. **不提交敏感信息** — API Keys、密码等绝不提交Git

---

**最后更新**: 2026-04-10  
**维护**: 所有参与Agent共同维护  
**版本**: 1.0

---

*🤖 多Agent协同，高效交付！*
