# DevOps Infrastructure Lab

Учебный DevOps-проект, в котором небольшое Flask-приложение постепенно превращается в полноценный инфраструктурный стенд.

Проект используется для практики управления приложением, автоматизации локальных операций, настройки reverse proxy, балансировки нагрузки, контейнеризации и дальнейшего перехода к Docker Compose, CI/CD и оркестрации.

## О проекте

Flask-приложение упаковано в Docker-образ и запускается в нескольких контейнерах. Контейнеры используют один и тот же образ, но публикуют порт приложения на разные порты хоста.

Перед backend-контейнерами расположен Nginx, который выступает единой точкой входа и распределяет запросы между экземплярами приложения по алгоритму round-robin.

Текущая схема:

```text
                              ┌──────────────────────┐
                              │ backend-1 container  │
                              │ Flask :3000          │
                              └──────────▲───────────┘
                                         │
                                  host :3000
                                         │
Client ──► devops-pet.local:8080 ──► Nginx
                                         │
                                  host :3001
                                         │
                              ┌──────────▼───────────┐
                              │ backend-2 container  │
                              │ Flask :3000          │
                              └──────────────────────┘
```

Если один экземпляр приложения становится недоступен, Nginx продолжает направлять запросы на работающий backend.

## Реализовано

* Flask-приложение с HTML-страницей и API;
* конфигурация через переменные окружения;
* запуск нескольких экземпляров приложения;
* Bash-скрипты для запуска, обнаружения и остановки backend-процессов;
* отдельные логи и PID-файлы для экземпляров, запущенных напрямую на хосте;
* проверка состояния через health check;
* Nginx reverse proxy;
* локальное доменное имя `devops-pet.local`;
* round-robin балансировка нагрузки;
* обработка отказа одного backend;
* endpoint с метриками Prometheus;
* контейнеризация Flask-приложения;
* multi-stage Docker build;
* облегчённый runtime-образ на базе `python:3.12-slim`;
* запуск приложения внутри контейнера от непривилегированного пользователя;
* Docker HEALTHCHECK для `/api/health`;
* запуск нескольких контейнеров из одного Docker-образа;
* подключение Docker-контейнеров к существующему Nginx через опубликованные порты;
* `.dockerignore` для исключения локального окружения, `.env` и логов из build context.

## API

Приложение предоставляет несколько маршрутов:

| Маршрут       | Назначение                           |
| ------------- | ------------------------------------ |
| `/`           | Главная HTML-страница                |
| `/api/health` | Проверка состояния приложения        |
| `/api/info`   | Информация о приложении и экземпляре |
| `/metrics`    | Метрики в формате Prometheus         |

Пример ответа `/api/info`:

```json
{
  "app": "DevOps Pet Service",
  "hostname": "a1b2c3d4e5f6",
  "instance": "default",
  "version": "0.1.0"
}
```

При запуске нескольких контейнеров поле `hostname` позволяет увидеть, какой контейнер обработал запрос, и проверить работу балансировщика.

## Структура проекта

```text
devops-infrastructure-lab/
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── templates/
│       └── index.html
├── infra/
│   └── nginx/
│       ├── devops-pet.conf
│       └── check-curl.sh
├── scripts/
│   ├── setup-app.sh
│   ├── start-instances.sh
│   ├── discover-app.sh
│   └── stop-instances.sh
├── Dockerfile
├── .dockerignore
├── .gitignore
└── README.md
```

## Управление приложением без Docker

До контейнеризации приложение запускалось как несколько отдельных процессов на хосте.

### Подготовка окружения

```bash
./scripts/setup-app.sh
```

Скрипт создаёт виртуальное окружение и устанавливает зависимости приложения.

### Запуск backend

```bash
./scripts/start-instances.sh \
  3000 backend-1 \
  3001 backend-2
```

Аргументы передаются парами:

```text
<порт> <имя экземпляра>
```

Для каждого экземпляра создаются:

```text
logs/<instance>.log
logs/<instance>.pid
```

### Проверка состояния

```bash
./scripts/discover-app.sh
```

Скрипт анализирует слушающие TCP-сокеты, находит процессы приложения и проверяет endpoint `/api/health`.

В результате выводятся:

* PID процесса;
* порт;
* команда запуска;
* HTTP-код;
* состояние экземпляра.

### Остановка backend

```bash
./scripts/stop-instances.sh backend-1 backend-2
```

Перед остановкой скрипт проверяет, что PID действительно принадлежит процессу `app/main.py`.

## Docker

Приложение собирается в Docker-образ `server-handover:1.0`.

Dockerfile использует multi-stage build: зависимости устанавливаются в отдельном builder-stage, после чего в финальный образ переносятся установленные Python-пакеты и код приложения.

В runtime используется `python:3.12-slim`.

Внутри контейнера создаётся непривилегированный пользователь `appuser`, от имени которого запускается Flask-приложение.

Для проверки состояния контейнера используется Docker HEALTHCHECK, обращающийся к:

```text
http://localhost:3000/api/health
```

### Сборка образа

```bash
docker build -t server-handover:1.0 .
```

### Запуск двух backend-контейнеров

```bash
docker run -d --name backend-1 -p 3000:3000 server-handover:1.0
docker run -d --name backend-2 -p 3001:3000 server-handover:1.0
```

Оба контейнера создаются из одного образа:

```text
server-handover:1.0
        │
        ├── backend-1 → host:3000 → container:3000
        └── backend-2 → host:3001 → container:3000
```

### Проверка состояния контейнера

```bash
docker inspect --format='{{.State.Health.Status}}' backend-1
```

`--format — format — вывести только выбранное поле`.

Ожидаемый результат:

```text
healthy
```

Проверить пользователя внутри контейнера:

```bash
docker exec backend-1 whoami
```

Ожидаемый результат:

```text
appuser
```

## Nginx

Конфигурация Nginx находится в:

```text
infra/nginx/devops-pet.conf
```

Nginx работает на хостовой системе и принимает запросы на:

```text
http://devops-pet.local:8080
```

В конфигурации определена группа upstream:

```nginx
upstream devops_backend {
    server 127.0.0.1:3000;
    server 127.0.0.1:3001;
}
```

Порты `3000` и `3001` на хосте опубликованы Docker-контейнерами и ведут на порт `3000` соответствующего Flask-приложения внутри контейнера.

Таким образом, полный путь запроса выглядит так:

```text
Client
  ↓
Nginx :8080
  ↓
upstream
  ├── 127.0.0.1:3000 → backend-1 container → Flask :3000
  └── 127.0.0.1:3001 → backend-2 container → Flask :3000
```

Для локального разрешения имени используется запись:

```text
127.0.0.1 devops-pet.local
```

Проверить работу балансировки можно скриптом:

```bash
./infra/nginx/check-curl.sh
```

Также запрос можно выполнить напрямую через Nginx:

```bash
curl -H "Host: devops-pet.local" http://localhost:8080/api/info
```

`-H — header — передать HTTP-заголовок`.

Последовательные ответы позволяют увидеть, что запросы обрабатываются разными контейнерами.

## Отказоустойчивость

При работе двух контейнеров Nginx распределяет запросы между ними.

Если один backend становится недоступен, второй продолжает обслуживать запросы:

```text
backend-1 недоступен
        ↓
Nginx
        ↓
backend-2 продолжает обслуживать запросы
```

Если недоступны оба backend, Nginx возвращает:

```text
502 Bad Gateway
```

## Технологии

* Python;
* Flask;
* Bash;
* Linux;
* Nginx;
* Docker;
* Git;
* Prometheus client.

## Дальнейшее развитие

Следующие этапы проекта:

```text
Docker Compose
CI/CD
Ansible
Kubernetes
Terraform
Prometheus
Grafana
```