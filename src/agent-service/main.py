import os
import subprocess
import yaml
import re
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Dict, List

app = FastAPI(title="KSC AIBox Integrated Hub", version="2.2.0")

BASE_DIR = "/ksc_aibox"
CONFIG_PATH = f"{BASE_DIR}/config/npu-topology.yml"
STATIC_DIR = "/app/static"

if os.path.exists(STATIC_DIR):
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

def get_npu_metrics():
    """解析 npu-smi info 的实时数据"""
    try:
        output = subprocess.check_output(["npu-smi", "info"], encoding='utf-8')
        # 正则提取 HBM 占用 (例如: 3555 / 65536)
        hbm_matches = re.findall(r"(\d+)\s+/\s+65536", output)
        metrics = []
        for i, hbm in enumerate(hbm_matches):
            metrics.append({
                "id": i,
                "hbm_used": f"{int(hbm)/1024:.1f} GB",
                "hbm_percent": f"{int(hbm)/655.36:.1f}%"
            })
        return metrics
    except:
        return []

@app.get("/")
async def read_index(): return FileResponse(f"{STATIC_DIR}/index.html")

@app.get("/admin")
async def read_admin(): return FileResponse(f"{STATIC_DIR}/dashboard.html")

@app.get("/api/v1/system/status")
async def get_system_status():
    npu = get_npu_metrics()
    containers = []
    try:
        res = subprocess.check_output(["docker", "ps", "--format", "{{.Names}}|{{.Status}}"], encoding='utf-8')
        for line in res.strip().split('\n'):
            if line: containers.append(line.split('|'))
    except: pass
    
    return {"npu": npu, "containers": containers}

@app.get("/api/v1/ai/topology")
async def get_topology():
    if not os.path.exists(CONFIG_PATH): return {"npu_topology": {}}
    with open(CONFIG_PATH, 'r') as f: return yaml.safe_load(f)

@app.post("/api/v1/ai/topology/apply")
async def update_topology(data: Dict):
    with open(CONFIG_PATH, 'w') as f: yaml.dump(data, f)
    cmd = f"cd {BASE_DIR}/ansible && ansible-playbook -i inventory/hosts playbooks/08-deploy-commercial-appliance-v2.yml"
    subprocess.Popen(cmd, shell=True)
    return {"status": "processing"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000)
