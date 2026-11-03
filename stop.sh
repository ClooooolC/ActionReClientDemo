#!/usr/bin/env bash
# 停止由 start.sh 启动的 ActionReClientDemo
#
# 用法：
#   ./stop.sh
#
# 可选环境变量：
#   STOP_TIMEOUT  等待进程退出的秒数（默认 10）；超时后发送 SIGKILL 强制结束
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENTRY="$PROJECT_DIR/main.py"
RUN_DIR="$PROJECT_DIR/.run"
PID_FILE="$RUN_DIR/app.pid"
STOP_TIMEOUT=${STOP_TIMEOUT:-10}

# 与 start.sh 一致：确认 PID 对应的确实是本应用，避免 PID 复用时误杀其他进程
is_app_process() {
    local pid=$1
    local cmd
    kill -0 "$pid" 2>/dev/null || return 1
    cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
    case "$cmd" in
        *"$ENTRY"*) return 0 ;;
        *) return 1 ;;
    esac
}

if [ ! -f "$PID_FILE" ]; then
    echo "应用未运行（没有 PID 文件）"
    exit 0
fi

pid=$(cat "$PID_FILE" 2>/dev/null || true)
if [ -z "$pid" ] || ! is_app_process "$pid"; then
    rm -f "$PID_FILE"
    echo "应用未运行（PID 文件已过期，已清理）"
    exit 0
fi

echo "正在停止应用 (PID $pid)…"
kill -TERM "$pid" 2>/dev/null || true

# 等待进程退出，最多 STOP_TIMEOUT 秒
waited=0
limit=$((STOP_TIMEOUT * 10))
while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$limit" ]; do
    sleep 0.1
    waited=$((waited + 1))
done

if kill -0 "$pid" 2>/dev/null; then
    echo "应用未在 ${STOP_TIMEOUT} 秒内退出，强制结束 (PID $pid)" >&2
    kill -KILL "$pid" 2>/dev/null || true
    sleep 0.5
fi

if kill -0 "$pid" 2>/dev/null; then
    echo "停止失败：进程 $pid 仍在运行" >&2
    exit 1
fi

rm -f "$PID_FILE"
echo "应用已停止 (PID $pid)"
