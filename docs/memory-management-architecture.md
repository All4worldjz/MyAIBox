# KSC AIBox 内存管理架构方案

## 1. 资源概况

### 硬件资源
```
内存: 256GB DDR4 (NUMA节点0: 128GB, NUMA节点1: 128GB)
NPU: 4张昇腾910B4-1, 每张64GB HBM (共256GB HBM)
```

### 应用内存需求

| 服务类型 | 内存需求 | 优先级 | NUMA亲和性 |
|----------|----------|--------|------------|
| 系统服务 | 8GB | P0 | 均衡 |
| MySQL | 8-16GB | P1 | 节点0 |
| PostgreSQL | 8-16GB | P1 | 节点1 |
| Redis | 4GB | P1 | 节点0 |
| Milvus | 16-32GB | P2 | 节点1 |
| Neo4j | 8GB | P2 | 节点0 |
| vLLM推理 | 32-128GB | P0 | 按NPU绑定 |
| AI Service | 4-8GB | P0 | 节点0 |
| WPS Office | 4GB | P2 | 节点1 |
| 其他应用 | 8GB | P3 | 均衡 |

**常规应用总需求: 68-104GB**

## 2. 内存管理策略

### 策略A: 动态HugePages (推荐)

```
优点:
- 按需分配，不浪费内存
- 系统自动管理
- 兼顾推理性能和其他应用

配置:
vm.nr_hugepages = 0              # 不预留
vm.hugetlb_dynamic_alloc = 1     # 启用动态分配
vm.max_map_count = 262144        # 支持大内存映射
```

### 策略B: 分级预留

```
优点:
- 保证推理服务性能
- 明确内存边界
- 便于容量规划

配置:
HugePages预留: 64GB (32000页)
常规应用可用: 192GB
推理服务可用: 64GB + 动态扩展
```

### 策略C: NUMA分区

```
优点:
- 避免跨NUMA访问
- 最大化性能
- 清晰的资源隔离

配置:
NUMA节点0 (128GB):
├── 系统服务: 8GB
├── 数据库: 32GB
├── NPU0/1推理: 64GB HugePages
└── 其他: 24GB

NUMA节点1 (128GB):
├── 向量数据库: 32GB
├── NPU2/3推理: 64GB HugePages
└── 其他: 32GB
```

## 3. 推荐方案: 混合动态策略

### 配置参数

```bash
# /etc/sysctl.d/99-ksc-aibox-memory.conf

# HugePages配置
vm.nr_hugepages = 32000              # 预留64GB基础
vm.hugetlb_dynamic_alloc = 1         # 启用动态分配
vm.hugepages_treat_as_movable = 1    # 允许迁移

# 内存管理
vm.max_map_count = 262144
vm.overcommit_memory = 1
vm.overcommit_ratio = 80
vm.swappiness = 10

# 透明大页
echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
echo madvise > /sys/kernel/mm/transparent_hugepage/defrag
```

### 内存分配表

```
┌─────────────────────────────────────────────────────────────┐
│                    内存分配方案 (256GB)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  预留HugePages: 64GB (NPU推理基础)                          │
│  ├── NPU0/1推理: 32GB (NUMA节点0)                           │
│  └── NPU2/3推理: 32GB (NUMA节点1)                           │
│                                                             │
│  动态HugePages: 按需分配 (最大64GB)                          │
│  └── 当推理服务需要时自动扩展                                │
│                                                             │
│  常规内存: 128GB+                                            │
│  ├── 系统服务: 8GB                                          │
│  ├── 数据库: 40GB                                           │
│  ├── 向量数据库: 32GB                                       │
│  ├── AI服务: 8GB                                            │
│  ├── WPS: 4GB                                               │
│  └── 缓冲: 36GB+                                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 4. NUMA亲和性配置

### NPU与NUMA绑定

```yaml
# NPU NUMA映射
npu_numa_mapping:
  npu0:
    numa_node: 0
    hugepages: 16000  # 32GB
    cpu_affinity: "0-31"
  npu1:
    numa_node: 0
    hugepages: 16000  # 32GB
    cpu_affinity: "0-31"
  npu2:
    numa_node: 1
    hugepages: 16000  # 32GB
    cpu_affinity: "32-63"
  npu3:
    numa_node: 1
    hugepages: 16000  # 32GB
    cpu_affinity: "32-63"
```

### 数据库NUMA绑定

```bash
# MySQL绑定到NUMA节点0
numactl --cpunodebind=0 --membind=0 mysqld

# PostgreSQL绑定到NUMA节点1
numactl --cpunodebind=1 --membind=1 postgres

# Milvus绑定到NUMA节点1
numactl --cpunodebind=1 --membind=1 milvus
```

## 5. 容器内存限制

### K3s Pod内存配置

```yaml
# vLLM推理服务
resources:
  limits:
    memory: "64Gi"
    hugepages-2Mi: "32Gi"
  requests:
    memory: "32Gi"
    hugepages-2Mi: "16Gi"

# MySQL
resources:
  limits:
    memory: "16Gi"
  requests:
    memory: "8Gi"

# Milvus
resources:
  limits:
    memory: "32Gi"
  requests:
    memory: "16Gi"
```

## 6. 监控与调优

### 内存监控脚本

```bash
#!/bin/bash
# 内存监控脚本

echo "=== 内存状态 ==="
echo "总内存: $(free -h | grep Mem | awk '{print $2}')"
echo "可用内存: $(free -h | grep Mem | awk '{print $7}')"
echo ""
echo "=== HugePages状态 ==="
grep HugePages /proc/meminfo
echo ""
echo "=== NUMA内存分布 ==="
numactl -H | grep -E "node [0-1]"
echo ""
echo "=== 内存压力 ==="
cat /proc/pressure/memory 2>/dev/null || echo "PSI未启用"
```

### 自动调优脚本

```bash
#!/bin/bash
# 根据负载自动调整HugePages

CURRENT_HUGEPAGES=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
MEM_AVAILABLE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

# 如果可用内存低于20GB，减少HugePages
if [ $MEM_AVAILABLE -lt 20971520 ]; then
    NEW_HUGEPAGES=$((CURRENT_HUGEPAGES - 8000))
    if [ $NEW_HUGEPAGES -ge 16000 ]; then
        sysctl -w vm.nr_hugepages=$NEW_HUGEPAGES
        echo "Reduced HugePages to $NEW_HUGEPAGES"
    fi
fi

# 如果可用内存高于100GB，增加HugePages
if [ $MEM_AVAILABLE -gt 104857600 ]; then
    NEW_HUGEPAGES=$((CURRENT_HUGEPAGES + 8000))
    if [ $NEW_HUGEPAGES -le 64000 ]; then
        sysctl -w vm.nr_hugepages=$NEW_HUGEPAGES
        echo "Increased HugePages to $NEW_HUGEPAGES"
    fi
fi
```

## 7. 实施步骤

### 步骤1: 调整HugePages配置

```bash
# 立即生效
sysctl -w vm.nr_hugepages=32000

# 持久化
echo "vm.nr_hugepages=32000" > /etc/sysctl.d/99-hugepages.conf
```

### 步骤2: 配置透明大页

```bash
echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
echo madvise > /sys/kernel/mm/transparent_hugepage/defrag
```

### 步骤3: 验证配置

```bash
# 检查HugePages
grep HugePages /proc/meminfo

# 检查可用内存
free -h

# 检查NUMA状态
numactl -H
```

## 8. 预期效果

| 指标 | 调整前 | 调整后 |
|------|--------|--------|
| HugePages预留 | 240GB | 64GB |
| 可用内存 | 4GB | 180GB+ |
| 推理性能 | 最优 | 优秀 |
| 应用兼容性 | 差 | 好 |

---

*方案设计: Qwen Code*
*创建时间: 2026-04-03*