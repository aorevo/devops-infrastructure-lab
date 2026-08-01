# Server Handover Report

Учебный DevOps-проект с небольшим Flask-приложением и инструментами для локального управления несколькими экземплярами backend.

## Возможности приложения

Приложение предоставляет следующие маршруты:

- `/` — главная HTML-страница;
- `/api/health` — проверка состояния приложения;
- `/api/info` — информация о приложении и экземпляре;
- `/metrics` — метрики Prometheus.

Приложение поддерживает запуск нескольких экземпляров одного backend на разных портах.

## Структура проекта

```text
app/
├── main.py
├── requirements.txt
└── templates/
    └── index.html

scripts/
├── setup-app.sh
├── start-instances.sh
├── discover-app.sh
└── stop-instances.sh
```

## Подготовка приложения

Создать виртуальное окружение и установить зависимости:

```bash
./scripts/setup-app.sh
```

Скрипт создаст каталог `.venv` и установит зависимости из:

```text
app/requirements.txt
```

## Ручной запуск

Активировать виртуальное окружение:

```bash
source .venv/bin/activate
```

Запустить приложение с настройками по умолчанию:

```bash
python app/main.py
```

По умолчанию используются:

```text
PORT=3000
INSTANCE_ID=default
APP_NAME=DevOps Pet Service
APP_VERSION=0.1.0
LOG_LEVEL=INFO
```

Запустить экземпляр с собственным портом и идентификатором:

```bash
PORT=4100 INSTANCE_ID=backend-1 python app/main.py
```

Для запуска второго экземпляра открыть другой терминал:

```bash
source .venv/bin/activate
PORT=7200 INSTANCE_ID=backend-2 python app/main.py
```

Каждый экземпляр должен использовать отдельный свободный порт.

## Автоматический запуск экземпляров

Запустить один экземпляр:

```bash
./scripts/start-instances.sh 4100 backend-1
```

Запустить несколько экземпляров:

```bash
./scripts/start-instances.sh \
  4100 backend-1 \
  7200 backend-2
```

Аргументы передаются парами:

```text
<порт> <имя-инстанса>
```

Для каждого экземпляра создаются:

```text
logs/<имя-инстанса>.log
logs/<имя-инстанса>.pid
```

## Проверка экземпляров

Найти все локальные экземпляры приложения и проверить `/api/health`:

```bash
./scripts/discover-app.sh
```

Проверить код завершения:

```bash
echo $?
```

Коды завершения:

```text
0 — все найденные экземпляры HEALTHY
1 — экземпляры не найдены или хотя бы один экземпляр UNHEALTHY
```

Проверить экземпляр вручную:

```bash
curl http://127.0.0.1:4100/api/health
curl http://127.0.0.1:4100/api/info
```

Пример ответа `/api/info`:

```json
{
  "app": "DevOps Pet Service",
  "hostname": "ubuntu",
  "instance": "backend-1",
  "version": "0.1.0"
}
```

## Остановка экземпляров

Остановить один экземпляр:

```bash
./scripts/stop-instances.sh backend-1
```

Остановить несколько экземпляров:

```bash
./scripts/stop-instances.sh backend-1 backend-2
```

Скрипт:

1. читает PID из `logs/<имя-инстанса>.pid`;
2. проверяет существование процесса;
3. проверяет, что процесс запускает `app/main.py`;
4. отправляет процессу `SIGTERM`;
5. удаляет PID-файл.

## Полный локальный цикл

```bash
./scripts/start-instances.sh \
  4100 backend-1 \
  7200 backend-2

./scripts/discover-app.sh

curl http://127.0.0.1:4100/api/info
curl http://127.0.0.1:7200/api/info

./scripts/stop-instances.sh backend-1 backend-2

./scripts/discover-app.sh
```

## Следующие этапы

Планируемое развитие проекта:

```text
Nginx
Docker
Docker Compose
CI/CD
Ansible
Kubernetes
Terraform
Prometheus и Grafana
```