# Huawei Ascend 910B NPU 驱动安装完整上下文记录

> 本文档记录完整的安装过程、问题排查和解决方案，供后续参考和AI工具上下文恢复使用。

---

## 1. 项目概述

### 1.1 整体目标
在远程服务器 `10.212.128.192` 上安装华为昇腾 910B NPU 驱动，完成系统配置，为后续 AI 训练/推理环境做准备。

### 1.2 服务器信息
- **IP地址**: 10.212.128.192 (SSH as root)
- **操作系统**: openEuler 24.03 LTS-SP3 (从 SP1 升级)
- **内核版本**: 6.6.0-144.0.0.130.oe2403sp3.aarch64
- **架构**: aarch64 (ARM64)
- **CPU**: 华为鲲鹏处理器
- **内存**: 250GB
- **存储**: 69GB root + 3.6TB home

### 1.3 NPU 硬件信息
- **型号**: Huawei Ascend 910B (IT22PDHC)
- **数量**: 4 张
- **PCIe Device ID**: 19e5:d802
- **PCIe 位置**: 
  - 01:00.0 (NPU 0)
  - 02:00.0 (NPU 1)
  - 81:00.0 (NPU 2)
  - 82:00.0 (NPU 3)

### 1.4 驱动版本
- **驱动版本**: 25.5.1
- **固件版本**: 7.8.0.6.201
- **安装路径**: `/usr/local/Ascend/`

---

## 2. 关键知识点

### 2.1 驱动下载注意事项
⚠️ **重要**: 必须下载 ZIP 整包，不能只下载单个 .run 文件！
- ZIP 包包含：驱动、固件、工具、依赖库等完整组件
- 单独 .run 文件缺少必要的依赖和配置文件
- 下载地址: https://www.hiascend.com/software/cann/community

### 2.2 安装顺序规则
- **首次安装**: Driver → Firmware
- **升级安装**: Firmware → Driver

### 2.3 openEuler SP3 内核问题
SP3 内核与 NPU 驱动存在兼容性问题：

1. **UB (Unified Bus) 内置问题**
   - SP3 内核将 UB 模块内置，导致驱动编译失败
   - 解决方案：修改驱动源码中的 UB 相关代码

2. **MIN/ALIGN_DOWN 宏冲突**
   - 驱动定义的 MIN/ALIGN_DOWN 宏与内核冲突
   - 解决方案：在驱动源码中重命名这些宏

3. **mdev 模块缺失** ⚠️ **本次发现的新问题**
   - SP3 内核未编译 VFIO_MDEV 模块
   - 导致 drv_vascend 模块无法加载
   - 解决方案：从内核源码手动编译 mdev.ko

### 2.4 系统配置要点
- **multipath**: 必须禁用，否则会导致 NPU 设备识别异常
- **console**: 配置串口控制台 `console=ttyAMA0,115200`
- **panic**: 设置 `panic=10` 自动重启
- **用户**: 创建 HwHiAiUser 用户/组

---

## 3. 安装过程记录

### 3.1 操作系统升级
```bash
# 从 SP1 升级到 SP3
yum update -y
```

### 3.2 驱动安装步骤

#### Step 1: 安装依赖
```bash
yum install -y gcc make dkms kernel-devel kernel-source flex bison openssl-devel elfutils-libelf-devel
```

#### Step 2: 解压驱动包
```bash
unzip Ascend-hdk-910b-npu_25.5.1_linux-aarch64.zip
cd Ascend-hdk-910b-npu_25.5.1_linux-aarch64
```

#### Step 3: 安装驱动 (DKMS 方式)
```bash
./Ascend-hdk-910b-npu_25.5.1_linux-aarch64.run --install --dkms
```

#### Step 4: 安装固件
```bash
./Ascend-hdk-910b-firmware_7.8.0.6.201_linux-aarch64.run --install
```

### 3.3 驱动源码修复

#### 修复 MIN/ALIGN_DOWN 宏冲突
文件: `/usr/src/davinci_ascend-1.0/vascend_drv/kvmdt.c`

```c
// 原代码 (第62-65行)
#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef ALIGN_DOWN
#define ALIGN_DOWN(addr, align) ((addr) & ~(align - 1))
#endif

// 修改为
#ifndef DRV_MIN
#define DRV_MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef DRV_ALIGN_DOWN
#define DRV_ALIGN_DOWN(addr, align) ((addr) & ~(align - 1))
#endif

// 同时替换所有使用处
sed -i 's/MIN(/DRV_MIN(/g' kvmdt.c
sed -i 's/ALIGN_DOWN(/DRV_ALIGN_DOWN(/g' kvmdt.c
```

#### 重新编译驱动
```bash
dkms remove davinci_ascend/1.0 --all
dkms add davinci_ascend/1.0
dkms build davinci_ascend/1.0
dkms install davinci_ascend/1.0
```

### 3.4 mdev 模块编译 (本次新增)

#### 问题现象
```
drv_vascend: Unknown symbol mdev_register_parent (err -2)
drv_vascend: Unknown symbol mdev_unregister_parent (err -2)
```

#### 解决方案
```bash
# 1. 安装内核源码
yum install -y kernel-source-6.6.0-144.0.0.130.oe2403sp3.aarch64

# 2. 准备编译环境
cd /usr/src/linux-6.6.0-144.0.0.130.oe2403sp3.aarch64
cp /boot/config-$(uname -r) .config
echo "CONFIG_VFIO_MDEV=m" >> .config
make modules_prepare

# 3. 编译 mdev 模块
make M=drivers/vfio/mdev modules

# 4. 安装模块
mkdir -p /lib/modules/$(uname -r)/extra
cp drivers/vfio/mdev/mdev.ko /lib/modules/$(uname -r)/extra/
xz /lib/modules/$(uname -r)/extra/mdev.ko
depmod -a

# 5. 配置自动加载
echo "mdev" >> /etc/modules-load.d/ascend.conf
echo "drv_vascend" >> /etc/modules-load.d/ascend.conf
```

### 3.5 系统配置

#### 禁用 multipath
```bash
# /etc/multipath.conf
blacklist {
    devnode "*"
}

# modprobe blacklist
echo "blacklist dm-multipath" >> /etc/modprobe.d/blacklist.conf

# dracut 配置
echo 'omit_drivers+=" dm-multipath "' >> /etc/dracut.conf.d/multipath.conf
dracut -f
```

#### 内核参数
```bash
grubby --update-kernel=ALL --args="console=ttyAMA0,115200 console=tty0 panic=10"
```

#### 创建用户
```bash
groupadd -g 1000 HwHiAiUser
useradd -g 1000 -u 1000 -d /home/HwHiAiUser -m HwHiAiUser
```

#### 环境变量
```bash
# /etc/profile.d/ascend.sh
export ASCEND_HOME=/usr/local/Ascend
export ASCEND_DRIVER_PATH=/usr/local/Ascend/driver
export ASCEND_TOOL_PATH=/usr/local/Ascend/tools
export PATH=$ASCEND_TOOL_PATH/bin:$PATH
export LD_LIBRARY_PATH=$ASCEND_DRIVER_PATH/lib:$LD_LIBRARY_PATH
```

#### BIOS 文件目录
```bash
mkdir -p /home/bios/driver/device
cp /usr/local/Ascend/driver/device/*.bin /home/bios/driver/device/
```

---

## 4. 文件系统状态

### 4.1 已创建文件
| 文件路径 | 说明 |
|---------|------|
| `docs/NPU-DRIVER-INSTALLATION.md` | NPU 驱动安装指南 |
| `docs/SYSTEM-CONFIGURATION.md` | 系统配置指南 |
| `docs/SKILL.md` | 故障排查经验 (更新 entries 10.6-10.11) |
| `ansible/playbooks/00-install-npu-driver.yml` | Ansible 安装 playbook |

### 4.2 远程服务器关键文件
| 文件路径 | 说明 |
|---------|------|
| `/etc/modules-load.d/ascend.conf` | 模块自动加载配置 |
| `/lib/modules/.../extra/mdev.ko.xz` | 手动编译的 mdev 模块 |
| `/usr/local/Ascend/version.info` | 驱动版本信息 |
| `/home/bios/driver/device/*.bin` | NPU 固件文件 |
| `/root/ascend-backup/` | 配置备份目录 |
| `/usr/local/sbin/ascend-disable` | 快速禁用脚本 |
| `/usr/local/sbin/ascend-enable` | 快速启用脚本 |
| `/root/ascend-backup/README.txt` | 回滚说明文档 |

### 4.3 Git 提交记录
- `fe556e7` - docs: 添加NPU驱动安装指南和系统配置文档
- `05831f0` - docs: 添加NPU驱动下载ZIP包的重要提醒

---

## 5. 当前状态

### 5.1 已完成
1. ✅ 操作系统升级到 SP3
2. ✅ NPU 驱动 25.5.1 安装 (DKMS)
3. ✅ NPU 固件 7.8.0.6.201 安装
4. ✅ MIN/ALIGN_DOWN 宏冲突修复
5. ✅ mdev 模块编译和安装
6. ✅ multipath 禁用配置
7. ✅ 串口控制台和 panic 参数配置
8. ✅ HwHiAiUser 用户创建
9. ✅ 环境变量配置
10. ✅ BIOS 文件目录创建
11. ✅ 回滚措施配置

### 5.2 待完成
1. ⏳ 重启系统验证 NPU 设备
2. ⏳ 运行 npu-smi info 验证 4 张 NPU
3. ⏳ 安装 CANN 软件栈 (下一步)

### 5.3 当前模块状态
```
drv_vascend           118784  0  ✓ 已加载
mdev                   24576  1 drv_vascend  ✓ 已加载
drv_vascend_stub       28672  7 ...  ✓ 已加载
vfio                   69632  2 vfio_iommu_type1,drv_vascend  ✓ 已加载
```

---

## 6. 回滚措施

### 6.1 启动菜单选项
| Index | 名称 | 说明 |
|-------|------|------|
| 0 | openEuler SP3 (No NPU) | **安全模式** - 禁用 NPU 模块 |
| 1 | 正常启动 | **默认** - 启用 NPU 模块 |
| 2 | SP1 内核 | 备用内核 |

创建安全启动项命令：
```bash
grubby --add-kernel=/boot/vmlinuz-6.6.0-144.0.0.130.oe2403sp3.aarch64 \
  --title="openEuler SP3 (No NPU)" \
  --copy-default \
  --args="module_blacklist=mdev,drv_vascend"
```

### 6.2 快速命令
```bash
# 禁用 NPU 模块
ascend-disable

# 启用 NPU 模块
ascend-enable
```

### 6.3 手动回滚步骤
```bash
# 禁用模块自动加载
mv /etc/modules-load.d/ascend.conf /etc/modules-load.d/ascend.conf.disabled

# 恢复模块自动加载
mv /etc/modules-load.d/ascend.conf.disabled /etc/modules-load.d/ascend.conf
```

### 6.4 紧急恢复流程
如果系统启动卡住：
1. 通过串口 console (ttyAMA0,115200) 或 BMC 访问
2. 在 GRUB 菜单选择 "openEuler SP3 (No NPU)"
3. 系统将以安全模式启动，不加载 NPU 模块
4. 登录后执行修复操作

---

## 7. 故障排查经验

### 7.1 drv_vascend 无法加载
**症状**: `Unknown symbol mdev_register_parent (err -2)`
**原因**: SP3 内核未编译 VFIO_MDEV 模块
**解决**: 从内核源码手动编译 mdev.ko

### 7.2 驱动编译失败
**症状**: `error: redefinition of 'MIN'`
**原因**: 驱动宏定义与内核冲突
**解决**: 重命名驱动中的 MIN/ALIGN_DOWN 宏

### 7.3 NPU 设备文件缺失
**症状**: `/dev/davinci*` 只有 manager，无实际设备
**原因**: drv_vascend 模块未加载
**解决**: 先加载 mdev，再加载 drv_vascend

### 7.4 固件加载失败
**症状**: `File copy error. name="/home/bios/driver/device/ascend_910b_syscfg.bin"`
**原因**: BIOS 文件目录不存在
**解决**: 创建 `/home/bios/driver/device/` 并复制固件文件

---

## 8. 下一步操作

### 8.1 立即执行
```bash
# 重启系统
ssh root@10.212.128.192 'reboot'

# 重启后验证 (等待 2 分钟)
ssh root@10.212.128.192 'ls /dev/davinci* && npu-smi info'
```

### 8.2 验证清单
1. 检查 4 个 NPU 设备文件: `/dev/davinci0` ~ `/dev/davinci3`
2. 运行 `npu-smi info` 显示 4 张 NPU 信息
3. 检查 `npu-smi info -t health` 健康状态
4. 验证模块自动加载: `lsmod | grep mdev`

### 8.3 后续安装
NPU 驱动验证成功后，继续安装：
1. CANN 软件栈 (torch-npu, mindspore 等)
2. Docker 环境
3. 训练/推理框架

---

## 9. Ansible Playbook

位于: `ansible/playbooks/00-install-npu-driver.yml`

可用于自动化部署到其他服务器。

---

## 10. 参考链接

- 华为昇腾社区: https://www.hiascend.com/
- CANN 下载: https://www.hiascend.com/software/cann/community
- 驱动文档: https://www.hiascend.com/document
- openEuler 文档: https://docs.openeuler.org/

---

## 11. 完整安装记录 (2026-04-03)

### 11.1 已安装组件
| 组件 | 版本 | 安装日期 |
|------|------|----------|
| 驱动 (driver) | 25.5.1 | 2026-04-03 |
| 固件 (firmware) | 7.8.0.6.201 | 2026-04-03 |
| CANN Toolkit | 9.0.0-beta.2 | 2026-04-03 |

### 11.2 问题修复记录

#### 问题1: mdev 模块缺失
- **错误**: `drv_vascend: Unknown symbol mdev_register_parent (err -2)`
- **原因**: openEuler SP3 内核未编译 VFIO_MDEV 模块
- **解决**: 从内核源码编译 mdev.ko 并配置自动加载

#### 问题2: npu-smi 报错 "dcmi module initialize failed. ret is -8005"
- **原因**: CANN Toolkit 未安装
- **解决**: 安装本地 CANN toolkit 9.0.0-beta.2

#### 问题3: 固件加载失败 "File copy error"
- **错误**: `File copy error. (dev_id=X; file=4; name="/home/bios/driver/device/ascend_910b_device_boot.img"; -2)`
- **原因**: 驱动代码硬编码路径 `/home/bios/driver/device/`，但固件默认在 `/usr/local/Ascend/driver/device/`
- **解决**: 复制固件到正确路径
```bash
mkdir -p /home/bios/driver/device
cp -r /usr/local/Ascend/driver/device/* /home/bios/driver/device/
```

### 11.3 最终验证结果
```
=== 系统状态 ===
  up 2 min, load average: 0.61

=== NPU状态 ===
| NPU   Name   | Health | Power(W) | Temp(C) |
| 910B4-1     | OK     | 71.6     | 39      |
| 910B4-1     | OK     | 74.0     | 40      |
| 910B4-1     | OK     | 77.2     | 40      |
| 910B4-1     | OK     | 72.6     | 40      |

=== 设备文件 ===
/dev/davinci_manager
/dev/davinci1 ~ davinci4
```

---

*文档生成时间: 2026-04-03*
*最后更新: CANN安装和固件路径修复完成，NPU驱动验证成功*