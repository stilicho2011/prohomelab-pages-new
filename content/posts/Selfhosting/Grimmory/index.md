---
title: Grimmory — self-hosted библиотека и читалка для вашей коллекции книг
published: 2026-04-02
pinned: false
description: Пошаговое руководство по установке и настройке Grimmory — self-hosted платформы для управления библиотекой электронных книг с веб-читалкой и поддержкой Docker.
tags:
  - Books
  - Docker
  - Self-Hosting
  - Grimmory
slug: /grimmory
categories: Self-Hosting
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Self-Hosting
youtube_id: X-UFP3VGEaI
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: "Подробная инструкция по установке и настройке Grimmory: развёртывание в Docker, добавление книг, организация библиотеки и использование встроенной веб-читалки."
---

Если вам понравилась эта статья, то можете поддержать автора, став спонсором на [Boosty](https://boosty.to/stilicho2011).

<iframe width="560" height="315" src="https://www.youtube.com/embed/X-UFP3VGEaI?si=eJUuAAl2mVlgH6uy" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

В одной из недавних [статей](https://prohomelab.com/posts/booklore/) я рассказывал про приложение Booklore — платформу для управления своей web-библиотекой.

При этом в другой своей [статье](https://prohomelab.com/posts/best-apps-2025/), посвящённой лучшим open-source приложениям 2025 года, я указал это приложение как одно из открытий года.

По странному стечению обстоятельств буквально за пару дней до публикации видеообзора на это приложение автор удалил этот проект.

---

# Что случилось с Booklore: разбор ситуации

Удаление проекта **Booklore** стало неожиданностью для пользователей, но если разобрать сообщения разработчика и обсуждения в Reddit/GitHub, становится понятна реальная картина.

---

## Позиция разработчика

Автор проекта опубликовал [тред](https://www.reddit.com/r/selfhosted/comments/1rs4nx0/my_side_of_the_story_from_the_developer_of/) на Reddit под названием:

> “My side of the story, from the developer of BookLore”

Это была попытка объяснить происходящее, однако ключевую роль сыграла не только его позиция, а скорее реакция пользователей.

Один из показательных комментариев:

> “you removed the API docs without notice”

### Что это означает по факту:

- изменения вносились **без предупреждения**; 
- нарушалась **обратная совместимость**.

В итоге страдали пользователи и разработчики интеграций
---

## Конфликт с сообществом

Со временем накопились системные проблемы во взаимодействии с пользователями.

### Из основных претензии можно отметить следующие: 

- существенные, вплоть до breaking changes, изменения без уведомлений;  
- удаление или ломание функциональности;  
- слабая на грани отсутствия обратная связь;  

В результате возник классический для мира *open-source* конфликт:  
**разработчик vs сообщество**
---

## Резкое исчезновение проекта

В момент удаления пользователи зафиксировали:

- GitHub-репозиторий стал недоступен (404)
- Discord-сервер исчез
- не было официального объявления

Это выглядело как **исключительно эмоциональное решение**, своего рода реакция на местами более чем справедливую критику, а потому это было некрасиво по отношению к обычным пользователям, которые не были в курсе происходящего.
---

## Проблемы с форками и лицензией

Дополнительным фактором стали споры вокруг лицензии (AGPL-3.0).

### Что происходило:

- появились форки проекта (например, Grimmory, герой сегодняшней статьи)
- обсуждались возможные нарушения лицензии
- возникли конфликты вокруг использования кода 

Последнее - вообще нередкий случай, долстаточно посмотреть на ситуацию вокруг OnlyOffice и Nextcloud.
---

## Накалпивающиеся негатив вокруг проекта

Ещё до удаления наблюдались тревожные сигналы:

- баги
- обсуждения “стоит ли использовать Booklore”  
- критика архитектурных решений  
- вопросы к telemetry. Да, тут тоже были вопросы.  

То есть проект уже находился под давлением со стороны пользователей.
---

## Итог: проект был удалён

Фактически к удалению Booklore привела не какая-то одна причина, а целая цепочка событий:
---

## Главный вывод

В данном случае это не обычная история про “разработчик устал”, как недавно произошло с очень хорошим проектом [Palmr](https://github.com/kyantech/Palmr).

Скорее речь идёт о **плохой коммуникации → конфликте → токсичной среде → резком удалении проекта**.
---

Ваш покорный слуга об этом ничего не знал и спокойно опубликовал видео про этот [проект](https://www.youtube.com/watch?v=IY65OiL_AtU&t=235s) на разных видеоплощадках.
Мне, конечно, написали в комментариях о том, что я неправ, проект уже мёртв, а видео неактуально. Ну ладно, у меня нет конфликта с сообществом, поэтому вот вам замена.
Как я указал выше, оригинальный проект Booklore был быстро форкнут сообществом. Так как оригинальный Booklore публиковался под лицензией AGPL, то проект [Grimmory](https://grimmory.org/) — это фактически один в один перелицованный Booklore, но с новым названием.
Если посмотреть файлы конфигурации, то в оригинальном docker-compose файле до сих пор фигурирует переменная booklore. В любом случае, так как получилась ситуация, в которой я опубликовал уже на дату публикации неактуальную статью, исправляюсь.

Ниже привожу рабочий вариант docker-compose файла и файла окружения

```yaml
services:                               # Секция описания сервисов (контейнеров)

  booklore:                             # Имя сервиса BookLore
    image: grimmory/grimmory:latest     # Docker-образ BookLore из Docker Hub (тег latest)
    # image: ghcr.io/booklore-app/booklore:latest
    # Альтернативный образ из GitHub Container Registry (закомментирован)
    container_name: grimmory            # Явное имя контейнера в Docker
    environment:                        # Переменные окружения контейнера
      - USER_ID=${APP_USER_ID}          # UID пользователя для работы контейнера (права на файлы)
      - GROUP_ID=${APP_GROUP_ID}        # GID группы для файлов и каталогов
      - TZ=${TZ}                        # Часовой пояс контейнера
      - DATABASE_URL=${DATABASE_URL}    # URL подключения к базе данных MariaDB
      - DATABASE_USERNAME=${DB_USER}    # Имя пользователя базы данных
      - DATABASE_PASSWORD=${DB_PASSWORD} # Пароль пользователя базы данных
      - BOOKLORE_PORT=${BOOKLORE_PORT}  # Внутренний порт BookLore
    depends_on:                         # Зависимости сервиса
      mariadb:                          # Зависимость от сервиса mariadb
        condition: service_healthy      # Запуск только после успешного healthcheck БД
    ports:
      - "${BOOKLORE_PORT}:${BOOKLORE_PORT}"   # Проброс порта: host → container (обычно не нужен при использовании Traefik)
    volumes:
      - ./data:/app/data                # Данные приложения BookLore
      - ./books:/books                  # Каталог с библиотекой книг
      - ./bookdrop:/bookdrop            # Папка для автоматического импорта книг
    healthcheck:                        # Проверка работоспособности контейнера
      test: wget -q -O - http://localhost:${BOOKLORE_PORT}/api/v1/healthcheck
      # HTTP-запрос к встроенному healthcheck API BookLore
      interval: 60s                     # Интервал между проверками
      retries: 5                        # Количество попыток до признания контейнера unhealthy
      start_period: 60s                 # Время ожидания перед началом проверок
      timeout: 10s                      # Таймаут одной проверки
    restart: unless-stopped             # Автоперезапуск контейнера (кроме ручной остановки)
    networks:
      proxy:                            # Подключение к внешней сети proxy (Traefik)
    labels:                             # Метки Docker для интеграции с Traefik
      - "traefik.enable=true"           # Включаем обработку контейнера Traefik
      - "traefik.http.routers.grimmory.entrypoints=web" # HTTP-вход (порт 80)
      - "traefik.http.routers.grimmory.rule=Host(`grimmory.stilicho.ru`)" # Направляем трафик с домена booklore.stilicho.ru в этот контейнер
      - "traefik.http.middlewares.grimmory-https-redirect.redirectscheme.scheme=https" # Middleware для редиректа HTTP → HTTPS
      - "traefik.http.routers.grimmory.middlewares=grimmory-https-redirect" # Применяем middleware редиректа к HTTP-маршруту
      - "traefik.http.routers.grimmory-secure.entrypoints=websecure" # HTTPS-вход (порт 443)
      - "traefik.http.routers.grimmory-secure.rule=Host(`grimmory.stilicho.ru`)" # HTTPS-маршрут для того же домена
      - "traefik.http.routers.grimmory-secure.tls=true" # Включаем TLS (HTTPS)
      - "traefik.http.routers.grimmory-secure.service=grimmory"  # Привязываем HTTPS-роутер к сервису booklore
      - "traefik.http.services.grimmory.loadbalancer.server.port=6060" # Внутренний порт BookLore внутри контейнера
      - "traefik.docker.network=proxy" # Указываем Traefik, в какой Docker-сети искать контейнер
#
  mariadb:                              # Сервис базы данных MariaDB
    image: lscr.io/linuxserver/mariadb:11.4.5
    # Образ MariaDB от LinuxServer.io (стабильный и удобный)
    container_name: mariadb             # Явное имя контейнера
    environment:                        # Переменные окружения MariaDB
      - PUID=${DB_USER_ID}              # UID владельца файлов БД
      - PGID=${DB_GROUP_ID}             # GID владельца файлов БД
      - TZ=${TZ}                        # Часовой пояс
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}       # Пароль root-пользователя БД
      - MYSQL_DATABASE=${MYSQL_DATABASE}       # Имя базы данных, создаваемой при первом запуске
      - MYSQL_USER=${DB_USER}       # Пользователь БД
      - MYSQL_PASSWORD=${DB_PASSWORD}    # Пароль пользователя БД
    volumes:
      - ./mariadb/config:/config        # Каталог с данными и конфигурацией MariaDB
    restart: unless-stopped             # Автоперезапуск контейнера
    healthcheck:                        # Проверка доступности БД
      test: [ "CMD", "mariadb-admin", "ping", "-h", "localhost" ]
      interval: 5s                      # Интервал проверки
      timeout: 5s                       # Таймаут проверки
      retries: 10                       # Количество попыток
    networks:
      proxy:                            # Подключение к сети proxy (Traefik)

networks:
  proxy:                                # Определение сети proxy
    external: true                      # Сеть уже существует и не создаётся Docker самостоятельно
```

Файл с окружением

```yaml
# =========================================================
# 🎯 BookLore — основные настройки приложения
# =========================================================

APP_USER_ID=1000
# UID пользователя на хосте, от имени которого
# BookLore будет работать внутри контейнера.
# Нужен для корректных прав доступа к volume.
APP_GROUP_ID=1000
# GID группы на хосте.
# Должен совпадать с владельцем каталогов data / books / bookdrop.
TZ=Europe/Moscow
# Часовой пояс контейнеров.
# Используется для логов, планировщиков и временных меток.
BOOKLORE_PORT=6060
# Порт, на котором BookLore слушает внутри контейнера.
# Также используется Traefik как внутренний порт сервиса.
# =========================================================
# 🗄️ Подключение BookLore к базе данных MariaDB
# =========================================================
DATABASE_URL=jdbc:mariadb://mariadb:3306/grimmory
# JDBC-строка подключения к MariaDB:
# - mariadb        → имя сервиса в docker-compose
# - 3306           → стандартный порт MariaDB
# - grimmory       → имя базы данных
DB_USER=grimmory
# Пользователь базы данных,
# под которым BookLore подключается к MariaDB.
DB_PASSWORD=ChangeMe_BookLoreApp_2025!
# Пароль пользователя базы данных.
# ⚠️ ОБЯЗАТЕЛЬНО сменить в продакшене.
# =========================================================
# 🔧 Настройки контейнера MariaDB (инициализация)
# =========================================================
DB_USER_ID=1000
# UID пользователя, от имени которого
# MariaDB пишет данные в volume.
DB_GROUP_ID=1000
# GID группы для файлов базы данных.
MYSQL_ROOT_PASSWORD=ChangeMe_MariaDBRoot_2025!
# Пароль root-пользователя MariaDB.
# Используется только для администрирования БД.
MYSQL_DATABASE=grimmory
# Имя базы данных, которая будет автоматически
# создана при первом запуске контейнера MariaDB.
```
