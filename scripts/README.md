# 脚本目录

本目录包含本地执行的脚本文件。

## 文件说明

| 脚本 | 说明 |
|------|------|
| deploy.sh | 一键部署脚本 |

## deploy.sh 使用方法

```bash
# 显示帮助
./scripts/deploy.sh -h

# 列出所有Playbook
./scripts/deploy.sh -l

# 执行单个Playbook
./scripts/deploy.sh 01    # 目录创建
./scripts/deploy.sh 02    # 数据迁移
./scripts/deploy.sh 03    # 系统优化
./scripts/deploy.sh 04    # 健康检查

# 执行所有Playbook
./scripts/deploy.sh all

# 检查模式 (不实际执行)
./scripts/deploy.sh -c 03

# 详细输出
./scripts/deploy.sh -v 03
```

## 注意事项

1. 确保已配置SSH免密登录
2. 确保Ansible环境正确安装
3. 执行前建议先使用检查模式验证