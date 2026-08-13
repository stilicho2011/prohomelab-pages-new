---
title: Diun — уведомления об обновлениях Docker-образов
published: 2025-11-01
pinned: false
description: "Подробный обзор Diun (Docker Image Update Notifier): установка, настройка, уведомления в Telegram и интеграции с self-hosted инфраструктурой."
tags:
  - Docker
  - Diun
  - Self-Hosting
slug:
categories: Docker
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Self-Hosting
youtube_id: uHkyp6IiHcI
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Подробная инструкция по установке и настройке Diun для отслеживания обновлений Docker-образов. Рассмотрены шаги по развертыванию, интеграции с уведомлениями и автоматизации мониторинга, чтобы своевременно обновлять контейнеры и повышать безопасность системы.
---


<iframe width="100%" height="468" src="https://www.youtube.com/embed/uHkyp6IiHcI?si=jJj_t7s9_brLxzcO" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

## Diun — уведомления об обновлениях Docker-образов

### Что такое Diun

**Diun (Docker Image Update Notifier)** — это инструмент с открытым исходным кодом, разработанный [CrazyMax](https://github.com/crazy-max/diun), который следит за обновлениями Docker-образов и уведомляет, когда выходит новая версия.  

Diun не обновляет контейнеры автоматически — он лишь сообщает, что **появилась новая версия образа**, оставляя решение за вами. Это особенно важно, если вы хотите контролировать процесс обновления и избегать непредвиденных изменений в продакшене.

Это существенное отличие от такого приложения как **Watchtower,** которое не только проверяет наличие новой версии, но и сразу устанавливает ее. 

**DIUN** - рекомендуемое приложение для мониторинга контейнеров от [linuxserver.io](https://docs.linuxserver.io/)

---

### Зачем нужен Diun

Если у вас есть домашний сервер, кластер Proxmox или просто несколько контейнеров на VPS, со временем образы устаревают. Проверять обновления вручную — неудобно.

Diun решает эту задачу автоматически:

\- Проверяет Docker Hub, GHCR, Quay.io, GitLab и приватные реестры    
\- Работает по cron-расписанию или при старте    
\- Отправляет уведомления через десятки сервисов    
\- Поддерживает фильтры и теги    
\- Может отслеживать **контейнеры**, **compose-файлы**, **stack-и** или **registry-списки** 

---

### Установка Diun через Docker Compose

Создайте каталог и файл \`docker-compose.yml\`

Ниже привожу свой вариант docker compose файла, который использовался в ролике

```yaml
services:
    diun:  # Определяем сервис Diun в составе Docker Compose
        image: crazymax/diun:latest  # Официальный образ Diun с Docker Hub
        container_name: diun         # Имя контейнера (для удобства в `docker ps`)
        command: serve               # Основная команда — запустить веб/cron-сервис Diun
        volumes:
            - "/path/to/user/directory/data:/data"  # Локальный каталог для хранения базы данных и конфигурации Diun
            - "/var/run/docker.sock:/var/run/docker.sock"  # Доступ к Docker API для отслеживания образов и контейнеров
        environment:
            - "TZ=Europe/Moscow"  # Устанавливаем часовой пояс (важно для cron и временных меток)
            - "LOG_LEVEL=info"    # Уровень логирования: trace | debug | info | warn | error | fatal | panic
            - "DIUN_WATCH_WORKERS=50"  # Количество параллельных потоков при проверке образов (ускоряет работу при множестве контейнеров)
            - "DIUN_WATCH_SCHEDULE=0 */6 * * *"  # Cron-расписание: проверять обновления каждые 6 часов
            - "DIUN_WATCH_JITTER=30s"  # Добавляет случайную задержку (до 30 секунд), чтобы избежать одновременного старта нескольких задач
            - "DIUN_WATCH_RUNONSTARTUP=true"  # Запуск проверки сразу при старте контейнера, не дожидаясь расписания
            - "DIUN_PROVIDERS_DOCKER=true"  # Активирует провайдер Docker: Diun будет отслеживать образы запущенных контейнеров
            - "DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=true"  # Включает мониторинг всех контейнеров по умолчанию, без необходимости вручную задавать label `diun.enable=true`

            # --- Настройки уведомлений через Telegram ---
            - "DIUN_NOTIF_TELEGRAM_TOKEN=token"  # Токен Telegram-бота, созданного через @BotFather
            - "DIUN_NOTIF_TELEGRAM_chatIDs=chatid"  # ID чата или пользователя, куда будут отправляться уведомления (можно указать несколько через запятую)

            # --- Настройки уведомлений через Gotify ---
            - "DIUN_NOTIF_GOTIFY_ENDPOINT=https://gotify.domain.ru"  # URL вашего сервера Gotify
            - "DIUN_NOTIF_GOTIFY_TOKEN=token"  # Токен приложения Gotify (создаётся в веб-интерфейсе Gotify)
            - "DIUN_NOTIF_GOTIFY_PRIORITY=1"  # Приоритет уведомления (0 — низкий, 5 — высокий)
            - "DIUN_NOTIF_GOTIFY_TIMEOUT=10s"  # Таймаут ожидания ответа от Gotify при отправке уведомления

        labels:
            - "diun.enable=true"  # Метка, разрешающая Diun отслеживать этот контейнер (опционально, если `WATCHBYDEFAULT=false`)
        restart: always  # Перезапуск контейнера при сбое или перезагрузке Docker-хоста
```

После первого запуска Diun создаст базу `data/diun.db` и начнёт мониторить все контейнеры Docker. Более подробно можно будет посмотреть в логах приложения

Diun гибко настраивается. Ниже — краткий обзор самых полезных возможностей.

### Режимы работы

*   **Watch (наблюдение)** — Diun периодически сканирует все контейнеры, чтобы проверить обновления.
*   **Events (события)** — реагирует на запуск контейнера и проверяет, есть ли более свежий образ.
*   **Database mode** — хранит состояние всех проверенных образов, чтобы не слать повторные уведомления.

### Метки контейнеров

Можно указать, какие контейнеры отслеживать. Добавьте в `docker-compose.yml`:

```yaml
labels:
  - "diun.enable=true" 
```

или наоборот — исключите ненужные контейнеры.

### Провайдеры

Diun поддерживает разные источники:

*   `docker` — работа с локальным Docker-демоном
*   `swarm` — отслеживание образов в Docker Swarm
*   `file` — список образов в YAML-файле
*   `kubernetes` — (экспериментально) проверка образов в подах
*   `watchtower` — импорт конфигурации из Watchtower

Пример YAML-провайдера:

```yaml
db:
  path: diun.db

watch:
  workers: 20
  schedule: "0 */6 * * *"

regopts:
  - name: "myregistry"
    username: fii
    password: bor
    timeout: 5s
  - name: "docker.io/crazymax"
    selector: image
    username: fii
    password: bor
  - name: "docker.io"
    selector: image
    username: foo
    password: bar

providers:
  file:
    filename: /path/to/config.yml

```

```yaml
### /path/to/config.yml

# Watch latest tag of crazymax/nextcloud image on docker.io (DockerHub)
# with registry options named 'docker.io/crazymax' (image selector).
- name: docker.io/crazymax/nextcloud:latest

# Watch 4.0.0 tag of jfrog/artifactory-oss image on frog-docker-reg2.bintray.io (Bintray)
# with registry options named 'myregistry' (name selector).
- name: jfrog-docker-reg2.bintray.io/jfrog/artifactory-oss:4.0.0
  regopt: myregistry

# Watch coreos/hyperkube image on quay.io (Quay) and assume latest tag.
# Add foo=bar metadata to be used in notification template.
- name: quay.io/coreos/hyperkube
  metadata:
    foo: bar

# Watch crazymax/swarm-cronjob image and assume docker.io registry and latest tag
# with registry options named 'docker.io/crazymax' (image selector).
# Only include tags matching regexp ^1\.2\..* and only be notified on new tag.
- name: crazymax/swarm-cronjob
  watch_repo: true
  notify_on:
    - new
  include_tags:
    - ^1\.2\..*

# Watch portainer/portainer image on docker.io (DockerHub) and assume latest tag
# with registry options named 'docker.io' (image selector).
# Only watch latest 10 tags and include tags matching regexp ^\d+\.\d+\..*
- name: docker.io/portainer/portainer
  watch_repo: true
  max_tags: 10
  include_tags:
    - ^\d+\.\d+\..*

# Watch alpine image (library) and assume docker.io registry and latest tag
# with registry options named 'docker.io' (image selector).
# Force linux/arm64/v8 platform for this image
- name: alpine
  watch_repo: true
  platform:
    os: linux
    arch: arm64
    variant: v8

```

Более подробно можно почитать в [официальной документации](https://crazymax.dev/diun/providers/file/#directory) 

### Уведомления (notifications)

**Diun** умеет отправлять уведомления более чем в 15 сервисов:

| Сервис | Переменные окружения |
| --- | --- |
| Telegram | `DIUN_NOTIF_TELEGRAM_TOKEN`, `DIUN_NOTIF_TELEGRAM_CHATIDS` |
| Discord | `DIUN_NOTIF_DISCORD_WEBHOOKURL` |
| Gotify | `DIUN_NOTIF_GOTIFY_ENDPOINT`, `DIUN_NOTIF_GOTIFY_TOKEN` |
| Slack | `DIUN_NOTIF_SLACK_WEBHOOKURL` |
| Email | `DIUN_NOTIF_MAIL_SMTP_HOST`, `DIUN_NOTIF_MAIL_FROM`, `DIUN_NOTIF_MAIL_TO` |
| Webhook | `DIUN_NOTIF_WEBHOOK_ENDPOINT` |

Можно использовать несколько сервисов для уведомлений одновременно, как это указано у меня в docker compose файле.

### Заключение

**Diun** — это обязательный инструмент для всех, кто использует Docker в self-hosted инфраструктуре.  
Он лёгкий, стабильный, не требует сложной настройки и отлично сочетается с другими DevOps-сервисами.

Если вы хотите держать свою инфраструктуру в актуальном состоянии, **Diun поможет вовремя узнавать об обновлениях и избегать сюрпризов.**