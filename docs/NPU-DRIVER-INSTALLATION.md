# 华为昇腾NPU驱动安装指南

> 本文档记录在openEuler 24.03 LTS-SP3上安装华为昇腾910B NPU驱动的完整流程和踩坑经验。

---

## 目录

1. [环境信息](#1-环境信息)
2. [安装前准备](#2-安装前准备)
3. [驱动安装步骤](#3-驱动安装步骤)
4. [常见问题解决](#4-常见问题解决)
5. [验证安装](#5-验证安装)
6. [附录](#6-附录)

---

## 1. 环境信息

### 1.1 硬件配置

| 组件 | 规格 |
|------|------|
| CPU | 华为鲲鹏920 (aarch64) |
| NPU | 4×华为昇腾910B (IT22PDHC) |
| 内存 | 256GB DDR4 |
| 存储 | 3.6TB NVMe SSD |

### 1.2 软件版本

| 软件 | 版本 |
|------|------|
| 操作系统 | openEuler 24.03 LTS-SP3 |
| 内核 | 6.6.0-144.0.0.130.oe2403sp3.aarch64 |
| NPU驱动 | 25.5.1 |
| NPU固件 | 7.8.0.6.201 |

### 1.3 NPU设备信息

```bash
# 查看NPU PCIe设备
lspci | grep -i ascend
# 01:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
# 02:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
# 81:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
# 82:00.0 Processing accelerators: Huawei Technologies Co., Ltd. Device d802 (rev 20)
```

---

## 2. 安装前准备

### 2.1 系统升级

```bash
# 升级到openEuler 24.03 LTS-SP3
yum update -y

# 安装新内核
yum install -y kernel-6.6.0-144.0.0.130.oe2403sp3.aarch64

# 重启加载新内核
reboot
```

### 2.2 安装编译依赖

```bash
# 安装必要的编译工具和依赖
yum install -y gcc make dkms kernel-devel kernel-headers net-tools

# 注意：net-tools提供ifconfig，驱动安装脚本需要
```

### 2.3 创建HwHiAiUser用户

```bash
# NPU驱动需要HwHiAiUser用户
groupadd HwHiAiUser
useradd -g HwHiAiUser -d /home/HwHiAiUser -m HwHiAiUser -s /bin/bash

# 验证用户创建
id HwHiAiUser
# 输出: 用户id=1001(HwHiAiUser) 组id=1001(HwHiAiUser) 组=1001(HwHiAiUser)
```

### 2.4 准备驱动文件

> ⚠️ **重要提醒：必须下载ZIP文件包**
>
> 从华为昇腾社区下载驱动时，**务必下载ZIP压缩包**（如`Ascend-hdk-910b-npu_25.5.1_linux-aarch64.zip`），**不要单独下载.run文件**。
>
> **原因**：
> - ZIP包包含完整的驱动和固件文件
> - ZIP包内的.run文件经过正确打包和签名
> - 单独下载的.run文件可能不完整或版本不匹配
> - ZIP包通常包含安装脚本和文档
>
> **下载地址**：https://www.hiascend.com/software/cann/community
>
> **下载步骤**：
> 1. 选择对应的产品型号（Ascend 910B）
> 2. 选择操作系统（openEuler aarch64）
> 3. 下载ZIP格式的驱动包
> 4. 解压后使用其中的.run文件

```bash
# 驱动文件位置（解压后）
drivers/NPU-910B/Ascend-hdk-910b-npu_25/Ascend-hdk-910b-npu_25.5.1_linux-aarch64/

# 关键文件
# - Ascend-hdk-910b-npu-driver_25.5.1_linux-aarch64.run (驱动包)
# - Ascend-hdk-910b-npu-firmware_7.8.0.6.201.run (固件包)
# - install.sh (安装脚本，可选)

# 解压ZIP包
unzip Ascend-hdk-910b-npu_25.5.1_linux-aarch64.zip -d /path/to/drivers/
```

---

## 3. 驱动安装步骤

### 3.1 复制驱动文件到服务器

```bash
# 从本地复制到远程服务器
scp Ascend-hdk-910b-npu-driver_25.5.1_linux-aarch64.run \
    Ascend-hdk-910b-npu-firmware_7.8.0.6.201.run \
    root@10.212.128.192:/tmp/
```

### 3.2 安装驱动

```bash
# 添加执行权限
chmod +x /tmp/Ascend-hdk-910b-npu-driver_25.5.1_linux-aarch64.run

# 执行驱动安装
cd /tmp
./Ascend-hdk-910b-npu-driver_25.5.1_linux-aarch64.run --full
```

### 3.3 解决编译错误（openEuler SP3）

**问题**：DKMS编译失败，MIN/ALIGN_DOWN宏重定义

```bash
# 错误信息
/var/lib/dkms/davinci_ascend/1.0/build/vascend_drv/kvmdt.c:62: 错误："MIN"重定义 [-Werror]
/var/lib/dkms/davinci_ascend/1.0/build/dvpp_cmdlist/base/dvpp_cmdlist_define.h:11: 错误："ALIGN_DOWN"重定义 [-Werror]
```

**解决方案**：修改驱动源码，添加条件编译

```bash
# 修改kvmdt.c
sed -i "62i #ifndef MIN" /usr/src/davinci_ascend-1.0/vascend_drv/kvmdt.c
sed -i "64i #endif" /usr/src/davinci_ascend-1.0/vascend_drv/kvmdt.c

# 修改dvpp_cmdlist_define.h
sed -i "10i #ifndef ALIGN_DOWN" /usr/src/davinci_ascend-1.0/dvpp_cmdlist/base/dvpp_cmdlist_define.h
sed -i "12i #endif" /usr/src/davinci_ascend-1.0/dvpp_cmdlist/base/dvpp_cmdlist_define.h

# 重新编译DKMS模块
dkms build davinci_ascend/1.0
dkms install davinci_ascend/1.0
```

### 3.4 安装固件

```bash
# 安装固件（首次安装：驱动→固件；升级：固件→驱动）
chmod +x /tmp/Ascend-hdk-910b-npu-firmware_7.8.0.6.201.run
./Ascend-hdk-910b-npu-firmware_7.8.0.6.201.run --full

# 输出：
# The firmware of [4] chips are successfully upgraded.
```

### 3.5 配置环境变量

```bash
# 创建环境变量配置文件
cat > /etc/profile.d/ascend.sh << 'EOF'
# Ascend NPU Environment
export ASCEND_HOME_PATH=/usr/local/Ascend
export ASCEND_DRIVER_PATH=/usr/local/Ascend/driver
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:/usr/local/Ascend/driver/lib64/inner:$LD_LIBRARY_PATH
export PATH=/usr/local/Ascend/bin:$PATH
EOF

# 加载环境变量
source /etc/profile.d/ascend.sh
```

---

## 4. 常见问题解决

### 4.1 HwHiAiUser用户不存在

**错误信息**：
```
[Driver] [ERROR] ERR_NO:0x0091; ERR_DES: HwHiAiUser not exists!
```

**解决方案**：
```bash
groupadd HwHiAiUser
useradd -g HwHiAiUser -d /home/HwHiAiUser -m HwHiAiUser -s /bin/bash
```

### 4.2 缺少ifconfig命令

**错误信息**：
```
[Driver] [ERROR] The list of missing tools: ifconfig,
```

**解决方案**：
```bash
yum install -y net-tools
```

### 4.3 MIN/ALIGN_DOWN宏重定义

**错误信息**：
```
错误："MIN"重定义 [-Werror]
错误："ALIGN_DOWN"重定义 [-Werror]
```

**原因**：openEuler SP3内核已定义这些宏，驱动源码重复定义

**解决方案**：见[3.3节](#33-解决编译错误openeuler-sp3)

### 4.4 npu-smi找不到共享库

**错误信息**：
```
npu-smi: error while loading shared libraries: libc_sec.so: cannot open shared object file
```

**解决方案**：
```bash
# 配置环境变量
source /etc/profile.d/ascend.sh

# 或手动设置
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:/usr/local/Ascend/driver/lib64/inner:$LD_LIBRARY_PATH
```

### 4.5 内核模块签名警告

**错误信息**：
```
drv_vascend_stub: module verification failed: signature and/or required key missing - tainting kernel
```

**说明**：这是警告信息，不影响功能。openEuler默认不强制模块签名验证（`CONFIG_MODULE_SIG_FORCE is not set`）。

---

## 5. 验证安装

### 5.1 检查驱动版本

```bash
cat /usr/local/Ascend/version.info
# version=25.5.1
```

### 5.2 检查内核模块

```bash
lsmod | grep -E "davinci|ascend|drv_" | head -10
# ascend_xsmem          200704  0
# drv_pcie_vnic_host     61440  0
# drv_dvpp_cmdlist      282624  0
# ...
```

### 5.3 检查设备文件

```bash
ls -la /dev/davinci*
# crw-rw----. 1 root root 510, 1  /dev/davinci1
# crw-rw----. 1 root root 510, 2  /dev/davinci2
# crw-rw----. 1 root root 510, 3  /dev/davinci3
# crw-rw----. 1 root root 510, 4  /dev/davinci4
# crw-------. 1 root root 511, 0  /dev/davinci_manager
```

### 5.4 检查NPU状态

```bash
# 加载环境变量
source /etc/profile.d/ascend.sh

# 列出所有NPU
npu-smi info -l
# Total Count                    : 4
# NPU ID                         : 1
# Product Name                   : IT22PDHC
# Serial Number                  : 1025BB058015
# ...

# 检查健康状态
npu-smi info -t health -i 1
# Health                         : OK
```

### 5.5 检查DKMS状态

```bash
dkms status
# davinci_ascend/1.0, 6.6.0-144.0.0.130.oe2403sp3.aarch64, aarch64: installed
```

---

## 6. 附录

### 6.1 安装顺序说明

| 场景 | 安装顺序 |
|------|----------|
| 首次安装 | 驱动 → 固件 |
| 升级 | 固件 → 驱动 |

### 6.2 驱动文件说明

| 文件 | 说明 | 大小 |
|------|------|------|
| `Ascend-hdk-910b-npu-driver_*.run` | 驱动安装包 | ~115MB |
| `Ascend-hdk-910b-npu-firmware_*.run` | 固件安装包 | ~278KB |

### 6.3 安装参数说明

| 参数 | 说明 |
|------|------|
| `--full` | 完整安装 |
| `--upgrade` | 升级安装 |
| `--uninstall` | 卸载 |

### 6.4 关键目录

| 目录 | 说明 |
|------|------|
| `/usr/local/Ascend/driver` | 驱动安装目录 |
| `/usr/src/davinci_ascend-1.0` | DKMS源码目录 |
| `/var/lib/dkms/davinci_ascend` | DKMS构建目录 |
| `/lib/modules/$(uname -r)/updates` | 内核模块目录 |
| `/var/log/ascend_seclog` | 安装日志目录 |

### 6.5 故障排查命令

```bash
# 查看安装日志
tail -100 /var/log/ascend_seclog/ascend_install.log

# 查看DKMS构建日志
cat /var/lib/dkms/davinci_ascend/1.0/build/make.log

# 查看内核日志中的NPU信息
dmesg | grep -E "davinci|ascend|19e5"

# 查看PCIe设备
lspci -vvv | grep -E "Ascend|d802" -A10

# 查看内核模块依赖
modprobe -c | grep -E "davinci|ascend|drv_"
```

### 6.6 卸载驱动

```bash
# 卸载驱动
./Ascend-hdk-910b-npu-driver_25.5.1_linux-aarch64.run --uninstall

# 或使用rpm卸载
rpm -e Ascend910B-driver --nodeps

# 清理DKMS
dkms remove davinci_ascend/1.0 --all
rm -rf /usr/src/davinci_ascend-1.0
rm -rf /var/lib/dkms/davinci_ascend
```

---

## 更新历史

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-04-03 | 1.0 | 初始版本，记录openEuler SP3安装NPU驱动流程 |