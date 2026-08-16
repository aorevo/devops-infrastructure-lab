#!/bin/bash

set -uo pipefail

found=0
found_healthy=0
found_unhealthy=0

while read -r state recv_q send_q local_address peer_address process_info; do

    pid_part="${process_info#*pid=}"
    pid_backend="${pid_part%%,*}"
    port_backend="${local_address##*:}"

    [[ -r "/proc/$pid_backend/cmdline" ]] || continue

    link_to_backend=$(tr '\0' ' ' < /proc/"$pid_backend"/cmdline)

    [[ "$link_to_backend" != *"app/main.py"* ]] && continue

    ((found += 1))

    echo -e "====Найдено приложение====\nPID: $pid_backend\nPORT: $port_backend\nCOMMAND: $link_to_backend\n"

    if status_code=$(curl -s --connect-timeout 2 -o /dev/null -w "%{http_code}" http://127.0.0.1:$port_backend/api/health); then
        if [[ $status_code -eq 200 ]]; then
            echo -e "Приложение запущено успешно\nHTTP: $status_code\nHEALTHY\n=====\n"
            ((found_healthy += 1))
        else
            echo -e "Внимание\nHTTP: $status_code\nUNHEALTHY\n=====\n"
            ((found_unhealthy += 1))
        fi
    else
        echo -e "Не удалось подключиться\n=====\n"
        ((found_unhealthy += 1))
    fi

done < <(ss -H -tlpn) 

if [[ "$found" -eq 0 ]]; then
    echo "Экземпляры приложения не найдены"
    exit 1
fi

if [[ "$found_unhealthy" -ne 0 ]]; then
    echo -e "Найдено $found_unhealthy UNHEALTHY экземпляров\n"
    exit 1
else
    echo -e "\n===Итог===\nВсе найденные экземпляры HEALTHY\nКоличество: $found_healthy"
    exit 0
fi