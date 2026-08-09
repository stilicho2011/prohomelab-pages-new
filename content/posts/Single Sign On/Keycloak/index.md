---
title: Установка и настройка Keycloak
published: 2025-08-02
pinned: false
description: Пошаговая инструкция по установке Keycloak с помощью Docker и обратного прокси на базе Traefik.
tags:
  - Authentik
  - IAM
  - IdP
  - SSO
  - Homelab
  - Keycloak
  - Authelia
  - Zitadel
slug: /keycloak
categories: Keycloak
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - IAM-решения
youtube_id: OPk-woAkZaw
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Пошаговая инструкция по установке и настройке Keycloak для организации двухфакторной аутентификации с обратным прокси. Рассмотрены конфигурация пользователей, интеграция с Docker и рекомендации по повышению безопасности веб-сервисов.
---

## Что такое Keycloak

Keycloak — это open-source решение для управления идентификацией и доступом (IAM) с поддержкой SSO (Single Sign-On), OAuth2, OpenID Connect, SAML 2.0 и других стандартов. Оно часто используется DevOps- и enterprise-средой (де-факто стандарт в крупном энтерпрайзе) для централизованной аутентификации и авторизации пользователей в приложениях.

<iframe width="100%" height="468" src="https://www.youtube.com/embed/OPk-woAkZaw?si=V0vZZEPZ388XWgQ5" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на бусти (ссылка в разделе контакты)
---

## Зачем нужен Keycloak

Keycloak позволяет централизованно управлять аутентификацией пользователей:

- Единый вход (SSO) для всех приложений
- Поддержка внешних провайдеров (Google, GitHub и др.)
- Подключение LDAP и Active Directory
- Удобная админка
- OpenID Connect и OAuth 2.0

---

## Что понадобится

- Docker + Docker Compose
- Обратный прокси (Traefik)
- Домен с настройкой DNS (`auth.example.ru`)
- SSL-сертификат (через Let's Encrypt)

---

## Возможности Keycloak

### Аутентификация и авторизация

- Single Sign-On (SSO) — единый вход во все подключенные приложения.

- Поддержка социальных логинов — Google, Facebook, GitHub и др.

- Поддержка стандартов — OAuth2, OpenID Connect, SAML 2.0.

- Поддержка MFA (многофакторная аутентификация) — TOTP (Google Authenticator и аналоги).

### Управление пользователями и ролями

- Создание и управление пользователями, группами и ролями.

- Делегированное администрирование (разграничение доступа между администраторами).

- Импорт и экспорт пользователей (LDAP, CSV, REST API).

### Интеграция с корпоративной инфраструктурой

- Интеграция с LDAP / Active Directory.

- SCIM-подобные возможности через REST API.

- Поддержка клиента CLI и Admin REST API.

### Multi-tenancy и реалмы

- Поддержка множественных реалмов (изолированных доменов аутентификации).

- Каждый реалм имеет свои настройки, пользователей, клиентов и политик.

### Кастомизация

- Кастомизация UI экранов входа и регистрации.

- Расширяемость через Java SPI/плагины.

- Локализация интерфейса.

### Аудит и безопасность

- Аудит логов входа и действий.

- Настраиваемые политики паролей.

- Поддержка ограничений IP, блокировка по IP, brute-force защита.

## Docker compose файл, который используется в ролике

```yaml
services:
    postgres:
        image: postgres:16-alpine
        container_name: keycloak-db
        restart: always
        expose:
            - 5432
        volumes:
            - /home/path/to/keycloak/database:/var/lib/postgresql/data
        environment:
            POSTGRES_DB: ${POSTGRES_DB}
            POSTGRES_USER: ${POSTGRES_USER}
            POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
        healthcheck:
            test:
                [
                    "CMD",
                    "pg_isready",
                    "-q",
                    "-d",
                    "${POSTGRES_DB}",
                    "-U",
                    "${POSTGRES_USER}",
                ]
            interval: 10s
            timeout: 5s
            retries: 3
            start_period: 60s
        networks:
            - keycloak

    keycloak:
        image: quay.io/keycloak/keycloak
        container_name: keycloak
        command: start
        environment:
            KC_HOSTNAME: ${KEYCLOAK_HOSTNAME}
            KC_BOOTSTRAP_ADMIN_USERNAME: ${KC_BOOTSTRAP_ADMIN_USERNAME}
            KC_BOOTSTRAP_ADMIN_PASSWORD: ${KC_BOOTSTRAP_ADMIN_PASSWORD}
            KC_DB: postgres
            KC_DB_URL: jdbc:postgresql://postgres/${POSTGRES_DB}
            KC_DB_USERNAME: ${POSTGRES_USER}
            KC_DB_PASSWORD: ${POSTGRES_PASSWORD}
            KC_PROXY_HEADERS: "xforwarded"
            KC_HTTP_ENABLED: true
            KC_HEALTH_ENABLED: true
            PROXY_ADDRESS_FORWARDING: "true"
        healthcheck:
            test:
                - "CMD-SHELL"
                - |
                    exec 3<>/dev/tcp/localhost/9000 &&
                    echo -e 'GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' >&3 &&
                    cat <&3 | tee /tmp/healthcheck.log | grep -q '200 OK'
            interval: 10s
            timeout: 5s
            retries: 3
            start_period: 90s
        #ports:
        #  - 8080:8080
        #expose:
        #  - 8080 # web ui http
        #  - 9000 # health endpoint
        restart: always
        depends_on:
            postgres:
                condition: service_healthy
        networks:
            - keycloak
            - proxy
        labels:
            - "traefik.enable=true"
            - "traefik.http.routers.keycloak.entrypoints=http"
            - "traefik.http.routers.keycloak.rule=Host(`keycloak.domain.ru`)"
            - "traefik.http.middlewares.keycloak-https-redirect.redirectscheme.scheme=https"
            - "traefik.http.routers.keycloak.middlewares=keycloak-https-redirect"
            - "traefik.http.routers.keycloak-secure.entrypoints=https"
            - "traefik.http.routers.keycloak-secure.rule=Host(`keycloak.domain.ru`)"
            - "traefik.http.routers.keycloak-secure.tls=true"
            - "traefik.http.routers.keycloak-secure.service=keycloak"
            - "traefik.http.services.keycloak.loadbalancer.server.port=8080"
            - "traefik.docker.network=proxy"

networks:
    keycloak:
        internal: true
    proxy:
        external: true
```

Значения в файле переменных

```yaml
# define FQDN hostname
KEYCLOAK_HOSTNAME=keycloak.stilicho.ru

# define login credentials
KC_BOOTSTRAP_ADMIN_USERNAME=admin
KC_BOOTSTRAP_ADMIN_PASSWORD=password

# define database credentials
POSTGRES_DB=keycloak_db
POSTGRES_USER=keycloak_db_user
POSTGRES_PASSWORD=keycloak_db_user_password
```

---

## Ссылки

- [Откуда я узнал, как настраивать Portainer](https://www.keycloak.org/securing-apps/oidc-layers)
