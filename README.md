# Server Handover Report

Учебный Linux-проект, который постепенно объединяет несколько миссий буткемпа:

- развёртывание приложения `DostavkaEda`;
- работа с конфигурацией, логами и отчётом для передачи смены;
- базовая подготовка, защита и мониторинг сервера;
- сетевой аудит, диагностика связности, DNS и firewall.

Репозиторий будет дополняться следующими работами по мере прохождения буткемпа.

## Что выполнено

На сервере был создан отдельный пользователь `appuser`, подготовлена структура каталогов приложения и развёрнут релиз `v1.0`.

Приложение запускается через `systemd` от пользователя `appuser`. Активная версия определяется символьной ссылкой `current`.

Также были подготовлены:

- права доступа к конфигурационным файлам;
- swap-файл;
- резервное копирование конфигурации;
- архивация старых логов;
- анализ access-лога;
- отчёт о деплое;
- отчёт для передачи смены;
- пользователь `deploy` и базовый hardening сервера;
- мониторинг заполненности диска;
- общий crontab для выполненных скриптов;
- сетевой аудит сервера и карта слушающих портов;
- проверка L3-связности, DNS, TCP/80 и HTTP;
- UFW с политикой `deny incoming` и ограничением PostgreSQL по подсети;
- автоматическая сборка сетевого паспорта.

## Структура репозитория

```text
server-handover-report/
├── configs/
│   ├── deploy-sudoers
│   └── jail.local
├── cron/
│   └── ops-jobs
├── scripts/
│   ├── archive-logs.sh
│   ├── backup-config.sh
│   ├── disk_watch.sh
│   ├── generate-handover.sh
│   └── generate-network-passport.sh
├── systemd/
│   └── dostavka.service
├── deploy-report-example.md
├── handover-example.md
├── network-passport-example.md
├── server_setup.md
└── README.md
```

## Структура приложения

```text
/srv/dostavka-eda/
├── config/
├── current -> releases/v1.0/
├── logs/
└── releases/
    └── v1.0/
        ├── config/
        │   ├── app.yaml
        │   └── db.yaml
        ├── README.md
        ├── server.sh
        └── static/
            └── index.html
```

## Systemd-сервис

Unit-файл:

```text
/etc/systemd/system/dostavka.service
```

Содержимое unit-файла находится в репозитории:

```text
systemd/dostavka.service
```

Сервис запускает:

```text
/srv/dostavka-eda/current/server.sh
```

Пользователь сервиса:

```text
appuser
```

После запуска сервис имеет состояние:

```text
active
enabled
```

## Отчёт о деплое

Во время развёртывания был создан файл `~/deploy-report.md`.

Пример отчёта находится в файле:

```text
deploy-report-example.md
```

Отчёт содержит:

- имя сервера;
- дату деплоя;
- версию релиза;
- путь к релизу;
- размер релиза;
- состояние сервиса.

## Работа с конфигурацией и логами

В директории `scripts/` находятся Bash-скрипты:

```text
scripts/
├── archive-logs.sh
├── backup-config.sh
├── disk_watch.sh
├── generate-handover.sh
└── generate-network-passport.sh
```

### backup-config.sh

Создаёт архив конфигурации приложения:

```text
~/backups/config-YYYY-MM-DD.tar.gz
```

### archive-logs.sh

Архивирует ротированные файлы:

```text
access.log.1 ... access.log.7
```

Архив сохраняется в:

```text
/srv/dostavka-eda/logs/archive/
```

### generate-handover.sh

Анализирует `access.log` и создаёт отчёт:

```text
~/handover.md
```

В отчёт входят:

- имя хоста;
- дата;
- количество запросов;
- пять URL с ошибками `500`;
- три самых активных IP;
- сетевой интерфейс и default gateway;
- результат L3-проверки default gateway;
- резолв `dostavka-eda.local`;
- HTTP-код локального web-сервиса;
- краткий итог.

Пример результата находится в файле:

```text
handover-example.md
```

### generate-network-passport.sh

Собирает сетевой паспорт в:

```text
~/passport/passport.md
```

Паспорт включает:

- слушающие TCP-порты через `ss -tlnp`;
- адрес внешнего интерфейса и default route;
- L3-проверку доступности default gateway;
- системный резолв через `getent` и DNS-проверку через `dig`;
- сравнение `getent` и `dig` для выявления локальной записи `/etc/hosts`;
- проверку TCP/80 через `nc`;
- HTTP-код через `curl`;
- итоговый `ufw status verbose`.

Пример результата и разбор найденных особенностей находятся в:

```text
network-passport-example.md
```

Важно: `0.0.0.0` в выводе `ss` означает, что сервис слушает на всех IPv4-интерфейсах, но это не гарантирует доступность извне — входящий трафик дополнительно фильтруется firewall.

### disk_watch.sh

Проверяет заполненность корневого раздела `/` и пишет warning в системный лог, если занято больше 80%.

## Сетевой аудит и firewall

В учебном стенде были зафиксированы интерфейс `eth0`, IPv4 `10.10.115.94/32` и default gateway `169.254.1.1`.

Проверки выполнялись по слоям:

- L3 — `ping`;
- DNS — `getent hosts` и `dig`;
- L4 — `nc -zv localhost 80`;
- L7 — `curl` к локальному web-сервису.

Локальный HTTP-сервис успешно ответил кодом `200`, а TCP-подключение к порту 80 завершилось `succeeded`.

UFW настроен по принципу default deny:

```text
Default: deny (incoming), allow (outgoing)
22/tcp  ALLOW IN  Anywhere
80/tcp  ALLOW IN  Anywhere
5432    ALLOW IN  10.0.1.0/24
```

Порт `5432` в зафиксированном стенде слушает только `127.0.0.1`. Поэтому правило UFW для `10.0.1.0/24` разрешает трафик на уровне firewall, но само приложение всё равно не будет доступно из подсети, пока не начнёт слушать на подходящем интерфейсе.

Порты `6379`, `3000` и `8080` слушают на `0.0.0.0`, однако отдельных разрешающих правил UFW для них нет, поэтому входящие подключения блокируются политикой `deny incoming`.

## Автоматический запуск

Общий вариант crontab находится в файле:

```text
cron/ops-jobs
```

Для него скрипты размещаются в `/opt/ops/`.

Настроены следующие запуски:

- `disk_watch.sh` — каждые пять минут;
- `backup-config.sh` — каждый день в 02:00;
- `archive-logs.sh` — каждое воскресенье в 03:00;
- `generate-handover.sh` — каждый день в 08:00.

Сетевой паспорт запускается вручную при аудите или перед передачей сервера:

```bash
/opt/ops/generate-network-passport.sh
```

## Подготовка сервера

Создан пользователь `deploy`, настроены вход по SSH-ключу, `sudo` без пароля, UFW, `chrony`, swap, Fail2ban и мониторинг диска.

Итоговый отчёт:

```text
server_setup.md
```

`server_setup.md` является снимком более ранней миссии по подготовке сервера. Актуальная конфигурация firewall из сетевой миссии зафиксирована отдельно в `network-passport-example.md`.

Конфигурационные файлы:

```text
configs/deploy-sudoers
configs/jail.local
```
