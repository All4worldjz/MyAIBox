#!/usr/bin/env python3
"""
高速断点续传下载脚本 - 使用wget/curl优化
用法: python3 fast_download.py [--threads N]
"""

import os
import sys
import subprocess
import time
import signal

# ==================== 配置区 ====================
DOWNLOAD_URL = "https://wps-ai-ci-cd-data.ks3-cn-beijing.ksyuncs.com/ytj-install/3.7.0-arm64/AI_910B/ytj-install-3.7.0-arm64-AI_910B-20260408-126.tar?KSSAccessKeyId=AKLTqR35NbefRZ2DUPLCqOCC&Expires=1775728722&Signature=mEXoO2NXLA48j%2FdvOSvC9wZrstc%3D"
OUTPUT_DIR = "/ksc_aibox/source"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "ytj-install-3.7.0-arm64-AI_910B-20260408-126.tar")
LOG_FILE = os.path.join(OUTPUT_DIR, "download.log")
# ===============================================

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'

def log(msg, color=None):
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    msg = f"[{timestamp}] {msg}"
    if color:
        msg = f"{color}{msg}{Colors.NC}"
    print(msg, flush=True)
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(msg.replace('\033[0;31m', '').replace('\033[0;32m', '').replace('\033[1;33m', '').replace('\033[0;34m', '').replace('\033[0;36m', '').replace('\033[1;37m', '').replace('\033[0m', '') + '\n')
    except:
        pass

def format_size(size_bytes):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"

def check_tool(tool_name):
    """检查工具是否可用"""
    result = subprocess.run(['which', tool_name], capture_output=True, text=True)
    return result.returncode == 0

def download_with_wget():
    """使用wget下载，支持断点续传"""
    log("使用 wget 进行高速下载...", Colors.CYAN)
    log("wget 优势: 自动断点续传、稳定可靠", Colors.CYAN)
    print()
    
    cmd = [
        'wget',
        '-c',  # 断点续传
        '--tries=10',  # 重试10次
        '--retry-connrefused',  # 连接拒绝时重试
        '--waitretry=10',  # 重试间隔10秒
        '--timeout=120',  # 超时120秒
        '--progress=bar:force',  # 显示进度条
        '-O', OUTPUT_FILE,
        DOWNLOAD_URL
    ]
    
    log(f"开始下载...", Colors.GREEN)
    log(f"目标: {OUTPUT_FILE}", Colors.CYAN)
    print()
    
    try:
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, 
                                  universal_newlines=True, bufsize=1)
        
        last_line = ""
        for line in process.stdout:
            line = line.strip()
            if line:
                # 更新同一行的进度
                if '...' in line or '%' in line or 'MB' in line or 'GB' in line:
                    print(f'\r{Colors.CYAN}{line}{Colors.NC}', end='', flush=True)
                else:
                    print(f'{Colors.YELLOW}{line}{Colors.NC}', flush=True)
                last_line = line
        
        process.wait()
        print()
        
        if process.returncode == 0:
            log("\n下载完成!", Colors.GREEN)
            return True
        else:
            log(f"\n下载失败，退出码: {process.returncode}", Colors.RED)
            return False
            
    except KeyboardInterrupt:
        log("\n\n下载被中断，可以重新运行脚本继续下载", Colors.YELLOW)
        return False
    except Exception as e:
        log(f"\n下载出错: {e}", Colors.RED)
        return False

def download_with_curl():
    """使用curl下载，作为备选方案"""
    log("使用 curl 进行下载...", Colors.CYAN)
    print()
    
    cmd = [
        'curl',
        '-L',  # 跟随重定向
        '-C', '-',  # 断点续传
        '--retry', '10',  # 重试10次
        '--retry-delay', '10',  # 重试间隔
        '--speed-limit', '1000',  # 最低速度
        '--speed-time', '60',  # 速度限制时间
        '-o', OUTPUT_FILE,
        DOWNLOAD_URL
    ]
    
    log(f"开始下载...", Colors.GREEN)
    log(f"目标: {OUTPUT_FILE}", Colors.CYAN)
    print()
    
    try:
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  universal_newlines=True, bufsize=1)
        
        for line in process.stdout:
            line = line.strip()
            if line:
                print(f'\r{Colors.CYAN}{line}{Colors.NC}', end='', flush=True)
        
        process.wait()
        print()
        
        if process.returncode == 0:
            log("\n下载完成!", Colors.GREEN)
            return True
        else:
            log(f"\n下载失败，退出码: {process.returncode}", Colors.RED)
            return False
            
    except KeyboardInterrupt:
        log("\n\n下载被中断，可以重新运行脚本继续下载", Colors.YELLOW)
        return False
    except Exception as e:
        log(f"\n下载出错: {e}", Colors.RED)
        return False

def verify_file():
    """验证文件"""
    if not os.path.exists(OUTPUT_FILE):
        return False
    
    file_size = os.path.getsize(OUTPUT_FILE)
    log(f"\n文件大小: {format_size(file_size)}", Colors.CYAN)
    
    # 检查文件类型
    try:
        result = subprocess.run(['file', OUTPUT_FILE], capture_output=True, text=True)
        if 'tar' in result.stdout.lower() or 'gzip' in result.stdout.lower():
            log(f"文件类型: {result.stdout.strip()}", Colors.GREEN)
            return True
        else:
            log(f"警告: 文件类型可能不正确: {result.stdout.strip()}", Colors.YELLOW)
            return False
    except:
        pass
    
    return file_size > 0

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='高速断点续传下载工具')
    parser.add_argument('--tool', choices=['wget', 'curl'], default=None, help='指定下载工具')
    args = parser.parse_args()
    
    # 确保目录存在
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    log("=" * 70, Colors.WHITE)
    log("高速断点续传下载工具", Colors.WHITE)
    log("=" * 70, Colors.WHITE)
    log(f"URL: {DOWNLOAD_URL[:80]}...", Colors.CYAN)
    log(f"目标: {OUTPUT_FILE}", Colors.CYAN)
    print()
    
    # 检查已有文件
    if os.path.exists(OUTPUT_FILE):
        file_size = os.path.getsize(OUTPUT_FILE)
        if file_size > 0:
            log(f"发现部分文件: {format_size(file_size)}", Colors.YELLOW)
            log("将继续下载（断点续传）", Colors.GREEN)
            print()
    
    # 选择下载工具
    if args.tool:
        tool = args.tool
    elif check_tool('wget'):
        tool = 'wget'
    elif check_tool('curl'):
        tool = 'curl'
    else:
        log("错误: 未找到可用的下载工具 (wget/curl)", Colors.RED)
        sys.exit(1)
    
    log(f"使用下载工具: {tool}", Colors.GREEN)
    print()
    
    # 执行下载
    if tool == 'wget':
        success = download_with_wget()
    else:
        success = download_with_curl()
    
    # 验证文件
    if success and verify_file():
        log("\n" + "=" * 70, Colors.GREEN)
        log("下载成功!", Colors.GREEN)
        log("=" * 70, Colors.GREEN)
        log(f"文件: {OUTPUT_FILE}", Colors.CYAN)
        log(f"大小: {format_size(os.path.getsize(OUTPUT_FILE))}", Colors.CYAN)
        log("\n可以使用以下命令解压:", Colors.YELLOW)
        print(f"  {Colors.BLUE}cd {OUTPUT_DIR} && tar -xf {os.path.basename(OUTPUT_FILE)}{Colors.NC}")
        log("=" * 70, Colors.GREEN)
        return 0
    elif not success:
        log("\n下载未完成，可以重新运行脚本继续下载", Colors.YELLOW)
        return 1
    else:
        log("\n文件验证失败", Colors.YELLOW)
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        log("\n\n脚本被用户中断", Colors.YELLOW)
        sys.exit(1)
