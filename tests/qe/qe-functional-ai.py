import requests
import sys

def test_endpoint(name, url, payload):
    print(f"Testing {name}...")
    try:
        r = requests.post(url, json=payload, timeout=30)
        if r.status_code == 200:
            print(f"  [PASS] {name} responds 200 OK")
            return True
        else:
            print(f"  [FAIL] {name} returns {r.status_code}: {r.text[:100]}")
            return False
    except Exception as e:
        print(f"  [ERROR] {name} connection failed: {e}")
        return False

# 1. Embedding Test
emb_ok = test_endpoint("Embedding (BGE)", "http://127.0.0.1:5377/v1/embeddings", 
                       {"model": "bge-large-zh-v1.5", "input": "测试"})

# 2. Reranker Test
rerank_ok = test_endpoint("Reranker", "http://127.0.0.1:5277/v1/rerank", 
                          {"query": "什么是一体机", "documents": ["这是一款AI一体机"]})

# 3. Main Model (Qwen 14B)
qwen_ok = test_endpoint("Main Model (14B)", "http://127.0.0.1:8000/api/v1/chat/completions/13b", 
                        {"model": "qwen", "messages": [{"role": "user", "content": "你好"}]})

if not (emb_ok and rerank_ok and qwen_ok):
    sys.exit(1)
