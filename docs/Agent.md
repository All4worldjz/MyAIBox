# AI Agent 协作指南 (Agent Collaboration Guide)

> 本文档指导如何使用Qwen Code或其他AI Coding工具与人类工程师协作，完成一体机的初始化安装和配置。

## 概述

本文档定义了AI Agent在KSC AIBox项目中的角色、职责和工作流程，确保AI与人类工程师高效协作。

## AI Agent 角色定义

### 核心能力

| 能力 | 描述 |
|------|------|
| **系统分析** | 分析服务器硬件、软件、网络配置 |
| **自动化部署** | 使用Ansible自动化部署和配置 |
| **故障诊断** | 识别问题根因并提供解决方案 |
| **文档生成** | 自动生成配置文档和交接文档 |
| **最佳实践** | 应用鲲鹏/欧拉/昇腾最佳实践 |

### 工作模式

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Agent 工作流程                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 接收任务 ──→ 2. 分析环境 ──→ 3. 制定计划                │
│       │              │              │                       │
│       ↓              ↓              ↓                       │
│  人类确认 ←── 4. 展示方案 ←── 收集信息                       │
│       │                                                    │
│       ↓                                                    │
│  5. 执行任务 ──→ 6. 验证结果 ──→ 7. 生成报告                │
│       │              │              │                       │
│       └──────────────┴──────────────┘                       │
│                      │                                      │
│                      ↓                                      │
│               8. 提交Git记录                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 项目上下文加载

### 必读文件

AI Agent在开始工作前，应首先阅读以下文件以加载项目上下文：

```
1. README.md           # 项目概述和结构
2. docs/handoff.md     # 项目交接文档
3. docs/SKILL.md       # 技能和经验文档
4. VERSION             # 当前版本信息
5. ansible/group_vars/all.yml  # 全局配置变量
```

### 环境信息获取命令

```bash
# 服务器连接
ssh root@10.212.128.192

# 系统信息
hostnamectl status
cat /etc/os-release
uname -a

# 硬件信息
lscpu
free -h
lspci | grep -i huawei
npu-smi info -l

# 服务状态
systemctl list-units --type=service --state=running
docker ps -a

# 存储状态
lsblk
df -h
```

## 任务执行规范

### 1. 任务接收

当人类工程师提出任务时，AI Agent应：

1. **理解需求**: 明确任务目标和范围
2. **评估风险**: 识别潜在风险和影响
3. **确认优先级**: 确定任务优先级
4. **制定计划**: 分解任务为可执行步骤

### 2. 计划展示

在执行任何修改操作前，AI Agent必须：

1. **展示计划**: 清晰说明将要执行的操作
2. **说明影响**: 解释操作对系统的影响
3. **等待确认**: 获得人类工程师确认后再执行

示例：
```
我计划执行以下操作：
1. 安装K3s容器编排平台
2. 配置K3s使用/ksc_aibox/k3s数据目录
3. 开放6443端口

影响：
- 需要重启Docker服务
- 将占用约2GB内存
- 开放6443端口可能带来安全风险

是否继续？
```

### 3. 执行规范

#### Ansible Playbook执行

```bash
# 标准执行流程
cd /Users/whoami2028/Workshop/GITREPO/MyAIBox/ansible

# 检查语法
/Library/Frameworks/Python.framework/Versions/3.11/bin/ansible-playbook -i inventory/hosts playbooks/<name>.yml --syntax-check

# 执行 (详细输出)
/Library/Frameworks/Python.framework/Versions/3.11/bin/ansible-playbook -i inventory/hosts playbooks/<name>.yml -v

# 执行 (检查模式，不实际修改)
/Library/Frameworks/Python.framework/Versions/3.11/bin/ansible-playbook -i inventory/hosts playbooks/<name>.yml --check
```

#### 远程命令执行

```bash
# 使用SSH执行远程命令
ssh root@10.212.128.192 "command"

# 执行多行命令
ssh root@10.212.128.192 "echo 'line1' && echo 'line2'"

# 传输文件
scp local_file root@10.212.128.192:/remote/path/
```

### 4. 验证规范

每个任务执行后，AI Agent必须验证：

1. **服务状态**: 确认服务正常运行
2. **配置生效**: 确认配置已应用
3. **功能测试**: 执行基本功能测试
4. **日志检查**: 检查是否有错误日志

### 5. 文档更新

任务完成后，AI Agent应更新：

1. **Git提交**: 提交所有修改到dev分支
2. **handoff.md**: 更新项目状态
3. **SKILL.md**: 记录新学到的经验

## 协作模式

### 模式1: 主动执行

适用于：低风险、标准化任务

```
AI Agent: 我检测到系统有可更新的软件包，建议执行更新。
         预计影响：重启部分服务，耗时约5分钟。
         是否执行？

人类: 执行

AI Agent: [执行更新...]
         更新完成，已更新3个软件包。
```

### 模式2: 建议确认

适用于：中风险、需要决策的任务

```
AI Agent: 我发现vLLM容器配置错误，设备davinci4不存在。
         建议方案：
         A. 重建容器，使用davinci0-3
         B. 修改现有容器配置
         C. 暂不处理
         
         推荐方案A，是否采用？

人类: 采用方案A

AI Agent: [执行方案A...]
         容器已重建，状态正常。
```

### 模式3: 请求指导

适用于：高风险、不确定的任务

```
AI Agent: 我需要安装K3s，但发现以下问题：
         1. SELinux可能阻止部分操作
         2. 需要确认是否使用内网镜像仓库
         
         请提供指导：
         - SELinux策略如何处理？
         - 是否有内网镜像仓库地址？

人类: [提供指导...]

AI Agent: 收到，将按照指导执行...
```

## 错误处理

### 错误分类

| 级别 | 描述 | 处理方式 |
|------|------|----------|
| **INFO** | 信息提示 | 记录日志，继续执行 |
| **WARN** | 警告 | 提示用户，等待确认 |
| **ERROR** | 错误 | 停止执行，报告错误 |
| **FATAL** | 严重错误 | 回滚操作，请求人工介入 |

### 错误恢复流程

```
1. 记录错误详情
2. 分析错误原因
3. 提供解决方案
4. 等待人类确认
5. 执行恢复操作
6. 验证恢复结果
```

### 常见错误处理

#### SSH连接失败

```bash
# 检查网络
ping 10.212.128.192

# 检查SSH服务
ssh -v root@10.212.128.192

# 检查防火墙
ssh root@10.212.128.192 "firewall-cmd --list-all"
```

#### Ansible执行失败

```bash
# 检查主机连通性
ansible all -i inventory/hosts -m ping

# 检查Python版本
ansible all -i inventory/hosts -m setup -a "filter=ansible_python_version"

# 详细错误输出
ansible-playbook -i inventory/hosts playbooks/<name>.yml -vvv
```

#### NPU设备不可用

```bash
# 检查驱动
cat /usr/local/Ascend/version.info

# 检查设备
ls -la /dev/davinci*

# 检查NPU状态
npu-smi info -l
```

## 安全规范

### 敏感信息处理

1. **不记录密码**: 不要在日志、文档中记录密码
2. **使用变量**: 敏感配置使用Ansible Vault或环境变量
3. **权限控制**: 确保配置文件权限正确

### 操作审计

所有修改操作都会被审计系统记录：

```bash
# 查看审计日志
ausearch -k config_modify | tail -20

# 查看NPU访问日志
ausearch -k npu_access | tail -20
```

## Git工作流

### 提交规范

```
feat: 新功能
fix: 修复bug
docs: 文档更新
chore: 维护性工作
refactor: 重构
test: 测试相关
```

### 提交示例

```bash
git add -A
git commit -m "feat: 添加K3s安装Playbook

- 安装K3s v1.28.x
- 配置数据目录到/ksc_aibox/k3s
- 开放6443 API端口
- 配置镜像仓库"

git log --oneline -n 3
```

## 质量检查清单

### 任务完成前检查

- [ ] 所有步骤已执行
- [ ] 服务状态正常
- [ ] 配置已生效
- [ ] 日志无错误
- [ ] 文档已更新
- [ ] Git已提交

### Playbook质量检查

- [ ] 语法检查通过
- [ ] 幂等性验证
- [ ] 错误处理完善
- [ ] 注释清晰
- [ ] 变量使用合理

## 持续改进

### 经验记录

每次遇到新问题或学到新知识，应更新SKILL.md：

```markdown
## 新经验标题

### 问题描述
[描述遇到的问题]

### 解决方案
[描述解决方案]

### 经验总结
[总结经验教训]
```

### 文档维护

定期更新以下文档：

- handoff.md: 项目状态变化时
- SKILL.md: 获得新经验时
- README.md: 项目结构变化时

---

## 附录: 常用命令速查

### 系统管理

```bash
# 服务管理
systemctl start|stop|restart|status <service>
systemctl enable|disable <service>

# 日志查看
journalctl -u <service> -f
journalctl -p err --no-pager -n 20

# 进程管理
ps aux | grep <name>
kill -9 <pid>
```

### Docker管理

```bash
# 容器管理
docker ps -a
docker start|stop|rm <container>
docker logs <container> -f

# 镜像管理
docker images
docker rmi <image>
docker pull <image>

# 资源清理
docker system prune -f
```

### NPU管理

```bash
# NPU状态
npu-smi info -l
npu-smi info -t health -i 0 -c 0
npu-smi info -t memory -i 0 -c 0

# NPU拓扑
npu-smi info -t topo
```

### 网络管理

```bash
# 防火墙
firewall-cmd --list-all
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --reload

# 网络
ip addr show
ip route show
ss -tlnp
```

---

*本文档由Qwen Code生成，最后更新: 2026-04-03*