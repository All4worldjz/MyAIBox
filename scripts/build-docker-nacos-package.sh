#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/source/nacos/templates/docker-only"
OUTPUT_ZIP="${ROOT_DIR}/source/nacos/templates/nacos-config-docker-3.7.0.zip"

validate_docker_only_config() {
  local -a scan_targets=(
    "${SOURCE_DIR}/COMMON"
    "${SOURCE_DIR}/SERVICE"
  )
  local -a forbidden_patterns=(
    '172\\.'
    '58\\.56\\.139\\.106'
    '42\\.236\\.74\\.152'
    'redis-svc'
    'postgresql-service'
    'minio-service'
    'neo4j-service'
    'rabbitmq-svc'
    'nacos-namespace'
    'nlp-capacity-integration'
    'web-reader'
    'plss-open'
    'plss-plugin'
    'plss-test'
    'hmjd'
    'xxx\\.xx\\.xx\\.xxx'
  )

  local pattern
  local failed=0
  for pattern in "${forbidden_patterns[@]}"; do
    if rg -n "${pattern}" "${scan_targets[@]}" >/dev/null 2>&1; then
      echo "forbidden pattern found in docker-only config: ${pattern}" >&2
      rg -n "${pattern}" "${scan_targets[@]}" || true
      failed=1
    fi
  done

  if [[ "${failed}" -ne 0 ]]; then
    exit 1
  fi
}

if [[ ! -d "${SOURCE_DIR}/COMMON" || ! -d "${SOURCE_DIR}/SERVICE" ]]; then
  echo "docker-only nacos config source is missing: ${SOURCE_DIR}" >&2
  exit 1
fi

validate_docker_only_config

rm -f "${OUTPUT_ZIP}"
(
  cd "${SOURCE_DIR}"
  zip -qr "${OUTPUT_ZIP}" .meta.yml COMMON SERVICE
)

echo "built: ${OUTPUT_ZIP}"
