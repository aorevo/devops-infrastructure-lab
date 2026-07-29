#!/bin/bash

set -euo pipefail

OUTPUT_DIR="$HOME/passport"
REPORT="$OUTPUT_DIR/passport.md"

mkdir -p "$OUTPUT_DIR"

DEFAULT_ROUTE=$(ip route | awk '/^default/ {print; exit}')
GATEWAY=$(awk '{print $3}' <<< "$DEFAULT_ROUTE")
INTERFACE=$(awk '{print $5}' <<< "$DEFAULT_ROUTE")
IP_ADDRESS="unknown"

if [ -n "$INTERFACE" ]; then
    IP_ADDRESS=$(ip -br -4 addr show "$INTERFACE" 2>/dev/null | awk 'NR==1 {print $3}')
    IP_ADDRESS=${IP_ADDRESS:-unknown}
fi

if [ -n "$GATEWAY" ] && ping -c 2 -W 1 "$GATEWAY" >/dev/null 2>&1; then
    L3_STATUS="OK"
else
    L3_STATUS="FAIL"
fi

DOSTAVKA_GETENT=$(getent hosts dostavka-eda.local 2>/dev/null || true)
DOSTAVKA_DIG=$(dig +short dostavka-eda.local 2>/dev/null || true)
METRICS_GETENT=$(getent hosts metrics.internal 2>/dev/null || true)
METRICS_DIG=$(dig +short metrics.internal 2>/dev/null || true)
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost 2>/dev/null || true)
HTTP_CODE=${HTTP_CODE:-000}
NC_RESULT=$(nc -zv localhost 80 2>&1 || true)

{
    echo "# Сетевой паспорт"
    echo
    echo "## Открытые порты"
    echo
    echo '```text'
    ss -tlnp 2>&1 || true
    echo '```'
    echo
    echo "- \`0.0.0.0\` / \`[::]\` — сервис слушает на всех соответствующих интерфейсах; фактический внешний доступ зависит от firewall."
    echo "- \`127.0.0.1\` — сервис доступен только локально."

    echo
    echo "## Сеть и связность"
    echo
    echo "- Интерфейс: \`${INTERFACE:-unknown}\` — \`$IP_ADDRESS\`"
    echo "- Default gateway: \`${GATEWAY:-unknown}\`"
    echo "- L3-связность с gateway: **$L3_STATUS**"
    echo
    echo "### DNS dostavka-eda.local"
    echo
    echo '```text'
    echo "getent hosts dostavka-eda.local"
    printf '%s\n' "${DOSTAVKA_GETENT:-<нет результата>}"
    echo
    echo "dig +short dostavka-eda.local"
    printf '%s\n' "${DOSTAVKA_DIG:-<нет результата>}"
    echo '```'

    echo
    echo "### Проверка /etc/hosts: metrics.internal"
    echo
    echo '```text'
    echo "getent hosts metrics.internal"
    printf '%s\n' "${METRICS_GETENT:-<нет результата>}"
    echo
    echo "dig +short metrics.internal"
    printf '%s\n' "${METRICS_DIG:-<нет результата>}"
    echo '```'

    echo
    echo "### Web"
    echo
    echo '```text'
    printf '%s\n' "$NC_RESULT"
    echo "HTTP code: $HTTP_CODE"
    echo '```'

    echo
    echo "## Firewall"
    echo
    echo '```text'
    ufw status verbose 2>&1 || true
    echo '```'
} > "$REPORT"

printf 'Network passport written to %s\n' "$REPORT"
