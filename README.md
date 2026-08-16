# DevOps Infrastructure Lab

Учебный DevOps-проект вокруг небольшого Flask-сервиса.

Проект постепенно развивается от ручного запуска приложения к контейнерной инфраструктуре с Nginx, PostgreSQL, Redis, Docker Compose, Ansible и CI/CD.

## Архитектура

```text
Client
  │
  ▼
Nginx :80
  │
  ▼
Flask backend :3000
  │
  ├── PostgreSQL 16
  └── Redis 7
```

`Nginx` смотрит наружу и принимает HTTP-запросы на порту `80`.

`backend` — Flask-приложение с API, проверками состояния и Prometheus-метриками.

`PostgreSQL` хранит данные приложения, `Redis` используется как внутренняя зависимость backend.

`migrator` — служебный контейнер для создания и восстановления резервных копий PostgreSQL.

## Инфраструктура

Весь основной стек описан в `compose.yaml`.

Используются две Docker-сети:

* `frontend` — `web` и `backend`;
* `backend` — `backend`, `db`, `redis` и `migrator`.

В сеть смотрит только Nginx. Порты backend, PostgreSQL и Redis наружу не публикуются.

Backend соединяет обе сети: принимает запросы от Nginx и обращается к PostgreSQL и Redis.

Для PostgreSQL используется named volume `pgdata`, поэтому данные сохраняются при пересоздании контейнера.

Backend собирается через multi-stage `Dockerfile` на Python 3.12. Финальный контейнер основан на `python:3.12-slim` и запускается не от `root`, а от пользователя `appuser`.

### Проверки состояния

У приложения есть две разные проверки.

`/api/health` показывает, что само Flask-приложение запущено:

```bash
curl http://localhost/api/health
```

`/api/ready` дополнительно проверяет, доступны ли PostgreSQL и Redis:

```bash
curl http://localhost/api/ready
```

PostgreSQL проверяется через `SELECT 1`, Redis — через `PING`.

Если одна из зависимостей недоступна, `/api/ready` возвращает HTTP `503`, при этом `/api/health` может продолжать отвечать `200`.

Compose использует `service_healthy`, поэтому backend запускается только после готовности PostgreSQL и Redis, а Nginx — после готовности backend.

### Конфигурация

Пароль PostgreSQL передаётся через `PG_PASSWORD` из локального `.env`.

Сам `.env` не хранится в Git и исключён из контекста сборки Docker. В репозитории лежит только `.env.example`.

Для PostgreSQL также настроены:

* проверка состояния через `pg_isready`;
* лимит памяти `512M`;
* ротация Docker-логов;
* постоянное хранение данных в volume.

### Метрики

Backend отдаёт Prometheus-метрики:

```bash
curl http://localhost/metrics
```

Сам Prometheus в текущий стек пока не входит.

### Ansible

Ansible используется для подготовки Linux-хоста и развёртывания приложения.

`ansible/setup-docker.yml`:

* устанавливает Docker;
* запускает и включает `docker.service`;
* создаёт `/srv/devops-infrastructure-lab`.

`ansible/deploy-app.yml` копирует необходимые файлы проекта в `/srv/devops-infrastructure-lab` и запускает:

```bash
docker compose up -d --build
```

Текущий `inventory.ini` рассчитан на локальную VM через `ansible_connection=local`.

### CI/CD

CI запускается при `push` и `pull_request`.

```text
checkout
   ↓
установка зависимостей
   ↓
сборка Docker image
   ↓
запуск backend
   ↓
проверка /api/health
```

CD запускается при создании Git-тега `v*`.

После успешной проверки образ backend публикуется в GitHub Container Registry:

```text
ghcr.io/aorevo/devops-infrastructure-lab:<tag>
```

Сейчас CD отвечает за сборку и публикацию образа. Автоматического развёртывания из GHCR на сервер пока нет.

## Структура проекта

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yml              # сборка и проверка backend
│       └── cd.yml              # публикация release-образа в GHCR
│
├── ansible/
│   ├── inventory.ini           # inventory для локальной VM
│   ├── setup-docker.yml        # подготовка Docker-хоста
│   └── deploy-app.yml          # развёртывание Compose stack
│
├── app/
│   ├── main.py                 # Flask API и проверки зависимостей
│   ├── requirements.txt        # Python-зависимости
│   └── templates/
│
├── infra/
│   └── nginx/
│       └── default.conf        # reverse proxy
│
├── legacy/                     # предыдущая версия инфраструктуры
├── compose.yaml                # текущий Compose stack
├── Dockerfile                  # образ backend
├── .env.example                # пример переменных окружения
└── README.md
```

В `legacy/` сохранён предыдущий этап проекта: ручной запуск Flask-инстансов, shell-скрипты и установка Nginx непосредственно на Linux-хост.

## Запуск

Создать локальный `.env`:

```bash
cp .env.example .env
```

Указать свой пароль PostgreSQL в `PG_PASSWORD`.

Запустить стек:

```bash
docker compose up -d --build
```

## Проверка работы

Проверить состояние контейнеров:

```bash
docker compose ps
```

Проверить, что приложение работает:

```bash
curl http://localhost/api/health
```

Ожидаемый ответ:

```json
{"status":"ok"}
```

Проверить доступность PostgreSQL и Redis:

```bash
curl http://localhost/api/ready
```

Ожидаемый ответ:

```json
{
  "postgres": "ok",
  "redis": "ok",
  "status": "ready"
}
```

Проверить метрики:

```bash
curl http://localhost/metrics
```

## Резервное копирование PostgreSQL

Для служебных команд используется Compose profile `tools`.

Создать резервную копию базы:

```bash
mkdir -p backups

docker compose run --rm migrator \
  pg_dump -h db -U postgres -d postgres \
  > backups/postgres-backup.sql
```

Восстановить базу из SQL-файла:

```bash
docker compose run --rm -T migrator \
  psql -h db -U postgres -d postgres \
  < backups/postgres-backup.sql
```

## Основные решения

* **В сеть смотрит только Nginx.** На хосте открыт только порт `80`; backend, PostgreSQL и Redis доступны внутри Docker-сетей.
* **Сервисы разведены по сетям.** Nginx видит backend, а PostgreSQL и Redis находятся во внутренней сети и напрямую Nginx недоступны.
* **Проверки приложения и его зависимостей разделены.** Можно отличить ситуацию «сам backend не работает» от «backend работает, но недоступна база или Redis».
* **Данные PostgreSQL не зависят от контейнера.** Они хранятся в `pgdata` и не пропадают после пересоздания `db`.
* **Backend работает не от root.** Для образа используется multi-stage build и отдельный пользователь `appuser`.
* **Развёртывание собрано в Ansible.** Подготовку хоста и запуск Compose stack не нужно повторять вручную по шагам.

## Что дальше

* поднять полный Docker Compose stack в CI и проверять взаимодействие Nginx, backend, PostgreSQL и Redis;
* привести CD к схеме, где сервер получает уже собранный Docker image из GHCR, а не собирает backend самостоятельно;
* добавить несколько практических Bash-скриптов для обслуживания проекта: проверка состояния сервисов, просмотр логов, backup базы;
* расширить диагностику контейнеров и Linux-хоста: использование CPU/RAM, место на диске, состояние сервисов и логов;
* после закрепления Docker и CI/CD перейти к базовому Kubernetes-развёртыванию этого же приложения.