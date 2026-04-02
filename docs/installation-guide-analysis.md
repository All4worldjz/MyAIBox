# 一体机部署文档分析 (K3s版本)

> 来源: 一体机部署文档-k3s.docx
> 分析时间: 2026-04-03

## 1. 部署前提

### 系统要求
- 操作系统: openEuler 24.03 (LTS-SP3)
- 端口要求: 7890, 5050

### 当前环境对比
| 项目 | 文档要求 | 当前环境 | 状态 |
|------|----------|----------|------|
| 操作系统 | openEuler 24.03 LTS-SP3 | openEuler 24.03 LTS-SP1 | ⚠️ 版本差异 |
| 端口7890 | 需要访问 | 未开放 | ❌ 待配置 |
| 端口5050 | 需要访问 | 未开放 | ❌ 待配置 |

## 2. 底座部署流程

### 2.1 数据同步
```bash
# 配置KS3访问凭证
cat > .ks3utilconfig << EOF
[Credentials]
language=CH
accessKeyID=AKXXXXXPg
accessKeySecret=OB0lXXXXXXXz5
endpoint=ks3-cn-beijing.ksyuncs.com
loglevel=debug
EOF

# 同步数据
./ks3util-linux-arm64-v2.14.1 --config-file .ks3utilconfig \
  sync ks3://gov-wps-ai-delivery-data/k3s/ ./k3s/ \
  --force --update-rule=2 \
  --checkpoint-dir=.ks3util_checkpoint --jobs=20
```

### 2.2 代码仓库
```
ssh://ezone.ksyun.com:23/ezone/gov-auto-delivery/gov_AI_delivery.git
```

### 2.3 环境安装
```bash
# 安装Anaconda
sh Anaconda3-2025.06-0-Linux-x86_64.sh
# 路径: /usr/local/anaconda3

# 创建虚拟环境
conda create -n aibox python=3.12
conda activate aibox

# 安装依赖
cd /opt/gov_AI_delivery
pip3.12 install -r requirements.txt

# 启动装机服务
python3.12 web/app.py
```

## 3. 应用部署

### 3.1 前置服务安装 (Playbook)
```yaml
# hyper-convergence/prerequisite.yml
# 需要配置:
# - 节点信息、IP
# - repo仓库地址
# - harbor仓库地址
# - Prometheus地址
# - 项目信息
# - 节点类型: controller
# - 架构: arm64
# - 版本
```

### 3.2 应用配置 (Playbook)
```yaml
# hyper-convergence/config.yml
# 同上配置参数
```

## 4. 脚本部署方式 (推荐)

### 4.1 目录结构
```
/opt/onesystem/
├── ai_install/          # AI服务安装
├── app_install/         # 应用安装 (最后执行)
├── ds_install/          # DeepSeek安装
├── hmjd_install/        # 黑马校对安装
├── lynx_install/        # Lynx测试安装
├── middle_install/      # 中间件安装
├── web_app/             # Web应用
└── weboffice_install/   # WPS Office安装
```

### 4.2 部署顺序
```bash
# 1. 部署DeepSeek
cd /opt/onesystem/ds_install
sh install-ds.sh

# 2. 部署黑马校对
cd /opt/onesystem/hmjd_install
sh install_hmjd.sh

# 3. 部署中间件
cd /opt/onesystem/middle_install
bash install-middle.sh http://192.170.5.65:30080 zhongtai

# 4. 部署WPS Office
cd /opt/onesystem/weboffice_install
bash install-weboffice.sh http://192.170.5.65:30080

# 5. 部署AI服务
cd /opt/onesystem/ai_install
bash install-AI.sh

# 6. 部署应用 (最后，需要授权)
cd /opt/onesystem/app_install
bash install-app.sh http://192.170.5.65:30080
```

### 4.3 验证
```bash
# 确认所有pod正常 (共45个)
kubectl -n middle get pod
```

## 5. 服务验证

### 5.1 黑马校对
- 后台管理: http://服务器IP:8733/cms/login.html
- 账号: admin/123456
- 校对系统: http://服务器IP:8733/user/login.html
- 账号: GYZH/123456
- 需要激活: 将机器码发给负责人获取授权码

### 5.2 WPS激活
- 激活页面: http://实际IP:39521
- 前台页面: http://实际IP:30080/plss/front/
- 初始化账号: buSys/zZT^aR#85G
- 套红模板账号: suwellWm/7B(LVe-BY&
- 管理员账号: admin/)e@mmYWS2(

### 5.3 参数配置
- 配置地址: http://实际IP:30080/plss/backend/operation/config/parameter
- 必须修改: "hm.check.host": "实际IP:8733"
- 性能测试参数: "nlp.algorithm.outline.draft.current.limit": "30"

## 6. 性能测试

```bash
# 并发测试 (约1小时)
kubectl -n lynx exec -it lynx-test -- /bin/sh -c "cd /opt/bf && lynx && cd /opt/wdx/ && python3 loop_run.py"

# 测试结果处理
kubectl -n lynx exec -it lynx-test -- /bin/sh -c "python lynx_log.py"

# 测试结果分析
kubectl -n lynx exec -it lynx-test -c mysql -- /bin/sh -c "mysql -uroot -p'Onesystem@kc' -D excel_analysis -e 'source /get_result.sql'"

# 清理测试资源
kubectl -n lynx delete pod lynx-test
ctr -n k8s.io image delete docker.io/library/lynx-mysql:v1 docker.io/library/lynx-python:v1
```

## 7. 待确认信息

| 信息项 | 文档示例 | 需要确认 |
|--------|----------|----------|
| KS3 accessKeyID | AKXXXXXPg | 实际密钥 |
| KS3 accessKeySecret | OB0lXXXXXXXz5 | 实际密钥 |
| repo仓库地址 | - | 实际地址 |
| harbor仓库地址 | 192.170.5.65:30080 | 实际地址 |
| Prometheus地址 | - | 实际地址 |
| 项目信息 | zhongtai | 实际项目名 |

## 8. 下一步行动

1. **确认环境信息**: 获取实际的仓库地址、密钥等
2. **开放端口**: 7890, 5050
3. **同步数据**: 从KS3下载部署包
4. **安装K3s**: 执行前置服务Playbook
5. **部署应用**: 按顺序执行安装脚本
6. **服务验证**: 激活和测试各服务

---

*本文档由Qwen Code自动分析生成*