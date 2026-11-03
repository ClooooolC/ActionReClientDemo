#!/usr/bin/env bash
# 启动 ActionReClientDemo（PyQt5 客户端）
#
# 用法：
#   ./start.sh
#
# 可选环境变量：
#   PYTHON_BIN  指定 Python 解释器；默认优先使用 .venv/bin/python，否则使用 python3
#
# 应用会在后台运行，PID 写入 .run/app.pid，输出写入 .run/app.log。
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENTRY="$PROJECT_DIR/main.py"
RUN_DIR="$PROJECT_DIR/.run"
PID_FILE="$RUN_DIR/app.pid"
LOG_FILE="$RUN_DIR/app.log"

# 判断进程是否为本应用：既能避免重复启动，也能防止 PID 被复用时误判
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

# 已有实例在运行，直接返回成功，避免重复启动
if [ -f "$PID_FILE" ]; then
    running_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$running_pid" ] && is_app_process "$running_pid"; then
        echo "应用已在运行 (PID $running_pid)"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

if [ ! -f "$ENTRY" ]; then
    echo "错误：找不到入口文件 $ENTRY" >&2
    exit 1
fi

# 选择 Python 解释器
if [ -n "${PYTHON_BIN:-}" ]; then
    if ! resolved=$(command -v "$PYTHON_BIN" 2>/dev/null); then
        echo "错误：PYTHON_BIN 指定的解释器不存在：$PYTHON_BIN" >&2
        exit 1
    fi
    PYTHON_BIN=$resolved
elif [ -x "$PROJECT_DIR/.venv/bin/python" ]; then
    PYTHON_BIN="$PROJECT_DIR/.venv/bin/python"
else
    PYTHON_BIN=$(command -v python3 || true)
fi

if [ -z "${PYTHON_BIN:-}" ] || [ ! -x "$PYTHON_BIN" ]; then
    echo "错误：未找到 Python 解释器，请安装 python3 或通过 PYTHON_BIN 指定" >&2
    exit 1
fi

mkdir -p "$RUN_DIR"
# 应用按相对路径读取 data/，必须在项目根目录下运行
cd "$PROJECT_DIR"

printf '\n[%s] 启动应用：%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$PYTHON_BIN" "$ENTRY" >> "$LOG_FILE"

nohup "$PYTHON_BIN" "$ENTRY" </dev/null >> "$LOG_FILE" 2>&1 &
app_pid=$!
echo "$app_pid" > "$PID_FILE"

# 稍等片刻，确认进程没有立即退出（缺依赖、无图形环境、数据缺失等问题会在这里暴露）
sleep 1
if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "启动失败：应用已退出。日志末尾（${LOG_FILE}）：" >&2
    tail -n 20 "$LOG_FILE" >&2 || true
    rm -f "$PID_FILE"
    exit 1
fi

echo "应用已启动 (PID $app_pid)"
echo "日志文件：$LOG_FILE"
