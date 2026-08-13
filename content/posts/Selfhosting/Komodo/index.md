---
title: "Переезжаем с Portainer на Komodo: полная установка и настройка"
description: "Пошаговая инструкция по установке Komodo как альтернативы Portainer: docker-compose, MongoDB, bind mount вместо volumes, вход через authentik (OIDC) и подключение дополнительных хостов через Periphery."
date: 2026-08-01
draft: true
tags: ["homelab", "docker", "self-hosting", "komodo"]
categories: ["Self-Hosting"]
---

## Зачем переходить с Portainer на Komodo

Portainer долго был стандартом де-факто для управления Docker через веб-интерфейс, но у него есть ограничения: нет полноценного CI/CD-воркфлоу, слабая работа с git-репозиториями, устаревающий UI. [Komodo](https://komo.do) — более молодой инструмент ([исходники на GitHub](https://github.com/moghtech/komodo)), который закрывает эти пробелы: он умеет деплоить стеки прямо из git, поддерживает распределённое управление несколькими хостами через агент Periphery, и предлагает более современный подход к CI/CD внутри домашней инфраструктуры. Собственно говоря, на эти вещи разработчики и делали упор судя по всему. Полный список возможностей — в [официальном описании "What is Komodo"](https://komo.do/docs/intro).

В этой статье я опишу полную установку: от docker-compose файла до входа через [Authentik](https://prohomelab.com/posts/authentik/) и подключения дополнительного хоста как удалённого агента.

## Архитектура

Komodo состоит из трёх компонентов:

- **Core** — центральный сервис, веб-интерфейс и API.
- **Periphery** — агент, который стоит на каждом управляемом хосте и общается с Core.
- **База данных** — Core хранит все данные (конфигурации ресурсов, пользователей, логи) в MongoDB-совместимой базе.

Про базу стоит сказать отдельно: Komodo умеет работать либо с обычной MongoDB, либо с [FerretDB](https://www.ferretdb.com) — прокси-адаптером, который эмулирует протокол MongoDB, а данные реально хранит в Postgres. Для этой статьи я выбрал классический вариант с MongoDB — он официально рекомендуемый и самый протестированный (подробности — в [документации по установке Core](https://komo.do/docs/setup)). Хотя почему не предусмотреть возможность работать с Postgres напрямую непонятно!? С моей точки зрения - это огромный минус.

## Подготовка: структура директорий

Я предпочитаю bind mount вместо именованных Docker volume — так удобнее делать бэкапы и заглядывать в данные напрямую с хоста. Но это добавляет определенные сложности, в особенности с правами. Мой проект лежит по пути `/home/stilicho/docker/komodo`.

Создаём структуру директорий заранее:

```bash
mkdir -p /home/stilicho/docker/komodo/{mongo/data,mongo/configdb,keys,backups}
```

> [!NOTE]
> > **Важно продумать сразу, а не потом.** Если у вас, как и у меня, все остальные docker-compose проекты лежат рядом, в общей родительской папке (например `/home/stilicho/docker/vaultwarden`, `/home/stilicho/docker/gotify` и т.д.), то `PERIPHERY_ROOT_DIRECTORY` нужно указывать на эту **родительскую** директорию (`/home/stilicho/docker`), а не на подпапку внутри `komodo`. Иначе позже, когда будете переносить существующие стеки в Komodo (см. раздел ниже), Periphery physически не будет видеть их файлы и выдаст `No such file or directory`, даже если путь в UI указан правильно. Подробнее — в разделе про перенос стеков.

## docker-compose.yaml

Вот итоговый compose-файл. За основу взят [официальный пример с MongoDB](https://github.com/moghtech/komodo/blob/main/compose/mongo.compose.yaml), но с несколькими важными правками:

- volume заменены на bind mount под наш путь;
- каждому сервису задан `container_name` для удобства;


```yaml
################################
# 🦎 KOMODO COMPOSE - MONGO 🦎 #
################################

## This compose file will deploy:
##   1. MongoDB
##   2. Komodo Core
##   3. Komodo Periphery

services:
  mongo:
    image: mongo
    container_name: komodo-mongo
    labels:
      komodo.skip: # Prevent Komodo from stopping with StopAllContainers
    command: --quiet --wiredTigerCacheSizeGB 0.25
    restart: unless-stopped
    # ports:
    #   - 27017:27017
    volumes:
      - /home/stilicho/docker/komodo/mongo/data:/data/db
      - /home/stilicho/docker/komodo/mongo/configdb:/data/configdb
    networks:
      - komodo
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${KOMODO_DATABASE_USERNAME}
      MONGO_INITDB_ROOT_PASSWORD: ${KOMODO_DATABASE_PASSWORD}

  core:
    image: ghcr.io/moghtech/komodo-core:${COMPOSE_KOMODO_IMAGE_TAG:-2}
    container_name: komodo-core
    init: true
    restart: unless-stopped
    depends_on:
      - mongo
    ports:
      - 9120:9120
    env_file: ./compose.env
    environment:
      KOMODO_DATABASE_ADDRESS: mongo:27017
    volumes:
      ## Ключи для связи Core / Periphery
      - /home/stilicho/docker/komodo/keys:/config/keys
      ## Датированные бэкапы БД - https://komo.do/docs/setup/backup
      - /home/stilicho/docker/komodo/backups:/backups
    networks:
      - proxy
      - komodo
    security_opt:
      - no-new-privileges:true
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.komodo.entrypoints=web"
      - "traefik.http.routers.komodo.rule=Host(`komodo.stilicho.ru`)"
      - "traefik.http.middlewares.komodo-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.komodo.middlewares=komodo-https-redirect"
      - "traefik.http.routers.komodo-secure.entrypoints=websecure"
      - "traefik.http.routers.komodo-secure.rule=Host(`komodo.stilicho.ru`)"
      - "traefik.http.routers.komodo-secure.tls=true"
      - "traefik.http.routers.komodo-secure.service=komodo"
      - "traefik.http.services.komodo.loadbalancer.server.port=9120"
      - "traefik.docker.network=proxy"

  ## Можно развернуть Periphery как контейнер (этот блок),
  ## либо как systemd-сервис через бинарник:
  ## https://github.com/moghtech/komodo/tree/main/scripts
  periphery:
    image: ghcr.io/moghtech/komodo-periphery:${COMPOSE_KOMODO_IMAGE_TAG:-2}
    container_name: komodo-periphery
    init: true
    restart: unless-stopped
    depends_on:
      - core
    env_file: ./compose.env
    volumes:
      - /home/stilicho/docker/komodo/keys:/config/keys
      - /var/run/docker.sock:/var/run/docker.sock
      - /proc:/proc
      - ${PERIPHERY_ROOT_DIRECTORY:-/etc/komodo}:${PERIPHERY_ROOT_DIRECTORY:-/etc/komodo}
    networks:
      - proxy
      - komodo

networks:
  proxy:                  # Внешняя сеть Traefik
    external: true
  komodo:                 # Внешняя сеть для связи Core / Mongo / Periphery
    external: true
```

Обе сети — внешние, поэтому создайте их заранее (Compose не создаст `external` сети сам):

```bash
docker network create proxy   # если ещё не создана
docker network create komodo
```

> [!caution] 
> > **Важный момент про сети.** Если явно указать `networks:` у сервиса (как у `core` — сеть `proxy` для Traefik), Docker Compose перестаёт автоматически добавлять его в дефолтную сеть проекта. Поэтому все три сервиса, которым нужно общаться друг с другом (`mongo`, `core`, `periphery`), явно подключены к отдельной сети `komodo` — она специально выделена под внутреннюю коммуникацию между контейнерами Komodo, а `proxy` используется только там, где сервис реально должен быть виден Traefik (то есть только у `core`).

## compose.env — переменные окружения

Второй файл, `compose.env`, хранит все настройки и секреты. Часть значений нужно сгенерировать самостоятельно.

```bash
####################################
# 🦎 KOMODO COMPOSE - VARIABLES 🦎 #
####################################

COMPOSE_KOMODO_IMAGE_TAG="2"
COMPOSE_KOMODO_BACKUPS_PATH=/home/stilicho/docker/komodo/backups

## Данные для доступа к БД — обязательно смените с дефолтных!
KOMODO_DATABASE_USERNAME=<придумайте_логин>
KOMODO_DATABASE_PASSWORD=<придумайте_надёжный_пароль>

TZ=Europe/Moscow

#=-------------------------=#
#= Komodo Core Environment =#
#=-------------------------=#

KOMODO_HOST=https://komodo.stilicho.ru
KOMODO_TITLE=Komodo

KOMODO_PERIPHERY_PUBLIC_KEY=file:/config/keys/periphery.pub

## Локальный админ на случай проблем с OIDC
KOMODO_LOCAL_AUTH=true
KOMODO_INIT_ADMIN_USERNAME=admin
KOMODO_INIT_ADMIN_PASSWORD=<надёжный_пароль>

KOMODO_FIRST_SERVER_NAME=Local

KOMODO_DEFAULT_PAGINATION_LIMIT=50

## Секреты — сгенерируйте случайные строки, например: openssl rand -hex 32
KOMODO_WEBHOOK_SECRET=<random_hex_32>
KOMODO_JWT_SECRET=<random_hex_32>
KOMODO_JWT_TTL="1-day"

KOMODO_MONITORING_INTERVAL="15-sec"
KOMODO_RESOURCE_POLL_INTERVAL="1-hr"

## Включаем, чтобы OIDC-пользователи не требовали ручной активации
KOMODO_ENABLE_NEW_USERS=true

## OIDC Login (authentik)
KOMODO_OIDC_ENABLED=true
KOMODO_OIDC_PROVIDER=https://authentik.stilicho.ru/application/o/komodo/
## Раскомментируйте, только если Core обращается к authentik по внутреннему адресу,
## отличному от публичного домена выше
# KOMODO_OIDC_REDIRECT_HOST=https://auth.stilicho.ru
KOMODO_OIDC_CLIENT_ID=<client_id_из_authentik>
KOMODO_OIDC_CLIENT_SECRET=<client_secret_из_authentik>
KOMODO_OIDC_AUTO_REDIRECT=false ## если указать значение true, то не будет варианта выбора входа. Пока не создан админ, оставьте false

#=------------------------------=#
#= Komodo Periphery Environment =#
#=------------------------------=#

PERIPHERY_CORE_ADDRESS=ws://core:9120
PERIPHERY_CONNECT_AS=${KOMODO_FIRST_SERVER_NAME}
PERIPHERY_CORE_PUBLIC_KEYS=file:/config/keys/core.pub

## Все стеки/репозитории/сборки Periphery должны лежать внутри этого пути.
## Указываем родительскую папку, где лежат ВСЕ ваши compose-проекты
## (включая komodo, но и все остальные) — иначе Periphery не сможет
## прочитать файлы уже существующих стеков при их переносе в Komodo.
PERIPHERY_ROOT_DIRECTORY=/home/stilicho/docker

PERIPHERY_INCLUDE_DISK_MOUNTS=/etc/hostname
```

Полный список переменных с комментариями смотрите в [оригинальном файле на GitHub](https://github.com/moghtech/komodo/blob/main/compose/compose.env) — я оставил только то, что реально нужно поменять для рабочей установки.

## Настройка входа через Authentik

Если вы, как и я, используете Authentik как единую точку входа для homelab-сервисов, Komodo прекрасно с ним интегрируется — есть даже [отдельная страница про интеграцию с Authentik в официальной документации](https://komo.do/docs/setup/advanced).

### В authentik

1. **Applications → Applications → Create with Wizard**
   - Name: `Komodo`
   - Slug: `komodo` 
1. **Provider type:** OAuth2/OpenID Connect
2. **Authorization flow:** Explicit (или ваш стандартный)
3. **Redirect URI** (тип Strict):
   ```
   https://komodo.stilicho.ru/auth/oidc/callback
   ```
4. Сохраните — получите **Client ID** и **Client Secret**.

### В compose.env

Подставьте полученные значения в `KOMODO_OIDC_CLIENT_ID` и `KOMODO_OIDC_CLIENT_SECRET`.

Важный момент: Komodo не умеет создавать OIDC-пользователей сразу с правами админа. Первый вход всегда происходит через локального админа, заданного в `KOMODO_INIT_ADMIN_USERNAME`/`PASSWORD`.

## Запуск

Прежде чем поднимать контейнеры, стоит сделать один трюк — симлинк, чтобы Docker Compose автоматически подхватывал переменные без флага `--env-file`:

```bash
cd /home/stilicho/docker/komodo
ln -s compose.env .env
docker compose up -d
```

Если вы не сделаете симлинк и запустите `docker compose up -d` без `--env-file compose.env`, Compose не подставит переменные `KOMODO_DATABASE_USERNAME`/`PASSWORD` в блок `environment:` сервиса `mongo` — вы увидите warning про пустые значения, и MongoDB инициализируется с пустыми credentials. Если это уже произошло, нужно снести данные и перезапустить:

```bash
docker compose down
rm -rf mongo/data/* mongo/configdb/*
docker compose up -d
```

Проверьте логи на отсутствие ошибок:

```bash
docker logs komodo-mongo --tail 50
docker logs komodo-core --tail 50
```

## Первый вход и активация OIDC-аккаунта

1. Откройте `https://komodo.stilicho.ru`.
2. Залогиньтесь под локальным админом (`admin` / пароль из `compose.env`).
3. Нажмите кнопку **OIDC** и залогиньтесь через authentik — Komodo автоматически создаст вашего пользователя (уже активного, благодаря `KOMODO_ENABLE_NEW_USERS=true`).
4. Вернитесь под локальным админом → **Settings → Users** → найдите свежесозданного OIDC-пользователя → повысьте его до **Admin**.

После этого можно пользоваться входом через Authentik как основным, а локальный админ остаётся как резервный вариант.

> **Важный нюанс с `KOMODO_OIDC_AUTO_REDIRECT=true`.** Эта опция автоматически перенаправляет **любого** неавторизованного пользователя на Authentik, минуя форму логина Komodo — даже в режиме инкогнито. Из-за этого зайти под локальным админом обычным способом не получится. Если нужно попасть на форму локального логина (например, чтобы повысить свежесозданного OIDC-пользователя до админа), временно отключите редирект:

> ```bash
> # в compose.env
> KOMODO_OIDC_AUTO_REDIRECT=false
> ```
> ```bash
> docker compose up -d
> ```
> Зайдите под `admin`, сделайте нужные правки, затем верните `KOMODO_OIDC_AUTO_REDIRECT=true` обратно и снова примените `docker compose up -d`.

## Возможности Komodo и что где находится

Прежде чем переходить к установке, коротко пройдёмся по интерфейсу — что вообще умеет Komodo и где это искать после первого входа. В левом меню несколько основных разделов-ресурсов:

- **Servers** — список подключённых Docker-хостов (у вас будет минимум один — локальный, плюс все хосты, подключённые через Periphery, как в разделе про Immich ниже). Тут видно статус подключения, CPU/RAM/диск, версию Docker.
- **Stacks** — аналог "Stacks" в Portainer: управление docker-compose проектами. Именно сюда попадают ваши стеки после миграции (см. следующий раздел).
- **Containers** — плоский список всех контейнеров на всех подключённых серверах, с возможностью старт/стоп/рестарт/логи/exec, без привязки к конкретному стеку.
- **Builds** — если вы хотите, чтобы Komodo сама собирала Docker-образы из git-репозитория (CI-часть, которой у Portainer вообще нет).
- **Repos** — управление git-репозиториями, которые Komodo клонирует и может отслеживать на предмет изменений (для авто-редеплоя по вебхуку).
- **Procedures** и **Actions** — многошаговые сценарии автоматизации (например: "остановить стек A → сделать backup → обновить образ → запустить снова"), можно вызывать вручную, по расписанию или по вебхуку.
- **Syncs** — декларативная синхронизация конфигурации: описываете все ресурсы (стеки, серверы, процедуры) в TOML-файлах в git, и Komodo приводит реальное состояние в соответствие с описанным — похоже на Terraform, но для вашего homelab.
- **Alerts** — журнал алертов.
- **Settings** — пользователи, роли, API-ключи, вебхуки для нотификаций (Discord/Slack/Telegram/Gotify и т.д.).

При обычном homelab-сценарии 80% времени вы будете проводить в **Servers** и **Stacks** — остальное подключается по мере роста аппетитов (git-сборки, синхронизация конфигов).

## Перенос существующих docker-compose стеков в Komodo

Важный момент, который стоит понимать сразу: Komodo, в отличие от Dockge, **не сканирует** хост автоматически и не подхватывает уже работающие compose-проекты сама. Каждый стек нужно явно "объявить" в Komodo — указать, где лежат его файлы, и к какому серверу он относится (механика описана в [официальной доке по Docker Compose / Stacks](https://komo.do/docs/deploy/compose)). Готового инструмента автоматической миграции именно с Portainer нет — это подтверждают и сами разработчики в [обсуждении на GitHub](https://github.com/moghtech/komodo/discussions/161) — переносить нужно вручную, стек за стеком (для этого есть неофициальная утилита [komodo-import](https://github.com/FoxxMD/komodo-import), которая генерирует конфигурацию по существующим папкам, но это community-инструмент, не часть самой Komodo). Но я все сделал руками.

Хорошая новость: миграция не требует останавливать текущие контейнеры. Portainer и Komodo прекрасно работают параллельно, пока вы переносите стеки по одному — рабочий процесс не прерывается.

### Как перенести один стек

1. **Servers → выберите хост** (или общий раздел **Stacks** → **Create Stack**).
2. Задайте имя стека — **оно должно совпадать с именем существующего compose-проекта**. Узнать текущее имя проекта можно так:
   ```bash
   docker compose ls
   ```
3. Источник файлов — выбираете один из трёх режимов:
   - **UI Defined** — вставляете содержимое compose-файла прямо в веб-интерфейс, Komodo сама пишет файл на хост при деплое.
   - **Files on Server** — указываете путь к уже существующему compose-файлу на хосте (то, что нужно для миграции существующих стеков — просто указываете туда же, где они уже лежат, например `/home/alaricus/docker/vaultwarden`).
   - **Git Repo** — Komodo клонирует репозиторий на хост и деплоит оттуда; изменения отслеживаются в git, можно настроить авто-редеплой по вебхуку на push.
1. Для варианта **Files on Server** — обязательно укажите правильный `Run Directory` (папка с compose-файлом) и `File Paths` (имя файла, обычно `docker-compose.yaml`, `docker-compose.yml` или `compose.yaml`).

   Если у стека есть свой `.env` файл (частый случай — например, у меня так был устроены много контейнеров) — не пытайтесь пересоздавать его через поле **Environment** в UI. Используйте отдельное поле **Additional Env Files**, укажите там `.env` (путь относительно `Run Directory`), и обязательно **снимите галочку "Track"** — она предназначена именно для внешне управляемых файлов, которые вы продолжите редактировать вручную на диске, а не через Komodo.

2. Привяжите стек к нужному **Server** (для локального хоста — тот, что назван `Local`  и т.д.).
3. Нажмите **Deploy** (или сначала **Refresh**, чтобы Komodo прочитала текущее состояние без пересоздания контейнеров) — если контейнеры уже запущены с тем же именем проекта, Komodo просто "возьмёт их под управление", а не пересоздаст с нуля.

> **Важно про пути при удалённых хостах.** Если стек мигрируется на хост с Periphery-агентом, путь к compose-файлу должен быть доступен внутри директории `root_directory` этого агента. Это касается **обоих** вариантов установки, не только контейнера — я сам ошибочно думал, что systemd-вариант такого ограничения не имеет, но это не так: `root_directory` — это встроенное ограничение самой Periphery, а не следствие Docker-монтирования. Для контейнера это означает попадание пути в примонтированную директорию `PERIPHERY_ROOT_DIRECTORY`, для systemd — совпадение с `root_directory` в `periphery.config.toml`. В обоих случаях все ваши стеки должны физически лежать внутри этого пути.

### Если получаете "No such file or directory"

Это самая частая ошибка при первом переносе стека, и почти всегда она означает одно: **контейнеризованный Periphery физически не видит указанную директорию**, потому что `PERIPHERY_ROOT_DIRECTORY` смотрит на слишком узкую папку (например, только на саму `komodo`, а не на родительскую директорию со всеми проектами — см. предупреждение в начале статьи).

Диагностика по шагам:

**1. Проверьте, что Periphery реально видит директорию стека:**
```bash
docker exec komodo-periphery ls /home/stilicho/docker/<имя_стека>
```
Если `No such file or directory` — значит монтирование слишком узкое, идём к шагу 2.

**2. Проверьте, что симлинк `.env → compose.env` создан** (без него `PERIPHERY_ROOT_DIRECTORY` из `compose.env` не подставится в `docker-compose.yaml` при пересоздании контейнера):
```bash
ls -la ~/docker/komodo/.env
```
Нет файла — создайте (см. раздел "Запуск" выше).

**3. Поправьте `PERIPHERY_ROOT_DIRECTORY` в `compose.env`** на родительскую папку со всеми стеками и пересоздайте контейнеры **именно из папки проекта**:

```bash
cd /home/stilicho/docker/komodo
docker compose down
docker compose up -d
```
Важно: `down` + `up`, а не `restart`.

**4. Проверьте фактическое монтирование** внутри уже запущенного контейнера:

```bash
docker inspect komodo-periphery --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
```

Должны увидеть строку с вашей новой родительской директорией, а не старый узкий путь.

**5. Вернитесь на страницу стека в Komodo UI и нажмите Refresh ещё раз** (иногда интерфейс держит закэшированный результат прошлой попытки — если ошибка не пропала сразу, обновите страницу браузера целиком).

### Массовая миграция через Sync

Если стеков много и переносить их по одному через UI утомительно, можно описать все сразу декларативно через **Syncs** — TOML-файлы с определением ресурсов, которые Komodo применяет одним махом. Подробности — в [официальной документации по Sync Resources](https://komo.do/docs/resources/sync-resources). Для homelab с десятком-двумя контейнеров ручной перенос через UI обычно быстрее, чем разбираться с синтаксисом TOML — но если стеков полсотни, Sync того стоит. Слава Богу у меня их пока еще не больше 50.

Один Komodo Core может управлять несколькими Docker-хостами одновременно — для этого на каждом дополнительном хосте нужно установить агент **Periphery**. У меня, например, есть отдельный хост с Immich, который я подключил именно так.

Periphery можно запустить как Docker-контейнер (это уже встроено в наш `docker-compose.yaml` для локального хоста), но для **удалённых** хостов официально рекомендуется systemd-установка — она проще и избегает сложностей с монтированием сокета и путей через слой контейнера. Полное описание всех способов установки — в [официальной документации "Connect More Servers"](https://komo.do/docs/setup/connect-servers).

### Root-установка (рекомендуемый способ)

На целевом хосте, где нужно поставить агент:

```bash
curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py \
  | sudo python3 - \
  --core-address="https://komodo.stilicho.ru" \
  --connect-as="immich-host" \
  --onboarding-key="O-ваш_ключ_из_UI"
```

`--onboarding-key` берётся в Komodo UI: **Servers → Add Server**, там генерируется одноразовый ключ вида `O-...`, который свяжет новый агент с вашим Core.

Включаем автозапуск:

```bash
sudo systemctl enable periphery
sudo systemctl status periphery
```

### User-установка (без root-сервиса)

Если не хотите root-сервис, можно поставить Periphery как **user-level** systemd service:

```bash
curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py \
  | python3 - --user \
  --core-address="https://komodo.stilicho.ru" \
  --connect-as="immich-host" \
  --onboarding-key="O-ваш_ключ_из_UI"
```

Обязательно включите linger, иначе сервис остановится при выходе из SSH-сессии:

```bash
sudo loginctl enable-linger $USER
```

### Грабли, на которые я наступил (и как их избежать сразу)

При user-установке скрипт на момент написания статьи **не меняет** `root_directory` в конфиге — он остаётся `/etc/komodo` по умолчанию, куда обычный пользователь писать не может. В результате сервис падает с ошибкой:

```
Failed to write private key pem to "/etc/komodo/keys/periphery.key"
Caused by: Permission denied (os error 13)
```

И вторые грабли, в которые я наступил уже позже, когда пытался перенести существующий стек immich в Komodo: `root_directory` — это не просто "куда положить ключи", это **единственная директория, внутри которой Periphery вообще способна видеть какие-либо файлы** (и для systemd-варианта тоже, не только для контейнера — я сам ошибочно думал иначе). Если указать туда узкий путь вроде `~/.local/share/komodo`, Periphery не увидит ваши реальные compose-проекты, которые лежат где-то в другом месте (например, `~/docker/immich`), и при попытке добавить Stack вы получите `No such file or directory`.

Чтобы не наступать на эти грабли дважды, сразу правим конфиг на правильное значение — родительскую директорию, где у вас на этом хосте лежат (или будут лежать) все compose-проекты:

```bash
nano ~/.config/komodo/periphery.config.toml
```

```toml
root_directory = "/home/<ваш_юзер>/docker"
```

Создаём директорию **от имени своего пользователя**, не через `sudo mkdir` (иначе владельцем снова окажется `root`, и грабли с правами повторятся):

```bash
mkdir -p /home/<ваш_юзер>/docker
```

Перезапускаем:

```bash
systemctl --user daemon-reload
systemctl --user restart periphery
journalctl --user -u periphery -n 30 --no-pager
```

В логе должно появиться:

```
INFO PeripheryStartup: PeripheryConfig { ... root_directory: "/home/<ваш_юзер>/docker", ... }
INFO Logged in to Komodo Core komodo.stilicho.ru websocket as Server immich-host
```

> **Если вы уже прошли онбординг со старым узким путём** (как получилось у меня) — после смены `root_directory` ключи (`periphery.key`, `periphery.pub`, `core.pub`) будут искаться по новому пути и их там не будет. Проще всего скопировать их из старой локации в новую, чтобы не проходить онбординг заново:
> ```bash
> mkdir -p /home/<ваш_юзер>/docker/keys
> cp /home/<ваш_юзер>/.local/share/komodo/keys/* /home/<ваш_юзер>/docker/keys/
> ```
> После этого перезапуск сервиса должен пройти без повторного онбординга.

Проверьте, что нужная папка (в моём случае — `immich`) теперь видна:

```bash
ls /home/<ваш_юзер>/docker/immich
```

Если файлы видны — можно возвращаться в Komodo UI и создавать Stack для этого сервиса точно так же, как мы делали для локальных стеков (**Server** → `immich-host`, **Source** → Files on Server, **Run Directory** → `/home/<ваш_юзер>/docker/immich`, **File Paths** → ваше имя compose-файла — проверьте точное название через `docker compose ls` прямо на этом хосте).

Также убедитесь, что ваш пользователь состоит в группе `docker` — без этого Periphery не сможет достучаться до `docker.sock`:

```bash
groups $USER
sudo usermod -aG docker $USER   # если нужно — затем перелогиньтесь
```

### Проверка в UI

После успешного онбординга новый хост появится в Komodo UI на вкладке **Servers** в статусе "Connected", с видимыми метриками (CPU/RAM/диск) и полным списком контейнеров этого хоста — включая, в моём случае, Immich. Дальше им можно управлять (деплой, рестарт, логи) прямо из Komodo, без захода по SSH.

## Мониторинг диска и алерты

Komodo умеет присылать алерты по использованию диска на каждом подключённом сервере. Чтобы получить корректный размер именно корневого раздела (а не заниженное/завышенное значение из-за особенностей подсчёта), в `compose.env` уже стоит:

```bash
PERIPHERY_INCLUDE_DISK_MOUNTS=/etc/hostname
```

Если получите алерт вида (на вставке ниже именно мой алерт):

```json
{
  "name": "Local",
  "path": "/etc/hostname",
  "used_gb": 178.38,
  "total_gb": 228.39
}
```

— это не ошибка Komodo, а честное сообщение о реальном заполнении диска. Стоит проверить, что именно ест место:

```bash
docker system df -v
sudo du -xh --max-depth=1 / | sort -rh | head -20
```

Обратите внимание на флаг `-x` у `du` — он не даёт команде заходить в другие смонтированные файловые системы (например, сетевые шары в `/mnt`), так что вы видите только то, что реально занимает место на локальном диске. И не забывайте `sudo` — без него `du` молча пропускает директории вроде `/var/lib/docker`, к которым у обычного пользователя нет прав чтения, и итоговая цифра окажется сильно заниженной.

## Итог

Мы развернули Komodo с:

- MongoDB как базой данных (без FerretDB/Postgres);
- bind mount вместо именованных volume для всех данных;
- Traefik-маршрутизацией по домену;
- входом через authentik (OIDC) с fallback на локального админа;
- дополнительным хостом, подключённым через Periphery как systemd-агент.

Главный практический урок этой статьи — **`root_directory`/`PERIPHERY_ROOT_DIRECTORY` нужно продумывать сразу**, до первого деплоя, а не по факту получения `No such file or directory`. Это ограничение действует одинаково и для контейнеризованного Periphery, и для systemd-агента (в том числе на удалённых хостах вроде моего `immich-host`) — указывайте сразу родительскую директорию, где лежат или будут лежать все ваши compose-проекты на конкретном хосте, а не узкую служебную папку. Я на этом моменте много времени потерял

Также я описал, как выглядит сам интерфейс и как перенести уже работающие compose-стеки в Komodo без даунтайма.

За кадром пока остались **Builds** и **Repos** — то есть сборка образов прямо из git и полноценный CI/CD-воркфлоу. У меня в планах снять видео про установку Forgejo как self-hosted git-сервер и подключить его к Komodo для автоматических сборок и деплоя по вебхуку — об этом расскажу в следующих статьях.

