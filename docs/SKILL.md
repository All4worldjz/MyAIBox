# KSC AIBox 技能与经验文档 (Skills & Experience)

> 本文档记录项目实施过程中的技能、踩坑、排错和优化经验，供后续参考。

---

## 目录

1. [硬件平台技能](#1-硬件平台技能)
2. [操作系统技能](#2-操作系统技能)
3. [NPU技能](#3-npu技能)
4. [Docker技能](#4-docker技能)
5. [网络技能](#5-网络技能)
6. [存储技能](#6-存储技能)
7. [安全技能](#7-安全技能)
8. [Ansible技能](#8-ansible技能)
9. [HCI一体机技能](#9-hci一体机技能)
10. [踩坑记录](#10-踩坑记录)
11. [排错案例](#11-排错案例)
12. [优化经验](#12-优化经验)

---

## 1. 硬件平台技能

### 1.1 华为鲲鹏920处理器

#### 架构特点

```
架构: ARMv8.2-A (aarch64)
核心: 64核 (2插座 × 32核/插座)
NUMA: 2节点
L3缓存: 64MB (2实例)
频率: 2.6GHz
```

#### NUMA拓扑

```bash
# 查看NUMA拓扑
lscpu | grep NUMA

# 输出:
NUMA 节点：        2
NUMA 节点0 CPU：   0-31
NUMA 节点1 CPU：   32-63
```

#### NUMA最佳实践

```bash
# 查看NUMA内存分布
cat /sys/devices/system/node/node*/meminfo | grep MemTotal

# NUMA绑定执行
numactl --cpunodebind=0 --membind=0 <command>

# 查看进程NUMA亲和性
numactl -p <pid>
```

#### 经验总结

| 场景 | 建议 |
|------|------|
| 单线程应用 | 绑定到单个NUMA节点 |
| 多线程应用 | 根据数据分布绑定 |
| NPU推理 | NPU与CPU同NUMA节点 |
| 数据库 | 绑定到对应NUMA节点 |

### 1.2 华为昇腾910B4-1 NPU

#### 硬件规格

```
型号: 昇腾910B4-1 (IT22PDHC)
HBM: 64GB/NPU, 1600MHz
数量: 4张
总HBM: 256GB
驱动版本: 25.2.3
```

#### NPU拓扑分析

```bash
# 查看NPU拓扑
npu-smi info -t topo

# 输出:
       NPU0    NPU1    NPU2    NPU3    CPU Affinity
NPU0    X      PHB     SYS     SYS     0-31
NPU1    PHB     X      SYS     SYS     0-31
NPU2    SYS     SYS     X      PHB     32-63
NPU3    SYS     SYS     PHB     X      32-63
```

#### 拓扑说明

| 连接类型 | 说明 | 性能 |
|----------|------|------|
| X | 自身 | - |
| PHB | 同PCIe Host Bridge | 高 |
| PIX | 同PCIe交换机 | 高 |
| PXB | 跨PCIe交换机 | 中 |
| SYS | 跨NUMA节点 | 低 |
| HCCS | 高速互联 | 最高 |

#### NPU配对建议

```
推荐配对 (同NUMA高性能):
- NPU0 + NPU1 (NUMA节点0)
- NPU2 + NPU3 (NUMA节点1)

避免配对 (跨NUMA低性能):
- NPU0 + NPU2
- NPU0 + NPU3
- NPU1 + NPU2
- NPU1 + NPU3
```

---

## 2. 操作系统技能

### 2.1 openEuler 24.03 LTS-SP1

#### 系统特点

```
基于: RHEL兼容
内核: 6.6.0
包管理: dnf/yum
SELinux: 默认Enforcing
```

#### 系统优化配置

##### 内核参数优化

```bash
# /etc/sysctl.d/99-ksc-aibox-optimization.conf

# 网络优化
net.core.somaxconn = 65535
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.ip_local_port_range = 1024 65535

# 内存优化
vm.swappiness = 10
vm.max_map_count = 262144
vm.overcommit_memory = 1
vm.min_free_kbytes = 1048576

# 文件系统
fs.file-max = 2097152
fs.nr_open = 2097152
```

##### 资源限制优化

```bash
# /etc/security/limits.d/99-ksc-aibox.conf

*    soft    nofile    655350
*    hard    nofile    655350
*    soft    nproc     655350
*    hard    nproc     655350
*    soft    memlock   unlimited
*    hard    memlock   unlimited
```

#### tuned性能配置

```bash
# 查看可用配置
tuned-adm list

# 推荐配置
tuned-adm profile accelerator-performance

# 验证
tuned-adm active
```

### 2.2 HugePages配置

#### 为什么需要HugePages

- NPU大模型推理需要大量连续内存
- 默认4KB页面导致页表过大
- 2MB HugePages减少TLB缺失

#### 配置方法

```bash
# 计算需要的HugePages数量
# 假设需要256GB HugePages
# 256GB / 2MB = 131072 页

# 配置
sysctl -w vm.nr_hugepages=131072

# 持久化
echo "vm.nr_hugepages=131072" >> /etc/sysctl.d/99-hugepages.conf

# 验证
grep HugePages /proc/meminfo
```

#### 经验总结

| 场景 | HugePages配置 |
|------|---------------|
| 单NPU推理 | 64GB (32000页) |
| 双NPU推理 | 128GB (64000页) |
| 四NPU推理 | 256GB (128000页) |

---

## 3. NPU技能

### 3.1 NPU驱动管理

#### 驱动版本检查

```bash
# 查看驱动版本
cat /usr/local/Ascend/version.info

# 输出:
version=25.2.3
```

#### NPU状态检查

```bash
# 列出所有NPU
npu-smi info -l

# 检查健康状态
npu-smi info -t health -i 0 -c 0

# 检查温度
npu-smi info -t temp -i 0 -c 0

# 检查功耗
npu-smi info -t power -i 0 -c 0

# 检查内存
npu-smi info -t memory -i 0 -c 0
```

### 3.2 NPU设备权限

#### 设备文件

```bash
ls -la /dev/davinci*

# 输出:
crw-rw----. 1 HwHiAiUser HwHiAiUser 235, 0 /dev/davinci0
crw-rw----. 1 HwHiAiUser HwHiAiUser 235, 1 /dev/davinci1
crw-rw----. 1 HwHiAiUser HwHiAiUser 235, 2 /dev/davinci2
crw-rw----. 1 HwHiAiUser HwHiAiUser 235, 3 /dev/davinci3
crw-rw----. 1 HwHiAiUser HwHiAiUser 236, 0 /dev/davinci_manager
```

#### udev规则配置

```bash
# /etc/udev/rules.d/99-npu.rules
KERNEL=="davinci[0-9]*", MODE="0666"
KERNEL=="davinci_manager", MODE="0666"
KERNEL=="devmm_svm", MODE="0666"
KERNEL=="hisi_hdc", MODE="0666"

# 重载规则
udevadm control --reload-rules
```

### 3.3 NPU容器配置

#### Docker设备映射

```bash
# 正确的设备映射
docker run --device=/dev/davinci0 \
           --device=/dev/davinci1 \
           --device=/dev/davinci2 \
           --device=/dev/davinci3 \
           --device=/dev/davinci_manager \
           --device=/dev/devmm_svm \
           --device=/dev/hisi_hdc \
           <image>
```

#### 环境变量

```bash
# NPU环境变量
export ASCEND_VISIBLE_DEVICES=0,1,2,3
export ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:$LD_LIBRARY_PATH
```

---

## 4. Docker技能

### 4.1 Docker数据目录迁移

#### 迁移步骤

```bash
# 1. 停止Docker
systemctl stop docker

# 2. 创建新目录
mkdir -p /ksc_aibox/docker/data

# 3. 同步数据
rsync -avz /var/lib/docker/ /ksc_aibox/docker/data/

# 4. 修改配置
# /etc/docker/daemon.json
{
  "data-root": "/ksc_aibox/docker/data"
}

# 5. 启动Docker
systemctl start docker

# 6. 验证
docker info | grep "Docker Root Dir"
```

#### 注意事项

- 迁移前确保有足够磁盘空间
- 使用rsync保持文件属性
- 迁移后验证容器状态

### 4.2 Docker日志管理

#### 日志配置

```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
```

#### 日志清理

```bash
# 清理所有容器日志
truncate -s 0 /var/lib/docker/containers/*/*-json.log

# 或使用Docker命令
docker system prune -f
```

---

## 5. 网络技能

### 5.1 华为HNS网卡

#### 网卡特点

```
型号: 华为HNS GE/10GE/25GE
端口: 6个 (每NUMA节点3个)
支持: RDMA
```

#### 网卡NUMA亲和性

```bash
# 查看网卡NUMA节点
cat /sys/bus/pci/devices/0000:7d:00.1/numa_node

# 输出: 0 (NUMA节点0)
```

#### 网络优化

```bash
# 增大网络缓冲区
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.wmem_max=134217728

# TCP优化
sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"
```

### 5.2 防火墙配置

#### 开放端口

```bash
# 开放端口
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --reload

# 查看开放端口
firewall-cmd --list-ports
```

#### 服务访问

```bash
# 开放服务
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https --permanent
```

---

## 6. 存储技能

### 6.1 NVMe SSD优化

#### 查看SSD信息

```bash
# 查看SMART信息
smartctl -a /dev/nvme0n1

# 查看温度
smartctl -A /dev/nvme0n1 | grep Temperature

# 查看写入量
smartctl -A /dev/nvme0n1 | grep "Data Units"
```

#### IO调度

```bash
# 查看当前调度器
cat /sys/block/nvme0n1/queue/scheduler

# NVMe推荐使用none或mq-deadline
echo none > /sys/block/nvme0n1/queue/scheduler
```

### 6.2 文件系统优化

#### ext4挂载选项

```bash
# /etc/fstab
UUID=xxx /ksc_aibox ext4 defaults,noatime,nodiratime 0 0
```

#### readahead优化

```bash
# 查看当前值
blockdev --getra /dev/nvme0n1

# 设置为8192 (4MB)
blockdev --setra 8192 /dev/nvme0n1
```

---

## 7. 安全技能

### 7.1 SELinux配置

#### 查看状态

```bash
getenforce
# Enforcing

sestatus
```

#### 上下文设置

```bash
# 查看文件上下文
ls -Z /ksc_aibox/

# 设置上下文
semanage fcontext -a -t var_lib_t "/ksc_aibox(/.*)?"
restorecon -Rv /ksc_aibox/
```

#### 常见问题解决

```bash
# 查看SELinux拒绝日志
ausearch -m AVC -ts recent

# 生成策略模块
audit2allow -a -M mypolicy
semodule -i mypolicy.pp
```

### 7.2 审计配置

#### 审计规则

```bash
# /etc/audit/rules.d/ksc-aibox.rules

# NPU访问监控
-w /dev/davinci0 -p rw -k npu_access
-w /dev/davinci1 -p rw -k npu_access

# 配置文件监控
-w /etc/ssh/sshd_config -p wa -k config_modify
-w /etc/docker/daemon.json -p wa -k config_modify
```

#### 查看审计日志

```bash
# 查看NPU访问
ausearch -k npu_access | tail -20

# 查看配置修改
ausearch -k config_modify | tail -20
```

---

## 8. Ansible技能

### 8.1 项目结构

```
ansible/
├── ansible.cfg           # Ansible配置
├── inventory/            # 主机清单
│   └── hosts
├── group_vars/           # 全局变量
│   └── all.yml
├── playbooks/            # Playbook剧本
│   ├── 01-xxx.yml
│   └── 02-xxx.yml
├── roles/                # Ansible角色
├── files/                # 静态文件
└── templates/            # 模板文件
```

### 8.2 常用模块

| 模块 | 用途 |
|------|------|
| shell | 执行Shell命令 |
| copy | 复制文件 |
| template | 部署模板 |
| sysctl | 内核参数 |
| systemd | 服务管理 |
| lineinfile | 修改文件行 |
| firewalld | 防火墙配置 |

### 8.3 最佳实践

#### 幂等性

```yaml
# 使用changed_when控制状态
- name: 检查配置
  shell: grep "xxx" /etc/config
  register: result
  changed_when: false
  failed_when: false

- name: 修改配置
  lineinfile:
    path: /etc/config
    line: "xxx"
  when: result.rc != 0
```

#### 错误处理

```yaml
- name: 可能失败的任务
  shell: some_command
  register: result
  failed_when: "'error' in result.stderr"
  ignore_errors: yes
```

---

## 9. HCI一体机技能

### 9.1 健康检查服务

#### 服务定义

```bash
# /etc/systemd/system/ksc-aibox-health-check.service
[Unit]
Description=KSC AIBox Health Check Service

[Service]
Type=oneshot
ExecStart=/ksc_aibox/scripts/monitor/system-health-check.sh

[Install]
WantedBy=multi-user.target
```

#### 定时器定义

```bash
# /etc/systemd/system/ksc-aibox-health-check.timer
[Unit]
Description=KSC AIBox Health Check Timer

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

### 9.2 自愈服务

#### 自愈脚本

```bash
#!/bin/bash
# /ksc_aibox/scripts/maintenance/self-healing.sh

# Docker自愈
if [ "$(systemctl is-active docker)" != "active" ]; then
  systemctl restart docker
fi

# 网络自愈
if ! ip link show enp125s0f1 | grep -q "state UP"; then
  nmcli connection up enp125s0f1
fi

# 时间同步自愈
chronyc makestep
```

---

## 10. 踩坑记录

### 10.1 NPU设备映射错误

#### 问题描述

```bash
# vLLM容器启动失败
docker: Error response from daemon: error gathering device information 
while adding custom device "/dev/davinci4": no such file or directory.
```

#### 原因分析

- 系统只有4张NPU (davinci0-3)
- 容器配置了不存在的davinci4

#### 解决方案

```bash
# 修改容器设备映射
docker run --device=/dev/davinci0 \
           --device=/dev/davinci1 \
           --device=/dev/davinci2 \
           --device=/dev/davinci3 \
           ...
```

### 10.2 HugePages不生效

#### 问题描述

```bash
# 配置HugePages后不生效
sysctl -w vm.nr_hugepages=128000
grep HugePages_Total /proc/meminfo
# HugePages_Total: 0
```

#### 原因分析

- 内存碎片化严重
- 需要连续内存块

#### 解决方案

```bash
# 方法1: 重启系统
reboot

# 方法2: 释放内存后重试
sync && echo 3 > /proc/sys/vm/drop_caches
sysctl -w vm.nr_hugepages=128000
```

### 10.3 SELinux阻止Docker

#### 问题描述

```bash
# Docker启动失败
Error starting daemon: SELinux is not supported with the overlay2 graph driver
```

#### 解决方案

```bash
# 方法1: 设置SELinux为Permissive (临时)
setenforce 0

# 方法2: 配置Docker使用SELinux
# /etc/docker/daemon.json
{
  "selinux-enabled": true
}
```

### 10.4 network.service失败

#### 问题描述

```bash
systemctl status network
# Active: failed
```

#### 原因分析

- openEuler使用NetworkManager
- network.service与NetworkManager冲突

#### 解决方案

```bash
# 禁用network.service
systemctl disable network.service

# 使用NetworkManager
systemctl status NetworkManager
```

### 10.5 内存不足导致NPU初始化失败

#### 问题描述

```bash
# NPU初始化失败
npu-smi info -t health -i 0 -c 0
# Error: Cannot initialize NPU
```

#### 原因分析

- HugePages占用大量内存
- 系统可用内存不足

#### 解决方案

```bash
# 检查内存使用
free -h

# 调整HugePages数量
sysctl -w vm.nr_hugepages=64000  # 减少到128GB

# 或增加Swap
dd if=/dev/zero of=/swapfile bs=1G count=64
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

---

## 11. 排错案例

### 11.1 容器无法访问NPU

#### 症状

```bash
docker exec -it <container> python -c "import torch_npu"
# ImportError: cannot import name 'torch_npu'
```

#### 排错步骤

```bash
# 1. 检查设备映射
docker inspect <container> | grep -A 10 "Devices"

# 2. 检查设备权限
ls -la /dev/davinci*

# 3. 检查容器内设备
docker exec -it <container> ls -la /dev/davinci*

# 4. 检查环境变量
docker exec -it <container> env | grep ASCEND
```

#### 解决方案

```bash
# 确保设备正确映射
docker run --device=/dev/davinci0 \
           --device=/dev/davinci_manager \
           --device=/dev/devmm_svm \
           --device=/dev/hisi_hdc \
           -e ASCEND_VISIBLE_DEVICES=0 \
           <image>
```

### 11.2 服务启动后立即退出

#### 症状

```bash
systemctl start myservice
systemctl status myservice
# Active: inactive (dead)
```

#### 排错步骤

```bash
# 1. 查看服务日志
journalctl -u myservice -n 50

# 2. 查看系统日志
dmesg | grep -i error | tail -20

# 3. 手动执行服务命令
/ksc_aibox/scripts/myservice.sh

# 4. 检查SELinux
ausearch -m AVC -ts recent
```

### 11.3 网络连接超时

#### 症状

```bash
curl https://example.com
# Connection timed out
```

#### 排错步骤

```bash
# 1. 检查网络接口
ip addr show

# 2. 检查路由
ip route show

# 3. 检查DNS
nslookup example.com

# 4. 检查防火墙
firewall-cmd --list-all

# 5. 检查代理设置
env | grep -i proxy
```

---

## 12. 优化经验

### 12.1 系统启动优化

```bash
# 查看启动时间
systemd-analyze time

# 查看启动服务耗时
systemd-analyze blame | head -20

# 禁用不必要的服务
systemctl disable bluetooth.service
systemctl disable cups.service
```

### 12.2 内存优化

```bash
# 调整vm.swappiness
sysctl -w vm.swappiness=10

# 调整脏页比例
sysctl -w vm.dirty_ratio=40
sysctl -w vm.dirty_background_ratio=10

# 定期清理缓存
echo 3 > /proc/sys/vm/drop_caches
```

### 12.3 磁盘IO优化

```bash
# 调整readahead
blockdev --setra 8192 /dev/nvme0n1

# 使用noatime挂载
mount -o remount,noatime /ksc_aibox
```

### 12.4 网络优化

```bash
# 增大TCP缓冲区
sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"

# 启用TCP快速打开
sysctl -w net.ipv4.tcp_fastopen=3
```

---

## 附录: 命令速查表

### 系统信息

```bash
uname -a                    # 内核信息
hostnamectl status          # 主机信息
cat /etc/os-release         # 系统版本
lscpu                       # CPU信息
free -h                     # 内存信息
lsblk                       # 磁盘信息
lspci                       # PCIe设备
```

### NPU管理

```bash
npu-smi info -l             # 列出NPU
npu-smi info -t health -i 0 -c 0  # 健康状态
npu-smi info -t temp -i 0 -c 0    # 温度
npu-smi info -t power -i 0 -c 0   # 功耗
npu-smi info -t memory -i 0 -c 0  # 内存
npu-smi info -t topo        # 拓扑
```

### Docker管理

```bash
docker ps -a                # 容器列表
docker images               # 镜像列表
docker logs <container>     # 容器日志
docker exec -it <container> bash  # 进入容器
docker system prune -f      # 清理资源
```

### 服务管理

```bash
systemctl status <service>  # 服务状态
systemctl start <service>   # 启动服务
systemctl stop <service>    # 停止服务
systemctl enable <service>  # 启用服务
systemctl disable <service> # 禁用服务
journalctl -u <service> -f  # 服务日志
```

### 网络管理

```bash
ip addr show                # 网络接口
ip route show               # 路由表
ss -tlnp                    # 监听端口
firewall-cmd --list-all     # 防火墙规则
```

---

*本文档由Qwen Code生成，持续更新中*
*最后更新: 2026-04-03*