---
title: Установка Nextcloud AIO — простое и мощное облако в Docker
published: 2025-10-25
pinned: false
description: Пошаговая установка Nextcloud AIO (All-in-One) в Docker. Разберем, что такое Nextcloud, чем отличается версия AIO, и приведем готовый docker-compose файл с пояснениями.
tags:
  - Nextcloud
  - Docker
slug: /nextcloud-aio
categories: Nextcloud
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Nextcloud
youtube_id: LOox1g4HfcU
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Пошаговая инструкция по установке и настройке Nextcloud AIO для развертывания личного облачного сервера. Рассмотрены установка через Docker, настройка пользователей, хранилища и веб-интерфейса, а также интеграция с мобильными устройствами.
---


<iframe width="100%" height="468" src="https://www.youtube.com/embed/LOox1g4HfcU?si=Dkmv-4Idonj_OP4Q" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

## Что такое Nextcloud

**Nextcloud** — популярная open-source платформа для создания собственного облачного хранилища и совместной работы.  
Она позволяет хранить файлы, документы, фотографии, синхронизировать их между устройствами, а также использовать встроенные сервисы:

- календарь и задачи;
- видеоконференции (**Nextcloud Talk**);
- офисные документы (**Nextcloud Office / Collabora**);
- систему заметок и совместного редактирования.

Nextcloud часто называют **самостоятельной альтернативой Google Workspace и Microsoft 365**, которую можно полностью контролировать и размещать на своём сервере без зависимости от внешних облаков.

---

## Что такое Nextcloud AIO

**Nextcloud AIO (All-in-One)** — официальная сборка Nextcloud, созданная разработчиками проекта для **максимального упрощения установки и обновления**.

В отличие от классической установки, где приходится вручную настраивать Apache/Nginx, PHP, Redis, MariaDB и Cron, AIO использует **Docker** и включает всё необходимое в контейнерах:

- Nextcloud (веб-интерфейс);
- PostgreSQL (база данных);
- Redis (кеширование);
- Collabora Online (редактирование документов);
- OnlyOffice (опционально);
- Backup-контейнер (автоматическое резервное копирование).

Главное преимущество AIO — **автоматическое обновление всех компонентов** и возможность развернуть рабочее облако всего за несколько минут.  
Сборка идеально подходит для **домашних серверов, LXC-контейнеров в Proxmox или VPS**, где важны простота и стабильность.

---

## Когда стоит использовать **Nextcloud AIO**?

Если вы хотите быстро развернуть Nextcloud с минимальными усилиями и без необходимости настройки отдельных компонентов.

---

## Требования к установке

Перед началом убедитесь, что у вас установлены:

- **Docker** и **Docker Compose** (версии 2.0+);
- сервер с не менее чем **2 ГБ ОЗУ**;
- доменное имя и доступ по **HTTPS** (желательно через Traefik, Caddy или Nginx Proxy Manager).

---

## Docker Compose для Nextcloud AIO

Ниже приведён минимальный пример `docker-compose.yml` для запуска Nextcloud AIO с обратным прокси **Traefik**, как показано в ролике в начале статьи:

```yaml
services:
  nextcloud-aio-mastercontainer:
    image: nextcloud/all-in-one:latest
    init: true
    restart: always
    container_name: nextcloud-aio-mastercontainer # This line is not allowed to be changed as otherwise AIO will not work correctly
    volumes:
      - nextcloud_aio_mastercontainer:/mnt/docker-aio-config # This line is not allowed to be changed as otherwise the built-in backup solution will not work
      - /var/run/docker.sock:/var/run/docker.sock:ro # May be changed on macOS, Windows or docker rootless. See the applicable documentation. If adjusting, don't forget to also set 'WATCHTOWER_DOCKER_SOCKET_PATH'!
    #network_mode: bridge # add to the same network as docker run would do
    ports:
      #- 80:80 # Can be removed when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else). See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
      - 8087:8080
      #- 8443:8443 # Can be removed when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else). See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
    environment: # Is needed when using any of the options below
       AIO_DISABLE_BACKUP_SECTION: false # Setting this to true allows to hide the backup section in the AIO interface. See https://github.com/nextcloud/all-in-one#how-to-disable-the-backup-section
       APACHE_PORT: 11000 # Is needed when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else). See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
       APACHE_IP_BINDING: 0.0.0.0 # Should be set when running behind a web server or reverse proxy (like Apache, Nginx, Caddy, Cloudflare Tunnel and else) that is running on the same host. See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
       BORG_RETENTION_POLICY: --keep-within=7d --keep-weekly=4 --keep-monthly=6 # Allows to adjust borgs retention policy. See https://github.com/nextcloud/all-in-one#how-to-adjust-borgs-retention-policy
      # COLLABORA_SECCOMP_DISABLED: false # Setting this to true allows to disable Collabora's Seccomp feature. See https://github.com/nextcloud/all-in-one#how-to-disable-collaboras-seccomp-feature
       NEXTCLOUD_DATADIR: /media/nextcloud # Allows to set the host directory for Nextcloud's datadir. ⚠️⚠️⚠️ Warning: do not set or adjust this value after the initial Nextcloud installation is done! See https://github.com/nextcloud/all-in-one#how-to-change-the-default-location-of-nextclouds-datadir
       NEXTCLOUD_MOUNT: /media # Allows the Nextcloud container to access the chosen directory on the host. See https://github.com/nextcloud/all-in-one#how-to-allow-the-nextcloud-container-to-access-directories-on-the-host
      # NEXTCLOUD_UPLOAD_LIMIT: 10G # Can be adjusted if you need more. See https://github.com/nextcloud/all-in-one#how-to-adjust-the-upload-limit-for-nextcloud
      # NEXTCLOUD_MAX_TIME: 3600 # Can be adjusted if you need more. See https://github.com/nextcloud/all-in-one#how-to-adjust-the-max-execution-time-for-nextcloud
      # NEXTCLOUD_MEMORY_LIMIT: 512M # Can be adjusted if you need more. See https://github.com/nextcloud/all-in-one#how-to-adjust-the-php-memory-limit-for-nextcloud
      # NEXTCLOUD_TRUSTED_CACERTS_DIR: /path/to/my/cacerts # CA certificates in this directory will be trusted by the OS of the nexcloud container (Useful e.g. for LDAPS) See See https://github.com/nextcloud/all-in-one#how-to-trust-user-defined-certification-authorities-ca
      # NEXTCLOUD_STARTUP_APPS: deck twofactor_totp tasks calendar contacts notes # Allows to modify the Nextcloud apps that are installed on starting AIO the first time. See https://github.com/nextcloud/all-in-one#how-to-change-the-nextcloud-apps-that-are-installed-on-the-first-startup
       NEXTCLOUD_ADDITIONAL_APKS: imagemagick # This allows to add additional packages to the Nextcloud container permanently. Default is imagemagick but can be overwritten by modifying this value. See https://github.com/nextcloud/all-in-one#how-to-add-os-packages-permanently-to-the-nextcloud-container
       NEXTCLOUD_ADDITIONAL_PHP_EXTENSIONS: imagick # This allows to add additional php extensions to the Nextcloud container permanently. Default is imagick but can be overwritten by modifying this value. See https://github.com/nextcloud/all-in-one#how-to-add-php-extensions-permanently-to-the-nextcloud-container
      # NEXTCLOUD_ENABLE_DRI_DEVICE: true # This allows to enable the /dev/dri device in the Nextcloud container. ⚠️⚠️⚠️ Warning: this only works if the '/dev/dri' device is present on the host! If it should not exist on your host, don't set this to true as otherwise the Nextcloud container will fail to start! See https://github.com/nextcloud/all-in-one#how-to-enable-hardware-transcoding-for-nextcloud
      # NEXTCLOUD_KEEP_DISABLED_APPS: false # Setting this to true will keep Nextcloud apps that are disabled in the AIO interface and not uninstall them if they should be installed. See https://github.com/nextcloud/all-in-one#how-to-keep-disabled-apps
      # TALK_PORT: 3478 # This allows to adjust the port that the talk container is using. See https://github.com/nextcloud/all-in-one#how-to-adjust-the-talk-port
      # WATCHTOWER_DOCKER_SOCKET_PATH: /var/run/docker.sock # Needs to be specified if the docker socket on the host is not located in the default '/var/run/docker.sock'. Otherwise mastercontainer updates will fail. For macos it needs to be '/var/run/docker.sock'
    # security_opt: ["label:disable"] # Is needed when using SELinux
    networks: 
      - nextcloud   
  # # Optional: Caddy reverse proxy. See https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md
  # # You can find further examples here: https://github.com/nextcloud/all-in-one/discussions/588
  # caddy:
  #   image: caddy:alpine
  #   restart: always
  #   container_name: caddy
  #   volumes:
  #     - ./Caddyfile:/etc/caddy/Caddyfile
  #     - ./certs:/certs
  #     - ./config:/config
  #     - ./data:/data
  #     - ./sites:/srv
  #   network_mode: "host"

  go-vod:
    image: radialapps/go-vod
    restart: always
    depends_on:
      - nextcloud-aio-mastercontainer
    environment:
      - NEXTCLOUD_HOST=https://next.domain.ru
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - /media/nextcloud:/mnt/ncdata:ro
    runtime: nvidia
    networks:
      - nextcloud 

volumes: # If you want to store the data on a different drive, see https://github.com/nextcloud/all-in-one#how-to-store-the-filesinstallation-on-a-separate-drive
  nextcloud_aio_mastercontainer:
    name: nextcloud_aio_mastercontainer # This line is not allowed to be changed as otherwise the built-in backup solution will not work

networks:
  nextcloud:
    name: nextcloud
    external: true   
```

Пример динамической конфигурации для обратного прокси **Traefik**

```yaml
http:
  routers:
    nextcloud:
      entrypoints:
        - "https"
      rule: "Host(`subdomain.domain.ru`)"
      middlewares:
        - https-redirect
        - nextcloud-secure-headers
      tls:
        domains:
          - main: "subdomain.domain.ru"
      service: nextcloud
  services:
    nextcloud:
      loadBalancer:
        servers:
          - url: "http://your_vm_ip:11000"
        passHostHeader: true
  middlewares:
    crowdsec-bouncer: #if you use crowdsec
      forwardauth:
        address: http://bouncer-traefik:8080/api/v1/forwardAuth
        trustForwardHeader: true
        # https://github.com/goauthentik/authentik/issues/2366
    middlewares-authentik: # if you use authentik
      forwardAuth:
        address: "http://authentik_server:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
          - X-authentik-jwt
          - X-authentik-meta-jwks
          - X-authentik-meta-outpost
          - X-authentik-meta-provider
          - X-authentik-meta-app
          - X-authentik-meta-version
    
    nextcloud-secure-headers:
      headers:
        hostsProxyHeaders:
          - "X-Forwarded-Host"
        referrerPolicy: "same-origin"
        customResponseHeaders:
          X-Robots-Tag: "noindex, nofollow" #changed from default "none" parameter
 
    https-redirect:
      redirectScheme:
        scheme: https
        permanent: true
   
    nextcloud-chain:
      chain:
        middlewares:
          # - ... (e.g. rate limiting middleware)
          - https-redirect
          - nextcloud-secure-headers
```

## Основные моменты моего файла

**Nextcloud AIO**

Контейнер: `nextcloud-aio-mastercontainer`

`container_name` и `volumes` с именем `nextcloud_aio_mastercontainer` менять нельзя — это правило для работы встроенного бэкапа.

Порты:

`8087:8080` — значит веб-интерфейс будет доступен на <http://host:8087>.

Остальные порты закомментированы, что нормально при использовании обратного прокси.

Переменные окружения:

`NEXTCLOUD_DATADIR: /media/nextcloud` и `NEXTCLOUD_MOUNT: /media` — правильно, чтобы **Nextcloud** и **go-vod** видели один и тот же каталог.

`APACHE_PORT` и `APACHE_IP_BINDING` настроены для обратного прокси.

`NEXTCLOUD_ADDITIONAL_APKS` и `NEXTCLOUD_ADDITIONAL_PHP_EXTENSIONS` — добавили `imagemagick` и `imagick`, что будет полезно для обработки изображений.

**go-vod**

Зависит от Nextcloud AIO (depends_on).

Используется NVIDIA GPU (runtime: nvidia и NVIDIA_VISIBLE_DEVICES=all).

`volumes: /media/nextcloud:/mnt/ncdata:ro` — только для чтения, чтобы Go-VOD мог обрабатывать файлы Nextcloud без риска изменения.

Переменная `NEXTCLOUD_HOST=https://next.domain.ru` — должна указывать на ваш реальный домен Nextcloud.

**Сеть**

Оба контейнера подключены к внешней сети nextcloud, что позволяет им общаться друг к другу по имени контейнера.

**Volumes**

`nextcloud_aio_mastercontainer` — важен для встроенного бэкапа.

Остальные данные Nextcloud находятся в NEXTCLOUD_DATADIR.

## Рекомендации / Проверки

GPU для go-vod:

Убедитесь, что драйвер NVIDIA и nvidia-container-toolkit установлены на хосте.

Проверить, что контейнер видит GPU.

Права на каталог Nextcloud:

`/media/nextcloud` должен быть доступен как для AIO, так и для go-vod.

Для go-vod стоит :ro (только для чтения), это безопасно.

Обратный прокси:

Порты 80/443 закомментированы, значит, нужно настроить внешний обратный прокси Nginx/Caddy/Traefik.

`APACHE_PORT = 11000`, убедитесь, что ваш прокси использует этот порт для проксирования.

Бэкап:

Не трогайте `volume nextcloud_aio_mastercontainer`.

Можно проверять резервные копии через AIO интерфейс.

## Запуск и настройка Nextcloud AIO

1. Сохраните файл как `docker-compose.yml`.

2. Запустите команду:

```yaml
docker compose up -d
```

1. Перейдите в браузере по адресу:

```bash
http://<IP_сервера>:8080
```

1. Следуйте мастеру установки:

- Укажите домен (например, cloud.prohomelab.com),

- Настройте HTTPS (через встроенный Let's Encrypt или прокси),

- Дождитесь автоматического развёртывания всех контейнеров.

## Заключение

Nextcloud AIO — идеальный вариант для тех, кто хочет запустить мощное облако «в один клик».
Он сочетает удобство Docker, автоматические обновления и надёжность официальной поддержки команды Nextcloud.
Такой подход отлично подойдёт для домашнего сервера, LXC-контейнера в Proxmox или VPS, где важны простота, безопасность и автономность.
