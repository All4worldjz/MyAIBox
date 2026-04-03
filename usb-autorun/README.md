# KSC AIBox U盘自动执行方案

## 概述

本方案提供系统恢复后自动检测并执行必要操作的能力，支持 **Shell脚本** 和 **Ansible Playbook** 两种执行格式。

## 文件结构

```
usb-autorun/
├── autorun.sh              # 主启动脚本（检测U盘并自动执行）
├── recovery-shell.sh       # 纯Shell版本恢复脚本
├── recovery-ansible.yml    # Ansible版本恢复Playbook
├── recovery-config.yml     # 配置文件
└── README.md               # 使用说明
```

## 使用方法

### 方法一：U盘自动执行

1. **准备U盘**
   - 将整个 `usb-autorun` 目录复制到U盘根目录
   - 将U盘标签设置为 `KSC_AUTO` 或 `KSC_AIBOX_AUTORUN`

2. **系统恢复后执行**
   ```bash
   # 插入U盘后，以root用户执行
   /mnt/usb/usb-autorun/autorun.sh
   ```

3. **自动检测**
   - 脚本会自动检测标记的U盘
   - 自动挂载并执行恢复操作
   - 完成后创建标记文件 `/ksc_aibox/.autorun_completed`

### 方法二：直接执行Shell脚本

```bash
# 以root用户执行
bash recovery-shell.sh --root /ksc_aibox --backup /backup --steps all

# 可选参数
--root      应用根目录 (默认: /ksc_aibox)
--backup    备份根目录 (默认: /backup)
--steps     执行步骤 (默认: all)
            可选: dirs,system,npu,docker,scripts,verify
--log       日志文件路径
--help      显示帮助
```

### 方法三：使用Ansible Playbook

```bash
# 创建inventory文件
echo "[aibox]" > inventory
echo "localhost ansible_connection=local" >> inventory

# 执行playbook
ansible-playbook -i inventory recovery-ansible.yml \
    -e "ksc_aibox_root=/ksc_aibox" \
    -e "backup_root=/backup" \
    -e "steps=all"
```

## 执行步骤说明

| 步骤 | 说明 | 执行内容 |
|------|------|----------|
| `dirs` | 创建目录结构 | 创建 `/ksc_aibox` 和 `/backup` 目录结构 |
| `system` | 系统优化 | 主机名、内核参数、资源限制、SSH加固、防火墙 |
| `npu` | NPU配置 | HugePages、设备权限、环境变量、NUMA绑定脚本 |
| `docker` | Docker配置 | daemon.json、数据目录、systemd override |
| `scripts` | 监控脚本 | 健康检查脚本、自愈脚本、systemd服务 |
| `verify` | 验证 | 验证目录、内核参数、服务状态 |

## 配置文件说明

编辑 `recovery-config.yml` 可自定义恢复行为：

```yaml
# 执行模式: shell / ansible / both
exec_mode: shell

# 执行步骤: all 或组合步骤
steps: all

# 目录配置
ksc_aibox_root: /ksc_aibox
backup_root: /backup
```

## 强制重新执行

如果系统已经执行过恢复（存在 `/ksc_aibox/.autorun_completed`），需要强制重新执行：

```bash
# 删除标记文件
rm /ksc_aibox/.autorun_completed

# 或使用 --force 参数
autorun.sh --force
```

## 日志和报告

- **日志文件**: `/var/log/ksc-aibox-autorun.log`
- **执行报告**: `/ksc_aibox/config/AUTORUN_REPORT.md`
- **版本文件**: `/ksc_aibox_ROOT/VERSION`

## 创建的目录结构

### /ksc_aibox 目录

```
/ksc_aibox/
├── apps/
│   ├── ascend/          # Ascend软件栈
│   ├── vllm/            # vLLM推理服务
│   ├── ai-service/      # AI服务应用
│   └── custom/          # 自定义应用
├── data/
│   ├── mysql/           # MySQL数据
│   ├── postgres/        # PostgreSQL数据
│   ├── redis/           # Redis数据
│   ├── milvus/          # Milvus向量库
│   ├── neo4j/           # Neo4j图数据库
│   └── minio/           # MinIO对象存储
├── models/
│   ├── llm/             # 大语言模型
│   ├── embedding/       # 嵌入模型
│   ├── rerank/          # 重排序模型
│   ├── vl/              # 视觉语言模型
│   └── mineru/          # MinerU模型
├── k3s/
│   ├── data/            # K3s数据目录
│   ├── storage/         # 本地存储
│   ├── manifests/       # 部署清单
│   ├── helm/            # Helm charts
│   └── kubeconfig/      # kubeconfig文件
├── docker/
│   ├── data/            # Docker数据目录
│   ├── compose/         # compose文件
│   ├── config/          # 配置文件
│   └── scripts/         # Docker脚本
├── logs/                # 日志目录
├── scripts/
│   ├── install/         # 安装脚本
│   ├── backup/          # 备份脚本
│   ├── restore/         # 恢复脚本
│   ├── monitor/         # 监控脚本
│   └── maintenance/     # 维护脚本
├── config/
│   ├── ansible/         # Ansible配置
│   ├── env/             # 环境变量
│   ├── secrets/         # 密钥文件
│   └── systemd/         # systemd配置
└── tmp/                 # 临时文件
```

### /backup 目录

```
/backup/
├── system/
│   ├── root_fs/         # 根文件系统备份
│   ├── config/          # 系统配置备份
│   └── packages/        # 软件包列表
├── application/
│   ├── ksc_aibox/       # 应用备份
│   ├── databases/       # 数据库备份
│   ├── models/          # 模型备份
│   └── docker/          # Docker备份
├── archive/
│   ├── monthly/         # 月度归档
│   └── yearly/          # 年度归档
└── logs/                # 备份日志
```

## 创建的systemd服务

| 服务 | 说明 | 定时执行 |
|------|------|----------|
| `ksc-aibox-health-check.timer` | 系统健康检查 | 每5分钟 |
| `ksc-aibox-self-healing.timer` | 自愈检查 | 每10分钟 |

## 验证恢复结果

```bash
# 检查目录结构
ls -la /ksc_aibox
ls -la /backup

# 检查内核参数
sysctl net.core.somaxconn vm.max_map_count

# 检查HugePages
grep HugePages /proc/meminfo

# 检查Docker
docker info | grep "Docker Root Dir"

# 检查NPU
npu-smi info -l

# 检查定时器
systemctl list-timers | grep ksc-aibox

# 查看版本信息
cat /ksc_aibox/VERSION
```

## 注意事项

1. **必须以root用户执行**
2. **执行前确保磁盘空间充足**（至少10GB）
3. **首次执行后会创建标记文件，防止重复执行**
4. **部分优化需要重启后完全生效**（如HugePages）
5. **NPU配置需要昇腾驱动已安装**

## 故障排查

```bash
# 查看日志
tail -100 /var/log/ksc-aibox-autorun.log

# 查看健康状态
cat /ksc_aibox/config/system-status.json

# 手动执行健康检查
/ksc_aibox/scripts/monitor/system-health-check.sh

# 手动执行自愈
/ksc_aibox/scripts/maintenance/self-healing.sh

# 快速恢复
/ksc_aibox/scripts/maintenance/quick-recovery.sh
```

## 版本信息

- 版本: 1.0.0
- 创建时间: 2026-04-03
- 适用系统: openEuler 24.03 LTS SP1/SP3
- 硬件平台: 华为鲲鹏920 + 昇腾910B4