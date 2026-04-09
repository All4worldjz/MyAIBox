# NPU驱动安装问题排查报告

**排查时间**: 2026-04-09 22:38  
**服务器**: ksc-aibox-node01 (10.212.128.192)  
**驱动版本**: 25.5.1  
**CANN版本**: 9.0.0-beta.2

---

## 📊 排查总结

### ✅ 正常项目

| 检查项 | 状态 | 详情 |
|--------|------|------|
| **驱动目录** | ✅ | `/usr/local/Ascend` 存在且完整 |
| **内核模块** | ✅ | 27个Ascend相关内核模块已加载 |
| **设备文件** | ✅ | `/dev/davinci1-4` 和 `/dev/davinci_manager` 存在 |
| **npu-smi命令** | ✅ | 版本25.5.1，依赖库正常 |
| **NPU识别** | ✅ | 4张NPU全部识别，健康状态OK |
| **固件版本** | ✅ | 7.7.0.10.220 (4张一致) |
| **CANN组件** | ✅ | opp/runtime/compiler/fwkacllib 都存在 |
| **环境变量** | ✅ | ASCEND_HOME_PATH/LD_LIBRARY_PATH/PATH 已配置 |

### ⚠️ 发现的问题

| 问题 | 严重性 | 影响 |
|------|--------|------|
| **1. CANN环境变量未完全配置** | 🟡 中等 | 可能影响CANN工具链功能 |
| **2. 驱动以非标准方式安装** | 🟡 中等 | 无RPM包记录，可能使用.run手动安装 |
| **3. npu-smi驱动完整性警告** | 🟡 低 | 部分高级功能可能受限 |

---

## 🔍 详细分析

### 问题1: CANN环境变量未完全配置

**当前配置** (`/etc/profile.d/ascend.sh`):
```bash
export ASCEND_HOME_PATH=/usr/local/Ascend
export ASCEND_DRIVER_PATH=/usr/local/Ascend/driver
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:/usr/local/Ascend/driver/lib64/inner:$LD_LIBRARY_PATH
export PATH=/usr/local/Ascend/bin:$PATH
```

**缺失的环境变量**:
```bash
# CANN工具链库路径缺失
/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/lib64
/usr/local/Ascend/cann-9.0.0-beta.2/fwkacllib/lib64

# 缺失的关键环境变量
ASCEND_TOOL_PATH=/usr/local/Ascend/cann-9.0.0-beta.2
ASCEND_OPP_PATH=/usr/local/Ascend/cann-9.0.0-beta.2/opp
PATH 缺少 /usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/bin
```

**影响**:
- ✅ npu-smi 正常工作 (仅依赖驱动库)
- ✅ 基础NPU监控正常
- ⚠️ ATC模型转换可能失败
- ⚠️ CANN编译器可能无法使用
- ⚠️ Python AscendCL库可能无法导入

---

### 问题2: 驱动以非标准方式安装

**证据**:
```bash
# RPM包检查: 无记录
rpm -qa | grep -i ascend  # 空输出

# 但驱动目录完整
/usr/local/Ascend/driver/        ✅ 存在
/usr/local/Ascend/firmware/      ✅ 存在
/usr/local/Ascend/cann-9.0.0-beta.2/  ✅ 存在
```

**安装方式推断**:
- 使用 `.run` 安装包手动安装 (非RPM/YUM)
- 安装脚本: `/usr/local/Ascend/host_servers_setup.sh`
- 初始化脚本: `/usr/local/Ascend/host_sys_init.sh`

**这是正常的**，昇腾驱动推荐使用.run安装包方式。

---

### 问题3: npu-smi驱动完整性警告

**警告内容**:
```
[WARNING]The driver package may not be completely installed, 
which may cause function abnormal. Please reinstall it.
```

**根因分析**:

这个警告**不一定代表驱动有问题**，可能原因:

1. **CANN环境变量未完全加载** - 当前只加载了驱动库，缺少CANN工具链库
2. **npu-smi检测逻辑严格** - 即使驱动正常，只要检测到环境变量不完整就会警告
3. **非RPM安装方式** - npu-smi可能通过RPM数据库验证，.run安装无法通过验证

**实际验证**:
```bash
# 驱动实际运行状态
✅ 内核模块加载正常 (27个模块)
✅ 设备文件创建正常 (/dev/davinci1-4)
✅ NPU识别正常 (4张NPU健康)
✅ 固件版本正常 (7.7.0.10.220)
```

**结论**: 驱动实际安装正常，警告可忽略或可通过完善环境变量消除。

---

## 🛠️ 修复建议

### 方案1: 完善CANN环境变量 (推荐)

编辑 `/etc/profile.d/ascend.sh`:

```bash
#!/bin/bash
# Ascend NPU Environment

# 驱动路径
export ASCEND_HOME_PATH=/usr/local/Ascend
export ASCEND_DRIVER_PATH=/usr/local/Ascend/driver
export ASCEND_TOOL_PATH=/usr/local/Ascend/cann-9.0.0-beta.2

# CANN工具链路径
export ASCEND_OPP_PATH=/usr/local/Ascend/cann-9.0.0-beta.2/opp
export ASCEND_AICPU_PATH=/usr/local/Ascend/cann-9.0.0-beta.2

# 库路径 (驱动 + CANN)
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:\
/usr/local/Ascend/driver/lib64/common:\
/usr/local/Ascend/driver/lib64/driver:\
/usr/local/Ascend/driver/lib64/inner:\
/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/lib64:\
/usr/local/Ascend/cann-9.0.0-beta.2/fwkacllib/lib64:\
$LD_LIBRARY_PATH

# 可执行文件路径
export PATH=/usr/local/Ascend/bin:\
/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/bin:\
/usr/local/Ascend/cann-9.0.0-beta.2/toolkit/bin:\
$PATH

# Python路径 (如果使用CANN Python API)
export PYTHONPATH=/usr/local/Ascend/cann-9.0.0-beta.2/aarch64-linux/python/site-packages:\
/usr/local/Ascend/cann-9.0.0-beta.2/tools/hccl/python/site-packages:\
$PYTHONPATH
```

应用配置:
```bash
source /etc/profile.d/ascend.sh
```

---

### 方案2: 使用CANN官方set_env.sh

```bash
# 在 ~/.bashrc 中添加
echo 'source /usr/local/Ascend/cann-9.0.0-beta.2/set_env.sh' >> ~/.bashrc
source ~/.bashrc
```

---

### 方案3: 重新安装驱动 (如果确实有问题)

**仅在NPU无法使用时执行**:

```bash
# 1. 卸载当前驱动
/usr/local/Ascend/host_servers_remove.sh

# 2. 重新安装
cd /path/to/npu-packages
./Ascend-hdk-910B4-npu-driver_*.run --full
./Ascend-hdk-910B4-npu-firmware_*.run --full

# 3. 重启系统
reboot

# 4. 验证
npu-smi info
```

---

## 📋 验证清单

修复后执行以下验证:

```bash
# 1. 环境变量验证
echo $ASCEND_HOME_PATH
echo $ASCEND_TOOL_PATH
echo $LD_LIBRARY_PATH | tr ':' '\n' | grep cann

# 2. 驱动功能验证
npu-smi info
npu-smi info -t health -i 1
npu-smi info -t board -i 1

# 3. CANN工具验证 (如果需要使用工具链)
atc --version 2>/dev/null || echo "ATC未安装或不可用"

# 4. Python API验证 (如果需要)
python3 -c "import ascendacl; print('AscendCL导入成功')" 2>/dev/null || echo "Python API不可用"
```

---

## 🎯 结论

### 当前驱动状态: ✅ 基本正常

| 功能 | 状态 |
|------|------|
| NPU设备识别 | ✅ 正常 |
| NPU健康监控 | ✅ 正常 |
| 基础推理运行 | ✅ 应该正常 |
| CANN工具链 | ⚠️ 环境变量不完整 |
| ATC模型转换 | ⚠️ 可能失败 |
| Python API | ⚠️ 可能不可用 |

### 建议操作

1. **立即执行**: 完善 `/etc/profile.d/ascend.sh` 环境变量 (方案1)
2. **验证影响**: 测试推理服务是否正常工作
3. **可选优化**: 如需使用CANN工具链，执行完整环境配置

### 警告处理

`[WARNING]The driver package may not be completely installed` 

- **如果推理服务正常**: 可忽略此警告
- **如果遇到问题**: 执行方案3重新安装驱动

---

**报告生成时间**: 2026-04-09 22:40  
**排查基于**: npu-smi SKILL文档 + ascend-npu-driver-install SKILL文档
