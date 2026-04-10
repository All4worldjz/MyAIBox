import os
import subprocess
import yaml
import re
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from typing import Dict

app = FastAPI(title="KSC AIBox Integrated Hub", version="2.4.0")

BASE_DIR = "/ksc_aibox"
CONFIG_PATH = f"{BASE_DIR}/config/npu-topology.yml"
STATIC_DIR = "/app/static"

if os.path.exists(STATIC_DIR):
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

def get_npu_metrics():
    """使用最稳健的模糊正则提取全量 NPU 显存占用"""
    try:
        # 使用 -l 获取更易解析的列表格式
        output = subprocess.check_output(["npu-smi", "info"], encoding='utf-8')
        # 匹配 "显存占用 / 总显存" 这种特征，例如 "3386 / 65536"
        # 排除掉表头中的 "0 / 0"
        all_matches = re.findall(r"(\d{3,})\s+/\s+65536", output)
        
        metrics = []
        for i, val in enumerate(all_matches):
            used_mb = int(val)
            metrics.append({
                "id": i,
                "hbm_used": f"{used_mb/1024:.1f} GB",
                "hbm_percent": f"{used_mb/65536*100:.1f}%"
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
    return {
        "npu": get_npu_metrics(),
        "containers": [line.split('|') for line in subprocess.check_output(["docker", "ps", "-a", "--format", "{{.Names}}|{{.Status}}"], encoding='utf-8').strip().split('\n') if line]
    }

@app.get("/api/v1/ai/topology")
async def get_topology():
    if not os.path.exists(CONFIG_PATH): return {"npu_topology": {}}
    with open(CONFIG_PATH, 'r') as f: return yaml.safe_load(f)

@app.post("/api/v1/ai/topology/apply")
async def update_topology(data: Dict):
    with open(CONFIG_PATH, 'w') as f: yaml.dump(data, f)
    cmd = f"cd {BASE_DIR}/docker-compose-v2 && docker-compose up -d"
    subprocess.Popen(cmd, shell=True)
    return {"status": "triggered"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000)
