---
title: Установка Authelia в Docker | Полный гайд
published: 2025-08-06
pinned: false
description: Пошаговая инструкция по установке и настройке Authelia в Docker. Узнайте, как защитить свои веб-приложения с помощью двухфакторной аутентификации и обратного прокси.
tags:
  - Authentik
  - IAM
  - IdP
  - SSO
  - Homelab
  - Keycloak
  - Authelia
  - Zitadel
slug:
categories: Authelia
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - IAM-решения
youtube_id: bJG-CMxmISc
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.webp
summary:
---


Authelia — это современное решение для управления доступом и двухфакторной аутентификации, которое легко разворачивается в Docker-среде. В этом руководстве мы разберём, что такое Authelia, как его установить и чем оно отличается от других решений для SSO (Single Sign-On).

<iframe width="100%" height="468" src="https://www.youtube.com/embed/bJG-CMxmISc?si=q-cLiavEGkcnjhQw" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
---

## Что такое Authelia?

**Authelia** — это открытая платформа для аутентификации и авторизации, предназначенная для защиты веб-приложений, развернутых за обратным прокси (например, [Traefik](https://doc.traefik.io/) или NGINX).

### Основные функции Authelia

- Защита любых веб-приложений по домену или URI
- Поддержка 2FA (TOTP, Duo, WebAuthn и др.)
- Интеграция с LDAP, Active Directory, или файлами
- Совместимость с Traefik, NGINX, Caddy
- Полноценный SSO механизм
- Поддержка ACL (прав доступа на основе правил)

---

## Чем отличается Authelia от других решений?

| Характеристика     | **Authelia** | Authentik | Keycloak | ZITADEL |
|--------------------|--------------|-----------|----------|---------|
| Легкость установки | ⭐⭐⭐⭐         | ⭐⭐⭐       | ⭐        | ⭐⭐      |
| Поддержка 2FA      | ✅            | ✅         | ✅        | ✅       |
| Поддержка SSO      | ✅            | ✅         | ✅        | ✅       |
| Open Source        | ✅            | ✅         | ✅        | ✅       |
| Web-интерфейс      | ❌ (консоль)  | ✅         | ✅        | ✅       |
| Производительность | Высокая       | Средняя    | Низкая   | Средняя |
| Поддержка ACL      | ✅            | ✅         | Ограничено| ❌      |

Authelia — отличный выбор для тех, кто хочет **максимальную безопасность** при **минимуме ресурсов**, особенно в self-hosted среде.

---

## Предварительные требования

Перед установкой убедитесь, что у вас есть:

- Docker и Docker Compose
- Обратный прокси (например, Traefik)
- Настроенные домены и HTTPS (например, через Let's Encrypt)
- Базовые знания работы с YAML и Docker

---

## Примерная структура проекта

```bash
authelia/
├── configuration.yml
├── users.yml
├── docker-compose.yml
└── secrets
 ```

```yaml
services:
    authelia:
        image: "authelia/authelia"
        container_name: "authelia"
        volumes:
            - "./secrets:/secrets:ro"
            - "./config:/config"
            - "./logs:/var/log/authelia/"
        networks:
            proxy:
        labels:
            - "traefik.enable=true"
            - "traefik.http.routers.authelia.rule=Host(`authelia.domain.ru`)"
            - "traefik.http.routers.authelia.entrypoints=https"
            - "traefik.http.routers.authelia.tls=true"
            - "traefik.http.middlewares.authelia.forwardAuth.address=http://authelia:9091/api/verify?rd=https://authelia.stilicho.ru"
            - "traefik.http.middlewares.authelia.forwardAuth.trustForwardHeader=true"
            - "traefik.http.middlewares.authelia.forwardAuth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
            - "traefik.http.services.authelia.loadbalancer.server.port=9091"
        environment:
            TZ: "Europe/Moscow"
            AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE: "/secrets/JWT_SECRET" # tr -cd '[:alnum:]' < /dev/urandom | fold -w 64 | head -n 1 > ./secrets/JWT_SECRET
            AUTHELIA_SESSION_SECRET_FILE: "/secrets/SESSION_SECRET" # tr -cd '[:alnum:]' < /dev/urandom | fold -w 64 | head -n 1 > ./secrets/SESSION_SECRET
            AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE: "/secrets/STORAGE_ENCRYPTION_KEY" # tr -cd '[:alnum:]' < /dev/urandom | fold -w 64 | head -n 1 > ./secrets/STORAGE_ENCRYPTION_KEY

    #whoami-secure:
    #    image: "traefik/whoami"
    #    restart: "unless-stopped"
    #    container_name: "whoami-secure"
    #    labels:
    #        - "traefik.enable=true"
    #        - "traefik.http.routers.whoami-secure.rule=Host(`whoami-secure.stilicho.ru`)"
    #        - "traefik.http.routers.whoami-secure.entrypoints=https"
    #        - "traefik.http.routers.whoami-secure.middlewares=authelia@docker"
    #    networks:
    #        proxy:

networks:
    proxy:
        external: true

```

```yaml
users:
    stilicho: ## Username
        displayname: "stilicho"
        ## WARNING: This is a default password for testing only!
        ## IMPORTANT: Change this password before deploying to production!
        ## Generate a new hash using the instructions at:
        ## https://www.authelia.com/reference/guides/passwords/#passwords
        ## Password is 'authelia'
        password: "$argon2id$v=19$m=65536,t=3,p=4$uSPUUUh/a5U7pNso6g2cMA$YJECeQHkv/qXZDB3W9ADkWj7DMSJRWcn/pVHTUvCbtI"
        email: "authelia@authelia.com"
        groups:
            - "admin"
            - "dev"

```

```yaml
server:
    address: tcp://0.0.0.0:9091/
log:
    level: debug
theme: dark
# This secret can also be set using the env variables AUTHELIA_JWT_SECRET_FILE
#jwt_secret:
default_redirection_url: https://authelia.stilicho.ru
totp:
    issuer: authelia.com

# duo_api:
#  hostname: api-123456789.example.com
#  integration_key: ABCDEF
#  # This secret can also be set using the env variables AUTHELIA_DUO_API_SECRET_KEY_FILE
#  secret_key: 1234567890abcdefghifjkl

authentication_backend:
    file:
        path: /config/users.yml
        password:
            algorithm: argon2
            # Recommended Parameters
            # Uses 2 GiB memory, then immediately releases it.
            # See https://www.authelia.com/reference/guides/passwords/#recommended-parameters-argon2
            # See https://www.rfc-editor.org/rfc/rfc9106.html#section-4 for details on tuning the parameters for your hardware.
            # After saving configuration file, password hash can be generated by running: docker run -v ./configuration.yml:/configuration.yml --rm authelia/authelia:latest authelia crypto hash generate --config /configuration.yml --password 'yourpassword'
            argon2:
                variant: argon2id
                iterations: 1
                memory: 2097152
                parallelism: 4
                key_length: 32
                salt_length: 16
            # Recommended Parameters when constrained by low memory or low powered hardware. Uses 64 KiB memory, then immediately releases it.
            # argon2:
            #   variant: argon2id
            #   iterations: 3
            #   memory: 65536
            #   parallelism: 4
            #   key_length: 32
            #   salt_length: 16

access_control:
    default_policy: deny
    rules:
        # Rules applied to everyone
        - domain: traefik-dashboard.stilicho.ru
          policy: two_factor
        #- domain: portainer.stilicho.ru #для portainer есть oidc
        #  policy: two_factor
        - domain: nginx.stilicho.ru
          policy: two_factor

session:
    name: authelia_session
    # This secret can also be set using the env variables AUTHELIA_SESSION_SECRET_FILE
    #secret:
    expiration: 14400 # 4 hour
    inactivity: 14400 # 4 hour
    domain: stilicho.ru # Should match whatever your root protected domain is

    # redis:
    #   host: redis
    #   port: 6379
    #   # This secret can also be set using the env variables AUTHELIA_SESSION_REDIS_PASSWORD_FILE
    #   # password: authelia

regulation:
    max_retries: 3
    find_time: 120
    ban_time: 300

storage:
    #encryption_key: /secrets/STORAGE_ENCRYPTION_KEY # Now required
    local:
        path: /config/db.sqlite3

#password_policy:
#  zxcvbn:
#    enabled: true
#    min_score: 4

#identity_providers:
#  oidc:
## The other portions of the mandatory OpenID Connect 1.0 configuration go here.
## See: https://www.authelia.com/c/oidc
#    clients:
#      - client_id: 'portainer'
#        client_name: 'Portainer'
#        client_secret: '$pbkdf2-sha512$310000$c8p78n7pUMln0jzvd4aK4Q$JNRBzwAo0ek5qKn50cFzzvE9RXV88h1wJn5KGiHrD0YKtZaR/nCb2CJPOsKaPK0hjf.9yHxzQGZziziccp6Yng'  # The digest of 'insecure_secret'.
#        public: false
#        authorization_policy: 'two_factor'
#        require_pkce: false
#        pkce_challenge_method: ''
#        redirect_uris:
#          - 'https://portainer.stilicho.ru'
#        scopes:
#         - 'openid'
#          - 'profile'
#          - 'groups'
#          - 'email'
#        response_types:
#          - 'code'
#        grant_types:
#          - 'authorization_code'
#        access_token_signed_response_alg: 'none'
#        userinfo_signed_response_alg: 'none'
#        token_endpoint_auth_method: 'client_secret_post'

#log:
#  level: info
#  format: text
#  file_path: /logs/authelia.log
#  keep_stdout: false

notifier:
    # smtp:
    #   username: test
    #   # This secret can also be set using the env variables AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE
    #   password: password
    #   host: mail.example.com
    #   port: 25
    #   sender: admin@example.com
    filesystem:
        filename: /config/notification.txt

```
