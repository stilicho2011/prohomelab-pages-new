---
title: "Обзор Linkwarden: Современный self-hosted менеджер закладок"
published: 2025-07-14
pinned: false
description: Linkwarden — это мощное и современное решение для хранения, архивации и управления закладками с открытым исходным кодом. В статье рассматриваются ключевые особенности, преимущества и сценарии использования.
tags:
  - Linkwarden
  - Docker
  - Self-Hosting
slug: /Linkwarden
categories: Linkwarden
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Self-Hosting
youtube_id: jyntWB8SQIw
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.webp
summary: Пошаговая инструкция по установке и настройке Linkwarden для безопасного управления ссылками. Рассмотрены установка сервера, настройка пользователей, интеграция с браузером и мобильными устройствами, а также базовые настройки безопасности.
---

<iframe width="100%" height="468" src="https://www.youtube.com/embed/jyntWB8SQIw?si=k8KkP0S03LjHm7w8" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на бусти (ссылка в разделе контакты).

## Что такое Linkwarden?

**Linkwarden** — это self-hosted приложение с открытым исходным кодом для управления и архивирования закладок. Оно создано для пользователей, которые ценят контроль над своими данными, хотят иметь локальную копию важной информации из Интернета и использовать удобный интерфейс для систематизации ссылок.

Проект активно развивается и позиционируется как альтернатива сервисам вроде Pocket, Raindrop.io и Pinboard, но с упором на приватность, автономность и open source.

![Linkwarden интерфейс](https://github.com/linkwarden/linkwarden/raw/main/public/screenshots/dashboard.png)

## Основные особенности

### Архивация веб-страниц

Linkwarden не просто сохраняет ссылку — он **архивирует содержимое страницы** (включая текст, изображения, стили), позволяя просматривать его даже в оффлайне. Это особенно полезно для создания базы знаний, хранения научных материалов и блогов, которые могут исчезнуть из Сети.

### Полноценный поиск

Поддерживается **полнотекстовый поиск** по сохранённым страницам. Вы можете найти нужный материал даже если забыли ссылку или название.

### Теги и коллекции

Ссылки можно организовывать с помощью **тегов** и **коллекций**, что значительно упрощает навигацию по большому количеству закладок.

### Мультипользовательская поддержка

Linkwarden поддерживает **мультипользовательский режим** с разграничением прав доступа. Это удобно для командной работы или семейного использования.

### Приватность и контроль

Развёртывая Linkwarden на собственном сервере, вы получаете полный контроль над своими данными. Поддерживается аутентификация через email, Google, GitHub и другие провайдеры с помощью протокола OAuth 2.0.


## Основные возможности в табличном формате

| Возможность | Описание |
|--------------|-----------|
| **Архивирование страниц** | Автоматически сохраняет HTML, PDF и скриншоты добавленных ссылок. |
| **Режим чтения и аннотации** | Позволяет читать статьи без рекламы, делать заметки и подсветку текста. |
| **Коллекции и теги** | Организует контент в иерархические коллекции с тегами. |
| **Совместная работа** | Делитесь коллекциями и управляйте правами участников. |
| **Импорт / экспорт** | Поддержка импортов из браузеров и экспорт в CSV/HTML. |
| **Поиск по контенту** | Быстрый полнотекстовый поиск (через Meilisearch). |
| **Интеграции (API, SSO)** | Поддержка Authentik, REST API и кастомных подключений. |
| **Расширения и клиенты** | Chrome Extension, PWA, Android и iOS приложения. |
| **AI-теги и автоанализ** | Определяет тематику ссылок по содержимому страницы. |
| **Wayback Machine** | Отправка ссылок на archive.org для долговременного хранения. |

---

### Простая установка (Docker)

Проект поставляется с готовыми Docker-контейнерами. Развертывание занимает всего пару минут:

```bash
git clone https://github.com/linkwarden/linkwarden
cd linkwarden
cp .env.example .env
docker compose up -d
```

### Файлы, которые использовались в ролике

Docker compose файл

```yaml
services:
  postgres:
    container_name: postgres_linkwarden
    image: postgres:16-alpine
    env_file: .env
    restart: always
    volumes:
      - /home/stilicho/docker/linkwarden/pgdata:/var/lib/postgresql/data
    networks:
      - linkwarden #not nessassary if you don not use another postgress instance
      #- proxy
  linkwarden:
    container_name: linkwarden
    env_file: .env
    environment:
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/postgres
    restart: always
    # build: . # uncomment this line to build from source
    image: ghcr.io/linkwarden/linkwarden:latest # comment this line to build from source
    #ports:
    #  - 3000:3000
    volumes:
      - /home/stilicho/docker/linkwarden/data:/data/data
    depends_on:
      - postgres
    networks:
      - proxy
      - linkwarden #not nessassary if you don not use another postgress instance
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      - "traefik.http.routers.linkwarden.entrypoints=http"
      - "traefik.http.routers.linkwarden.rule=Host(`linkwarden.domain.ru`)"
      - "traefik.http.middlewares.linkwarden-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.linkwarden.middlewares=linkwarden-https-redirect"
      - "traefik.http.routers.linkwarden-secure.entrypoints=https"
      - "traefik.http.routers.linkwarden-secure.rule=Host(`linkwarden.domain.ru`)"
      - "traefik.http.routers.linkwarden-secure.tls=true"
      - "traefik.http.routers.linkwarden-secure.tls.certresolver=cloudflare"
      - "traefik.http.routers.linkwarden-secure.service=linkwarden"
      - "traefik.http.services.linkwarden.loadbalancer.server.port=3000" # make sure the loadbalancer is the last line!!!

networks:
  proxy:
    external: true
  linkwarden:
    external: true
```

Файл окружения

```yaml
NEXTAUTH_URL=https://linkwarden.domain.ru/api/v1/auth
# NEXTAUTH_URL=http://localhost:3000/api/v1/auth # Uncomment this if you don't want to use another Identity Provider
NEXTAUTH_SECRET=linkwarden
POSTGRES_PASSWORD=Rpassword

# SMTP Settings
#NEXT_PUBLIC_EMAIL_PROVIDER=
#EMAIL_FROM=
#EMAIL_SERVER=
#BASE_URL=

#################
# SSO Providers #
#################

#AUTHENTIK_CUSTOM_NAME=Authentik
#NEXTAUTH_URL=https://linkwarden.domain.ru/api/v1/auth
#NEXT_PUBLIC_AUTHENTIK_ENABLED=true
#AUTHENTIK_CUSTOM_NAME=authentik
#AUTHENTIK_ISSUER=https://auth.domain.ru/application/o/linkwarden
#AUTHENTIK_CLIENT_ID=ID
#AUTHENTIK_CLIENT_SECRET=SECRET
```

## Сравнение с альтернативами

| Характеристика           | Linkwarden | Pocket | Raindrop.io | Wallabag |
|--------------------------|------------|--------|-------------|----------|
| Self-hosted              | ✅         | ❌     | ❌          | ✅       |
| Архивация страниц        | ✅         | ❌     | ✅ (Pro)     | ✅       |
| Полнотекстовый поиск     | ✅         | ✅     | ✅          | ✅       |
| Мультипользовательский   | ✅         | ❌     | ✅          | ✅       |
| Открытый исходный код    | ✅         | ❌     | ❌          | ✅       |


## Использование в homelab'е

Для владельцев домашнего сервера или homelab-энтузиастов, Linkwarden — отличное дополнение к стеку self-hosting-приложений. Он легко интегрируется с Traefik, Nginx или Caddy и может быть защищён через SSO (например, с Authentik или Authelia).

## Заключение

Linkwarden — это современный и мощный инструмент для управления ссылками, созданный с упором на приватность, удобство и независимость от облачных сервисов. Он идеально подойдёт как для личного использования, так и для совместной работы в команде или семье.
