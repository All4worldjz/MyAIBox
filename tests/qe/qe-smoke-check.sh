#!/bin/bash
# KSC AIBox Smoke Test Suite
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "=== [Phase 1] Port Connectivity Check ==="
ports=(9000 8000 8064 8848 5432 6379 1030 1031 1040 5377 5277)
for port in "${ports[@]}"; do
    nc -z -w 2 127.0.0.1 $port
    if [ $? -eq 0 ]; then
        echo -e "Port $port: ${GREEN}OPEN${NC}"
    else
        echo -e "Port $port: ${RED}CLOSED${NC}"
    fi
done

echo -e "\n=== [Phase 2] NPU Process Registration ==="
npu_count=$(npu-smi info -l | grep "Total Count" | awk '{print $4}')
echo "Total NPU Cards: $npu_count"
active_npu_procs=$(npu-smi info | grep -E "mindie|uvicorn" | wc -l)
if [ $active_npu_procs -ge 4 ]; then
    echo -e "NPU Compute: ${GREEN}ACTIVE ($active_npu_procs procs)${NC}"
else
    echo -e "NPU Compute: ${RED}INACTIVE (Expected >=4, Found $active_npu_procs)${NC}"
fi
