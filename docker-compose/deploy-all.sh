#!/bin/bash
# ============================================================
# KSC AIBox - 一键部署脚本
# 版本: 2.0 (Docker原生部署)
# 创建时间: 2026-04-09
# 使用方法: ./deploy-all.sh
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 基础路径
BASE_DIR="/ksc_aibox"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${BASE_DIR}/docker-compose"
SECRETS_DIR="${BASE_DIR}/secrets"
SOURCE_DIR="${BASE_DIR}/source"

# ============================================================
# 函数定义
# ============================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root用户执行此脚本"
        exit 1
    fi
}

check_prerequisites() {
    log_info "检查部署前置条件..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装"
        exit 1
    fi
    log_success "Docker已安装: $(docker --version)"
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装"
        exit 1
    fi
    log_success "Docker Compose已安装: $(docker-compose --version)"
    
    # 检查NPU驱动
    if ! command -v npu-smi &> /dev/null; then
        log_warning "NPU驱动未安装，AI推理服务将无法使用"
    else
        NPU_COUNT=$(npu-smi info -l 2>/dev/null | grep "Total Count" | awk '{print $4}' || echo "0")
        log_success "NPU驱动已安装，检测到 ${NPU_COUNT} 张NPU"
    fi
    
    # 检查磁盘空间
    DISK_AVAILABLE=$(df -BG ${BASE_DIR} 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ -z "${DISK_AVAILABLE}" ] || [ ${DISK_AVAILABLE} -lt 1200 ]; then
        log_warning "磁盘空间不足 ${DISK_AVAILABLE}GB，建议至少1200GB"
    else
        log_success "磁盘空间充足: ${DISK_AVAILABLE}GB"
    fi
    
    # 检查内存
    MEM_TOTAL=$(free -g | grep Mem | awk '{print $2}')
    if [ ${MEM_TOTAL} -lt 200 ]; then
        log_warning "内存不足 ${MEM_TOTAL}GB，建议至少200GB"
    else
        log_success "内存充足: ${MEM_TOTAL}GB"
    fi
    
    echo ""
}

create_directories() {
    log_info "创建持久化存储目录..."
    
    # 中间件数据目录
    for service in postgres mysql redis nacos elasticsearch minio neo4j rabbitmq etcd slc; do
        mkdir -p ${BASE_DIR}/data/${service}/{data,logs,backup}
        chmod -R 755 ${BASE_DIR}/data/${service}
    done
    
    # 应用数据目录
    mkdir -p ${BASE_DIR}/apps/{logs,import,nlp-capacity-integration,ofd2json,html/aiPlatform}
    chmod 777 ${BASE_DIR}/apps/logs ${BASE_DIR}/apps/import
    
    # WPS数据目录
    mkdir -p ${BASE_DIR}/weboffice/{log,html}
    chmod 777 ${BASE_DIR}/weboffice/log ${BASE_DIR}/weboffice/html
    
    # 模型目录
    mkdir -p ${BASE_DIR}/models/{llm,embedding,vl,rerank,mineru}
    
    # 密码目录
    mkdir -p ${SECRETS_DIR}
    chmod 700 ${SECRETS_DIR}
    
    # 日志目录
    mkdir -p ${BASE_DIR}/logs/{postgres,mysql,redis,nacos,elasticsearch,minio,neo4j,rabbitmq,etcd,apps,wps,ai,nginx}
    
    # 备份目录
    mkdir -p ${BASE_DIR}/backup/{daily,weekly,monthly}
    
    # 脚本目录
    mkdir -p ${BASE_DIR}/scripts/{deploy,backup,restore,monitor}
    
    log_success "目录结构创建完成"
}

generate_secrets() {
    log_info "生成密码文件..."
    
    if [ ! -f "${SECRETS_DIR}/.env.secrets" ]; then
        # 从模板复制
        cp ${COMPOSE_DIR}/.env.secrets.template ${SECRETS_DIR}/.env.secrets
        chmod 600 ${SECRETS_DIR}/.env.secrets
        log_success "密码文件已生成: ${SECRETS_DIR}/.env.secrets"
        log_warning "请妥善保管密码文件，建议修改默认密码"
    else
        log_success "密码文件已存在: ${SECRETS_DIR}/.env.secrets"
    fi
    
    # 复制配置文件
    if [ ! -f "${SECRETS_DIR}/.env.config" ]; then
        cp ${COMPOSE_DIR}/.env.config ${SECRETS_DIR}/.env.config
        chmod 644 ${SECRETS_DIR}/.env.config
        log_success "配置文件已生成: ${SECRETS_DIR}/.env.config"
    fi
}

load_images() {
    log_info "加载Docker镜像..."
    
    if [ ! -d "${SOURCE_DIR}" ]; then
        log_warning "安装包目录不存在: ${SOURCE_DIR}"
        log_warning "请手动加载镜像: docker load -i <image.tar>"
        return
    fi
    
    IMAGE_COUNT=0
    
    # 加载中间件镜像
    if [ -d "${SOURCE_DIR}/middleware/images" ]; then
        for tar in ${SOURCE_DIR}/middleware/images/*.tar; do
            if [ -f "${tar}" ]; then
                echo "  加载: $(basename ${tar})"
                docker load -i ${tar}
                IMAGE_COUNT=$((IMAGE_COUNT + 1))
            fi
        done
    fi
    
    # 加载应用镜像
    if [ -d "${SOURCE_DIR}/app/images" ]; then
        for tar in ${SOURCE_DIR}/app/images/*.tar; do
            if [ -f "${tar}" ]; then
                echo "  加载: $(basename ${tar})"
                docker load -i ${tar}
                IMAGE_COUNT=$((IMAGE_COUNT + 1))
            fi
        done
    fi
    
    # 加载WPS镜像
    if [ -d "${SOURCE_DIR}/weboffice/images" ]; then
        for tar in ${SOURCE_DIR}/weboffice/images/*.tar; do
            if [ -f "${tar}" ]; then
                echo "  加载: $(basename ${tar})"
                docker load -i ${tar}
                IMAGE_COUNT=$((IMAGE_COUNT + 1))
            fi
        done
    fi
    
    # 加载AI镜像
    if [ -d "${SOURCE_DIR}/AI_910B/images" ]; then
        for tar in ${SOURCE_DIR}/AI_910B/images/*.tar; do
            if [ -f "${tar}" ]; then
                echo "  加载: $(basename ${tar})"
                docker load -i ${tar}
                IMAGE_COUNT=$((IMAGE_COUNT + 1))
            fi
        done
    fi
    
    log_success "镜像加载完成，共加载 ${IMAGE_COUNT} 个镜像"
}

init_databases() {
    log_info "初始化数据库..."
    
    # 等待PostgreSQL启动
    log_info "等待PostgreSQL启动..."
    sleep 10
    
    # 执行PostgreSQL初始化脚本
    if [ -d "${SOURCE_DIR}/postgres/templates" ]; then
        for sql in ${SOURCE_DIR}/postgres/templates/*.sql; do
            if [ -f "${sql}" ]; then
                log_info "执行SQL: $(basename ${sql})"
                docker exec -i postgres psql -U postgres -d plss < ${sql} 2>/dev/null || log_warning "SQL执行失败: $(basename ${sql})"
            fi
        done
    fi
    
    # 等待MySQL启动
    log_info "等待MySQL启动..."
    sleep 10
    
    # 执行MySQL初始化脚本
    if [ -f "${SOURCE_DIR}/mysql/templates/create_table.sql" ]; then
        log_info "执行MySQL建表脚本"
        source ${SECRETS_DIR}/.env.secrets
        docker exec -i mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" wps < ${SOURCE_DIR}/mysql/templates/create_table.sql 2>/dev/null || log_warning "MySQL建表脚本执行失败"
    fi
    
    log_success "数据库初始化完成"
}

import_nacos_config() {
    log_info "导入Nacos配置..."

    local package_path=""

    if [ -f "${SOURCE_DIR}/nacos/templates/nacos-config-docker-3.7.0.zip" ]; then
        package_path="${SOURCE_DIR}/nacos/templates/nacos-config-docker-3.7.0.zip"
    elif [ -f "${SOURCE_DIR}/nacos/templates/nacos-config-ytj-3.7.0.zip" ]; then
        package_path="${SOURCE_DIR}/nacos/templates/nacos-config-ytj-3.7.0.zip"
    fi
    
    if [ -n "${package_path}" ]; then
        log_info "等待Nacos启动..."
        sleep 15

        local import_dir="/tmp/nacos-config-import"
        local token=""

        rm -rf "${import_dir}"
        mkdir -p "${import_dir}"
        unzip -oq "${package_path}" -d "${import_dir}"

        # Docker Compose 环境下修正常见的 K8s 服务名。
        perl -0pi -e '
            s/redis-svc/redis/g;
            s/postgresql-service/postgres/g;
            s/minio-service/minio/g;
            s/slc-svc/slc/g;
            s/rabbitmq-svc/rabbitmq/g;
            s/elasticsearch-cluster-ss-0\.elasticsearch-cluster-svc-headless:9200,elasticsearch-cluster-ss-1\.elasticsearch-cluster-svc-headless:9200,elasticsearch-cluster-ss-2\.elasticsearch-cluster-svc-headless:9200/elasticsearch:9200/g;
            s/ocr-svc:8090/plss-doc-proc:8063/g;
        ' "${import_dir}"/COMMON/*.yml "${import_dir}"/SERVICE/*.yml

        token="$(curl -s -X POST "http://127.0.0.1:38848/nacos/v1/auth/users/login" \
            -d "username=nacos" \
            -d "password=nacos" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')"

        if [ -z "${token}" ]; then
            log_warning "Nacos登录失败，跳过配置导入"
            return
        fi

        for file in "${import_dir}"/COMMON/*.yml; do
            [ -f "${file}" ] || continue
            curl -s -X POST "http://127.0.0.1:38848/nacos/v1/cs/configs?accessToken=${token}" \
                --data-urlencode "dataId=$(basename "${file}")" \
                --data-urlencode "group=COMMON" \
                --data-urlencode "content@${file}" \
                --data-urlencode "type=yaml" >/dev/null || log_warning "COMMON 导入失败: $(basename "${file}")"
        done

        for file in "${import_dir}"/SERVICE/*.yml; do
            [ -f "${file}" ] || continue
            curl -s -X POST "http://127.0.0.1:38848/nacos/v1/cs/configs?accessToken=${token}" \
                --data-urlencode "dataId=$(basename "${file}")" \
                --data-urlencode "group=SERVICE" \
                --data-urlencode "content@${file}" \
                --data-urlencode "type=yaml" >/dev/null || log_warning "SERVICE 导入失败: $(basename "${file}")"
        done
        
        log_success "Nacos配置导入完成"
    else
        log_warning "Nacos配置文件不存在，跳过导入"
    fi
}

start_services() {
    log_info "启动所有服务..."
    
    cd ${COMPOSE_DIR}
    
    # 分层启动
    log_info "启动中间件服务..."
    docker-compose up -d postgres mysql redis nacos elasticsearch minio neo4j rabbitmq etcd slc
    
    log_info "等待中间件启动 (30秒)..."
    sleep 30
    
    log_info "启动WPS Office服务..."
    docker-compose up -d weboffice-nginx webword webet webwpp webpdf
    
    log_info "等待WPS服务启动 (20秒)..."
    sleep 20
    
    log_info "启动应用微服务..."
    docker-compose up -d plss-gateway plss-system-server plss-web plss-document-process-server plss-search-server nlp-capacity-integration ai-qingqiu-13b-api
    
    log_info "等待微服务启动 (30秒)..."
    sleep 30
    
    log_info "启动AI推理服务..."
    docker-compose up -d qingqiu-qwen3 qwen4b emb reranker
    
    log_info "等待AI模型加载 (60秒)..."
    sleep 60
    
    log_success "所有服务启动完成"
}

verify_services() {
    log_info "验证服务状态..."
    
    echo ""
    echo "=== 容器状态 ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo "=== 中间件健康检查 ==="
    
    # PostgreSQL
    if docker exec postgres pg_isready -U postgres &>/dev/null; then
        log_success "PostgreSQL: 正常"
    else
        log_error "PostgreSQL: 异常"
    fi
    
    # MySQL
    source ${SECRETS_DIR}/.env.secrets
    if docker exec mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" &>/dev/null; then
        log_success "MySQL: 正常"
    else
        log_error "MySQL: 异常"
    fi
    
    # Redis
    if docker exec redis redis-cli -a "${REDIS_PASSWORD}" ping &>/dev/null; then
        log_success "Redis: 正常"
    else
        log_error "Redis: 异常"
    fi
    
    # Nacos
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8848/nacos/v1/cs/configs | grep -q "200"; then
        log_success "Nacos: 正常"
    else
        log_error "Nacos: 异常"
    fi
    
    echo ""
    echo "=== NPU状态 ==="
    if command -v npu-smi &> /dev/null; then
        npu-smi info | grep -E "NPU|Health" || log_warning "NPU状态查询失败"
    fi
    
    echo ""
    echo "=== 资源使用 ==="
    echo "磁盘使用:"
    df -h ${BASE_DIR} | tail -1
    
    echo ""
    echo "内存使用:"
    free -h | grep Mem
    
    echo ""
}

print_access_info() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=========================================="
    echo "  部署完成！"
    echo "=========================================="
    echo ""
    echo "访问地址:"
    echo "  WPS前台:     http://${SERVER_IP}:30080"
    echo "  WPS激活:     http://${SERVER_IP}:39521"
    echo "  黑马校对:    http://${SERVER_IP}:8733"
    echo "  AI对话:      http://${SERVER_IP}:8122"
    echo "  Nacos:       http://${SERVER_IP}:38848/nacos"
    echo "  MinIO控制台: http://${SERVER_IP}:9090"
    echo "  Neo4j浏览器: http://${SERVER_IP}:7474"
    echo "  RabbitMQ管理: http://${SERVER_IP}:15672"
    echo ""
    echo "默认账号密码请查看: ${SECRETS_DIR}/.env.secrets"
    echo ""
    echo "常用命令:"
    echo "  查看服务状态:   cd ${COMPOSE_DIR} && docker-compose ps"
    echo "  查看日志:       cd ${COMPOSE_DIR} && docker-compose logs -f"
    echo "  停止服务:       cd ${COMPOSE_DIR} && docker-compose down"
    echo "  重启服务:       cd ${COMPOSE_DIR} && docker-compose restart <service>"
    echo ""
    echo "=========================================="
}

# ============================================================
# 主流程
# ============================================================

main() {
    echo ""
    echo "=========================================="
    echo "  KSC AIBox Docker 一键部署脚本"
    echo "  版本: 2.0"
    echo "=========================================="
    echo ""
    
    check_root
    check_prerequisites
    
    # 步骤1: 创建目录
    create_directories
    
    # 步骤2: 生成密码
    generate_secrets
    
    # 步骤3: 加载镜像
    load_images
    
    # 步骤4: 启动服务
    log_info "启动Docker Compose服务..."
    cd ${COMPOSE_DIR}
    docker-compose up -d
    
    # 步骤5: 等待服务启动
    log_info "等待服务启动 (60秒)..."
    sleep 60
    
    # 步骤6: 初始化数据库
    init_databases
    
    # 步骤7: 导入Nacos配置
    import_nacos_config
    
    # 步骤8: 验证服务
    verify_services
    
    # 打印访问信息
    print_access_info
}

# 执行主流程
main "$@"
