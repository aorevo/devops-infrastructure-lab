#!/bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PYTHON="$ROOT_DIR/.venv/bin/python"
APP="$ROOT_DIR/app/main.py"
LOG_DIR="$ROOT_DIR/logs"

if [[ ! -x "$PYTHON" ]]; then
    echo "Виртуальное окружение не найдено, запустите скрипт setup-app.sh"
    exit 1
fi

if [[ $# -eq 0 || $(( $# % 2 )) -ne 0 ]]; then
    echo -e "Использование:\n$0 <порт> <имя-инстанса> [<порт> <имя-инстанса> ...]\n"
    echo -e "\nПример:\n$0 4100 backend-1 7200 backend-2"
    exit 1
fi

mkdir -p "$LOG_DIR"

while [[ $# -gt 0 ]]; do
    port="$1"
    instance="$2"

    echo "Запускаю $instance на порту $port"

    PORT="$port" INSTANCE_ID="$instance" \
        nohup "$PYTHON" "$APP" \
        > "$LOG_DIR/$instance.log" 2>&1 &

    pid=$!

    echo "$pid" > "$LOG_DIR/$instance.pid"
    echo "PID: $pid"
    echo "Лог: logs/$instance.log"
    echo

    shift 2
done