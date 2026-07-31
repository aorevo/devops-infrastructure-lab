# Сетевой паспорт

## Открытые порты

```text
State  Recv-Q Send-Q Local Address:Port Peer Address:Port Process
LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=75,fd=6),...)
LISTEN 0      1          127.0.0.1:5432      0.0.0.0:*    users:(("nc",pid=56,fd=3))
LISTEN 0      32         127.0.0.1:53        0.0.0.0:*    users:(("dnsmasq",pid=64,fd=5))
LISTEN 0      1            0.0.0.0:6379      0.0.0.0:*    users:(("nc",pid=57,fd=3))
LISTEN 0      5            0.0.0.0:3000      0.0.0.0:*    users:(("python3",pid=53,fd=3))
LISTEN 0      5            0.0.0.0:8080      0.0.0.0:*    users:(("python3",pid=49,fd=3))
LISTEN 0      511             [::]:80           [::]:*    users:(("nginx",pid=75,fd=7),...)
```

Интерпретация адресов:

- `0.0.0.0` / `[::]` — сервис слушает на всех соответствующих интерфейсах; внешний доступ дополнительно контролируется firewall.
- `127.0.0.1` — сервис слушает только локально.

Наблюдения:

- nginx слушает `80/tcp` на IPv4 и IPv6;
- `5432` слушает только на loopback, поэтому правило UFW для `10.0.1.0/24` само по себе не делает сервис доступным из этой подсети;
- `6379`, `3000` и `8080` слушают на `0.0.0.0`, но отдельные ALLOW-правила для них отсутствуют, поэтому входящий доступ блокируется политикой `deny incoming`.

## Сетевые реквизиты

```text
eth0@if1420      UP             10.10.115.94/32 fe80::8827:11ff:fe46:67f9/64
default via 169.254.1.1 dev eth0
```

- Интерфейс: `eth0`
- IPv4: `10.10.115.94/32`
- Default gateway: `169.254.1.1`

## Связность и DNS

### L3

Сохранённая проверка:

```text
PING backend (127.0.0.1) 56(84) bytes of data.
64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.014 ms

1 packets transmitted, 1 received, 0% packet loss
```

`backend` резолвится в `127.0.0.1`, поэтому эта проверка подтверждает работу локального сетевого стека, но не доказывает достижимость default gateway. Генератор сетевого паспорта проверяет `169.254.1.1` отдельно.

### DNS

```text
getent hosts dostavka-eda.local
127.0.0.1       backend dostavka-eda.local admin.dostavka-eda.local api.dostavka-eda.local db.dostavka-eda.local www.dostavka-eda.local

dig +short dostavka-eda.local
127.0.0.1
```

Системный резолвер и DNS возвращают адрес для `dostavka-eda.local`.

Для `metrics.internal` получено расхождение:

```text
getent hosts metrics.internal
203.0.113.99    metrics.internal

dig +short metrics.internal
<нет результата>
```

Это указывает на локальную запись `/etc/hosts`, которой нет в DNS.

### Web: L4 и L7

```text
Connection to localhost (::1) 80 port [tcp/http] succeeded!
HTTP code: 200
```

TCP-порт 80 доступен локально, а HTTP-сервис отвечает кодом `200`.

## Firewall

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
5432                       ALLOW IN    10.0.1.0/24
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (v6)                ALLOW IN    Anywhere (v6)
```

Итог:

- SSH `22/tcp` и HTTP `80/tcp` разрешены извне;
- `5432` разрешён firewall только из подсети приложения `10.0.1.0/24`;
- Redis `6379` и backend-порты `3000`/`8080` не имеют разрешающих правил и закрываются default deny.
