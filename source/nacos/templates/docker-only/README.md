Docker 专用 Nacos 业务配置源。

约束:
- 只保留 Docker Compose 当前支持的业务服务: `plss-gateway`、`plss-system`、`plss-record`、`plss-document-process`、`plss-search`
- 所有 K8s Service 名已清洗为 Docker 服务名
- 所有外部 IP、历史 AI 中台地址和占位地址都必须替换为 Docker 服务名或显式禁用
- `rabbitmq`、`neo4j`、`convert-edms` 仍作为可选 Docker 依赖保留为服务名，不再使用 K8s 命名
- 不再打包 `plss-open`、`plss-plugin`、`plss-test`、`plss-sentinel-gateway`
- 不允许把旧的白名单路径、历史业务路由或内网 IP 再带回包内

打包:
```bash
./scripts/build-docker-nacos-package.sh
```
