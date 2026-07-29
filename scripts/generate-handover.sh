#!/bin/bash

LOG_FILE="/srv/dostavka-eda/logs/access.log"
REPORT="$HOME/handover.md"

RESULT=$(
    awk '$9 == 500 {print $1}' "$LOG_FILE" \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -1
)

read -r N X <<< "$RESULT"

Y=$(
    awk -v ip="$X" '$9 == 500 && $1 == ip {print $7}' "$LOG_FILE" \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -1 \
        | awk '{print $2}'
)

GATEWAY=$(ip route | awk '/^default/ {print $3; exit}')
INTERFACE=$(ip route | awk '/^default/ {print $5; exit}')
IP_ADDRESS="unknown"

if [ -n "$INTERFACE" ]; then
    IP_ADDRESS=$(ip -br -4 addr show "$INTERFACE" 2>/dev/null | awk 'NR==1 {print $3}')
    IP_ADDRESS=${IP_ADDRESS:-unknown}
fi

if [ -n "$GATEWAY" ] && ping -c 1 -W 1 "$GATEWAY" >/dev/null 2>&1; then
    NETWORK_STATUS="OK"
else
    NETWORK_STATUS="FAIL"
fi

DOSTAVKA_ADDR=$(getent hosts dostavka-eda.local 2>/dev/null | awk 'NR==1 {print $1}')
DOSTAVKA_ADDR=${DOSTAVKA_ADDR:-"не резолвится"}

HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost 2>/dev/null || true)
HTTP_CODE=${HTTP_CODE:-000}

{
    echo "# Отчёт"
    echo
    echo "**Хост:** \`$(hostname)\`"
    echo
    echo "**Дата:** \`$(date +%F)\`"
    echo
    echo "**Всего запросов:** $(wc -l < "$LOG_FILE")"
    echo
    echo "## Топ URL по ошибкам 500"
    echo

    awk '$9 == 500 {print $7}' "$LOG_FILE" \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -5 \
        | awk '{printf "- `%s` — %s запросов\n", $2, $1}'

    echo
    echo "## Топ-3 IP по запросам"
    echo

    awk '{print $1}' "$LOG_FILE" \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -3 \
        | awk '{printf "- `%s` — %s запросов\n", $2, $1}'

    echo
    echo "## Сеть и связность"
    echo
    echo "- Интерфейс: \`${INTERFACE:-unknown}\` — \`$IP_ADDRESS\`"
    echo "- Default gateway: \`${GATEWAY:-unknown}\`"
    echo "- L3-связность с gateway: **$NETWORK_STATUS**"
    echo "- DNS \`dostavka-eda.local\`: \`$DOSTAVKA_ADDR\`"
    echo "- HTTP \`http://localhost\`: **$HTTP_CODE**"

    echo
    echo "## TL;DR"
    echo
    echo "Атака с IP $X: $N запросов, в основном 500 на URL $Y. Сеть до gateway: $NETWORK_STATUS, HTTP localhost: $HTTP_CODE."
} > "$REPORT"
