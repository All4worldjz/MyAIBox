# KSC AIBox 系统全面体检报告与改进行动计划

**服务器**: 10.212.128.192 (ksc-aibox-node01)  
**体检日期**: 2026-04-09  
**检查工具**: npu-smi 技能 + 系统全面扫描  
**报告生成**: AI Agent Skills 自动分析

---

## 一、系统总览

| 项目 | 当前配置 | 状态 | 原厂推荐 |
|------|----------|------|----------|
| **操作系统** | openEuler 24.03 LTS-SP3 | ✅ 匹配 | openEuler 24.03 LTS-SP3 |
| **内核版本** | 6.6.0-144.0.0.130.oe2403sp3.aarch64 | ✅ 匹配 | 6.6.0-144+ |
| **CPU** | 鲲鹏920 5220, 64核 (2×32) | ✅ 匹配 | 鲲鹏920 5220 |
| **内存** | 250GB DDR4 | ✅ 匹配 | 256GB |
| **NPU** | 4× Ascend 910B4-1, 64GB HBM | ✅ 匹配 | 昇腾910B4-1 |
| **存储** | Samsung 990 PRO 4TB NVMe | ✅ 匹配 | NVMe SSD |
| **网络** | 华为HNS 6端口 (1×UP) | ✅ 匹配 | GE/10GE/25GE |

---

## 二、驱动与软件版本评估

### 2.1 NPU 驱动

| 项目 | 当前版本 | 原厂推荐 | 评估 |
|------|----------|----------|------|
| **驱动软件** | 25.5.1 | 25.5.1+ | ✅ **最新** |
| **固件版本** | 7.7.0.10.220 | 7.8.0.6.201 | ⚠️ **需升级** |
| **兼容性** | OK | OK | ✅ 正常 |
| **配置一致性** | ⚠️ all.yml=25.2.3, npu_servers.yml=25.5.1 | 统一为 25.5.1 | ❌ **配置不一致** |

### 2.2 CANN 工具链

| 项目 | 当前版本 | 原厂推荐 | 评估 |
|------|----------|----------|------|
| **CANN 版本** | 9.0.0-beta.2 | 9.0.0+ (beta 或 RC) | ⚠️ **Beta 版本** |
| **ATC 工具** | 已安装 | 必备 | ✅ 正常 |
| **Python 包 (te/topi)** | ❌ 导入失败 (缺 numpy) | 必须可用 | ❌ **异常** |

### 2.3 Docker / 容器

| 项目 | 当前版本 | 原厂推荐 | 评估 |
|------|----------|----------|------|
| **Docker** | 18.09.0 (EulerVersion 18.09.0.346) | 20.10+ 或 podman | ⚠️ **过旧** |
| **存储驱动** | overlay2 | overlay2 | ✅ 正常 |
| **Cgroup Driver** | cgroupfs | systemd | ⚠️ **不一致** |
| **Ascend Docker Runtime** | ❌ 未安装 | 必备 | ❌ **缺失** |
| **运行容器** | 0 | 视业务需求 | ℹ️ 空闲 |

### 2.4 Python 环境

| 项目 | 当前状态 | 原厂推荐 | 评估 |
|------|----------|----------|------|
| **Python 版本** | 3.11.6 | 3.11+ | ✅ 正常 |
| **torch** | 2.1.0 | 2.1.0+ (Ascend 适配版) | ⚠️ 需确认是否为 npu 版 |
| **torch_npu** | ❌ 未安装 | 必备 | ❌ **缺失** |
| **numpy** | ❌ 未安装 | 必备 | ❌ **缺失** |
| **CANN te/topi** | ❌ 导入失败 | 必须可用 | ❌ **异常** |
| **Conda** | ❌ 未安装 | 推荐 | ⚠️ 缺失 |

---

## 三、系统配置评估

### 3.1 内核参数

| 参数 | 当前值 | 原厂推荐 | 评估 |
|------|--------|----------|------|
| **vm.nr_hugepages** | 122,880 (240GB) | 122,880 (240GB) | ✅ **完美** |
| **vm.nr_hugepages_mempolicy** | 122,880 | 122,880 | ✅ **完美** |
| **vm.swappiness** | 10 | 0-10 | ✅ **正常** |
| **vm.overcommit_memory** | 1 | 1 | ✅ **正常** |
| **kernel.shmmax** | 68,719,476,736 (64GB) | ≥64GB | ✅ **正常** |
| **kernel.shmall** | 4,294,967,296 | 足够大 | ✅ **正常** |

### 3.2 NUMA 配置

| 项目 | 当前状态 | 原厂推荐 | 评估 |
|------|----------|----------|------|
| **NUMA 节点** | 2 (Node 0-1) | 2 | ✅ 正常 |
| **Node 0** | CPU 0-31, 128GB | - | ✅ 正常 |
| **Node 1** | CPU 32-63, 128GB | - | ✅ 正常 |
| **NPU NUMA 亲和性** | ❓ 未确认 | NPU 绑定到对应 NUMA | ⚠️ **待验证** |
| **Transparent HugePages** | always | madvise/never | ⚠️ **建议调整** |

### 3.3 内存使用

| 项目 | 当前值 | 评估 |
|------|--------|------|
| **总内存** | 250GB | ✅ |
| **已用** | 246GB (98.4%) | 🔴 **极高！** |
| **可用** | 3.7GB | 🔴 **严重不足** |
| **Swap 使用** | 69MB / 4GB | ⚠️ 已使用 swap，说明物理内存不足 |

### 3.4 磁盘使用

| 挂载点 | 总大小 | 已用 | 可用 | 使用率 | 评估 |
|--------|--------|------|------|--------|------|
| `/` (root) | 69GB | 14GB | 52GB | 21% | ✅ 正常 |
| `/home` | 3.6TB | 220GB | 3.2TB | 7% | ✅ 正常 |
| `/ksc_aibox` | ❌ **未挂载** | - | - | - | ❌ **缺失！** |

---

## 四、安全配置评估

| 项目 | 当前状态 | 原厂推荐 | 评估 | 风险等级 |
|------|----------|----------|------|----------|
| **SELinux** | Enforcing | Permissive/Disabled (容器场景) | ⚠️ 可能影响容器/NPU 访问 | 🟡 中 |
| **Firewalld** | Active | 按需求开放端口 | ✅ 正常 | ✅ |
| **SSH Root 登录** | PermitRootLogin yes | prohibit-password | ⚠️ 密码认证风险 | 🟡 中 |
| **SSH 密码认证** | PasswordAuthentication yes | no (仅密钥) | ⚠️ 暴力破解风险 | 🟡 中 |
| **SSH 端口** | 22 (默认) | 非标准端口 | ⚠️ 扫描风险 | 🟢 低 |
| **iptables Kube 规则** | 存在 | K3s 自动管理 | ✅ 正常 | ✅ |
| **auditd** | Active | Active | ✅ 正常 | ✅ |

---

## 五、网络配置评估

| 项目 | 当前状态 | 原厂推荐 | 评估 |
|------|----------|----------|------|
| **活动网卡** | enp125s0f1 (10.212.128.192/22) | 多网卡绑定 | ⚠️ 单网卡运行 |
| **其他网卡** | enp125s0f0/2/3/4/5 (DOWN) | Bond/Team 模式 | ⚠️ 未利用冗余 |
| **默认网关** | 10.212.128.1 | 正确 | ✅ 正常 |
| **CNI 网络** | flannel.1 + cni0 (10.42.0.0/24) | Flannel/Calico | ✅ K3s 正常 |
| **Docker 网络** | 172.17.0.1/16 (bridge) | bridge/host | ✅ 正常 |
| **NTP 同步** | time.nju.edu.cn, Stratum 2 | 已同步 | ✅ 正常 |

---

## 六、NPU 专项评估

### 6.1 设备状态

| NPU ID | PCIe 总线 | 健康 | 温度 | 功耗 | HBM 使用 | PCIe 错误 | 评估 |
|--------|-----------|------|------|------|----------|-----------|------|
| 1 | 0000:82:00.0 | ✅ | 41°C | 72.3W | 4% | 0 | ✅ 正常 |
| 2 | 0000:81:00.0 | ✅ | 42°C | 74.9W | 4% | 0 | ✅ 正常 |
| 3 | 0000:02:00.0 | ✅ | 42°C | 78.1W | 4% | 0 | ✅ 正常 |
| 4 | 0000:01:00.0 | ✅ | 42°C | 78.1W | 4% | 0 | ✅ 正常 |

### 6.2 NPU 互联

| 项目 | 当前状态 | 原厂推荐 | 评估 |
|------|----------|----------|------|
| **HCCS 健康** | ❌ NOK (所有 NPU) | OK (多 chip 场景) | 🔴 **异常** |
| **HCCS Lane** | 全 0 | 应显示 active lanes | ❌ 未启用 |
| **P2P 配置** | ❌ 查询不支持 | 应启用 | ⚠️ 待确认 |
| **Device-share** | False (所有 NPU) | 按需求 | ℹ️ 未启用虚拟化 |

### 6.3 内核模块

| 模块 | 状态 | 评估 |
|------|------|------|
| `drv_vascend` | ✅ 加载 (4 引用) | ✅ 正常 |
| `drv_davinci_intf_host` | ✅ 加载 (13 引用) | ✅ 正常 |
| `drv_pcie_host` | ✅ 加载 (18 引用) | ✅ 正常 |
| `drv_devmm_host` | ✅ 加载 | ✅ 正常 |
| `ascend_xsmem` | ✅ 加载 | ✅ 正常 |
| **总计** | 27+ 模块 | ✅ 完整 |

### 6.4 设备权限

| 设备 | 权限 | 评估 |
|------|------|------|
| `/dev/davinci1-4` | crw-rw-rw- root:docker | ✅ 正确 |
| `/dev/davinci_manager` | crw-rw-rw- root:docker | ✅ 正确 |
| `/dev/devmm_svm` | crw------- root:root | ⚠️ 仅 root |
| `/dev/hisi_hdc` | crw------- root:root | ⚠️ 仅 root |

---

## 七、系统服务评估

| 服务 | 状态 | 评估 |
|------|------|------|
| **k3s** | ✅ Active | ✅ 正常 |
| **docker** | ✅ Active | ✅ 正常 |
| **chronyd** | ✅ Active | ✅ NTP 正常 |
| **firewalld** | ✅ Active | ✅ 正常 |
| **auditd** | ✅ Active | ✅ 正常 |
| **irqbalance** | ✅ Active | ✅ 正常 |
| **tuned** | ❌ 未安装 | ❌ **缺失** |
| **健康检查服务** | ❓ 未找到 | ⚠️ 待确认 |
| **自愈服务** | ❓ 未找到 | ⚠️ 待确认 |

---

## 八、问题汇总

### 🔴 严重问题 (P0 - 必须立即处理)

| # | 问题 | 影响 | 当前状态 |
|---|------|------|----------|
| P0-1 | **物理内存使用率 98.4%** | 系统可能 OOM，服务崩溃 | 246GB/250GB 已用 |
| P0-2 | **torch_npu 未安装** | 无法使用 NPU 进行 AI 推理/训练 | ModuleNotFoundError |
| P0-3 | **numpy 未安装** | CANN Python 包 (te/topi) 无法导入 | ModuleNotFoundError |
| P0-4 | **/ksc_aibox 目录未挂载** | 项目设计的核心数据路径不存在 | 仅 / 和 /home |

### 🟡 重要问题 (P1 - 一周内处理)

| # | 问题 | 影响 | 当前状态 |
|---|------|------|----------|
| P1-1 | **固件版本过旧** | 可能有稳定性/性能修复 | 7.7.0.10.220 → 7.8.0.6.201 |
| P1-2 | **CANN Beta 版本** | Beta 版可能有未修复 bug | 9.0.0-beta.2 |
| P1-3 | **Docker 版本过旧** | 缺少新特性，安全修复 | 18.09.0 → 20.10+ |
| P1-4 | **Ascend Docker Runtime 缺失** | 容器无法使用 NPU | 未安装 |
| P1-5 | **HCCS 互联状态 NOK** | NPU 间通信可能异常 | 所有 NPU NOK |
| P1-6 | **Ansible 配置版本不一致** | 自动化部署可能安装错误版本 | all.yml=25.2.3 vs 25.5.1 |

### 🟢 建议改进 (P2 - 一月内处理)

| # | 问题 | 影响 | 当前状态 |
|---|------|------|----------|
| P2-1 | **SELinux Enforcing** | 可能阻止容器/NPU 访问 | Enforcing |
| P2-2 | **SSH 密码认证启用** | 暴力破解风险 | PasswordAuthentication yes |
| P2-3 | **tuned 未安装** | 缺少性能优化配置 | 未安装 |
| P2-4 | **网络未做 Bond** | 单点故障风险 | 6 端口仅 1 个 UP |
| P2-5 | **Transparent HugePages always** | 可能影响 NPU 内存性能 | 建议 madvise |
| P2-6 | **Docker Cgroup Driver 不一致** | 与 K3s 可能冲突 | cgroupfs vs systemd |
| P2-7 | **健康检查/自愈服务缺失** | HCI 一体机核心功能缺失 | 未找到服务 |

---

## 九、改进行动计划

### Phase 1: 紧急修复 (1-2天)

#### 行动 1.1: 释放内存 / 分析内存占用

```bash
# 1. 分析内存占用
ssh root@10.212.128.192 << 'EOF'
# 查看进程内存占用 Top 10
ps aux --sort=-%mem | head -11
# 查看 K3s/Docker 内存占用
docker stats --no-stream
crictl pods --state Running 2>/dev/null
# 查看缓存/Slab 占用
free -h
cat /proc/meminfo | grep -E "Slab|SReclaimable|Cached"
EOF

# 2. 清理不必要的缓存和容器
ssh root@10.212.128.192 "sync && echo 3 > /proc/sys/vm/drop_caches"

# 3. 检查是否有内存泄漏的进程
ssh root@10.212.128.192 "dmesg | grep -i 'oom\|out of memory' | tail -10"
```

#### 行动 1.2: 安装 Python 依赖

```bash
ssh root@10.212.128.192 << 'EOF'
# 安装 numpy 和 torch_npu
pip3 install numpy
# 安装 torch_npu (Ascend 官方版本)
pip3 install torch-npu  # 或从 CANN 包中安装
# 验证
python3 -c "import numpy; import torch; import torch_npu; print('OK')"
EOF
```

#### 行动 1.3: 修复 CANN Python 环境

```bash
ssh root@10.212.128.192 << 'EOF'
# 安装 numpy 后验证 CANN te/topi
source /usr/local/Ascend/ascend-toolkit/set_env.sh
python3 -c "import te; import topi; print('CANN Python OK')"
EOF
```

#### 行动 1.4: 确认 /ksc_aibox 目录状态

```bash
ssh root@10.212.128.192 << 'EOF'
# 检查是否存在
ls -la /ksc_aibox 2>/dev/null || echo "目录不存在"
# 检查是否在 /home 下
ls -la /home/ksc_aibox 2>/dev/null || echo "不在 /home 下"
# 检查磁盘挂载
mount | grep ksc_aibox
cat /etc/fstab | grep ksc_aibox
EOF
```

---

### Phase 2: 驱动和固件升级 (3-5天)

#### 行动 2.1: 统一 Ansible 配置版本

```bash
# 修复 all.yml 中的版本不一致
# 文件: ansible/group_vars/all.yml
# 修改: npu_driver_version: "25.2.3" → "25.5.1"
```

#### 行动 2.2: 升级 NPU 固件

```bash
# 使用 Ansible 升级固件到 7.8.0.6.201
cd ansible
ansible-playbook -i inventory-npu.ini playbooks/01-install-npu-full-stack.yml \
  --tags "firmware" -v
# 或手动升级
ssh root@10.212.128.192 << 'EOF'
npu-smi upgrade -t mcu -i 0 -f <firmware_file.hpm>
npu-smi upgrade -a mcu -i 0  # 激活
reboot  # 需要重启
EOF
```

#### 行动 2.3: 评估 CANN 正式版升级

- 评估从 `9.0.0-beta.2` 升级到正式版 (如 `9.0.0` 或 `9.0.1`)
- 需验证与 torch/torch_npu 的兼容性
- 建议在测试环境先行验证

---

### Phase 3: 容器环境优化 (5-7天)

#### 行动 3.1: 升级 Docker 或迁移到 Podman

```bash
# 方案 A: 升级 Docker 到 20.10+
# 方案 B: 迁移到 Podman (openEuler 推荐)
# 注意: 需评估与现有容器化服务的兼容性
```

#### 行动 3.2: 安装 Ascend Docker Runtime

```bash
ssh root@10.212.128.192 << 'EOF'
# 安装 Ascend Docker Runtime
cd /usr/local/Ascend/docker
# 按照官方文档安装
# 配置 /etc/docker/daemon.json 添加 ascend runtime
systemctl restart docker
# 验证
docker info | grep -A5 "Runtimes"
EOF
```

#### 行动 3.3: 修正 Docker Cgroup Driver

```bash
# 修改 /etc/docker/daemon.json
# 添加: "exec-opts": ["native.cgroupdriver=systemd"]
systemctl restart docker
```

---

### Phase 4: 系统优化 (7-14天)

#### 行动 4.1: 安装 tuned 性能配置

```bash
ssh root@10.212.128.192 << 'EOF'
dnf install tuned -y
# 应用 NPU 性能配置档
tuned-adm profile throughput-performance
# 或自定义 NPU 配置
tuned-adm profile custom-npu
EOF
```

#### 行动 4.2: 调整 SELinux 策略

```bash
# 方案 A: 调整为 Permissive (开发环境)
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# 方案 B: 添加容器/NPU 相关 SELinux 策略 (生产环境推荐)
# 保持 Enforcing，但添加允许的模块
```

#### 行动 4.3: 加固 SSH 配置

```bash
ssh root@10.212.128.192 << 'EOF'
# 禁用密码认证
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
# 限制 Root 登录为仅密钥
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl restart sshd
EOF
```

#### 行动 4.4: 配置网络 Bond

```bash
# 使用 NetworkManager 配置 active-backup 或 LACP Bond
# 将 enp125s0f0 和 enp125s0f1 绑定为 bond0
nmcli con add type bond ifname bond0 mode active-backup
nmcli con add type bond-slave ifname enp125s0f0 master bond0
nmcli con add type bond-slave ifname enp125s0f1 master bond0
```

#### 行动 4.5: 调整 Transparent HugePages

```bash
# 修改为 madvise (推荐 NPU 场景)
echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
# 持久化
echo 'echo madvise > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local
```

---

### Phase 5: HCI 服务恢复 (14-21天)

#### 行动 5.1: 部署健康检查服务

```bash
# 使用 Ansible 部署
cd ansible
ansible-playbook -i inventory/hosts playbooks/04-health-check-and-best-practices.yml \
  --tags "health-check"
```

#### 行动 5.2: 部署自愈服务

```bash
cd ansible
ansible-playbook -i inventory/hosts playbooks/04-health-check-and-best-practices.yml \
  --tags "self-healing"
```

#### 行动 5.3: 排查 HCCS 互联问题

```bash
# 1. 确认服务器型号是否支持 HCCS
ssh root@10.212.128.192 "dmidecode -t system 2>/dev/null | grep Product"
# 2. 联系华为技术支持确认
# 3. 检查硬件拓扑配置
ssh root@10.212.128.192 "npu-smi info -t topo"
```

---

## 十、执行优先级建议

```
Week 1: Phase 1 (紧急修复)
├── Day 1: 内存分析 + Python 依赖安装
├── Day 2: /ksc_aibox 确认 + CANN Python 修复
└── Day 3: 验证修复效果

Week 2: Phase 2 (驱动升级)
├── Day 1: Ansible 配置统一
├── Day 2-3: 固件升级 + 重启窗口
└── Day 4-5: 验证 + CANN 正式版评估

Week 3: Phase 3 (容器优化)
├── Day 1-2: Docker 升级/Podman 迁移
├── Day 3: Ascend Docker Runtime 安装
└── Day 4-5: Cgroup Driver 修正 + 验证

Week 4: Phase 4 (系统优化)
├── Day 1: tuned 安装
├── Day 2: SELinux 调整
├── Day 3: SSH 加固
├── Day 4: 网络 Bond 配置
└── Day 5: THP 调整 + 全面验证

Week 5: Phase 5 (HCI 服务)
├── Day 1-2: 健康检查服务部署
├── Day 3-4: 自愈服务部署
└── Day 5: HCCS 问题排查
```

---

## 十一、风险与缓解措施

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| **固件升级需重启** | 业务中断 | 选择维护窗口，提前通知 |
| **Docker 升级可能破坏现有容器** | 服务不可用 | 升级前备份，测试环境验证 |
| **SELinux 调整可能降低安全性** | 安全风险 | 方案 A (Permissive) 仅限开发环境 |
| **内存释放可能影响运行中服务** | 服务重启 | 分析后再执行，避免强制 OOM Kill |
| **CANN 正式版升级可能不兼容** | AI 服务异常 | 测试环境验证，保留 Beta 版回滚 |

---

## 十二、成功标准

| 指标 | 当前 | 目标 |
|------|------|------|
| 内存使用率 | 98.4% | < 80% |
| torch_npu 可用性 | ❌ | ✅ |
| CANN te/topi 可用性 | ❌ | ✅ |
| /ksc_aibox 挂载 | ❌ | ✅ |
| NPU 固件版本 | 7.7.0.10.220 | 7.8.0.6.201 |
| Docker 版本 | 18.09.0 | 20.10+ 或 Podman |
| Ascend Docker Runtime | ❌ | ✅ |
| HCCS 状态 | NOK | 确认硬件规格或 OK |
| tuned 安装 | ❌ | ✅ |
| SSH 安全 | 密码认证 | 仅密钥认证 |
| 健康检查服务 | ❓ | ✅ 每 5 分钟 |
| 自愈服务 | ❓ | ✅ 每 10 分钟 |

---

*报告生成时间: 2026-04-09*  
*下次体检建议: 2026-04-16 (Phase 1-2 完成后)*
