---
title: "Arcane — современный менеджер Docker: обзор, установка и настройка"
published: 2026-10-01
pinned: false
description: "Разбираемся, что такое Arcane — открытый веб-интерфейс для управления Docker, — и пошагово поднимаем его через Docker Compose: секреты, подключение существующих стеков, reverse proxy и базовая безопасность."
tags: ["docker", "arcane", "self-hosting", "homelab"]
slug: "arcane-docker-manager"
category: "docker"
licenseName: "CC BY 4.0"
author: "Stilicho2011"
draft: true
series: ""
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: "Обзор Arcane — молодого, но быстро растущего веб-интерфейса для Docker — и пошаговая инструкция по установке, настройке секретов, подключению существующих compose-проектов и базовой защите сокета."
---

## Что такое Arcane

Arcane — открытый (BSD-3-Clause) веб-интерфейс для управления Docker, который позиционируется как современная альтернатива Portainer. Проект достаточно молодой, хотя и появился он не вчера, но развивается быстро: у репозитория на GitHub уже больше шести тысяч звёзд, а сам список фич выглядит более чем внушительным — контейнеры, образы, тома, сети, поддержка Docker Swarm, шаблоны для быстрого деплоя, удалённые окружения через агентов, сканирование образов на уязвимости, RBAC и OIDC для единого входа.

По ощущениям от сообщества (Reddit, форумы Synology-энтузиастов) Arcane занимает нишу между Dockge, который завязан почти исключительно на docker-compose и не умеет полноценно работать с образами/сетями/томами (и это не говоря уже о том, что проект скорее заброшен в настоящий момент), и Portainer, который многим кажется избыточным и тяжеловесным для домашней лаборатории. Arcane пытается дать «золотую середину»: понятный современный UI и при этом полноценное управление всеми сущностями Docker.

Если вы уже пробовали Komodo или Portainer, ключевое отличие Arcane в философии — это в первую очередь **UI поверх Docker Engine на конкретном хосте** (плюс агенты для удалённых хостов), а не полноценная CI/CD-платформа с процедурами и git-интеграцией, как в Komodo. Для домашней лаборатории из одного-двух хостов это может быть даже проще и понятнее.

## Что понадобится перед установкой

- Хост с установленным Docker и Docker Compose (v2).
- Открытый порт 3552 (по умолчанию) или настроенный reverse proxy.
- Пара сгенерированных секретов — `ENCRYPTION_KEY` и `JWT_SECRET` (сгенерируем на шаге 2).

## Шаг 1. Создаём compose.yaml

Создайте отдельную папку под Arcane и файл `compose.yaml` в ней:

```yaml
services:
  arcane:  # Название сервиса (используется как имя контейнера в сети Docker)
    image: ghcr.io/getarcaneapp/manager:latest  # Образ контейнера, тег latest — последняя версия
    container_name: arcane  # Явное имя контейнера (вместо автогенерируемого)
    #ports:
    #  - '3552:3552'  # Проброс порта отключён — доступ идёт только через Traefik, напрямую наружу порт не открыт
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # Доступ к Docker socket хоста — нужен приложению для управления контейнерами/образами
      - /home/stilicho/docker/arcane/data:/app/data  # Персистентное хранилище данных приложения на хосте
    environment:
      - APP_URL=https://arcane.stilicho.ru  # Публичный URL, по которому доступно приложение
      - PUID=1000  # ID пользователя внутри контейнера (для прав доступа к файлам на volume)
      - PGID=1000  # ID группы внутри контейнера (для прав доступа к файлам на volume)
      - ENCRYPTION_KEY=xxxxxxxxxxxxxxxxxxxxxx  # Ключ шифрования данных приложения (секрет)
      - JWT_SECRET=xxxxxxxxxxxxxxxxxxxxxx  # Секрет для подписи JWT-токенов авторизации
      - TZ=Europe/Moscow  # Часовой пояс контейнера
    cgroup: host  # Контейнер использует cgroup хоста (нужно для мониторинга/управления ресурсами других контейнеров)
    restart: unless-stopped  # Автоперезапуск контейнера при падении/перезагрузке хоста, кроме случаев ручной остановки
    networks:
      proxy:  # Подключение к сети proxy (используется Traefik)
    healthcheck:
      test: ['CMD', '/app/arcane', 'health']  # Команда проверки состояния контейнера
      interval: 30s  # Интервал между проверками
      timeout: 5s  # Максимальное время ожидания ответа на проверку
      retries: 3  # Количество неудачных попыток до статуса "unhealthy"
    labels:
      - "traefik.enable=true"  # Включаем Traefik для этого контейнера
      # =========================
      # HTTP ROUTER (порт 80)
      # =========================
      - "traefik.http.routers.arcane.entrypoints=web"
      # Traefik слушает входящий трафик на entrypoint "web" (обычно :80)
      # сюда попадает http://arcane.stilicho.ru
      - "traefik.http.routers.arcane.rule=Host(`arcane.stilicho.ru`)"
      # Правило: если Host совпадает — используем этот router
      # Traefik сравнивает заголовок Host
      - "traefik.http.routers.arcane.middlewares=arcane-https-redirect"
      # Применяем middleware (редирект на HTTPS)
      # ДО проксирования в контейнер
      - "traefik.http.middlewares.arcane-https-redirect.redirectscheme.scheme=https"
      # Сам middleware:
      # Traefik НЕ отправляет запрос в контейнер
      # он сразу отвечает клиенту:
      # 301 Redirect → https://arcane.stilicho.ru
      # =========================
      # HTTPS ROUTER (порт 443)
      # =========================
      - "traefik.http.routers.arcane-secure.entrypoints=websecure"
      # Входящий HTTPS трафик (обычно порт 443)
      - "traefik.http.routers.arcane-secure.rule=Host(`arcane.stilicho.ru`)"
      # То же правило по домену
      - "traefik.http.routers.arcane-secure.tls=true"
      # Включаем TLS:
      # Traefik завершает SSL (TLS termination)
      # расшифровывает HTTPS → дальше работает как HTTP
      - "traefik.http.routers.arcane-secure.service=arcane"
      # Указываем, в какой service отправлять трафик
      # router → service связка
      # =========================
      # SERVICE (куда идёт трафик)
      # =========================
      - "traefik.http.services.arcane.loadbalancer.server.port=3552"
      # Ключевая строка:
      # Traefik берёт IP контейнера в сети proxy
      # и делает запрос:
      # http://arcane:3552 (внутри Docker-сети)
      # НЕ через localhost и НЕ через ports
      # =========================
      # СЕТЬ
      # =========================
      - "traefik.docker.network=proxy"
      # Указываем, в какой сети искать контейнер
      # важно, если контейнер в нескольких сетях
      # Traefik возьмёт IP именно из сети proxy
# Описание сетей верхнего уровня (доступны всем сервисам)
networks:
  proxy:  # Название сети, к которой подключается сервис
    external: true  # Сеть уже существует (создана отдельно, например для Traefik), Compose её не создаёт
```

Пара моментов, на которые стоит обратить внимание сразу:

- `PUID`/`PGID` — если не указать, Arcane создаёт файлы от встроенного непривилегированного пользователя `65532:65532`. Если хотите, чтобы файлы на хосте принадлежали конкретному пользователю — пропишите его UID/GID.
- `/var/run/docker.sock` — обязательный том, через него Arcane получает доступ к Docker. Ниже разберём более безопасный вариант через socket proxy.
- `arcane-data` —  в базовом docker compose файле предлагается использовать докер том с базой данных и данными проектов Arcane, но я предпочитаю bind mount.

Опционально можно добавить ещё два тома, если планируете пользоваться соответствующими функциями:

- `/builds` — рабочая директория для Build Workspace (сборка образов из Dockerfile прямо в интерфейсе).
- `/backups` — куда Arcane будет складывать экспортированные бэкапы томов.

## Шаг 2. Генерируем секреты

`ENCRYPTION_KEY` и `JWT_SECRET` должны быть 32-байтными значениями (hex, base64 или raw). Проще всего сгенерировать их через `openssl` прямо в терминале:

```bash
echo "ENCRYPTION_KEY=$(openssl rand -hex 32)"
echo "JWT_SECRET=$(openssl rand -hex 32)"
```

Полученные значения подставьте в `compose.yaml` вместо `xxxxxxxxxxxxxxxxxxxxxx`.

## Шаг 3. Если хотите подключить существующие compose-проекты

Это важный момент, который легко упустить. Чтобы Arcane мог управлять уже существующим у вас на хосте compose-проектом (как, например, ваши стеки в `/opt/docker` или подобной папке), путь к проекту **должен совпадать снаружи и внутри контейнера**. То есть неправильно монтировать так:

```yaml
volumes:
  - /opt/docker:/app/data/projects
```

Правильно — монтировать один в один и явно указать переменную окружения:

```yaml
volumes:
  - /opt/docker:/opt/docker
environment:
  - PROJECTS_DIRECTORY=/opt/docker
```

Тогда относительные пути внутри compose-файлов (например `./config`) будут резолвиться так же, как если бы вы запускали `docker compose` руками из этой папки.

## Шаг 4. Если хост использует SELinux

Тем, кто держит хосты на Fedora/RHEL/CentOS с включённым SELinux, стоит выбрать один из двух вариантов:

**Вариант A — socket proxy (рекомендуется).** Вместо прямого монтирования `docker.sock` в Arcane поднимается `tecnativa/docker-socket-proxy`, который отдаёт только разрешённые операции (в примере ниже — контейнеры, образы, сети, тома, exec, события — без доступа к секретам, swarm и системным операциям):

```yaml
services:
  docker-socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    container_name: arcane-docker-proxy
    privileged: true
    environment:
      - EVENTS=1
      - PING=1
      - VERSION=1
      - AUTH=0
      - SECRETS=0
      - POST=1
      - BUILD=0
      - COMMIT=0
      - CONFIGS=0
      - CONTAINERS=1
      - DISTRIBUTION=0
      - EXEC=1
      - IMAGES=1
      - INFO=1
      - NETWORKS=1
      - NODES=0
      - PLUGINS=0
      - SERVICES=0
      - SESSION=0
      - SWARM=0
      - SYSTEM=0
      - TASKS=0
      - VOLUMES=1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  arcane:
    image: ghcr.io/getarcaneapp/manager:latest
    container_name: arcane
    ports:
      - '3552:3552'
    volumes:
      - arcane-data:/app/data
      - /path/to/projects:/app/data/projects:z
    environment:
      - PUID=1000
      - PGID=1000
      - ENCRYPTION_KEY=xxxxxxxxxxxxxxxxxxxxxx
      - JWT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxx
      - DOCKER_HOST=tcp://docker-socket-proxy:2375

volumes:
  arcane-data:
```

Такой подход стоит рассмотреть и без SELinux — просто как более безопасную практику, раз уж прямой доступ к `docker.sock` фактически равносилен root-доступу к хосту.

**Вариант B — прямое монтирование сокета** с меткой SELinux через `security_opt: - label:disable` и суффикс `:z` у тома с проектами — быстрее в настройке, но менее строго с точки зрения безопасности.

## Шаг 5. Запускаем

```bash
docker compose up -d
```

Проверить, что контейнер поднялся и не падает в цикле рестартов:

```bash
docker compose logs -f arcane
```

## Шаг 6. Первый вход

Открываем `http://<адрес-хоста>:3552` в браузере. При первом входе Arcane попросит сменить пароль администратора, заданный по умолчанию — сделайте это сразу, ещё до того как откроете интерфейс во внешнюю сеть.

## Шаг 7. Reverse proxy и WebSocket

Arcane активно использует WebSocket-соединение для живых логов, метрик и статусов контейнеров в реальном времени, поэтому при публикации через reverse proxy обязательно нужно включить проксирование апгрейда соединения. Если у вас уже настроен Traefik, достаточно добавить лейблы:

Traefik проксирует WebSocket из коробки, никаких дополнительных заголовков прописывать не нужно. Для Nginx или Apache потребуется явно прокинуть заголовки `Upgrade`/`Connection` — это стоит держать в голове, если решите публиковать Arcane не через Traefik.

## Шаг 8. Health check (по желанию)

В образе есть встроенная команда `arcane health`, которую удобно повесить как Docker healthcheck:

```yaml
healthcheck:
  test: ['CMD', './arcane', 'health', '--timeout', '2s']
  interval: 10s
  timeout: 3s
  retries: 5
  start_period: 15s
```

`start_period` даёт время на прогон миграций базы при первом старте, чтобы это время не засчитывалось в неудачные проверки.

## Что ещё умеет Arcane

Помимо базового управления контейнерами/образами/сетями/томами, в интерфейсе есть несколько вещей, ради которых стоит присмотреться к проекту внимательнее:

- **Remote Environments** — подключение удалённых Docker-хостов через отдельного агента, по аналогии с Periphery у Komodo, только без git-репозитория и процедур — просто ещё один хост в списке окружений.
- **Шаблоны и реестры шаблонов** — быстрый деплой типовых стеков без ручного написания compose-файла.
- **Vulnerability Scans** — сканирование образов на уязвимости прямо из интерфейса.
- **RBAC и OIDC SSO** — если у вас уже поднят Authentik или другой OIDC-провайдер, Arcane можно подключить к нему для единого входа, как это часто делают с другими сервисами в домашней лаборатории.
- **Docker Swarm** — базовая поддержка, если кто-то из читателей всё ещё держит Swarm-кластер.
- **Автообновления** — Arcane умеет проверять и подтягивать собственные обновления самостоятельно.

## Итог

Arcane — неплохой вариант, если Portainer кажется избыточным, а Dockge — слишком тесно завязанным на голый docker-compose без нормального управления образами и томами. Установка через Docker Compose занимает несколько минут, а из настроек, которые действительно стоит сделать заранее — это сгенерировать нормальные секреты, продумать путь к существующим проектам (`PROJECTS_DIRECTORY`) и по возможности вынести доступ к Docker-сокету через socket proxy, а не монтировать его напрямую.
