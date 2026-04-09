# 系统优化执行记录

**执行日期**: 2026-04-09  
**执行人**: AI Agent (Qwen Code)  
**服务器**: 10.212.128.192 (ksc-aibox-node01)  
**Playbook**: `ansible/playbooks/06-system-fixes.yml`

---

## 执行摘要

| 项目 | 状态 | 变更内容 |
|------|------|----------|
| Python 环境修复 | ✅ 完成 | numpy/decorator/attrs/psutil/tornado/grpcio/protobuf/scipy |
| CANN te 模块 | ✅ 可用 | 导入成功，topi 因版本特性不可用 |
| THP 调整 | ✅ 完成 | always → madvise，持久化到 rc.local |
| tuned 安装 | ✅ 完成 | 2.24.1, throughput-performance |
| SELinux 调整 | ✅ 完成 | Enforcing → Permissive |
| Ansible 版本 | ✅ 完成 | all.yml npu_driver_version 25.2.3→25.5.1 |
| NPU 固件 | ⚠️ 待冷启动 | 7.8.0.6.201 已安装，运行版本仍为 7.7.0.10.220 |
| 内存分析 | ✅ 完成 | 确认为 HugePages 预留非真实消耗 |
| AI Agent Skills | ✅ 完成 | 54 个技能部署完成 |

---

## 详细变更记录

### 1. Python 环境

```bash
# 安装前
ModuleNotFoundError: No module named 'numpy'
CANN te: 失败

# 安装后
pip3 install numpy decorator attrs psutil tornado grpcio protobuf scipy sympy

# 验证
python3 -c "import te; print('CANN te: OK')"
# CANN te: OK ✅
```

### 2. Transparent HugePages

```bash
# 变更前
cat /sys/kernel/mm/transparent_hugepage/enabled
# [always] madvise never

# 执行
echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
echo "echo madvise > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.d/rc.local

# 变更后
cat /sys/kernel/mm/transparent_hugepage/enabled
# always [madvise] never
```

### 3. tuned 性能配置

```bash
# 安装前
tuned 未安装

# 安装
dnf install tuned -y
systemctl enable --now tuned
tuned-adm profile throughput-performance

# 验证
tuned-adm active
# Current active profile: throughput-performance
```

### 4. SELinux

```bash
# 变更前
getenforce
# Enforcing

# 执行
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# 变更后
getenforce
# Permissive
```

### 5. Ansible 配置版本

```yaml
# 文件: ansible/group_vars/all.yml
# 变更前
npu_driver_version: "25.2.3"

# 变更后
npu_driver_version: "25.5.1"
npu_firmware_version: "7.8.0.6.201"
cann_version: "9.0.0-beta.2"
```

### 6. NPU 固件

```bash
# 升级前
npu-smi info -t board -i 1 | grep Firmware
# Firmware Version: 7.7.0.10.220

# 执行
scp drivers/Ascend-hdk-910b-npu-firmware_7.8.0.6.201.run root@10.212.128.192:/root/
ssh root@10.212.128.192 "/root/Ascend-hdk-910b-npu-firmware_7.8.0.6.201.run --full"

# 激活状态 (upgrade-tool 确认)
/usr/local/Ascend/driver/tools/upgrade-tool --device_index -1 --component -1 --version
# Get component version(7.8.0.6.201) succeed

# 运行版本 (需冷启动)
npu-smi info -t board -i 1 | grep Firmware
# Firmware Version: 7.7.0.10.220 (待冷启动切换)
```

### 7. 内存分析

```bash
# 分析前 (free -h 显示)
total: 250Gi | used: 246Gi | free: 2.0Gi | available: 3.7Gi

# 发现
HugePages_Total: 122880 × 2MB = 240GB (预留给 NPU，不是真实消耗)
实际可用: MemAvailable ≈ 3.7GB

# Page Cache 清理后
free -h
# total: 250Gi | used: 245Gi | free: 6.5Gi | available: 4.7Gi
```

---

## 回滚指南

### Python 环境
```bash
pip3 uninstall numpy decorator attrs psutil tornado grpcio protobuf scipy sympy -y
```

### THP
```bash
echo always > /sys/kernel/mm/transparent_hugepage/enabled
# 从 rc.local 删除对应行
```

### tuned
```bash
dnf remove tuned -y
systemctl disable --now tuned
```

### SELinux
```bash
setenforce 1
sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
```

### Ansible 配置
```bash
cd ansible/group_vars
git checkout all.yml
```

### NPU 固件
```bash
# 固件降级 (需要旧版固件包)
npu-smi upgrade -t mcu -i 0 -f <old_firmware.hpm>
npu-smi upgrade -a mcu -i 0
reboot
```

---

## 相关文件

| 文件 | 用途 |
|------|------|
| `docs/SYSTEM-HEALTH-REPORT.md` | 完整体检报告 (12 章节) |
| `ansible/playbooks/06-system-fixes.yml` | 自动化修复 Playbook |
| `ansible/group_vars/all.yml` | 版本配置 (已统一) |
| `docs/handoff.md` | 交接文档 (已更新) |

---

*最后更新: 2026-04-09*
