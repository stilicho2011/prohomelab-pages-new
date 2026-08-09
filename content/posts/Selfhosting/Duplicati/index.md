---
title: Duplicati - резервное копирование с шифрованием для домашнего сервера
published: 2026-04-17
pinned: false
description: Пошаговая инструкция по установке и настройке Duplicati для автоматических зашифрованных бэкапов на домашнем сервере или в облако.
tags:
  - Backup
  - Docker
  - Self-Hosting
  - Duplicati
slug: /duplicati
categories: Backup
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Backup
youtube_id: bugfLS_Vvh8
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Пошаговая инструкция по установке и настройке Duplicati для автоматических зашифрованных бэкапов на домашнем сервере или в облако
---

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на [бусти](https://boosty.to/stilicho2011).

## Duplicati + Docker: автоматические бэкапы за 10 минут

Резервные копии — одна из самых важных частей любой инфраструктуры.  
Даже в домашнем Homelab, да и, собственно говоря, везде, потеря данных может стоить очень дорого. Причём речь идёт не только о самих данных, но и о времени, которое потребуется на их восстановление. Не исключено, что последнее окажется даже дороже.

> [!NOTE]
>У меня на YouTube-канале есть ролик про установку и настройку Proxmox Backup Server. Но это решение специфическое, и не все используют Proxmox в Homelab.


<iframe width="560" height="315" src="https://www.youtube.com/embed/bugfLS_Vvh8?si=Gz11RqtKpcl3iZwh" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

В этой статье разберём:

- что такое Duplicati
- как установить его на сервер
- как настроить автоматические бэкапы
- как хранить резервные копии локально и в облаке

## Что такое Duplicati  
  
**[Duplicati](https://duplicati.com/)** — это open-source система резервного копирования, которая поддерживает:  
  
- шифрование AES-256  
- дедупликацию  
- инкрементальные бэкапы  
- хранение в облаках  
- web-интерфейс управления  
  
Поддерживаемые хранилища:  
  
- S3  
- Backblaze B2  
- Google Drive  
- WebDAV  
- FTP / SFTP  
- локальные диски  
- NAS  
  
Это делает его отличным решением для **Homelab и self-hosted инфраструктуры**, так как поддерживает все что надо обычному хоумлабберу.  
  
---  
  
# Основные возможности

Из основных возможностей, наверное, стоит обратить внимание на:

## Шифрование

Все данные могут шифроваться на стороне клиента перед отправкой.

Поддерживаются:

- AES-256
- passphrase-защита

Это означает, что даже облачный провайдер не сможет прочитать ваши данные. То есть можно быть относительно спокойным за бэкапы в облаке и за то, что никто не будет тренировать свои ИИ-модели на ваших данных.
  
---  
  
## Инкрементальные бэкапы  
  
Duplicati хранит данные блоками.  
  
Это позволяет:  
  
- сохранять только изменения  
- уменьшать объём хранилища  
- ускорять резервное копирование  
  

Так как система сохраняет только ту информацию, которая изменилась, то все происходит очень быстро, а нам проще планировать объем дискового пространства

---
  
## Web-интерфейс  
  
После установки вы получаете удобную web-панель.  
  
Через неё можно:  
  
- создавать задания  
- управлять расписанием  
- восстанавливать файлы  
- проверять состояние бэкапов  
  
Тут, в общем-то, всё понятно. Конечно, администраторы со стажем могут кривить рот — мол, графический интерфейс это «пошло». Но не поддавайтесь на провокации. Интерфейс — это нормально. Если, конечно, его не школьник рисовал.


---

### Docker compose файл из видео

За основу я взял образ (сборку) от [linuxserver.io](https://hub.docker.com/r/linuxserver/duplicati) как наиболее user-friendly вариант для homelab 

```yaml
services:   # Раздел для описания всех сервисов Docker
  duplicati:   # Имя сервиса
    image: linuxserver/duplicati:latest   # Образ Docker, последняя версия Duplicati от LinuxServer
    container_name: duplicati   # Имя контейнера в Docker
    hostname: duplicati   # Имя хоста внутри контейнера
    entrypoint:   # Переопределение точки входа контейнера
      - /init   # Используется скрипт /init, предоставляемый образом LinuxServer
    #ports:   # Публикация портов контейнера на хосте
    #  - 8200:8200 # MGMT UI — интерфейс управления Duplicati будет доступен на порту 8200
    #expose:   # Порт, который будет виден другим контейнерам в сети Docker
    #  - 8200
    environment:   # Переменные окружения для контейнера
      - PUID=0   # UID пользователя внутри контейнера (0 = root, обычно для теста/администрирования)
      - PGID=1000   # GID группы внутри контейнера (должен соответствовать вашей группе на хосте)
      - TZ=Europe/Moscow   # Часовой пояс для контейнера
      - SETTINGS_ENCRYPTION_KEY=B2NcaR2X6gwSGt # Ключ шифрования Duplicati (необходимо изменить!)
      - DUPLICATI__WEBSERVICE_PASSWORD=adminadminadmin # Пароль для веб-интерфейса (изменить обязательно!)
    restart: unless-stopped   # Контейнер автоматически перезапустится, если он упадет, кроме явной остановки
    volumes:   # Монтирование директорий хоста в контейнер
      - /home/stilicho/docker/duplicati/backups:/backups   # Директория для хранения бэкапов
      - /home/stilicho/docker/duplicati/config:/config   # Конфигурация и настройки Duplicati
      - /home/stilicho/docker:/source # Директория с исходными файлами для бэкапа (можно изменить)
    networks:   # Сеть Docker, в которой будет работать контейнер
      - proxy
    labels:   # Метки для Traefik (обратного прокси)
      - "traefik.enable=true"   # Включить обработку Traefik для этого контейнера
      - "traefik.docker.network=proxy"   # Использовать сеть proxy для Traefik
      - "traefik.http.routers.duplicati.entrypoints=web"   # Входной пункт Traefik (порт 80)
      - "traefik.http.routers.duplicati.rule=Host(`duplicati.stilicho.ru`)"   # Домен, по которому доступен сервис
      - "traefik.http.middlewares.duplicati-https-redirect.redirectscheme.scheme=https"   # Перенаправление HTTP -> HTTPS
      - "traefik.http.routers.duplicati.middlewares=duplicati-https-redirect"   # Подключаем middleware для редиректа
      - "traefik.http.routers.duplicati-secure.entrypoints=websecure"   # HTTPS маршрут Traefik (порт 443)
      - "traefik.http.routers.duplicati-secure.rule=Host(`duplicati.stilicho.ru`)"   # Домен HTTPS
      - "traefik.http.routers.duplicati-secure.tls=true"   # Включаем TLS
      - "traefik.http.routers.duplicati-secure.tls.certresolver=cloudflare"   # Используем Cloudflare для генерации сертификата
      - "traefik.http.routers.duplicati-secure.service=duplicati"   # Назначаем сервис для маршрута
      - "traefik.http.services.duplicati.loadbalancer.server.port=8200"   # Порт сервиса внутри контейнера для Traefik
      #- traefik.http.routers.duplicati.middlewares=ipwhitelist@file   # (закомментировано) пример ограничения по IP

networks:   # Раздел для описания сетей
    proxy:   # Сеть с именем proxy
        external: true   # Используем внешнюю сеть Docker, созданную заранее (например для Traefik)
```

::: important
- **PUID=0** означает root в контейнере. Для production лучше использовать непривилегированного пользователя.
    
- **SETTINGS_ENCRYPTION_KEY** и **DUPLICATI__WEBSERVICE_PASSWORD** обязательно нужно менять на свои, иначе данные и веб-интерфейс небезопасны.
    
- **/source** монтируется весь `/home/stilicho/docker`, если не нужно все бэкапить — лучше сузить путь до конкретных папок.
    
- Traefik labels управляют HTTPS и редиректами. Если Traefik ещё не настроен — их можно удалить до настройки прокси.

-  пароли и другие чувствительные данные желательно указывать с помощью отдельного файла с окружением .env
:::

## Работа с приложением

Так как у меня есть видеообзор, в этой статье я остановлюсь только на ключевых деталях.

После установки приложения переходим по поддоменному имени. Откроется окно приветствия, где нужно ввести пароль администратора, указанный в `docker-compose` файле.

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/0.png)

Нас встречает довольно минималистичное меню с «выжигающим роговицу» светлым режимом. Ночной режим можно включить в разделе `Settings`.

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/1.png)


В разделе `Add backup` можно выбрать нужное действие: создать новый бэкап или восстановить его из конфигурационного файла (если он у вас есть).

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/2.png)

Так как нам нужно создать бэкап, выбираем опцию `Add new backup`.

В появившемся меню задаём необходимые параметры. При желании можно включить шифрование бэкапа.

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/3.png)

В следующих двух окнах выбираем:

- место хранения бэкапа
- используемый сервис

В видео я выбрал `File system`, так как бэкапил демонстрационные файлы на примонтированное через `fstab` хранилище.

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/4.png)

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/5.png)


Приложение предложит протестировать соединение.

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/6.png)

Если всё в порядке, в следующем окне нужно выбрать файлы для резервного копирования.

В нашем случае выбираем директорию `source`, так как она указана в `docker-compose` файле:

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/7.png)

В нашем случае выбираем директорию `source`, так как именно она у нас указано в docker compose файле

```yaml
 /home/stilicho/docker:/source # Директория с исходными файлами для бэкапа (можно изменить)
```

Далее задаём расписание бэкапов.
![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/8.png)

В следующем окне настраиваются дополнительные параметры: размер томов, количество хранимых копий и так далее.

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/9.png)

После завершения настройки в разделе `Home` появятся ваши задания для резервного копирования.

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Duplicati/10.png)

Как я уже писал выше, чтобы не усложнять статью, я не буду подробно разбирать процесс восстановления. В видеообзоре он показан, и там всё достаточно логично и интуитивно понятно.