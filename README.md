# DevOps Infrastructure Lab

DevOps-проект для практики контейнеризации, сетевого взаимодействия сервисов, reverse proxy и CI/CD.

Приложение состоит из Flask backend, Nginx, PostgreSQL и Redis. Вся инфраструктура запускается через Docker Compose.

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

Используются две Docker-сети:

* `frontend` — Nginx и backend;
* `backend` — backend, PostgreSQL и Redis.

PostgreSQL и Redis не публикуют порты наружу.

## Стек

* Python 3.12
* Flask
* Nginx
* Docker
* Docker Compose
* PostgreSQL 16
* Redis 7
* Prometheus Client
* GitHub Actions
* GitHub Container Registry
* Ansible

## Реализовано

* Flask REST API;
* Nginx reverse proxy;
* Docker Compose;
* разделение сервисов по Docker-сетям;
* PostgreSQL с persistent volume;
* Redis;
* healthcheck контейнеров;
* readiness check PostgreSQL и Redis;
* multi-stage Docker build;
* запуск backend от непривилегированного пользователя;
* Prometheus-метрики;
* конфигурация через environment variables;
* CI для сборки и проверки Docker image;
* CD с публикацией image в GitHub Container Registry.

## Структура проекта

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── ansible/
│   ├── inventory.ini
│   └── setup-nginx.yml
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── templates/
├── infra/
│   └── nginx/
│       ├── default.conf
│       └── check-curl.sh
├── scripts/
├── compose.yaml
├── Dockerfile
├── .env.example
└── README.md
```

## API

### Healthcheck

Проверяет доступность Flask-приложения.

```bash
curl http://localhost/api/health
```

Ответ:

```json
{
  "status": "ok"
}
```

### Readiness

Проверяет доступность зависимостей backend:

```bash
curl http://localhost/api/ready
```

При нормальной работе:

```json
{
  "postgres": "ok",
  "redis": "ok",
  "status": "ready"
}
```

Если PostgreSQL или Redis недоступны, endpoint возвращает `503`.

### Информация о приложении

```bash
curl http://localhost/api/info
```

Пример ответа:

```json
{
  "app": "DevOps Pet Service",
  "hostname": "container-id",
  "instance": "default",
  "version": "0.1.0"
}
```

### Метрики

```bash
curl http://localhost/metrics
```

Метрики экспортируются в формате Prometheus.

## Docker

Backend собирается через multi-stage Docker build.

Runtime-контейнер:

* основан на `python:3.12-slim`;
* запускается от пользователя `appuser`;
* слушает порт `3000`;
* имеет healthcheck на `/api/health`.

Nginx проксирует запросы в backend по имени Compose-сервиса:

```nginx
proxy_pass http://backend:3000;
```

## CI

Workflow:

```text
.github/workflows/ci.yml
```

Запускается при `push` и `pull_request`.

Этапы:

```text
checkout
   ↓
install dependencies
   ↓
docker build
   ↓
run container
   ↓
healthcheck
```

При ошибке сборки или healthcheck workflow завершается неуспешно.

## CD

Workflow:

```text
.github/workflows/cd.yml
```

Запускается для Git-тегов:

```text
v*
```

Пример:

```bash
git tag v1.0
git push origin v1.0
```

После успешной проверки Docker image публикуется в GitHub Container Registry:

```text
ghcr.io/aorevo/devops-infrastructure-lab:<tag>
```

## Ansible

Каталог `ansible/` содержит конфигурацию, созданную на предыдущем этапе проекта для практики автоматизации настройки Nginx на Linux-хосте.

Основной текущий способ запуска проекта — Docker Compose.

## Дальнейшее развитие

* интеграционная проверка полного Compose stack в CI;
* автоматизация backup/restore PostgreSQL;
* Prometheus и Grafana;
* Kubernetes;
* Terraform;
* централизованный сбор логов.
