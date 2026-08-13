---
title: "Forgejo + Komodo: версионируем и автоматически передеплоиваем все docker-стэки"
date: 
draft: true
tags: ["forgejo", "komodo", "docker", "self-hosting", "gitops"]
categories: ["homelab"]
---

## Зачем это вообще нужно

После переезда со всех compose-файлов на [Komodo](/posts/komodo-setup/) осталась одна незакрытая проблема: сами файлы `docker-compose.yml` по-прежнему лежали простыми текстовиками на диске, без истории изменений, без бэкапа "что было вчера", без единой точки правды (иностранный термин который бесит, но ничего не поделаешь). Правишь конфиг прямо на проде (да, у нас хоумлаберов тоже свой прод) — и если что-то пошло не так, откатываться не то что не на что, а просто ты уже и не помнишь с чего начинал, и где та самая еще рабочая версия.

Решение — завести собственный git-сервер (Forgejo) и связать его с Komodo так, чтобы:

- каждое изменение compose-файла фиксировалось в git;
- `git push` автоматически подтягивался на сервер и передеплоивал только изменившиеся стэки;
- всё это работало не только на основном хосте, но и на удалённых серверах (в моём случае — второй хост с Immich).

Дальше — весь путь от установки Forgejo до рабочего GitOps-пайплайна, с граблями, на которые я наступил, чтобы вы не наступали.

## Шаг 1. Устанавливаем Forgejo

Forgejo — форк Gitea, лёгкий self-hosted git-сервер. Ставится обычным compose-стэком. У меня уже был готовый Postgres на отдельном LXC-контейнере (управляю им через pgAdmin с Windows-машины), поэтому Forgejo подключил к нему, а не поднимал ещё один Postgres-контейнер рядом. Ниже я описываю, как это я делал у себя. В твоем случае, если у тебя нет единой базы данных, а есть отдельные для каждого стэка, то просто добавишь в компоуз данные для бд из официальной [документации](https://forgejo.org/docs/latest/admin/installation/docker/#postgresql-database)[Installation with Docker \| Forgejo – Beyond coding. We forge.](https://forgejo.org/docs/latest/admin/installation/docker/#postgresql-database) 

### База данных

В pgAdmin создаём роль и базу:

```sql
CREATE ROLE forgejo WITH LOGIN PASSWORD 'пароль';
CREATE DATABASE forgejo
  OWNER forgejo
  ENCODING 'UTF8'
  TEMPLATE template0;
```

Важный момент: если через GUI pgAdmin создать базу без явного указания `TEMPLATE template0`, можно получить ошибку `new encoding (UTF8) is incompatible with the encoding of the template database (SQL_ASCII)` — на некоторых серверах `template1` исторически настроен в другой кодировке. Я, как обычно, учусь на своих ошибках, но тебе то не надо?!

### docker-compose

```yaml
services:
  server:
    image: codeberg.org/forgejo/forgejo:14
    container_name: forgejo
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - FORGEJO__database__DB_TYPE=postgres
      - FORGEJO__database__HOST=192.168.1.79:5432
      - FORGEJO__database__NAME=forgejo
      - FORGEJO__database__USER=forgejo
      - FORGEJO__database__PASSWD=${FORGEJO_DB_PASSWORD}
    restart: always
    networks:
      - proxy
    volumes:
      - ./forgejo:/data
      - /etc/localtime:/etc/localtime:ro
    ports:
      - '3000:3000'
      - '222:22'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.forgejo.entrypoints=web"
      - "traefik.http.routers.forgejo.rule=Host(`forgejo.example.com`)"
      - "traefik.http.middlewares.forgejo-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.forgejo.middlewares=forgejo-https-redirect"
      - "traefik.http.routers.forgejo-secure.entrypoints=websecure"
      - "traefik.http.routers.forgejo-secure.rule=Host(`forgejo.example.com`)"
      - "traefik.http.routers.forgejo-secure.tls=true"
      - "traefik.http.routers.forgejo-secure.service=forgejo"
      - "traefik.http.services.forgejo.loadbalancer.server.port=3000"
      - "traefik.docker.network=proxy"
    security_opt:
      - no-new-privileges:true

networks:
  proxy:
    external: true
```

`docker compose up -d` — и по нашему доменному имени `https://forgejo.example.com` открывается install wizard. Там всё стандартно, кроме одного поля, которое легко пропустить: **Base URL**. По умолчанию там `http://localhost:3000/` — если не поправить на реальный домен, сломаются HTTPS-ссылки для клонирования и уведомления.

OpenID Connect сразу включил (пригодится позже для authentik), а self-registration оставил закрытой. Нам это не к чему, потому что у нас лчный закрытый сервер.

## Шаг 2. Монорепозиторий вместо репозитория на каждый стэк

Вариантов организации git было два: отдельный репозиторий на каждый стэк/VM/LXC или один общий репозиторий со всеми compose-файлами. Выбрал второй — проще администрировать, один Repo-ресурс в Komodo, один вебхук, одна Procedure на все стэки разом. Безусловно есть определенное неудобство о чем ниже, но с ним можно жить.

Создаю в Forgejo пустой приватный репозиторий (без README и .gitignore через веб-интерфейс — они появятся из первого коммита) и превращаю в git-репозиторий прямо ту папку, где уже который год лежат все compose-файлы:

```bash
cd /home/alaricus/docker
git init
git branch -M main
git remote add origin https://forgejo.example.com/user/docker-stacks.git
```

## Шаг 3. .gitignore — самая долгая часть

Вот тут у меня началось самое интересное. Ну может и не самое, подумаешь с бубном потанцевал. Первая наивная попытка `git add -A` в директории, где год копились данные полутора десятков контейнеров, выдаёт список из полутысячи с лишним файлов (не шутка, не гипербола или преувеличение). Разбирать его вручную — не вариант, поэтому пошёл по пути "сначала находим самое тяжёлое и самое опасное, потом причёсываем остальное".

**Что искать в первую очередь — размер:**

```bash
du -sh /home/alaricus/docker/*/* 2>/dev/null | sort -rh | head -30
```

Так определил гигабайты медиатек *arr-стэка (в основном это обложки от Lidarr и его же бекапы), базы уведомлений, кэши обложек аудиокниг — всё, что явно данные, а не конфигурация.

**Что искать во вторую — секреты.** Это оказалось важнее размера. В `git add -A` без разбора чуть не попали:

- `traefik/data/acme.json` — приватный ключ аккаунта Let's Encrypt и все выданные сертификаты (зачем нам это в нашем репо, правльно?);
- `vaultwarden/data/` — база менеджера паролей (это вообще самое важное);
- собственная папка данных Forgejo (`forgejo/forgejo/`) — сессии, JWT-ключ, и что забавно, сам git-репозиторий, который мы же и создаём, лежащий внутри самого себя;
- `komodo/keys/` и `komodo/mongo/data/` — ключи Periphery и база самой Komodo;
- `komodo/backups/` — а вот это уже было по-настоящему неприятно: автоматические ежедневные бэкапы Komodo включают экспорт **токенов git-провайдеров и API-ключей** в гзипованном виде. Эта папка попала в один из ранних коммитов раньше, чем я это заметил (правильно наверно сказать подумал) — узнал только разобрав тело вебхука, который Forgejo прислала на push. Хорошо, что репозиторий приватный и путь до этого коммита короткий, но токены на всякий случай стоит перевыпустить. Мало ли что?

Итоговый `.gitignore` получился длинным — где-то по три-пять строк на каждый стэк с базой данных или кэшем. Общий принцип, который я для себя вывел:

> [!hint] 
> > В git должно попадать только то, что ты написал руками. Всё, что сгенерировал контейнер сам — базы, ключи, кэши, логи, сессии — не конфигурация, а данные. Данные версионировать бессмысленно (они меняются каждую секунду) и вредно (там могут быть секреты).

Рабочий цикл проверки был такой:

```bash
git reset
git add -A
git status   # смотрим, что попало в staging
# находим лишнее → дописываем .gitignore → повторяем
```

Отдельно всплыла проблема прав: часть файлов создана контейнерами от нестандартного UID, и обычный пользователь их даже прочитать не может — `git add` падает с `Отказано в доступе`. Такие пути тоже пришлось добавлять в `.gitignore` по мере появления ошибок.

## Шаг 4. Первый коммит и push

```bash
git config --global user.name "твое имя в репо"
git config --global user.email "you@example.com"

git commit -m "Initial import of docker stacks"
git remote set-url origin https://user:TOKEN@forgejo.example.com/user/docker-stacks.git
git push -u origin main
git remote set-url origin https://forgejo.example.com/user/docker-stacks.git
```

Токен для push — Personal Access Token из Forgejo (Settings → Applications → Generate New Token, права `repository: Read and Write`).

## Шаг 5. Связываем с Komodo

Здесь у Komodo есть два принципиально разных подхода:

1. **Перевести каждый Stack на git-режим** — прописать в конфиге каждого стэка `repo`/`branch`/`run_directory`. Минус: Komodo клонирует репозиторий в свою собственную директорию, и все относительные bind-mount пути (`./data:/data` в compose-файлах) окажутся уже не там, где раньше — есть риск переехавших данных.
2. **Завести отдельный ресурс Repo**, который просто следит за репозиторием и умеет делать `git pull` — при этом указать ему путь клонирования = та же директория, где уже лежат стэки. Тогда `git pull` просто обновляет файлы на месте, а конфигурация Stack-ресурсов (`files on server`, абсолютные пути) вообще не меняется.

Выбрал второй — он безопаснее для уже работающей инфраструктуры.

**Настройка:**

1. Settings → Git Accounts → добавить аккаунт для `forgejo.example.com` с токеном.
2. Repos → New Repo → указать сервер, git-аккаунт, репозиторий, ветку `main` и **Path = та самая директория со стэками**.
3. Procedures → New Procedure → Stage 1: `Pull Repo` → Stage 2: `Batch Deploy Stack If Changed` с таргетом `*` (маска "все стэки").
4. На странице Procedure — вкладка Webhooks, копируем готовый URL вида `https://komodo.example.com/listener/github/procedure/<id>/main`.
5. В Forgejo: репозиторий → Settings → Webhooks → Add Webhook → тип **Gitea** (полностью совместим с "Github" auth style в Komodo) → вставляем URL, секрет, событие Push.

## Шаг 6. Проверка

```bash
echo "# test" >> some-stack/docker-compose.yaml
git add . && git commit -m "test webhook" && git push
```

Дальше смотрим тело доставки в Recent Deliveries на стороне Forgejo (там виден весь payload — какие файлы добавлены/изменены) и состояние Repo/Stack-ресурсов в Komodo — у обновлённого стэка должен смениться commit hash и пройти передеплой.

## Шаг 7. Масштабируем на второй хост

У меня есть отдельный сервер с Immich, подключённый к Komodo как удалённый Periphery-агент. Заводить для него отдельный репозиторий не стал — тот же монорепозиторий, стэки этого хоста просто легли туда ещё одной подпапкой.

Единственная тонкость — при первом `git checkout` на втором хосте, где уже есть локальные файлы (в моём случае — свежесозданный `.gitignore`), git отказывается переключаться на ветку из-за риска быть перезаписанным ("would be overwritten by checkout"). Решается просто: убрать конфликтующий файл, он всё равно придёт из репозитория при checkout, а специфичные для этого хоста строки (в моём случае — `immich/model-cache/`, `immich/postgres/`, `keys/`) дописываются в общий `.gitignore` уже после переключения на ветку.

Дальше — тот же рецепт: отдельный Repo-ресурс в Komodo с путём на этом сервере, и второй `Pull Repo` в том же Stage 1 существующей Procedure. Batch Deploy с маской `*` подхватывает стэки любого сервера сам, никаких изменений в Stage 2 не потребовалось.

## Итог

- Все compose-файлы под git, с историей изменений;
- `git push` из VS Code (а на Винде я пользуюсь именно им) автоматически прокатывается на все нужные серверы;
- секреты и данные контейнеров осознанно исключены — в репозитории только то, что действительно нужно для восстановления инфраструктуры с нуля;
- расширяется на новые хосты без переделки схемы — просто ещё один Repo-ресурс в Komodo и ещё одна строка в Stage 1.
