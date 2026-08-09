---
title: ZITADEL — современное IAM-решение с открытым исходным кодом
published: 2025-08-02
pinned: false
description: ZITADEL — это мощная и гибкая платформа для управления идентификацией и доступом (IAM), которая сочетает в себе поддержку современных протоколов, управление пользователями, MFA и многое другое.
tags:
  - Authentik
  - IAM
  - IdP
  - SSO
  - Homelab
  - Keycloak
  - Authelia
  - Zitadel
slug: zitadel-iam-overview
categories: Zitadel
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - IAM-решения
youtube_id: X7LDG2httyk
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: /featured.png
summary: Пошаговая инструкция по установке и настройке Zitadel для организации двухфакторной аутентификации с обратным прокси. Рассмотрены конфигурация пользователей, интеграция с Docker и рекомендации по повышению безопасности веб-сервисов.
---

## Что такое ZITADEL?

<iframe width="100%" height="468" src="https://www.youtube.com/embed/X7LDG2httyk?si=mkaNdbS8K4oFoHz1" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на бусти (ссылка в разделе контакты).

**ZITADEL** — это система управления идентификацией и доступом (IAM), разработанная швейцарской компанией **CAOS AG**. Она предоставляет полный набор функций по управлению пользователями, безопасной аутентификации и авторизации, подходящий как для небольших проектов, так и для крупных корпоративных решений.

Главное преимущество ZITADEL — это сочетание **открытого исходного кода**, **современной архитектуры** и **облачной ориентации**, что делает его удобным для DevOps, SaaS-платформ и internal tool-авторизации.

---

## Ключевые возможности ZITADEL

### Поддержка современных протоколов

- **OIDC (OpenID Connect)**  
- **OAuth 2.0**  
- **SAML 2.0**

Это делает Zitadel совместимым с большинством современных веб-приложений и сервисов.

### Многоарендность и управление организациями

- Поддержка multi-tenant архитектуры
- Отдельные пространства для организаций
- Делегирование прав администраторам

### Многофакторная аутентификация (MFA)

- Email/OTP  
- TOTP (Google Authenticator)  
- SMS  
- WebAuthn (FIDO2, YubiKey и др.)

Настраивается централизованно или на уровне организации.

### API и CLI

- Полноценный REST и gRPC API  
- `zitadel` CLI  
- Поддержка DevOps-инфраструктуры (CI/CD, GitOps)

### Ролевое управление доступом

- Роли на уровне проектов, приложений и пользователей  
- Кастомные клеймы и scopes в токенах  
- RBAC/ABAC-подход

### Облачное и локальное развёртывание

- Хостинг от разработчиков (SaaS)  
- Self-hosted: Docker, Kubernetes, Podman  
- Поддержка PostgreSQL и CockroachDB

---

## Преимущества ZITADEL

| Возможность              | ZITADEL        | Keycloak     | Auth0        | Authelia / TinyAuth |
|--------------------------|----------------|--------------|--------------|----------------------|
| Open Source              | ✅              | ✅            | ❌            | ✅                   |
| OIDC/SAML                | ✅              | ✅            | ✅            | ❌/частично           |
| MFA                      | ✅              | ✅            | ✅            | ❌/частично           |
| Multi-tenant             | ✅              | Частично     | ✅            | ❌                   |
| UI для self-service      | ✅              | ❌            | ✅            | ❌                   |
| API / CLI                | ✅              | Частично     | ✅            | ❌                   |

---

## Как начать

Пример docker compose файла, который использовался в ролике :

```bash
services:
    zitadel:
        restart: "always"
        container_name: zitadel
        networks:
            - zitadel
            - proxy
        image: "ghcr.io/zitadel/zitadel:latest"
        command: 'start-from-init --masterkey "${MASTERKEY_32}" --tlsMode external'
        env_file: .env
        environment:
            ZITADEL_DATABASE_POSTGRES_HOST: zitadel-db
            ZITADEL_DATABASE_POSTGRES_PORT: 5432
            ZITADEL_DATABASE_POSTGRES_DATABASE: zitadel
            ZITADEL_DATABASE_POSTGRES_USER_USERNAME: ${DB_USER}
            ZITADEL_DATABASE_POSTGRES_USER_PASSWORD: ${DB_PASSWORD}
            ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE: disable
            ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME: ${DB_ADMIN_USER}
            ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD: ${DB_ADMIN_PASSWORD}
            ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE: disable
            ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME: ${ZITADEL_LOGIN_USER} 
            ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD: ${ZITADEL_LOGIN_PASSWORD}
            ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORDCHANGEREQUIRED: false
            ZITADEL_FIRSTINSTANCE_ORG_NAME: HomeLab
            ZITADEL_PORT: 8080 #For External TLS (Also use h2c)
            ZITADEL_EXTERNALPORT: 443
            ZITADEL_EXTERNALDOMAIN: ${ZITADEL_SUBDOMAIN}.${DOMAIN_NAME} #eg. auth.DOMAIN_NAME
            ZITADEL_EXTERNALSECURE: true
        labels:
            - "traefik.enable=true"
            - "traefik.http.routers.zitadel.entrypoints=http"
            - "traefik.http.routers.zitadel.rule=Host(`${ZITADEL_SUBDOMAIN}.${DOMAIN_NAME}`)"
            - "traefik.http.middlewares.https-redirect.redirectscheme.scheme=https"
            - "traefik.http.routers.zitadel.middlewares=https-redirect"
            - "traefik.http.routers.zitadel-secure.entrypoints=https"
            - "traefik.http.routers.zitadel-secure.rule=Host(`${ZITADEL_SUBDOMAIN}.${DOMAIN_NAME}`)"
            - "traefik.http.routers.zitadel-secure.tls=true"
            - "traefik.http.routers.zitadel-secure.service=zitadel"
            - "traefik.http.services.zitadel.loadbalancer.server.scheme=h2c"
            - "traefik.http.services.zitadel.loadbalancer.passHostHeader=true"
            - "traefik.http.services.zitadel.loadbalancer.server.port=8080"
            - "traefik.docker.network=proxy"
        depends_on:
            zitadel-db:
                condition: "service_healthy"

    zitadel-db:
        restart: "always"
        container_name: zitadel-db
        image: postgres:17-alpine
        env_file: .env
        environment:
            POSTGRES_USER: ${DB_ADMIN_USER}
            POSTGRES_PASSWORD: ${DB_ADMIN_PASSWORD}
        networks:
            - zitadel
        healthcheck:
            test:
                [
                    "CMD-SHELL",
                    "pg_isready",
                    "-d",
                    "zitadel",
                    "-U",
                    "${DB_ADMIN_USER}",
                ]
            interval: "10s"
            timeout: "30s"
            retries: 5
            start_period: "20s"
        volumes:
            - ${DB_LOCATION}:/var/lib/postgresql/data

networks:
    zitadel:
        name: zitadel
    proxy:
        external: true
        name: proxy
```

Пример файла окружения с переменными

```bash
MASTERKEY_32=GENERATE_RANDOM_KEY_LENGTH_32_ChangeMe  #Replace Master Key (tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
DB_USER=Enter_DB_User_ChangeMe
DB_PASSWORD=Enter_DB_Password_ChangeMe
DB_ADMIN_USER=Enter_DB_Root_User_ChangeMe
DB_ADMIN_PASSWORD=Enter_DB_Root_Password_ChangeMe
ZITADEL_LOGIN_USER=Loginusername@Your_Domain_ChangeMe.com
ZITADEL_LOGIN_PASSWORD=Zitadel_Password_ChangeMe
ZITADEL_SUBDOMAIN=zitadel
DOMAIN_NAME=Your_Domain_ChangeMe.com
DB_LOCATION=/path/to/directory/zitadel/zitadel-db
```
