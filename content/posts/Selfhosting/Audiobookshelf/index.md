---
title: Audiobookshelf — лучший self-hosted сервер аудиокниг
published: 2025-07-14
pinned: false
description: Пошаговое руководство по установке Audiobookshelf — удобного сервиса для хранения и прослушивания аудиокниг. Установка через Docker, настройка и преимущества.
tags:
  - Audiobookshelf
  - Docker
  - Self-Hosting
slug: /audiobookshelf-install-docker
categories: Медиа-серверы
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Self-Hosting
youtube_id: 16dXTRP4Z-g
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.webp
summary: Полная инструкция по установке и настройке Audiobookshelf для хранения и прослушивания аудиокниг на личном сервере. Рассмотрены все шаги от установки до веб-интерфейса и мобильного доступа.
---

#  Audiobookshelf — лучший self-hosted сервер аудиокниг

<iframe width="100%" height="468" src="https://www.youtube.com/embed/16dXTRP4Z-g?si=91_9bJ1KOg3DiFzP" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>


Если вам понравилась эта статья, вы можете поддержать автора, став спонсором на Boosty (ссылка в разделе «Контакты»).

---

##  Вступление

Привет! Ты на сайте **Stilicho2011**, и сегодня мы поговорим об отличной self-hosted платформе — **Audiobookshelf**.

Если у тебя накопилось много аудиокниг, и ты хочешь слушать их с любого устройства, синхронизировать прогресс и не зависеть от сторонних сервисов — оставайся, будет интересно!

---

## Что такое Audiobookshelf?

**Audiobookshelf** — это бесплатное и полностью открытое веб-приложение, которое превращает твой сервер в полноценную аудиобиблиотеку.

**Основные возможности:**

- Загрузка и структурирование аудиокниг  
- Прослушивание через браузер и мобильное приложение  
- Синхронизация прогресса между устройствами  
- Закладки и заметки  
- Полный контроль и конфиденциальность  

---

## Установка через Docker

Проще всего установить Audiobookshelf с помощью Docker. Вот минимальный `docker-compose.yml`, который я использовал в ролике:

```yaml
services:
  audiobookshelf:
    image: ghcr.io/advplyr/audiobookshelf:latest
    container_name: audiobookshelf
    #ports:
    #  - 13378:80
    volumes:
      - /mnt/media:/audiobooks
      - /mnt/media:/podcasts
      - /home/user/docker/audiobookshelf/config:/config
      - /home/user/docker/audiobookshelf/metadata:/metadata
    environment:
      - TZ=Europe/Moscow
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      proxy:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.audiobookshelf.entrypoints=http"
      - "traefik.http.routers.audiobookshelf.rule=Host(`audiobookshelf.domain.ru`)"
      - "traefik.http.middlewares.audiobookshelf-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.audiobookshelf.middlewares=audiobookshelf-https-redirect"
      - "traefik.http.routers.audiobookshelf-secure.entrypoints=https"
      - "traefik.http.routers.audiobookshelf-secure.rule=Host(`audiobookshelf.domain.ru`)"
      - "traefik.http.routers.audiobookshelf-secure.tls=true"
      - "traefik.http.routers.audiobookshelf-secure.service=audiobookshelf"
      - "traefik.http.services.audiobookshelf.loadbalancer.server.port=80"
      - "traefik.docker.network=proxy"

networks:
  proxy:
    external: true
```
Запуск сервиса

```bash
docker compose up -d
```

После запуска — открой в браузере 'https://audiobookshelf.domain.ru'

 Интерфейс и возможности

- После первого входа можно:

- Добавить папки с аудиокнигами

- Автоматически подтянуть обложки и описания

- Использовать удобный встроенный плеер

- Отслеживать прогресс по книгам

- Работать с закладками и заметками

Поддерживаемые форматы:
.mp3, .m4b (с поддержкой глав), ID3-теги и встроенные обложки.
Доступен мобильный режим (через PWA или браузер), а также многопользовательский режим.
---

Безопасность и доступ из сети

Рекомендуется разместить Audiobookshelf за reverse-proxy, например:
Traefik + Authelia, Authentik, Keycloak, Zitadel,
или Nginx + Basic Auth.

Также стоит подключить SSL-сертификат Let's Encrypt, чтобы слушать книги из любой точки мира по HTTPS.
---

Плюсы и минусы

## Плюсы:

Бесплатно и с открытым исходным кодом

Простой и удобный интерфейс

Отличная синхронизация и мобильная поддержка

Работает полностью локально

## Минусы:

Нет поиска по содержимому книг

Некоторые форматы требуют перекодировки

Нельзя стримить напрямую из облачных хранилищ
---

Заключение

Audiobookshelf — отличное self-hosted решение для хранения и прослушивания аудиокниг.