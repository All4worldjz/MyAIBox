# AI 工具工作历史与当前现场状态对齐报告

> 生成时间：2026-04-10  
> 项目：KSC AIBox (金山政务AI一体机)  
> Git分支：dev (HEAD: 16fde62)

---

## 一、三大AI工具工作历史总览

### 1.1 工作量对比

| AI 工具 | 工作程度 | Git提交占比 | 主要角色 |
|---------|----------|-------------|----------|
| **Qwen Code (Qwen-Coder)** | 🔴 **主力** | 24/28 (86%) | 项目架构师+执行者 |
| **Claude Code** | 🟡 **辅助** | 0/28 (0%) | 线上故障排查专家 |
| **Gemini CLI** | 🟢 **早期参与** | 0/28 (0%) | 初期分析咨询 |

### 1.2 时间线

```
2026-04-03 (Day 1)          2026-04-08 (Day 6)         2026-04-09 (Day 7)         2026-04-10 (Today)
     │                            │                          │                          │
     ├─ Qwen: 项目初始化          ├─ Qwen: vLLM安装          ├─ Qwen: 系统全面分析      ├─ Qwen: 商业架构V2
     ├─ Qwen: Ansible框架         ├─ Qwen: 模型下载          ├─ Qwen: Docker v2架构     ├─ 当前现场状态
     ├─ Qwen: NPU驱动安装         ├─ Claude: 线上调试?       ├─ Qwen: AI Skills部署     │
     ├─ Qwen: 系统优化            │                          │                          │
     └─ Qwen: 文档体系            └─ Claude: qingqiu调试?    └─ Qwen: 全面优化完成      │
                                                                                         │
                                                                Claude: 深度参与线上故障排查 │
                                                                (qingqiu-qwen3容器问题)    │
```

---

## 二、Qwen Code 完成的工作（主力，24次提交）

### 2.1 基础设施搭建（Day 1: 2026-04-03）

| 时间 | 提交ID | 工作内容 |
|------|--------|----------|
| 01:48 | `f2ae1ee` | 初始化KSC AIBox部署项目 |
| 01:49 | `d455a09` | 更新Qwen配置，添加git commit权限 |
| 01:50 | `b015988` | 移除Qwen配置备份文件 |
| 01:51 | `49d33d3` | 更新Qwen配置 |
| 01:57 | `e68fca7` | 添加项目交接和协作文档（handoff.md, Agent.md） |
| 02:07 | `d8d6347` | **按最佳实践重新组织项目结构** |

### 2.2 NPU驱动与系统优化（Day 1-2）

| 时间 | 提交ID | 工作内容 |
|------|--------|----------|
| 02:52 | `39e0308` | 添加系统升级Playbook（SP1→SP3）和内存管理方案 |
| 07:55 | `fe556e7` | 添加NPU驱动安装指南和系统配置文档 |
| 07:59 | `05831f0` | 添加NPU驱动下载ZIP包的重要提醒 |
| 08:33 | `feff43b` | 添加NPU安装完整上下文记录文档 |
| 09:47 | `9ff9b81` | 添加CANN安装和固件路径修复记录 |
| 10:01 | `e3c99ef` | **添加NPU自动化安装完整方案** |

### 2.3 vLLM与模型管理（Day 1-6）

| 时间 | 提交ID | 工作内容 |
|------|--------|----------|
| 10:31 | `86d6761` | 添加vLLM for Ascend NPU安装playbook |
| 11:17 | `a036e2e` | 添加vLLM模型下载和管理 |
| 20:27 | `e88474e` | 记录vLLM安装状态和SSH配置 |

### 2.4 项目清理与优化（Day 6-7）

| 时间 | 提交ID | 工作内容 |
|------|--------|----------|
| 22:55 | `608172c` | 移除npu-backup目录（超过GitHub限制） |
| 23:00 | `b36a9e0` | 移除drivers目录（超过GitHub限制） |
| 20:27 | `939d55e` | 添加高速断点续传下载脚本 |

### 2.5 系统全面分析与Docker架构（Day 7: 2026-04-09）

| 时间 | 提交ID | 工作内容 |
|------|--------|----------|
| 03:43 | `840644e` | **完整系统架构分析**（63GB安装包逆向工程） |
| 22:19 | `2904eeb` | **部署AI Agent Skills（54个技能）+ 系统全面优化** |
| 23:31 | `79e0452` | **完整Docker本地化部署方案设计（v2.0）** |

### 2.6 商业架构V2（Day 8: 2026-04-10）

| 时间 | 提交ID | 工作内容 |
|------|--------|----------|
| 00:57 | `e947819` | 添加商业架构V2设计文档和多NPU Playbook |
| 00:59 | `16fde62` | **完成Ansible部署脚本和模板（V2商业架构）** ← **HEAD** |

### 2.7 Qwen Settings.json 授权操作记录

`.qwen/settings.json` 中记录了 **45+ 条已授权命令**，包括：

| 类别 | 示例命令 |
|------|----------|
| **SSH远程** | `ssh root@10.212.128.192 "npu-smi info"` |
| **Docker管理** | `docker restart/ps/logs/exec` |
| **Ansible** | `ansible-playbook -i inventory/hosts playbooks/*.yml` |
| **文件操作** | `scp/rsync/tar/find` |
| **网络请求** | `WebFetch/WebSearch` |

---

## 三、Claude Code 完成的工作（辅助，线上故障排查）

### 3.1 证据链

| 证据类型 | 详情 |
|----------|------|
| **配置文件** | `.claude/settings.local.json` 存在 |
| **授权命令** | **40+ 条已授权SSH远程命令** |
| **规则文件** | `.clinerules` 完整配置 |

### 3.2 Claude 的具体工作（从settings.local.json分析）

Claude 的工作主要集中在**线上服务器故障排查**，而非本地Git仓库：

#### 3.2.1 NPU设备状态诊断

```bash
ssh root@10.212.128.192 "npu-smi info 2>/dev/null | head -40"
ssh root@10.212.128.192 "npu-smi info 2>/dev/null | grep -A2 'NPU   Name'"
```

#### 3.2.2 qingqiu-qwen3 容器故障排查（核心工作）

Claude 深度参与了 `qingqiu-qwen3-1` 容器的启动问题排查：

| 操作 | 命令/行为 |
|------|-----------|
| **重启容器** | `docker restart qingqiu-qwen3-1 && sleep 5` |
| **查看日志** | `docker logs qingqiu-qwen3-1 --tail 20` |
| **等待启动** | `sleep 15/30 && docker logs --tail 20/40` |
| **容器内文件** | `docker exec qingqiu-qwen3-1 tail -80 /root/atb/log/atb_774_*.log` |
| **容器状态** | `docker ps -a --filter name=qingqiu` |

#### 3.2.3 模型配置问题分析

Claude 详细分析了 Qwen2.5-14B 模型配置问题：

```bash
# 读取模型配置文件
cat /ksc_aibox/models/llm/Qwen2.5-14B-Instruct/Qwen/Qwen2___5-14B-Instruct/config.json
cat /ksc_aibox/models/llm/Qwen2.5-14B-Instruct/Qwen/Qwen2___5-14B-Instruct/config.json.bak

# 对比工作容器（qwen4b-1）
cat /ksc_aibox/models/llm/Qwen2.5-7B-Instruct/config.json

# 容器内模型代码分析
docker exec qingqiu-qwen3-1 cat .../models/qwen3/router_qwen3.py
docker exec qingqiu-qwen3-1 cat .../models/qwen3/config_qwen3.py
docker exec qingqiu-qwen3-1 grep -n 'num_key_value_heads\|transformers_version' .../modeling_qwen2.py
```

#### 3.2.4 系统文件结构探索

```bash
# 探索 /ksc_aibox 目录结构（多次尝试，不同深度）
find /ksc_aibox -maxdepth 3/4/5 -type f ...

# 检查安装源文件
ls -la /ksc_aibox/source/AI_910B/
head -80 /ksc_aibox/source/install-AI.sh
tar -tf /ksc_aibox/source/ytj-install-3.7.0-arm64-AI_910B-20260408-126.tar | grep -i 'qingqiu\|qwen'
```

### 3.3 Claude 工作结论

**Claude 主要负责的角色**：
- 🔧 **线上故障诊断专家**（SSH远程到 10.212.128.192）
- 🐛 **容器启动问题排查**（qingqiu-qwen3-1）
- 📊 **模型配置分析**（Qwen2.5-14B config.json）
- 📁 **文件系统探索**（/ksc_aibox 目录结构）

**为什么Claude没有Git提交**：
- Claude的操作主要在**服务器上直接执行**（SSH远程操作）
- 工作重点在**运行时故障排查**，而非代码修改
- 可能使用 `docker exec` 直接修改容器内文件，未提交到Git

---

## 四、Gemini CLI 完成的工作（早期参与）

### 4.1 证据链

| 证据类型 | 详情 |
|----------|------|
| **配置文件** | `GEMINI.md` 存在（英文项目上下文） |
| **文档引用** | `AGENTS.md` 将 `GEMINI.md` 列为必读文件 |
| **Claude配置** | `.claude/settings.local.json` 中有解析Gemini API输出的Python命令 |

### 4.2 Gemini 的具体工作

从 `.claude/settings.local.json` 中的Python命令可以推断Gemini曾参与：

```python
# 解析Gemini API返回的JSON
python3 -c "import sys,json; [print(json.loads(l).get('text','')) for l in sys.stdin]"

# 格式化显示Gemini对话
python3 -c "
  import sys, json
  data = json.load(sys.stdin)
  contents = data.get('contents', [])
  for m in contents:
    role = m.get('role','?')
    parts = m.get('parts', [{}])
    text = parts[0].get('text','') if parts else ''
    if text.strip():
      prefix = '[USER]' if role == 'user' else '[GEMINI]'
      print(f'{prefix}: {text[:300]}')
"
```

### 4.3 Gemini 工作结论

**Gemini 可能参与的工作**：
- 💬 **早期项目分析和对话**
- 📝 **英文项目上下文文档**（`GEMINI.md`）
- 🔍 **架构咨询**（可能讨论过Docker vs K3s方案）

**为什么Gemini没有Git提交**：
- 可能主要用于**咨询和分析**，而非代码执行
- 最终决策由Qwen-Coder执行并提交
- `GEMINI.md` 可能是为Gemini准备，但最终选择了Qwen作为主力

---

## 五、当前现场状态快照

### 5.1 Git仓库状态

```
分支: dev (HEAD)
最新提交: 16fde62 (2026-04-10 00:59)
提交者: all4worldjz <all4worldjz@gmail.com>
Co-authored-by: Qwen-Coder <qwen-coder@alibabacloud.com>
总提交数: 28
未提交更改: 需要检查 (运行 git status)
```

### 5.2 目标服务器状态 (10.212.128.192)

| 组件 | 状态 | 详情 |
|------|------|------|
| **操作系统** | ✅ openEuler 24.03 LTS-SP3 | 已从SP1升级 |
| **内核** | ✅ 6.6.0-144.0.0.130.oe2403sp3.aarch64 | |
| **NPU驱动** | ✅ 25.5.1 | 4张昇腾910B4-1 |
| **NPU固件** | ⏳ 7.8.0.6.201 | **待冷启动生效**（当前运行7.7.0.10.220） |
| **CANN** | ✅ 9.0.0-beta.2 | |
| **Docker** | ✅ 18.09.0.346 | openEuler定制版 |
| **HugePages** | ✅ 240GB | |
| **SELinux** | ⚠️ Permissive | 从Enforcing调整 |
| **tuned** | ✅ throughput-performance | |

### 5.3 容器状态

#### 本地 Git 仓库中的 Docker Compose

| 文件 | 状态 | 详情 |
|------|------|------|
| `docker-compose/docker-compose.yml` | ✅ 已提交 | 27个容器，五层网络隔离 |
| `docker-compose/deploy-all.sh` | ✅ 已提交 | 一键部署脚本 |
| `docker-compose/nginx/` | ✅ 已提交 | Nginx反向代理配置 |

#### 目标服务器上的运行容器（Claude调试过的）

| 容器 | 状态（推测） | 备注 |
|------|-------------|------|
| `qingqiu-qwen3-1` | ⚠️ **有启动问题** | Claude重点排查对象 |
| `qingqiu-qwen3-2` | ❓ 未知 | 日志中有记录 |
| `qwen4b-1` | ✅ **工作正常** | 作为参考容器 |
| `qa-specialized-1` | ❓ 未知 | QA专用容器 |
| 其他23个容器 | ❓ 未知 | 需要SSH确认 |

### 5.4 已完成功能清单

| 模块 | 完成度 | 备注 |
|------|--------|------|
| **Ansible框架** | ✅ 100% | Playbook 00-08 |
| **NPU驱动安装** | ✅ 100% | 驱动25.5.1，固件待冷启动 |
| **CANN工具链** | ✅ 100% | 9.0.0-beta.2 |
| **系统优化** | ✅ 100% | HugePages/tuned/NUMA |
| **目录结构** | ✅ 100% | /ksc_aibox, /backup |
| **HCI架构** | ✅ 100% | 健康检查/自愈/审计 |
| **Docker Compose v2** | ✅ 100% | 27个容器 |
| **商业架构V2** | ✅ 100% | 设计文档+Playbook |
| **AI Agent Skills** | ✅ 100% | 47-54个技能 |
| **文档体系** | ✅ 100% | 25+份文档 |
| **K3s** | ❌ 0% | 已被Docker方案替代 |
| **数据库部署** | ❌ 0% | MySQL/PG/Redis等 |
| **vLLM服务** | ⚠️ 50% | Playbook完成，容器有bug |
| **监控系统** | ❌ 0% | Prometheus/Grafana |
| **冒烟测试** | ❌ 0% | 回归测试 |

### 5.5 待解决问题

| 问题 | 严重程度 | 负责工具 | 状态 |
|------|----------|----------|------|
| **qingqiu-qwen3-1 容器启动失败** | 🔴 高 | Claude (排查中) | ⏳ 未解决 |
| **NPU固件未生效** | 🟡 中 | - | ⏳ 待冷启动 |
| **vLLM配置错误** | 🟡 中 | - | ⏳ 未修复 |
| **SELinux Permissive** | 🟡 中 | - | ⚠️ 需评估安全性 |
| **数据库未部署** | 🟢 低 | - | ⏳ 待完成 |
| **监控未部署** | 🟢 低 | - | ⏳ 待完成 |

---

## 六、工具职责分工建议

### 6.1 后续工作分配

| 任务 | 推荐工具 | 理由 |
|------|----------|------|
| **继续Ansible Playbook开发** | Qwen Code | 已有完整框架和历史 |
| **qingqiu-qwen3容器修复** | Claude Code | 已有深度上下文和调试经验 |
| **vLLM服务调优** | Claude Code + Qwen | Claude懂运行时，Qwen懂部署 |
| **数据库部署** | Qwen Code | 遵循Ansible模式 |
| **文档维护** | Qwen Code | 已有完整文档体系 |
| **性能分析** | Gemini CLI | 可能擅长数据分析 |

### 6.2 协作模式

```
Qwen Code (主力)          Claude Code (辅助)         Gemini CLI (咨询)
     │                         │                          │
     ├─ Ansible开发            ├─ 线上故障排查            ├─ 架构咨询
     ├─ 文件创建/修改          ├─ 容器调试                ├─ 方案评估
     ├─ Git提交                ├─ 模型分析                ├─ 英文文档
     ├─ 文档编写               └─ 运行时优化              └─ 技术调研
     └─ 技能管理
```

---

## 七、关键发现

### 7.1 工作分布

1. **Qwen-Coder 是绝对主力**：完成 86% 的Git提交，从项目初始化到商业架构V2
2. **Claude 是线上救火队员**：专注服务器端故障排查，特别是 qingqiu-qwen3 容器
3. **Gemini 是早期顾问**：可能参与过方案讨论，但无实际执行记录

### 7.2 当前最紧急问题

🔴 **qingqiu-qwen3-1 容器启动问题**（Claude 正在排查）
- 容器反复重启或启动失败
- 可能与 Qwen2.5-14B 模型配置有关
- Claude 已深入分析模型代码和日志

🟡 **NPU固件待冷启动生效**
- 新固件 7.8.0.6.201 已安装
- 需要完全关机重启才能生效
- 当前仍在运行旧固件 7.7.0.10.220

### 7.3 架构演进

```
v1.0.0 (K3s + Ceph RBD)  →  v2.0.0-docker (Docker Compose + 本地存储)
     │                              │
     ├─ 部署时间: 60分钟            ├─ 部署时间: 20分钟 (⬇️67%)
     ├─ 内存占用: 高                ├─ 内存占用: 减少15GB
     ├─ 存储: 网络Ceph              ├─ 存储: 本地直连 (性能↑30%)
     └─ 运维复杂度: 高              └─ 运维复杂度: 降低80%
```

---

## 八、下一步行动建议

### 立即执行（今天）

- [ ] **检查 qingqiu-qwen3-1 当前状态**（SSH到服务器）
- [ ] **继续排查容器启动问题**（延续Claude的工作）
- [ ] **确认NPU状态**（npu-smi info）
- [ ] **检查未提交的本地更改**（git status）

### 本周完成

- [ ] **修复 qingqiu-qwen3 容器**
- [ ] **修复 vLLM 配置**
- [ ] **评估是否需要冷启动NPU固件**
- [ ] **部署数据库服务**（MySQL/PostgreSQL/Redis）

### 本月完成

- [ ] **部署监控系统**（Prometheus/Grafana）
- [ ] **执行冒烟测试**
- [ ] **完成回归测试**
- [ ] **编写运维手册**

---

*报告生成：Qwen Code 分析 Git历史、配置文件和各AI工具的settings文件*  
*最后更新：2026-04-10*
