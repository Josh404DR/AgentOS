import sys
import time

def print_progress(task_name, executor, progress, status_msg):
    bar_length = 20
    filled_length = int(bar_length * progress // 100)
    bar = '█' * filled_length + '░' * (bar_length - filled_length)
    
    output = (
        f"🔄 **AgentOS 任務執行中...**\n"
        f"───\n"
        f"📋 **任務**: `{task_name}`\n"
        f"👤 **執行者**: `{executor}`\n"
        f"⏳ **進度**: `[{bar}] {progress}%`\n"
        f"📢 **狀態**: {status_msg}\n"
        f"───\n"
        f"*最後更新: {time.strftime('%H:%M:%S')}*"
    )
    print(output)

if __name__ == "__main__":
    # 簡單測試用法: python monitor_ui.py "Sync Task" "Codex" 45 "Uploading files..."
    if len(sys.argv) > 4:
        print_progress(sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4])
