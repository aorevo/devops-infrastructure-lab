# DevOps Infrastructure Lab

Учебный проект для практики Linux, Nginx, Docker, Ansible и CI/CD.

Небольшое Flask-приложение запускается в двух Docker-контейнерах. Nginx принимает входящие запросы и распределяет их между экземплярами приложения. Настройка Nginx автоматизирована через Ansible, а сборка и проверка приложения выполняются в GitHub Actions.

## Архитектура

```text
                         ┌─────────────────────┐
                         │ backend-1           │
                         │ Flask :3000         │
                         └─────────▲───────────┘
                                   │
                              host :3000
                                   │
Client ──► Nginx :8080 ────────────┤
                                   │
                              host :3001
                                   │
                         ┌─────────▼───────────┐
                         │ backend-2           │
                         │ Flask :3000         │
                         └─────────────────────┘
```

Nginx работает на хосте и использует Docker-порты `3000` и `3001`.

## Реализовано

* Flask-приложение с API;
* два экземпляра приложения из одного Docker-образа;
* Nginx reverse proxy и round-robin балансировка;
* обработка отказа одного backend;
* Docker multi-stage build;
* запуск контейнера от непривилегированного пользователя;
* Docker healthcheck;
* метрики в формате Prometheus;
* автоматическая настройка Nginx через Ansible;
* CI для сборки и проверки Docker-контейнера;
* публикация релизных Docker-образов в GitHub Container Registry.

## API

| Маршрут       | Назначение                           |
| ------------- | ------------------------------------ |
| `/`           | HTML-страница                        |
| `/api/health` | Проверка состояния приложения        |
| `/api/info`   | Информация о приложении и контейнере |
| `/metrics`    | Метрики Prometheus                   |

Пример:

```json
{
  "app": "DevOps Pet Service",
  "hostname": "a1b2c3d4e5f6",
  "instance": "default",
  "version": "0.1.0"
}
```

Поле `hostname` позволяет определить контейнер, который обработал запрос.

## Структура

```text
devops-infrastructure-lab/
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
│       ├── devops-pet.conf
│       └── check-curl.sh
├── scripts/
├── Dockerfile
├── .dockerignore
└── README.md
```

## Docker

Сборка образа:

```bash
docker build -t devops-pet:local .
```

Запуск двух экземпляров:

```bash
docker run -d --name backend-1 -p 3000:3000 devops-pet:local
docker run -d --name backend-2 -p 3001:3000 devops-pet:local
```

Проверка через Nginx:

```bash
curl -H "Host: devops-pet.local" http://localhost:8080/api/info
```

Для локального имени используется запись:

```text
127.0.0.1 devops-pet.local
```

## Ansible

Playbook настраивает Nginx:

* проверяет наличие пакета;
* копирует конфигурацию;
* включает конфигурацию сайта;
* выполняет `nginx -t`;
* проверяет состояние сервиса;
* перезагружает конфигурацию только при изменениях.

На текущем этапе inventory использует локальную машину:

```ini
[web]
localhost ansible_connection=local
```

Запуск:

```bash
ansible-playbook -i ansible/inventory.ini ansible/setup-nginx.yml -K
```

## CI

Workflow `.github/workflows/ci.yml` запускается при push и pull request.

Он:

1. получает код;
2. настраивает Python;
3. устанавливает зависимости;
4. собирает Docker-образ;
5. запускает контейнер;
6. проверяет `/api/health`.

Ошибка на любом этапе завершает CI с ошибкой.

## CD

Workflow `.github/workflows/cd.yml` запускается для Git-тегов вида:

```text
v1.0
v1.1
v2.0
```

Перед публикацией релиза выполняется отдельная проверка Docker-контейнера.

```text
tag v*
   │
   ▼
test
   │
   │ success
   ▼
publish
   │
   ▼
GitHub Container Registry
```

Если проверка завершается ошибкой, публикация не выполняется.

Создание релиза:

```bash
git tag v1.0
git push origin v1.0
```

Релизный образ публикуется как:

```text
ghcr.io/aorevo/devops-infrastructure-lab:<tag>
```

## Технологии

Python, Flask, Linux, Nginx, Docker, Ansible, GitHub Actions, Git.

## Дальнейшее развитие

* Docker Compose;
* Kubernetes;
* Terraform;
* Prometheus и Grafana.