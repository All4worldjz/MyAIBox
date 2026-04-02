# 示例配置文件

本目录包含各种配置文件的示例，供参考和复制使用。

## 文件说明

| 文件 | 说明 |
|------|------|
| inventory-example | 主机清单示例 |
| group_vars-example.yml | 全局变量示例 |
| docker-daemon-example.json | Docker配置示例 |
| npu-numa-config-example.yaml | NPU NUMA配置示例 |

## 使用方法

1. 复制示例文件到对应位置
2. 根据实际环境修改配置
3. 执行相应的Playbook

```bash
# 复制并修改主机清单
cp examples/inventory-example ansible/inventory/hosts
vim ansible/inventory/hosts

# 复制并修改全局变量
cp examples/group_vars-example.yml ansible/group_vars/all.yml
vim ansible/group_vars/all.yml
```