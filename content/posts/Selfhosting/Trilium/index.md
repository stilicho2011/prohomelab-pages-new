---
title: Trilium — мощная система личных знаний под вашим контролем. Установка и особенности приложения
published: 2025-10-30
pinned: false
description: Пошаговая инструкция по установке, настройке и использованию Trilium — современного форка Trilium Notes для самохостинга и управления знаниями.
tags:
  - PKM
  - Self-Hosting
  - Trilium
  - Docker
slug: /trilium
categories: Personal Knowledge Base
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Self-Hosting
youtube_id: awr_Ri0WCYQ
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Пошаговая инструкция по установке и настройке Trilium для организации заметок и баз знаний на личном сервере. Рассмотрены установка через Docker, настройка веб-интерфейса, пользователей и рекомендации по эффективному управлению заметками.
---

# Trilium - TriliumNext — мощная система личных знаний под вашим контролем

<iframe width="560" height="315" src="https://www.youtube.com/embed/awr_Ri0WCYQ?si=vl0Qj-cGjFDBqwVs" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Введение: зачем нужен TriliumNext — и зачем вообще нужны PKM-инструменты

В эпоху информационного перенасыщения мы страдаем не от `нехватки знаний`, а скорее от объема информации, которая сваливается на нас каждый день, и от хаоса, который этот объем порождает: разрозненные идеи, потерянные связи, забытые контексты и прочие ужасы цифровизации.    
Для решения этой проблемы существуют инструменты, которые с легкой руки сообщества называют **Personal Knowledge Management (PKM)** — личные базы знаний. 

![[15db259765dcfeebb94a9cbcffac31fc_MD5.png]]

Такие системы позволяют:

*   **собирать** разрозненные заметки, идеи, ссылки, черновики в единое пространство;
*   **интегрировать** разные форматы (текст, изображения, диаграммы, таблицы, код) в одной базе;
*   **находить связи** между заметками через ссылки, граф, поиск, атрибуты;
*   **развивать знания** — не просто фиксировать факты, но связывать их, углублять, пересобирать;
*   **делать экспорт / бэкап** — чтобы вы не зависели от чьего-то облака.

В классических инструментах вроде Obsidian или Notion вы получаете либо «файловые» подходы (Markdown + плагины) либо облачную экосистему с ограничениями. **Obsidian**, **Notion** или **Joplin** хороши, но TriliumNext идёт дальше, предлагая **гибридный подход**: мощную древовидную структуру, гибкость базы данных и приватность self-hosted-решения. При этом надо учитывать, что Obsidian и Notion не open-source решения, а Joplin, хоть и популярное решение, но оно далеко от идеала.

TriliumNext — это не просто «просто заметки», а система, в которой заметка — это объект данных с полями, шаблонами, связями, атрибутами и визуальными интерфейсами. Когда ваша база растёт до сотен, тысяч заметок, разница ощущается особенно ярко.

## Что такое TriliumNext: краткий обзор

[TriliumNext](https://triliumnotes.org) — это современный форк оригинального проекта Trilium, актвно развиваемый сообществом. 

### Основные характеристики TriliumNext:

*   Заметки можно организовать в дерево произвольной глубины. Одну заметку можно разместить в нескольких местах дерева.

*   Расширенный редактор заметок WYSIWYG, включающий таблицы, изображения и [математические формулы с функцией](https://triliumnext.github.io/Docs/Wiki/text-notes) [автоматического форматирования](https://triliumnext.github.io/Docs/Wiki/text-notes#autoformat) Markdown
*   Поддержка редактирования [заметок с исходным кодом](https://triliumnext.github.io/Docs/Wiki/code-notes) , включая подсветку синтаксиса
*   Быстрая и простая [навигация между заметками](https://triliumnext.github.io/Docs/Wiki/note-navigation) , полнотекстовый поиск и [подъем заметок](https://triliumnext.github.io/Docs/Wiki/note-hoisting)
*   Бесперебойное [управление версиями заметок](https://triliumnext.github.io/Docs/Wiki/note-revisions)
*   [Атрибуты](https://triliumnext.github.io/Docs/Wiki/attributes) заметок можно использовать для организации заметок, создания запросов и создания расширенных [скриптов.](https://triliumnext.github.io/Docs/Wiki/scripts)
*   Прямая [интеграция OpenID и TOTP](https://github.com/TriliumNext/Trilium/blob/main/docs/User%20Guide/User%20Guide/Installation%20%26%20Setup/Server%20Installation/Multi-Factor%20Authentication.md) для более безопасного входа
*   [Синхронизация](https://triliumnext.github.io/Docs/Wiki/synchronization) с собственным сервером синхронизации
    *   есть [сторонний сервис для хостинга сервера синхронизации](https://trilium.cc/paid-hosting)
*   [Публикации](https://triliumnext.github.io/Docs/Wiki/sharing) (публикация) заметок в публичном пространстве
*   Надежное [шифрование заметок](https://triliumnext.github.io/Docs/Wiki/protected-notes) с детализацией по каждой заметке
*   Создание схем на основе [Excalidraw](https://excalidraw.com/) (тип примечания «холст»)
*   [Карты отношений](https://triliumnext.github.io/Docs/Wiki/relation-map) (relation maps) и [карты связей](https://triliumnext.github.io/Docs/Wiki/link-map) (link maps) для визуализации заметок и их отношений
*   Mind maps на основе [Mind Elixir](https://docs.mind-elixir.com/)
*   [Геокарты](https://github.com/TriliumNext/Trilium/blob/main/docs/User%20Guide/User%20Guide/Note%20Types/Geo%20Map.md) с отметками местоположения и GPX-треками
*   [Скриптинг](https://triliumnext.github.io/Docs/Wiki/scripts) — см. [Расширенные демонстрации](https://triliumnext.github.io/Docs/Wiki/advanced-showcases)
*   [REST API](https://triliumnext.github.io/Docs/Wiki/etapi) для автоматизации
*   Хорошо масштабируется как с точки зрения удобства использования, так и производительности при обработке более 100 000 заметок.
*   Оптимизированный для сенсорного экрана [мобильный интерфейс](https://triliumnext.github.io/Docs/Wiki/mobile-frontend) для смартфонов и планшетов
*   Встроенная [темная тема](https://triliumnext.github.io/Docs/Wiki/themes) , поддержка пользовательских тем
*   [Импорт и экспорт Evernote](https://triliumnext.github.io/Docs/Wiki/evernote-import) и [Markdown](https://triliumnext.github.io/Docs/Wiki/markdown)
*   [Web Clipper](https://triliumnext.github.io/Docs/Wiki/web-clipper) для удобного сохранения веб-контента
*   Настраиваемый пользовательский интерфейс (кнопки боковой панели, пользовательские виджеты, ...)
*   [Метрики](https://github.com/TriliumNext/Trilium/blob/main/docs/User%20Guide/User%20Guide/Advanced%20Usage/Metrics.md) вместе с [панелью инструментов Grafana](https://github.com/TriliumNext/Trilium/blob/main/docs/User%20Guide/User%20Guide/Advanced%20Usage/Metrics/grafana-dashboard.json)

Для получения дополнительной информации о TriliumNext можно еще почитать:

*   [awesome-trilium](https://github.com/Nriver/awesome-trilium) для сторонних тем, скриптов, плагинов и многого другого.
*   [TriliumRocks!](https://trilium.rocks/) — обучающие материалы, руководства и многое другое.

![[72fa734a275f592d16bec5cfd7a41a5e_MD5.png]]

TriliumNext превращает заметки в **объекты данных** — каждая запись может иметь атрибуты, связи, шаблон, визуализацию. Это делает систему ближе к базе знаний, чем к простому набору файлов.

\---

## Установка и настройка TriliumNext

Ниже приведен мой docker-compose файл с учетом, что я использую обратный прокси Traefik

```yaml
services:
  trilium:                                # Определяем сервис с именем "trilium"
    container_name: trilium               # Имя контейнера в Docker (для удобства)
    image: triliumnext/trilium:latest     # Используем официальный образ Trilium Next (последняя версия)
    restart: always                       # Контейнер будет автоматически перезапускаться при сбое или перезагрузке Docker
    environment:                          # Переменные окружения, передаваемые внутрь контейнера
      TRILIUM_NETWORK_TRUSTEDREVERSEPROXY: 172.18.0.0/16 # Доверенная сеть для обратного прокси
      TRILIUM_DATA_DIR: /home/node/trilium-data   # Путь к директории, где Trilium хранит свои данные внутри контейнера
      TZ: ${TZ}                                   # Устанавливаем часовой пояс из переменной окружения (обычно задан в .env)
      TRILIUM_MULTIFACTORAUTHENTICATION_OAUTHBASEURL: "https://trilium.domain.ru"  
        # Базовый URL для обратных вызовов OIDC (Trilium должен знать свой публичный адрес)
      TRILIUM_MULTIFACTORAUTHENTICATION_OAUTHCLIENTID: ${TRILIUM_CLIENT_ID}  
        # ID клиента OAuth (берётся из .env или секрета)
      TRILIUM_MULTIFACTORAUTHENTICATION_OAUTHCLIENTSECRET: ${TRILIUM_CLIENT_SECRET}  
        # Секрет клиента OAuth (также из .env)
      TRILIUM_MULTIFACTORAUTHENTICATION_OAUTHISSUERBASEURL: "https://auth.domain.ru/application/o/trilium"  
        # Адрес Identity Provider (в данном случае Authentik)
      TRILIUM_MULTIFACTORAUTHENTICATION_OAUTHISSUERNAME: "Authentik"  
        # Название провайдера аутентификации, отображаемое в интерфейсе Trilium
      TRILIUM_MULTIFACTORAUTHENTICATION_OAUTHISSUERICON: "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/authentik.svg"  
        # Иконка провайдера аутентификации (красивая мелочь для UI)
    volumes:                              # Монтируем локальные каталоги в контейнер
      - /home/user/docker/trilium:/home/node/trilium-data  
        # Основной том для данных (заменяет встроенную директорию Trilium)
      # Если надо, чтобы контейнер наследовал системный часовой пояс, раскомментируй:
      # - /etc/localtime:/etc/localtime:ro
        # Монтирование локального времени системы внутрь контейнера (только для чтения)
    networks:
      proxy:                              # Подключаем контейнер к внешней сети "proxy" (используется Traefik)
    labels:                               # Метки для интеграции с Traefik (обратный прокси)
      - "traefik.enable=true"                                      # Включаем обработку контейнера Traefik
      - "traefik.http.routers.trilium.entrypoints=web"             # Определяем HTTP-вход (порт 80)
      - "traefik.http.routers.trilium.rule=Host(`trilium.domain.ru`)" # Трафик на этот домен будет направляться в данный контейнер
      - "traefik.http.middlewares.trilium-https-redirect.redirectscheme.scheme=https" # Middleware для редиректа с HTTP на HTTPS
      - "traefik.http.routers.trilium.middlewares=trilium-https-redirect" # Применяем middleware редиректа к HTTP-маршруту
      - "traefik.http.routers.trilium-secure.entrypoints=websecure" # Определяем HTTPS-вход (порт 443)
      - "traefik.http.routers.trilium-secure.rule=Host(`trilium.domain.ru`)" # HTTPS-маршрут для того же домена
      - "traefik.http.routers.trilium-secure.tls=true" # Включаем TLS (HTTPS)
      - "traefik.http.routers.trilium-secure.service=trilium" # Привязываем HTTPS-маршрут к сервису Trilium
      - "traefik.http.services.trilium.loadbalancer.server.port=8080" # Указываем внутренний порт, на котором Trilium слушает в контейнере
      - "traefik.docker.network=proxy" # Указываем, что Traefik должен искать контейнер в сети "proxy"

networks:
  proxy:                                  # Определение внешней сети для взаимодействия с Traefik
    external: true                        # Сеть уже создана ранее (не создавать заново)

```

а также файл с переменными

```yaml
# Timezone
TZ=Europe/Moscow
# OAuth2 (Authentik)
TRILIUM_CLIENT_ID=client-id
TRILIUM_CLIENT_SECRET=client-secret
```

> [!NOTE]
>Trilium также поддерживается в Kubernetes, через Cloudron, HomelabOS, NixOS-модуль и пр.


Необходимо учитывать, что **Traefik** версии 3.6.4 и выше были небольшие breaking changes. В случае если вы используете **Traefik** как обратный прокси, то вам надо добавить в файл статической конфигурации следующий блок

```yaml
  websecure:                              # Точка входа для HTTPS (порт 443)
    address: ":443"                       # Слушать порт 443
    http:                                 # HTTP-настройки для HTTPS
      encodedCharacters:                  # Разрешённые закодированные символы (важно для Trilium)
        allowEncodedSlash: true           # Разрешить %2F
        allowEncodedPercent: true         # Разрешить %25
        allowEncodedHash: true            # Разрешить %23
```

### Расположение конфигурации

По умолчанию `config.ini`, база данных и другие важные файлы Trilium хранятся в директории данных. Если вы хотите использовать другое местоположение, можно задать переменную окружения `TRILIUM_DATA_DIR`, например:

`export TRILIUM_DATA_DIR=/home/myuser/data/my-trilium-data`

### Отключение / изменение лимита загрузки

Если вы сталкиваетесь с ограничением загрузки в 250 МБ по умолчанию и хотите увеличить этот лимит, вы можете установить переменную окружения `TRILIUM_NO_UPLOAD_LIMIT=true`, чтобы полностью отключить лимит:    
 

```yaml
export TRILIUM_NO_UPLOAD_LIMIT=true
```

Или же, если хотите просто увеличить лимит до значения больше, чем 250 МБ, можно использовать переменную `MAX_ALLOWED_FILE_SIZE_MB`, например:

```yaml
export MAX_ALLOWED_FILE_SIZE_MB=450
```

## Синхронизация

Приложение Trilium — «offline-first» решение для заметок: оно хранит все данные локально на клиенте-десктопе или так называемой серверной установке, как указано выше. Однако Trilium также предлагает возможность настроить синхронизацию с серверной инстанцией, позволяя нескольким десктоп-клиентам синхронизироваться с центральным сервером и, кстати, наоборот. Это создаёт топологию «звезда». [docs.triliumnotes.org+2triliumnext.github.io+2](https://docs.triliumnotes.org/user-guide/setup/synchronization)

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Trilium/5.png)

В этой конфигурации центральный сервер (называемый сервером синхронизации) и несколько клиентских (или настольных) экземпляров синхронизируются с сервером синхронизации. После настройки синхронизация становится автоматической и непрерывной, не требуя ручного вмешательства.

{{< alert >}}
**Note!** Obsidian? Нет, не слышал
{{< /alert >}}

### Настройка синхронизации 

#### Вопросы безопасности 

Безопасная настройка сервера критически важна и может сначала показаться сложной. Для обеспечения безопасности и предотвращения потенциальных уязвимостей важно использовать действительный ssl сертификат (HTTPS), а не незашифрованное HTTP-соединение.

#### Синхронизация экземпляра рабочего стола с сервером синхронизации

Этот метод используется, когда у вас уже есть настольный экземпляр Trilium и вы хотите настроить сервер синхронизации на своем веб-хостинге или просто докер машине.

1.  **Развертывание сервера** : убедитесь, что экземпляр сервера развернут, но не инициализирован.
2.  **Конфигурация рабочего стола** : откройте экземпляр рабочего стола, перейдите в раздел «Параметры» -> вкладка «Синхронизация» -> «Конфигурация синхронизации» и укажите в поле «Адрес экземпляра сервера» адрес вашего сервера синхронизации. Нажмите «Сохранить».

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Trilium/0.png)


**3\. Тестирование синхронизации** : нажмите кнопку «Тест синхронизации», чтобы проверить подключение к серверу синхронизации. В случае успеха клиент начнёт передачу всех данных на сервер. Этот процесс может занять некоторое время, но вы можете продолжать использовать Trilium. Периодически проверяйте сервер, чтобы убедиться в завершении синхронизации. После завершения вы увидите экран входа на сервер.

### Синхронизация сервера синхронизации с десктопным экземпляром приложения 

Этот метод используется, когда у вас уже есть сервер синхронизации (наш экземпляр, уставленный в нашей homelab) и вы хотите настроить новый экземпляр рабочего стола для синхронизации с ним.

1.  **Настройка рабочего стола** : следуйте инструкциям [на странице установки рабочего стола](https://docs.triliumnotes.org/user-guide/setup/desktop.html) .
2.  **Первоначальная конфигурация** : при появлении запроса выберите вариант настройки синхронизации с сервером синхронизации.

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Trilium/1.png)


1.  **Сведения о сервере** : настройте адрес сервера Trilium и введите правильное имя пользователя и пароль для аутентификации.
2.  **Завершить настройку** : нажмите кнопку «Завершить настройку». В случае успеха вы увидите следующий экран:

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Trilium/3.png)


### Мобильный фронтенд

Trilium ( [серверная версия](https://docs.triliumnotes.org/user-guide/setup/server.html) ) имеет мобильный веб-интерфейс, оптимизированный для сенсорных устройств — смартфонов и планшетов. Он активируется автоматически при входе в систему на основе определения браузера.

Мобильный интерфейс имеет ограниченный функционал по сравнению с полнофункциональным десктопным интерфейсом. 

Обратите внимание, что это не приложение для Android/iOS, а просто удобная для мобильных устройств веб-страница, размещенная на [сервере](https://docs.triliumnotes.org/user-guide/setup/server.html) .

#### Ограничения 

Мобильный интерфейс предоставляет лишь некоторые функции полного десктопного интерфейса:

*   можно просматривать все дерево заметок, читать и редактировать все типы заметок, но создавать можно только текстовые заметки
*   чтение и редактирование [защищенных заметок](https://docs.triliumnotes.org/user-guide/concepts/notes/protected-notes.html) возможно, но их создание не поддерживается
*   параметры редактирования не поддерживаются
*   клонирование заметок не поддерживается
*   загрузка вложенных файлов не поддерживается

## Веб-клиппер

![Правило для доступа к WebGUI (порт 8006)](01-Projects/Prohomelab/Selfhosting/Trilium/2.png)


Trilium Web Clipper — это расширение для веб-браузера, которое позволяет пользователю вырезать текст, снимки экрана, целые страницы и короткие заметки и сохранять их непосредственно в Trilium Notes.

Проект размещен [здесь](https://github.com/TriliumNext/web-clipper).

Поддерживаются браузеры Firefox и Chrome, но сборка Chrome должна работать и в других браузерах на базе Chromium.

Я использую [эту](https://github.com/Nriver/trilium-web-clipper-plus) версию

### Функциональность 

*   выберите текст и вырежьте его с помощью контекстного меню, вызываемого правой кнопкой мыши
*   нажмите на изображение или ссылку и сохраните его через контекстное меню
*   сохранить всю страницу из всплывающего или контекстного меню
*   сохранить снимок экрана (с инструментом обрезки) из всплывающего или контекстного меню
*   создать короткую текстовую заметку из всплывающего окна

Trilium сохранит эти вырезки как новую дочернюю заметку в заметке «Входящие Clipper».

По умолчанию это [дневная заметка](https://docs.triliumnotes.org/user-guide/advanced-usage/advanced-showcases/day-notes.html), но вы можете переопределить это.

Если имеется несколько вырезок с одной и той же страницы (и в один и тот же день), то они будут добавлены в одну и ту же заметку.

#### Конфигурация

Расширение должно подключаться к работающему экземпляру Trilium. По умолчанию оно сканирует диапазон портов на локальном компьютере, чтобы найти экземпляр Trilium на рабочем столе.

Также можно настроить адрес [сервера](https://docs.triliumnotes.org/user-guide/setup/server.html) , если вы не запускаете настольное приложение или хотите, чтобы он работал без запуска настольного приложения.


Так как статья получилась уже достаточно длинной, то наверно об особенностях работы приложения я продолжу уже в другой статье.