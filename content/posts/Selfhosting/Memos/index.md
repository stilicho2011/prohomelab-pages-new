---
title: Memos — минималистичное приложение для заметок и личных мыслей. Установка и возможности self-hosted решения
published: 2026-02-17
pinned: false
description: Пошаговая инструкция по установке, настройке и использованию Memos — лёгкого open-source приложения для ведения заметок, дневника и личной базы знаний с возможностью самохостинга.
tags:
  - PKM
  - Self-Hosting
  - Memos
  - Docker
slug: /memos
categories: Personal Knowledge Base
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Self-Hosting
youtube_id: kK0nx3FlsBs
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Разбираем установку и настройку Memos — минималистичного self-hosted приложения для быстрых заметок и личного дневника. Покажу запуск в Docker, основные возможности, организацию заметок и сценарии использования в homelab.
---


## Memos — лёгкое self-hosted приложение для заметок. Обзор возможностей и сценарии использования в homelab

Если вы ищете минималистичное self-hosted приложение для заметок, которое можно развернуть в Docker или LXC-контейнере в Proxmox, — Memos заслуживает внимания.
Это open-source решение для ведения личных заметок, технического дневника и базы знаний без перегруженного интерфейса и лишних функций.

<iframe width="560" height="315" src="https://www.youtube.com/embed/kK0nx3FlsBs?si=4NwFtXozu1rCN3OV" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

### Что такое Memos и чем оно отличается от других систем заметок

Memos — это лёгкое open-source приложение для заметок в формате временной ленты (timeline).
В отличие от перегруженных сервисов вроде Notion или Obsidian, здесь нет сложной иерархии страниц, баз данных и блоковых структур.

Главная идея — быстрая фиксация мыслей:

- короткие текстовые записи

- поддержка Markdown

- автоматическая фиксация времени

- теги прямо в тексте

- быстрый поиск

По философии это ближе к «техническому микроблогу», чем к классической wiki.

## Почему Memos подходит для self-hosted и homelab

Для homelab важны три вещи:

- Контроль над данными

- Простота развёртывания

- Минимальные требования к ресурсам

Memos закрывает все три пункта.


### Основные возможности Memos

1. Формат ленты (timeline)

Все заметки отображаются в виде хронологической ленты.
Это удобно для записи идей по проектам

2. Теги и фильтрация

Поддерживаются хештеги:

```yaml
#docker
#proxmox
#traefik
#auth
```

Можно фильтровать по тегам и быстро находить записи.
Это удобно при ведении заметок.

3. Поддержка нескольких пользователей

Memos позволяет:

- создавать пользователей

- изолировать данные

- использовать роли

Можно развернуть один экземпляр для семьи или команды.

4. Минимальные системные требования

Memos не требует:

- отдельной PostgreSQL

- сложной конфигурации

- внешнего кэша

- тяжёлых зависимостей

Это делает его идеальным кандидатом для:

- мини-ПК

- одноплатников

- VPS

5. Лёгкая база знаний

Если не нужна сложная иерархия как в Trilium Notes или тяжёлый PKM-подход, Memos отлично подойдёт для атомарных заметок.

## Преимущества Memos:

- Open-source

- Self-hosted

- Минимализм

- Быстрое развёртывание

- Низкое потребление ресурсов

- Поддержка Docker

## Возможные ограничения

Memos не подойдёт, если вам нужны:

- сложные вложенные структуры

- базы данных внутри заметок

- канбан-доски

- продвинутая wiki-система

Это осознанно минималистичный инструмент.

Итог

Memos — это идеальный self-hosted цифровой блокнот для homelab-инфраструктуры.

Если вам нужно:

- быстро записывать мысли

- хранить данные локально

это одно из самых простых и удобных решений.


## Пример docker compose файла из видео ролика

```yaml
services:
  memos:
    image: neosmemo/memos:stable
    container_name: memos
    #ports:
    #  - "5230:5230"
    volumes:
      - /home/путь/до/memos:/var/opt/memos
    environment:
      - MEMOS_MODE=prod
      - MEMOS_PORT=5230
    restart: unless-stopped
    networks:
      proxy:                              # Подключаем контейнер к внешней сети "proxy" (используется Traefik)
    labels:                               # Метки для интеграции с Traefik (обратный прокси)
      - "traefik.enable=true"                                      # Включаем обработку контейнера Traefik
      - "traefik.http.routers.memos.entrypoints=web"             # Определяем HTTP-вход (порт 80)
      - "traefik.http.routers.memos.rule=Host(`memos.домен.ru`)"  # Трафик на этот домен будет направляться в данный контейнер   
      - "traefik.http.middlewares.memos-https-redirect.redirectscheme.scheme=https"         # Middleware для редиректа с HTTP на HTTPS
      - "traefik.http.routers.memos.middlewares=memos-https-redirect"          # Применяем middleware редиректа к HTTP-маршруту
      - "traefik.http.routers.memos-secure.entrypoints=websecure"          # Определяем HTTPS-вход (порт 443)
      - "traefik.http.routers.memos-secure.rule=Host(`memos.домен.ru`)"         # HTTPS-маршрут для того же домена 
      - "traefik.http.routers.memos-secure.tls=true"          # Включаем TLS (HTTPS)
      - "traefik.http.routers.memos-secure.service=memos"     # Привязываем HTTPS-маршрут к сервису memos     
      - "traefik.http.services.memos.loadbalancer.server.port=5230"          # Указываем внутренний порт, на котором memos слушает в контейнере
      - "traefik.docker.network=proxy"          # Указываем, что Traefik должен искать контейнер в сети "proxy"                          
   
networks:
  proxy:                                  # Определение внешней сети для взаимодействия с Traefik
    external: true                        # Сеть уже создана ранее (не создавать заново)        
```