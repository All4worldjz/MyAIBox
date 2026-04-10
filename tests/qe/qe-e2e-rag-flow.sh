#!/bin/bash
# KSC AIBox E2E RAG Workflow Test
echo "=== [Phase 3] E2E RAG Workflow Test ==="

# Step 1: Gateway Connectivity
echo "Checking Java Gateway (8064)..."
nc -z -w 2 127.0.0.1 8064
if [ $? -eq 0 ]; then
    echo "[INFO] Gateway 8064 is reachable."
else
    echo "[FAIL] Gateway 8064 is unreachable."
fi

# Step 2: Full Stack latency check (13B Model via AI Gateway)
echo "Probing AI Gateway (8000) for 13B inference..."
start_time=$(date +%s)
# Note: Just a probe, not expecting a full generation if weights aren't fully loaded
curl -s -m 10 -X POST http://127.0.0.1:8000/api/v1/chat/completions/13b   -H "Content-Type: application/json"   -d '{"messages": [{"role": "user", "content": "Test"}]}' > /tmp/qe_e2e_res.txt
res_code=$?
end_time=$(date +%s)
elapsed=$((end_time - start_time))

if [ $res_code -eq 0 ]; then
    echo "[PASS] AI Gateway responded in ${elapsed}s."
else
    echo "[FAIL] AI Gateway probe failed (Code: $res_code) after ${elapsed}s."
fi
