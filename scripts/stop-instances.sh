#!/bin/bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"

if [[ $# -eq 0 ]]; then
    echo -e "Использование\n $0 <имя_инстанса> [<имя инстанса> ...]\n"
    echo -e "\nПример:\n$0 backend-1 backend-2"
    exit 1
fi

while [[ $# -gt 0 ]]; do
    instance="$1"
    pid_file="$LOG_DIR/$instance.pid"

    echo "Проверяю $instance..."

    if [[ ! -f "$pid_file" ]]; then
        echo "PID-файл для $instance не найден"
        shift
        continue
    fi

    pid_backend=$(cat "$pid_file")

    if ! kill -0 "$pid_backend" 2>/dev/null; then
        echo "$instance уже не запущен. Удаляю устаревший PID-файл"
        rm -f "$pid_file"
        shift
        continue
    fi

    if [[ ! -r "/proc/$pid_backend/cmdline" ]]; then
        echo "Не удалось прочитать команду процесса $pid_backend"
        shift
        continue
    fi

    link_to_backend=$(tr '\0' ' ' < "/proc/$pid_backend/cmdline")

    if [[ "$link_to_backend" != *"app/main.py"* ]]; then
        echo "PID $pid_backend не принадлежит app/main.py. Пропускаю"
        shift
        continue
    fi

    kill "$pid_backend"
    rm -f "$pid_file"

    echo "$instance остановлен, PID: $pid_backend"

    shift
done