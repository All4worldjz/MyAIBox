# Huawei Ascend 910B NPU 自动化安装指南

> 使用 Ansible Playbook 实现一键自动化安装

---

## 1. 概述

本文档描述如何使用 Ansible Playbook 在 openEuler SP3 系统上自动化安装 Huawei Ascend 910B NPU 驱动、固件和 CANN Toolkit。

### 1.1 支持的组件版本

| 组件 | 版本 |
|------|------|
| 驱动 (driver) | 25.5.1 |
| 固件 (firmware) | 7.8.0.6.201 |
| CANN Toolkit | 9.0.0-beta.2 |

### 1.2 目标系统

- **操作系统**: openEuler 24.03 LTS-SP3
- **内核**: 6.6.0-144.0.0.130.oe2403sp3.aarch64
- **架构**: aarch64 (ARM64)
- **NPU**: Huawei Ascend 910B (4x)

---

## 2. 文件结构

```
MyAIBox/
├── ansible/
│   ├── playbooks/
│   │   └── 01-install-npu-full-stack.yml  # 主安装 playbook
│   ├── inventory-npu.ini                    # 主机清单
│   └── group_vars/
│       └── npu_servers.yml                 # 全局变量
├── npu-backup/
│   ├── driver/                             # 驱动文件
│   ├── firmware/                           # 固件文件
│   ├── cann-9.0.0-beta.2/                  # CANN Toolkit
│   ├── home/bios/driver/device/            # 设备固件
│   └── etc/                                # 配置文件
└── docs/
    └── NPU-ANSIBLE-INSTALLATION.md         # 本文档
```

---

## 3. 快速开始

### 3.1 前置条件

1. Ansible 2.9+
2. SSH 访问权限 (root)
3. 目标系统已安装 openEuler SP3

### 3.2 安装步骤

```bash
# 1. 进入项目目录
cd /path/to/MyAIBox

# 2. 编辑 inventory 文件，添加目标服务器
vim ansible/inventory-npu.ini

# 3. 运行安装 playbook
cd ansible
ansible-playbook -i inventory-npu.ini playbooks/01-install-npu-full-stack.yml

# 4. 重启系统
ssh root@<target-server> 'reboot'

# 5. 验证安装
ssh root@<target-server> 'npu-smi info'
```

---

## 4. 手动安装步骤 (非 Ansible)

如果需要手动安装，请按以下步骤操作：

### 4.1 环境准备

```bash
# 禁用 SELinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# 禁用防火墙
systemctl stop firewalld
systemctl disable firewalld

# 创建必要目录
mkdir -p /home/bios/driver/device
mkdir -p /var/log/ascend_seclog
mkdir -p /etc/ascend
```

### 4.2 安装驱动

```bash
# 复制驱动文件
cp -r npu-backup/driver/* /usr/local/Ascend/
cp -r npu-backup/firmware/* /usr/local/Ascend/

# 运行驱动安装脚本
cd /usr/local/Ascend/driver/tools
chmod +x install_npudrv.sh
./install_npudrv.sh --install-for-all
```

### 4.3 安装固件 (关键步骤)

```bash
# 复制固件到设备路径 (910B 必须)
cp -r /usr/local/Ascend/driver/device/* /home/bios/driver/device/

# 设置权限
chmod 644 /home/bios/driver/device/*

# 修复 SELinux 上下文
restorecon -Rv /home/bios/driver/device/
```

### 4.4 安装 CANN Toolkit

```bash
# 复制 CANN 文件
cp -r npu-backup/cann-9.0.0-beta.2 /usr/local/Ascend/

# 创建符号链接
ln -sf /usr/local/Ascend/cann-9.0.0-beta.2 /usr/local/Ascend/cann
ln -sf /usr/local/Ascend/cann/aarch64-linux/bin /usr/local/Ascend/cann/bin
```

### 4.5 配置模块自动加载

```bash
# 创建模块加载配置
cat > /etc/modules-load.d/ascend.conf << 'EOF'
mdev
drv_vascend
EOF

# 加载模块
modprobe mdev
modprobe drv_vascend
```

### 4.6 配置环境变量

```bash
# 全局环境变量
cat > /etc/profile.d/ascend-cann.sh << 'EOF'
export ASCEND_INSTALL_PATH=/usr/local/Ascend
export ASCEND_TOOLKIT_HOME=/usr/local/Ascend/cann
export PATH=$PATH:/usr/local/Ascend/cann/bin:/usr/local/Ascend/cann/compiler/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Ascend/cann/lib64
export PYTHONPATH=$PYTHONPATH:/usr/local/Ascend/cann/python/site-packages
EOF

# 加载环境变量
source /etc/profile.d/ascend-cann.sh

# root 用户环境变量
echo "source /usr/local/Ascend/cann/set_env.sh" >> /root/.bashrc
```

### 4.7 重启验证

```bash
# 重启系统
reboot

# 等待系统启动后验证
ssh root@<target-server> 'npu-smi info'
```

---

## 5. 排错指南

### 5.1 常见错误

#### 错误 1: mdev 模块缺失

**错误信息**:
```
drv_vascend: Unknown symbol mdev_register_parent (err -2)
```

**原因**: openEuler SP3 内核未编译 VFIO_MDEV 模块

**解决方案**:
```bash
# 从内核源码编译 mdev 模块
cd /usr/src/linux-$(uname -r)
make -C /lib/modules/$(uname -r)/build M=drivers/vfio/mdev modules
cp drivers/vfio/mdev/mdev.ko /lib/modules/$(uname -r)/extra/
depmod -a

# 重新加载模块
modprobe mdev
modprobe drv_vascend
```

#### 错误 2: npu-smi 报错 "dcmi module initialize failed. ret is -8005"

**错误信息**:
```
dcmi module initialize failed. ret is -8005
```

**原因**: CANN Toolkit 未安装

**解决方案**:
```bash
# 安装 CANN Toolkit
cd /root
unzip Ascend-cann-toolkit_9.0.0-beta.2_linux-aarch64.zip
chmod +x Ascend-cann-toolkit_9.0.0-beta.2_linux-aarch64.run
./Ascend-cann-toolkit_9.0.0-beta.2_linux-aarch64.run --full --quiet
```

#### 错误 3: 固件加载失败 "File copy error"

**错误信息**:
```
File copy error. (dev_id=X; file=4; name="/home/bios/driver/device/ascend_910b_device_boot.img"; -2)
```

**原因**: 驱动代码硬编码路径 `/home/bios/driver/device/`，但固件默认在 `/usr/local/Ascend/driver/device/`

**解决方案**:
```bash
# 复制固件到正确路径
mkdir -p /home/bios/driver/device
cp -r /usr/local/Ascend/driver/device/* /home/bios/driver/device/
chmod 644 /home/bios/driver/device/*
restorecon -Rv /home/bios/driver/device/

# 重新加载驱动
modprobe -r drv_vascend
modprobe drv_vascend
```

### 5.2 验证命令

```bash
# 检查模块加载
lsmod | grep -E "mdev|drv_vascend"

# 检查设备文件
ls -la /dev/davinci*

# 检查驱动版本
cat /usr/local/Ascend/version.info

# 检查固件版本
cat /usr/local/Ascend/firmware/version.info

# 检查 npu-smi
source /usr/local/Ascend/cann/set_env.sh
npu-smi info

# 检查 dmesg
dmesg | grep -E "ascend|davinci|d802" | tail -30
```

---

## 6. 备份与恢复

### 6.1 备份当前安装

```bash
# 在服务器上执行
ssh root@10.212.128.192 'tar -czf - -C /usr/local/Ascend driver firmware cann-9.0.0-beta.2' > npu-backup.tar.gz
ssh root@10.212.128.192 'tar -czf - -C / home/bios' >> npu-backup.tar.gz
```

### 6.2 使用 Ansible 备份

```bash
# 运行备份 playbook
ansible-playbook -i inventory-npu.ini playbooks/99-backup-npu.yml
```

---

## 7. 卸载

```bash
# 卸载 CANN
/usr/local/Ascend/cann/cann_uninstall.sh

# 卸载驱动
/usr/local/Ascend/driver/tools/install_npudrv.sh --uninstall

# 清理文件
rm -rf /usr/local/Ascend
rm -rf /home/bios
rm -f /etc/modules-load.d/ascend.conf
rm -f /etc/profile.d/ascend-cann.sh
```

---

## 8. 参考链接

- 华为昇腾社区: https://www.hiascend.com/
- CANN 下载: https://www.hiascend.com/software/cann
- Ansible 文档: https://docs.ansible.com/
- openEuler 文档: https://docs.openeuler.org/

---

*文档更新时间: 2026-04-03*
*版本: 1.0*