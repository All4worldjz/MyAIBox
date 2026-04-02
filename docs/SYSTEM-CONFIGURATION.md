# 系统配置指南

> 本文档记录KSC AIBox服务器的系统配置，包括内核参数、multipath禁用、串口console等关键配置。

---

## 目录

1. [内核参数配置](#1-内核参数配置)
2. [multipath禁用配置](#2-multipath禁用配置)
3. [串口Console配置](#3-串口console配置)
4. [NPU环境变量配置](#4-npu环境变量配置)
5. [配置验证清单](#5-配置验证清单)

---

## 1. 内核参数配置

### 1.1 当前内核参数

```bash
# 查看当前内核启动参数
cat /proc/cmdline

# 输出：
BOOT_IMAGE=/vmlinuz-6.6.0-144.0.0.130.oe2403sp3.aarch64 
root=/dev/mapper/openeuler-root 
ro 
rd.lvm.lv=openeuler/root 
rd.lvm.lv=openeuler/swap 
video=VGA-1:640x480-32@60me 
cgroup_disable=files 
apparmor=0 
crashkernel=1024M,high 
smmu.bypassdev=0x1000:0x17 
smmu.bypassdev=0x1000:0x15 
arm64.nopauth 
console=ttyAMA0,115200 
console=tty0 
panic=10
```

### 1.2 关键参数说明

| 参数 | 说明 | 值 |
|------|------|-----|
| `console=ttyAMA0,115200` | ARM串口console | 波特率115200 |
| `console=tty0` | VGA控制台 | - |
| `panic=10` | panic后10秒自动重启 | 避免系统卡死 |
| `crashkernel=1024M,high` | kdump预留内存 | 1GB |
| `cgroup_disable=files` | 禁用cgroup files子系统 | 性能优化 |
| `arm64.nopauth` | 禁用PAuth指令 | 兼容性 |
| `smmu.bypassdev` | SMMU旁路设备 | NPU相关 |

### 1.3 修改内核参数

```bash
# 为所有内核添加参数
grubby --update-kernel=ALL --args="console=ttyAMA0,115200 console=tty0 panic=10"

# 为特定内核添加参数
grubby --update-kernel=/boot/vmlinuz-6.6.0-144.0.0.130.oe2403sp3.aarch64 --args="panic=10"

# 查看内核参数
grubby --info=ALL | grep args

# 设置默认启动内核
grubby --set-default=/boot/vmlinuz-6.6.0-144.0.0.130.oe2403sp3.aarch64
```

### 1.4 内核参数最佳实践

| 场景 | 推荐参数 |
|------|----------|
| 服务器（有串口） | `console=ttyAMA0,115200 console=tty0` |
| 服务器（无串口） | `console=tty0` |
| 生产环境 | `panic=10`（自动重启） |
| 调试环境 | `panic=0`（不重启，便于调试） |

---

## 2. multipath禁用配置

### 2.1 为什么禁用multipath

- 系统使用单一NVMe SSD，不需要多路径
- multipath可能导致启动卡死
- 减少不必要的系统开销

### 2.2 配置文件

#### /etc/multipath.conf

```bash
# 创建multipath配置文件
cat > /etc/multipath.conf << 'EOF'
# Disable multipath for all devices
# This system uses single NVMe SSD, no multipath needed
defaults {
    user_friendly_names no
    find_multipaths no
}

blacklist {
    devnode "^.*"
}
EOF
```

#### /etc/modprobe.d/blacklist-multipath.conf

```bash
# 创建modprobe黑名单
echo "blacklist dm-multipath" > /etc/modprobe.d/blacklist-multipath.conf
```

#### /etc/dracut.conf.d/no-multipath.conf

```bash
# 创建dracut配置，禁用initramfs中的multipath
cat > /etc/dracut.conf.d/no-multipath.conf << 'EOF'
# Disable multipath in initramfs
omit_dracutmodules+=" multipath "
EOF
```

### 2.3 禁用服务

```bash
# 禁用multipathd服务
systemctl disable multipathd
systemctl disable multipathd.socket

# 停止服务（如果正在运行）
systemctl stop multipathd
systemctl stop multipathd.socket
```

### 2.4 重新生成initramfs

```bash
# 重新生成initramfs
dracut -f --omit multipath /boot/initramfs-$(uname -r).img $(uname -r)

# 验证initramfs中是否包含multipath
lsinitrd /boot/initramfs-$(uname -r).img | grep multipath
# 应无输出或只有内核模块文件
```

### 2.5 验证配置

```bash
# 检查multipath服务状态
systemctl is-enabled multipathd multipathd.socket
# 应输出: disabled disabled

# 检查multipath设备
multipath -ll
# 应无输出

# 检查dm-multipath模块是否加载
lsmod | grep dm_multipath
# 如果有输出，说明模块已加载但被黑名单阻止自动加载
```

---

## 3. 串口Console配置

### 3.1 为什么需要串口Console

- 服务器通常通过IPMI/BMC管理
- VGA输出可能不可见（无连接显示器）
- 串口console可捕获启动错误信息

### 3.2 检查可用串口设备

```bash
# 检查串口设备
ls -la /dev/ttyAMA* /dev/ttyS*

# ARM服务器通常使用ttyAMA0（PL011 UART）
# x86服务器通常使用ttyS0（8250/16550 UART）
```

### 3.3 配置串口Console

```bash
# 添加串口console参数
grubby --update-kernel=ALL --args="console=ttyAMA0,115200 console=tty0"

# 验证配置
grubby --info=ALL | grep args
```

### 3.4 Console参数说明

| 参数 | 说明 |
|------|------|
| `console=ttyAMA0,115200` | ARM PL011串口，波特率115200 |
| `console=tty0` | VGA控制台 |
| 多个console | 最后一个为主console，其他也会输出 |

### 3.5 验证Console配置

```bash
# 查看当前console
cat /proc/console
# 输出: ttyAMA0

# 查看内核启动参数
cat /proc/cmdline | grep console
```

---

## 4. NPU环境变量配置

### 4.1 配置文件

#### /etc/profile.d/ascend.sh

```bash
# 创建环境变量配置文件
cat > /etc/profile.d/ascend.sh << 'EOF'
# Ascend NPU Environment
export ASCEND_HOME_PATH=/usr/local/Ascend
export ASCEND_DRIVER_PATH=/usr/local/Ascend/driver
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:/usr/local/Ascend/driver/lib64/inner:$LD_LIBRARY_PATH
export PATH=/usr/local/Ascend/bin:$PATH
EOF

# 设置权限
chmod +x /etc/profile.d/ascend.sh
```

### 4.2 加载环境变量

```bash
# 加载环境变量
source /etc/profile.d/ascend.sh

# 验证环境变量
echo $ASCEND_HOME_PATH
# 输出: /usr/local/Ascend

# 验证npu-smi命令
npu-smi info -l
```

---

## 5. 配置验证清单

### 5.1 启动前检查

```bash
#!/bin/bash
# 系统配置验证脚本

echo "=== 系统配置验证 ==="

echo ""
echo "1. 内核参数检查"
echo "   console参数: $(cat /proc/cmdline | grep -o 'console=[^ ]*')"
echo "   panic参数: $(cat /proc/cmdline | grep -o 'panic=[^ ]*')"

echo ""
echo "2. multipath服务检查"
echo "   multipathd: $(systemctl is-enabled multipathd 2>/dev/null || echo 'disabled')"
echo "   multipathd.socket: $(systemctl is-enabled multipathd.socket 2>/dev/null || echo 'disabled')"

echo ""
echo "3. multipath配置文件检查"
echo "   /etc/multipath.conf: $([ -f /etc/multipath.conf ] && echo '存在' || echo '不存在')"
echo "   /etc/modprobe.d/blacklist-multipath.conf: $([ -f /etc/modprobe.d/blacklist-multipath.conf ] && echo '存在' || echo '不存在')"
echo "   /etc/dracut.conf.d/no-multipath.conf: $([ -f /etc/dracut.conf.d/no-multipath.conf ] && echo '存在' || echo '不存在')"

echo ""
echo "4. NPU环境变量检查"
echo "   ASCEND_HOME_PATH: ${ASCEND_HOME_PATH:-未设置}"
echo "   /etc/profile.d/ascend.sh: $([ -f /etc/profile.d/ascend.sh ] && echo '存在' || echo '不存在')"

echo ""
echo "5. NPU驱动检查"
echo "   DKMS状态: $(dkms status 2>/dev/null | head -1)"
echo "   NPU设备: $(ls /dev/davinci* 2>/dev/null | wc -l) 个"

echo ""
echo "6. 失败服务检查"
echo "   失败服务数量: $(systemctl list-units --type=service --state=failed | grep -c 'loaded')"

echo ""
echo "=== 验证完成 ==="
```

### 5.2 预期输出

```
=== 系统配置验证 ===

1. 内核参数检查
   console参数: console=ttyAMA0,115200 console=tty0
   panic参数: panic=10

2. multipath服务检查
   multipathd: disabled
   multipathd.socket: disabled

3. multipath配置文件检查
   /etc/multipath.conf: 存在
   /etc/modprobe.d/blacklist-multipath.conf: 存在
   /etc/dracut.conf.d/no-multipath.conf: 存在

4. NPU环境变量检查
   ASCEND_HOME_PATH: /usr/local/Ascend
   /etc/profile.d/ascend.sh: 存在

5. NPU驱动检查
   DKMS状态: davinci_ascend/1.0, 6.6.0-144.0.0.130.oe2403sp3.aarch64, aarch64: installed
   NPU设备: 5 个

6. 失败服务检查
   失败服务数量: 0

=== 验证完成 ===
```

---

## 附录

### A. 配置文件位置汇总

| 文件 | 说明 |
|------|------|
| `/etc/multipath.conf` | multipath配置 |
| `/etc/modprobe.d/blacklist-multipath.conf` | modprobe黑名单 |
| `/etc/dracut.conf.d/no-multipath.conf` | dracut配置 |
| `/etc/profile.d/ascend.sh` | NPU环境变量 |
| `/boot/grub2/grub.cfg` | GRUB配置（自动生成） |

### B. 相关命令

```bash
# 内核管理
grubby --info=ALL              # 查看所有内核信息
grubby --default-kernel        # 查看默认内核
grubby --set-default=<kernel>  # 设置默认内核

# multipath管理
multipath -ll                  # 查看multipath设备
multipath -t                   # 验证配置
multipath -F                   # 刷新multipath映射

# dracut管理
dracut --list-modules          # 列出可用模块
dracut -f <output> <version>   # 生成initramfs
lsinitrd <file>                # 查看initramfs内容

# systemd管理
systemctl is-enabled <service> # 检查服务是否启用
systemctl list-units --failed  # 列出失败服务
```

---

## 更新历史

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-04-03 | 1.0 | 初始版本，记录系统配置 |