# KSC AIBox 商用一体机终极架构设计 (V2.0)

> **文档状态**: Approved
> **日期**: 2026-04-09
> **目标定位**: 面向政企客户的“开箱即用” (Out-of-the-Box) 商业级 AI 一体机
> **核心指标**: 支持 200 用户 / 10 并发，极速 RAG 检索与公文写作，支持零代码交付与傻瓜式运维。

## 1. 架构演进与底座重构 (The Foundation)

### 1.1 摒弃 K3s，拥抱纯原生 Docker Compose
*   **重构动因**：单机物理节点运行 K8s/K3s 会带来无谓的内存开销（10GB+）、复杂的虚拟网络损耗（Flannel），以及极高的客户现场排障门槛。
*   **终极方案**：全面转向 Docker Compose。通过 `HostPath` 直接映射 NVMe 物理磁盘，实现数据库与 AI 模型 I/O 的零损耗；利用 Docker 原生内网实现微服务互通。

### 1.2 存储安全与冷热分离
*   **硬件规划建议**：系统与核心 DB/模型存放在 NVMe SSD (高性能)；客户海量上传文件 (MinIO) 存放在大容量 SATA RAID 阵列。
*   **外挂与加密**：支持 OOBE 阶段挂载客户内网 NAS；底层实施 LUKS 块级数据加密，保障政企数据绝对安全。

## 2. 面向高并发的 NPU 算力矩阵拓扑 (Compute Topology)

针对 4 张华为 Ascend 910B (64GB HBM)，设计了“业务隔离、动态路由、KV Cache 极度充裕”的拓扑矩阵，完美抗载 10 并发长文本 RAG：

*   **⚡ 卡 1 (`/dev/davinci1`)：主干生产力**
    *   部署：`qingqiu-qwen3` (13B, 实例A)
    *   显存占用 ~26GB，剩余 38GB 用于长文本 KV Cache。
*   **⚡ 卡 2 (`/dev/davinci2`)：多模态与检索枢纽**
    *   部署：`qwen4b` (OCR/版式) + `emb` (向量) + `reranker` (重排)
    *   显存极度宽裕，确保检索链路无延迟。
*   **⚡ 卡 3 (`/dev/davinci3`)：高并发负载均衡**
    *   部署：`qingqiu-qwen3` (13B, 实例B)
    *   通过内部 AI Gateway 将公文生成请求 Load Balance 到卡 1 和卡 3，双卡 76GB 缓存池轻松应对突发长文本生成。
*   **⚡ 卡 4 (`/dev/davinci4`)：问答引擎专区**
    *   部署：`DeepSeek-R1-Distill-Qwen` (14B)
    *   使用 vLLM 引擎原生拉起，独立显存，提供极速思维链推理体验。

## 3. 工业级交付与运维体系 (Day-2 Operations)

### 3.1 三位一体产品门户 (The Portals)
1.  **OOBE 初始化向导 (Zero-Console Setup)**：设备通电后通过浏览器进行 IP、License、LDAP 及外部存储挂载的图形化向导配置，一键点火初始化所有服务。
2.  **Admin Web Console (全局控制台)**：IT 管理员的驾驶舱。可视化展示 4 张 NPU 的温度/负载，提供服务启停、OTA 固件升级包上传、SOS 日志一键导出、出厂重置功能。
3.  **用户门户 (User Workspace)**：供 200 名员工使用的卡片式融合工作台，集成 AI 写作、文档检索和智能问答。

### 3.2 零代码系统集成 (Integration)
*   引入 **Keycloak** 作为统一身份认证枢纽 (Identity Broker)。
*   向下对所有 Java 微服务下发标准 JWT Token，向上在 Admin Console 提供图形化表单对接客户现有的 AD 域/LDAP/企业微信，杜绝现场二次开发。

### 3.3 三层自愈架构 (Self-Healing)
1.  **容器级**：Docker 配合 `healthcheck` 与 `restart: always` 应对进程级假死。
2.  **服务级**：常驻 `aibox-watchdog` 脚本，监控 Gateway 端口与 NPU 心跳，异常时自动重置容器网络或驱动。
3.  **系统级兜底**：当 NPU 连续报告硬件离线或严重报错码时，触发操作系统底层 `reboot` 物理重启。

## 4. 成本与 ROI 控制

*   **硬件成本**：极限压榨 4 张 910B 性能，避免了为了并发而盲目增加 NPU 数量的开销。
*   **研发成本**：摒弃 K8s，使用 Ansible + Docker Compose，降低后续迭代与排错门槛。
*   **实施成本**：通过 OOBE 和 Keycloak 实现标准化零代码交付，实施工程师无需敲打 Linux 命令即可完成进场安装。
