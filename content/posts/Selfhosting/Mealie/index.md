---
title: Mealie — self-hosted приложение для рецептов, планирования питания и списка покупок
published: 2025-10-25
pinned: false
description: Mealie — открытое self-hosted веб-приложение для управления рецептами, планирования питания и автоматического формирования списка покупок. Запуск на Docker или LXC в домашнем сервере Proxmox.
tags:
  - Mealie
  - Self-Hosting
  - Docker
slug: /mealie
categories: Self-hosted
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Self-Hosting
youtube_id: IyfOr-gnVYg
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Пошаговая инструкция по установке и настройке Mealie для управления рецептами на личном сервере. Рассмотрены установка через Docker, настройка базы данных, веб-интерфейса и мобильного доступа, а также интеграция с внешними источниками рецептов.
---


<iframe width="100%" height="468" src="https://www.youtube.com/embed/IyfOr-gnVYg?si=HDkXIqM64LZz_p6N" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

![](56229bc824840a680286166b94c86540_MD5.png)

## Что такое Mealie

**Mealie** — это **открытое**, **self-hosted** веб-приложение для управления рецептами, планирования питания и составления списка покупок.  
Сайт проекта: [mealie.io](https://mealie.io)  
Документация: [docs.mealie.io](https://docs.mealie.io)

Главные особенности:

- Установка на собственном сервере или домашней инфраструктуре — без зависимости от облачных сервисов.
- Импорт рецептов с веб-страниц с помощью встроенного «скрепера».
- Современный интерфейс на Vue.js, backend с REST API.
- Планировщик питания (meal planner) и списки покупок (shopping list).
- Поддержка нескольких пользователей и групп.
- Организация рецептов в коллекции, теги, категории.

---

## Основные возможности Mealie

1. **Импорт рецептов**  
   Можно вводить вручную или передавать ссылку на веб-страницу, и Mealie извлечет ингредиенты и инструкции.  
   Подробнее на GitHub: [github.com/mealie-recipes/mealie](https://github.com/mealie-recipes/mealie)

2. **Редактор рецептов**  
   Полное редактирование ингредиентов, инструкций, фото и описаний.

3. **Планировщик питания**  
   Распределение блюд по дням недели/месяца.

4. **Список покупок**  
   Автоматическое формирование списка на основе выбранных рецептов, с возможностью группировки по отделам магазина.

5. **Организация рецептов**  
   Теги, категории, коллекции (cookbooks) для удобного поиска.

6. **API и интеграции**  
   REST API, вебхуки, поддержка Home Assistant и других систем.

7. **Локализация**  
   Интерфейс доступен на многих языках.

---

## Почему Mealie интересен домашним энтузиастам

Если у вас уже есть домашний сервер или кластер (например, Proxmox и мини ПК), Mealie идеально впишется:

- Запуск в контейнере Docker или LXC.
- Полный контроль над данными — ваши рецепты, планы питания и списки покупок остаются у вас.
- Возможность использовать как контент-базу для блога или YouTube-канала.
- Интеграция с домашней автоматизацией: уведомления о запланированных блюдах, списки ингредиентов на холодильнике и др.

---

## Возможные ограничения

- Масштабирование порций (recipe scaling) может быть неидеальным.  
  [Источник обсуждения на Reddit](https://www.reddit.com/r/selfhosted/comments/moqspg/mealie_probably_the_best_selfhosted_recipe/)
- Требуются базовые навыки self-hosting: подготовка сервера/контейнера, резервное копирование, безопасность.
- Мобильные приложения сторонние, основное использование через веб-интерфейс.  
  [Пример мобильного клиента для iOS](https://apps.apple.com/kz/app/mealieswift/id6745277962)

---

## Как начать использовать Mealie

1. Подготовить сервер или контейнер (Docker Compose или LXC в Proxmox).
2. Установить Mealie: загрузить Docker-образ, настроить базу данных и переменные окружения.
3. Подключиться через браузер и создать пользователя.
4. Импортировать несколько рецептов (ссылки или вручную).
5. Создать план питания на неделю и проверить список покупок.
6. Настроить резервное копирование.
7. (Опционально) Интегрировать с Home Assistant для уведомлений о блюдах.

---

Mealie — отличный инструмент для домашних кулинаров и тех, кто ценит полный контроль над своими данными.  
Если у вас есть сервер или кластер Proxmox, его запуск — вопрос нескольких минут.

## Примерный docker compose файл, который использовался в ролике

```yaml
---
services:
    mealie:
        image: ghcr.io/mealie-recipes/mealie:latest #
        container_name: mealie
        #ports:
        #    - "9925:9000" #
        deploy:
            resources:
                limits:
                    memory: 1000M #
        volumes:
            - /home/user/docker/mealie/mealie-data:/app/data/
        environment:
            # Set Backend ENV Variables Here
            - ALLOW_SIGNUP=false
            - PUID=1000
            - PGID=1000
            - TZ=Europe/Moscow
            - MAX_WORKERS=1
            - WEB_CONCURRENCY=1
            - BASE_URL=https://mealie.user.ru
            - DEFAULT_GROUP=Home
            - DEFAULT_HOUSEHOLD=Family
            #Email Configuration
            - SMTP_HOST=smtp.gmail.com
            - SMTP_PORT=465
            - SMTP_FROM_NAME=mail@gmail.com
            - SMTP_AUTH_STRATEGY=SSL # Options: 'TLS', 'SSL', 'NONE'
            - SMTP_FROM_EMAIL=mail@gmail.com
            - SMTP_USER=mail@gmail.com
            - SMTP_PASSWORD=pas wor dddd password
            #OIDC credentials
            - OIDC_AUTH_ENABLED=true
            - OIDC_SIGNUP_ENABLED=true
            - OIDC_CONFIGURATION_URL=https://authentik.domain.ru/application/o/mealie/.well-known/openid-configuration
            - OIDC_CLIENT_ID=secret
            - OIDC_CLIENT_SECRET=big secret
            #  - OIDC_AUTO_REDIRECT=false
            - OIDC_REMEMBER_ME=true
            #  - OIDC_AUTO_REDIRECT=false
            - OIDC_SIGNUP_ENABLED=true
        #  - OIDC_USER_CLAIM=email
        #  - OIDC_GROUPS_CLAIM=groups
        #  - OIDC_USER_GROUP=my_family
        #  - OIDC_ADMIN_GROUP=mealie_Admins
        #  - OIDC_USER_GROUP=mealie_users
        #  - OIDC_PROVIDER_NAME=Authentik
        #  - LOG_LEVEL=DEBUG
        restart: unless-stopped
        networks:
            proxy:
        security_opt:
            - no-new-privileges:true
        labels:
            - "traefik.enable=true"
            - "traefik.http.routers.mealie.entrypoints=web"
            - "traefik.http.routers.mealie.rule=Host(`mealie.domain.ru`)"
            - "traefik.http.middlewares.mealie-https-redirect.redirectscheme.scheme=https"
            - "traefik.http.routers.mealie.middlewares=mealie-https-redirect"
            - "traefik.http.routers.mealie-secure.entrypoints=websecure"
            - "traefik.http.routers.mealie-secure.rule=Host(`mealie.domain.ru`)"
            - "traefik.http.routers.mealie-secure.tls=true"
            - "traefik.http.routers.mealie-secure.service=mealie"
            - "traefik.http.services.mealie.loadbalancer.server.port=9000"
            - "traefik.docker.network=proxy"

networks:
    proxy:
        external: true
```