---
title: "ProHomelab: автоматизация публикации статей через Forgejo"
published: 2026-09-21
pinned: false
description: "Настраиваю автоматическую публикацию статей: Obsidian отправляет контент в Forgejo, Forgejo Actions запускает сборку Hugo на Blowfish LXC, а готовый сайт автоматически загружается на smartape."
tags:
  - Obsidian
  - Forgejo
  - Hugo
  - Blowfish
  - CI/CD
  - Git
  - Автоматизация
slug: /automation-publishing
category: Automation
licenseName: CC BY 4.0
author: Stilicho2011
draft: true
cover: ./featured.png
series:
  - ProHomeLab
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
summary: "Полностью автоматизирую публикацию ProHomeLab: пишу статью в Obsidian, изменения автоматически попадают в Forgejo, Forgejo Actions запускает сборку Hugo на Blowfish LXC, а готовый сайт без ручного участия загружается на smartape."
---

## ProHomelab: автоматизация публикации статей - подробная инструкция (проверенная на практике)

Эта заметка описывает, как настроить автопубликацию статей: вы пишете в Obsidian → статья сама уходит в Forgejo → это запускает сборку сайта на Hugo (тема Blowfish) → готовый сайт сам заливается на хостинг. Ручной `hugo -D` и FileZilla больше не нужны.

Инструкция написана по итогам реального прохождения всего пути от начала до конца - включая все ошибки, в которые уже упёрлись один раз, и их готовые решения. Если пройти её по шагам с нуля, эти грабли встречаться не должны.

Рассчитана на новичка: каждая команда - с объяснением, что она делает и зачем. В примерах используются собственные имена репозиториев, сервера и логин - у вас они будут свои, но структура команд останется той же.

---

## Как это выглядит на схеме

Прежде чем нырять в шаги, вот общая картина того, что мы соберём. Дальше в инструкции разберём каждый блок отдельно, но сначала - откуда куда что движется.

![Как устроена автопубликация статей](pipeline-diagram.svg)

Коротко, своими словами:

- Вы сохраняете заметку в **Obsidian**.
- Она сама улетает в **репозиторий со статьями** на Forgejo (это просто хранилище текста, ничего больше).
- Этот репозиторий "будит" **репозиторий сайта** - говорит ему "появилось что-то новое, пора пересобрать сайт".
- **Раннер** (фоновая программа на вашем сервере) видит этот сигнал, забирает свежие статьи, запускает Hugo и собирает из них готовые HTML-страницы.
- Готовый сайт автоматически заливается на **хостинг** - именно то, что видят посетители.

Всё, что происходит между "сохранил в Obsidian" и "статья на сайте" - это и есть автоматизация, которую мы дальше настроим по шагам.

---

## 0. Термины, которые встретятся ниже

- **git** - система контроля версий. Отслеживает изменения файлов и умеет их отправлять на сервер.
- **репозиторий (repo)** - папка, за которой следит git.
- **remote** - адрес удалённого сервера (в нашем случае Forgejo), куда репозиторий отправляет изменения.
- **commit** - "снимок" изменений с комментарием, сохранённый в истории git.
- **push** - отправка коммитов на remote-сервер.
- **pull / clone** - скачивание репозитория (или его изменений) с сервера к себе.
- **submodule** - репозиторий внутри репозитория (у вас так подключена тема Blowfish).
- **CI/CD, Forgejo Actions** - механизм "если в репозитории что-то поменялось - автоматически выполни набор команд" (у GitHub это называется GitHub Actions, у Forgejo - Forgejo Actions).
- **раннер (runner)** - программа, которая физически выполняет эти автоматические команды.
- **workflow** - YAML-файл, описывающий, какие шаги и когда выполнять.
- **YAML** - текстовый формат файлов конфигурации (отступы важны, табы использовать нельзя, только пробелы).
- **secrets** - зашифрованные переменные (пароли, токены), которые Forgejo Actions подставляет в скрипт, не показывая их в логах.
- **токен доступа (Personal Access Token)** - длинная строка-пароль для программного доступа к Forgejo вместо обычного пароля аккаунта.
- **SSH** - протокол для подключения к серверу через терминал.
- **systemd-сервис** - способ в Linux запускать программу в фоне и держать её постоянно включённой, даже после перезагрузки.

---

## 1. Архитектура

Два репозитория в Forgejo:

1. **prohomelab-content** - только статьи (у меня это папка `01-Projects\Prohomelab` в Obsidian). Без темы Hugo, без служебных файлов Obsidian.
2. **prohomelab-site** - весь Hugo-проект: тема Blowfish, конфиги, layouts, скрипты сборки.

Почему два, а не один: Obsidian Git может версионировать только одну конкретную подпапку, и мешать в неё Hugo-специфичные файлы незачем.

Порядок событий при публикации статьи:

1. Сохранили заметку в Obsidian.
2. Плагин Obsidian Git сам коммитит и пушит изменение в **prohomelab-content**.
3. Push в prohomelab-content запускает свой workflow, который через Forgejo API "будит" второй репозиторий.
4. На сервере раннер: скачивает свежий контент → чинит обсидиановский синтаксис картинок → кладёт статьи в Hugo-проект → `hugo -D --minify` → заливает `public/` на хостинг по FTPS.

Важное отличие от того, как это делает GitHub: в Forgejo (по крайней мере в версии, использованной здесь, v13) **нет** API-события `repository_dispatch` с произвольным именем события, как в GitHub Actions. Есть только `workflow_dispatch` - запуск заранее известного конкретного workflow-файла по имени через `POST /repos/{owner}/{repo}/actions/workflows/{имя-файла}.yml/dispatches`. Вся схема ниже сразу построена на этом. Я в этом не особо разбирался и сначала получал ошибку 404 - в разделе Troubleshooting в конце статьи расписано, как её опознать и починить.

---

## Фаза 1. Приводим в порядок Hugo-репозиторий на сервере

### Шаг 1.1. Подключитесь к серверу по SSH

```bash
ssh root@IP_ВАШЕГО_СЕРВЕРА
```

Дальше все команды этого раздела - внутри этой SSH-сессии.

### Шаг 1.2. Перейдите в папку проекта

```bash
cd /home/prohomelab
pwd
```

Должно вывести `/home/prohomelab` (или ваш путь, если Hugo-проект лежит в другом месте).

### Шаг 1.3. Укажите git, кто вы

```bash
git config user.name "Ваше имя"
git config user.email "you@example.com"
```

Без `--global` - настройка применится только к этому репозиторию.

### Шаг 1.4. Создайте `.gitignore`

```bash
cat > .gitignore <<'EOF'
public/
resources/_gen/
.hugo_build.lock
EOF
cat .gitignore
```

`public/` (результат сборки Hugo) и `resources/_gen` (кэш) пересобираются каждый раз заново - хранить их в git не нужно.

### Шаг 1.5. Уберите `public/` и `resources/` из git, если уже попали

```bash
git rm -r --cached public resources 2>/dev/null || true
```

### Шаг 1.6. Первый коммит

```bash
git add .
git status
```

Проверьте список - `public/` и `resources/` быть не должно, остальное (`content/`, `themes/`, `hugo.toml`, `.gitmodules` и т.д.) - зелёным.

```bash
git commit -m "Initial commit: Hugo + Blowfish site"
```

### Шаг 1.7. Создайте пустой репозиторий в Forgejo

В браузере откройте свой Forgejo (у меня это `https://forgejo.ваш-домен.ru`) → "+" → **New Repository** → имя `prohomelab-site` → **НЕ** ставьте галочки инициализации (README/.gitignore/лицензия - репозиторий должен остаться пустым) → **Create Repository**.

### Шаг 1.8. Токен доступа вместо пароля (сразу, чтобы не спотыкаться на push)

Push по HTTPS в Forgejo требует не обычный пароль аккаунта, а Personal Access Token. Создайте один универсальный токен сразу для всех задач этого проекта:

`Settings → Applications → Generate New Token` → имя, например, `prohomelab-ci` → права: `write:repository` (repository access - All) → Generate. Сохраните значение токена - оно показывается только один раз.

### Шаг 1.9. Привяжите remote с токеном в URL

```bash
git remote add origin https://ваш-логин:ВАШ_ТОКЕН@forgejo.ваш-домен.ru/ваш-логин/prohomelab-site.git
git branch -M main
git push -u origin main
```

Замените `ваш-логин` на ваш логин Forgejo, `forgejo.ваш-домен.ru` - на адрес вашего инстанса Forgejo, а `ВАШ_ТОКЕН` - на токен из шага 1.8. Так push пройдёт сразу без интерактивных запросов пароля.

### Шаг 1.10. Проверьте результат

Откройте `https://forgejo.ваш-домен.ru/ваш-логин/prohomelab-site` - должны быть видны `hugo.toml`, `content/`, `themes/` и т.д.

**Чек-пойнт Фазы 1**: репозиторий Hugo-сайта существует и версионируется в Forgejo. ✅

---

## Фаза 2. Настраиваем Obsidian, чтобы статьи сами уходили в Forgejo

### Шаг 2.1. Создайте второй пустой репозиторий в Forgejo

Так же, как в 1.7, но с именем `prohomelab-content`.

### Шаг 2.2. Инициализируйте git прямо в папке со статьями (не во всём vault!)

На Windows, в PowerShell:

```powershell
cd "C:\Users\ваш-пользователь\Documents\Obsidian\ваш-vault\01-Projects\Prohomelab"
git init
git config user.name "Ваше имя"
git config user.email "you@example.com"
```

Если PowerShell не знает команду `git` - установите Git for Windows (`https://git-scm.com/download/win`), настройки по умолчанию, перезапустите PowerShell.

### Шаг 2.3. Исключите служебные файлы Obsidian

```powershell
@"
Prohomelab.base
_Prohomelab-Index.md
"@ | Out-File -Encoding utf8 .gitignore
Get-Content .gitignore
```

Допишите туда любые другие черновики/служебные заметки, которые не должны публиковаться.

### Шаг 2.4. Первый коммит и push

```powershell
git add .
git status
git commit -m "Initial content"
git remote add origin https://ваш-логин:ВАШ_ТОКЕН@forgejo.ваш-домен.ru/ваш-логин/prohomelab-content.git
git branch -M main
git push -u origin main
```

Тот же токен из Шага 1.8 подходит - он выдан с правами на все репозитории аккаунта.

### Шаг 2.5. Настройте плагин Obsidian Git на эту конкретную папку

Открыть Obsidian → Settings → Git → раздел **Advanced** → поле **Custom base path**:

```
01-Projects/Prohomelab
```

(со слэшем `/`, даже на Windows). Это ключевая настройка - без неё плагин работает с корнем всего vault.

После сохранения плагин может попросить перезагрузить Obsidian - соглашайтесь.

После перезагрузки, там же в настройках Git (названия полей могут отличаться версии от версии - у современных версий это объединённая формулировка):

- **Auto commit and sync interval (minutes)** - например `10`. Раз в N минут: если есть несохранённые изменения - коммит и сразу push. (В более старых версиях плагина это могло быть двумя отдельными полями - Vault backup interval и Auto push interval - тогда ставьте туда те же значения.)
- **Commit message on auto commit and sync** - можно оставить по умолчанию.
- **Pull on startup** - включите, чтобы подтягивать изменения при открытии Obsidian (полезно при работе с двух устройств).

Не путайте с настройкой **Automatically refresh Source Control View on file changes** - это просто обновление окна интерфейса, к автокоммиту/автопушу отношения не имеет.

### Шаг 2.6. Проверьте автокоммит

Откройте любую статью, допишите тестовый символ, сохраните. Через палитру команд (Ctrl+P) выполните команду коммита/синка вручную (не дожидаясь таймера), затем проверьте `https://forgejo.ваш-домен.ru/ваш-логин/prohomelab-content` - должен появиться новый коммит.

**Чек-пойнт Фазы 2**: сохранение заметки в Obsidian долетает до Forgejo без вашего участия. ✅

---

## Фаза 3. Ставим раннер на сервер

Раннер - фоновая программа, которая ждёт сигнала от Forgejo "в репозитории что-то поменялось, выполни вот эти команды".

### Шаг 3.1. Включите Forgejo Actions

**Если Forgejo у вас в Docker Compose** (частый случай): найдите на хосте, где лежит `docker-compose.yml`, папку данных - обычно она указана в `volumes:` как `./forgejo:/data`. Тогда конфиг лежит по пути:

```
<папка-с-docker-compose.yml>/forgejo/gitea/conf/app.ini
```

Отредактируйте его прямо на хосте (не заходя внутрь контейнера):

```bash
nano ./forgejo/gitea/conf/app.ini
```

Допишите в конец файла:

```ini
[actions]
ENABLED = true
```

Сохраните (Ctrl+O, Enter, Ctrl+X) и перезапустите контейнер:

```bash
docker restart forgejo
```

(имя контейнера смотрите в своём `docker-compose.yml`, поле `container_name`).

Проверьте, что настройка применилась:
```bash
docker exec forgejo cat /data/gitea/conf/app.ini | grep -A2 "\[actions\]"
```

Должно показать `ENABLED = true`.

Проверьте в браузере: откройте любой репозиторий (`prohomelab-site`) - сверху должна появиться вкладка **Actions**.

### Шаг 3.2. Получите токен для регистрации раннера

Откройте страницу администрирования раннеров. **Важно**: в некоторых версиях Forgejo путь без дефиса перед `admin`:

```
https://forgejo.ваш-домен.ru/admin/actions/runners
```

(а не `/-/admin/actions/runners`, как в документации GitHub-подобных систем - если получаете 404, пробуйте оба варианта).

Если страница недоступна - убедитесь, что ваш пользователь администратор инстанса:
```bash
docker exec -u git forgejo forgejo admin user list
```
Колонка `IsAdmin` должна быть `true`. Если нет:
```bash
docker exec -u git forgejo forgejo admin user change --username ваш-логин --admin
```
(`-u git` - обязательно, потому что Forgejo внутри контейнера работает от пользователя `git`, это видно в `app.ini` как `RUN_USER = git`).

На странице руннеров нажмите **Create new runner**, скопируйте одноразовый токен регистрации (действует ограниченное время).

### Шаг 3.3. Узнайте актуальную версию раннера

У code.forgejo.org (в отличие от GitHub) нет alias `/latest/download/...`. Откройте в браузере страницу релизов:

```
https://code.forgejo.org/forgejo/runner/releases
```

Найдите самый верхний релиз без пометки Pre-release и запомните номер тега (на момент написания - `v13.0.0`, но у вас может быть свежее - используйте актуальный).

### Шаг 3.4. Установите раннер

На сервере, подставив реальную версию вместо `X.X.X` - лучше не набирать вручную, а скопировать точную ссылку на нужный файл со страницы релизов (правый клик по названию файла → "Копировать адрес ссылки"), чтобы не ошибиться в номере:

```bash
cd /opt
curl -L "ССЫЛКА_НА_forgejo-runner-X.X.X-linux-amd64" -o forgejo-runner
file forgejo-runner
```

Обязательно проверьте вывод `file` - должно быть `ELF 64-bit LSB executable`. Если вместо этого `ASCII text` / `HTML document` - значит скачался не бинарник, а страница с ошибкой (неверная ссылка), нужно вернуться на страницу релизов и скопировать ссылку заново.

Если всё верно:

```bash
chmod +x forgejo-runner
mv forgejo-runner /usr/local/bin/
```

### Шаг 3.5. Зарегистрируйте раннер

```bash
mkdir -p /etc/forgejo-runner
cd /etc/forgejo-runner

forgejo-runner register \
  --instance https://forgejo.ваш-домен.ru \
  --token ТОКЕН_ИЗ_ШАГА_3.2 \
  --name my-runner \
  --labels host:host \
  --no-interactive
```

**Важный нюанс формата**: `--labels host:host`, а не просто `--labels host`. Формат лейбла в Forgejo Actions - `имя:тип`. Слева от двоеточия - произвольное имя (то, что пишется в `runs-on:` в workflow-файле), справа - тип-бэкенд. Тип `host` означает "выполнять задания напрямую в системе, без Docker" - удобно, если ваш сервер - это LXC-контейнер, а запускать Docker внутри LXC (вложенная виртуализация) - отдельная головная боль, которой мы так избегаем. Если указать просто `host` без двоеточия, Forgejo не поймёт, каким бэкендом это исполнять, и задания будут зависать в очереди.

Проверьте:
```bash
cat /etc/forgejo-runner/.runner
```
В поле `labels` должно быть `"host:host"`.

### Шаг 3.6. Сгенерируйте config.yaml

В новых версиях раннера (v13+) это отдельный обязательный шаг:

```bash
forgejo-runner generate-config > /etc/forgejo-runner/config.yaml
```

Файл большой (там документированы все опции внутри комментариев) - менять ничего не нужно, значения по умолчанию подходят для host-режима.

### Шаг 3.7. Создайте systemd-сервис

```bash
cat > /etc/systemd/system/forgejo-runner.service <<'EOF'
[Unit]
Description=Forgejo Actions Runner
After=network.target

[Service]
ExecStart=/usr/local/bin/forgejo-runner daemon
WorkingDirectory=/etc/forgejo-runner
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now forgejo-runner
systemctl status forgejo-runner
```

Должно быть `active (running)`.

Проверьте в веб-интерфейсе `https://forgejo.ваш-домен.ru/admin/actions/runners` - раннер должен появиться со статусом **Idle** (может занять минуту).

### Шаг 3.8. Установите зависимости для сборки и деплоя

```bash
apt update
apt install -y git lftp locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
```

Пакет `locales` и генерация `en_US.UTF-8` нужны, чтобы `lftp` (и некоторые другие утилиты) корректно работали со строками - без этого будут случаться труднообъяснимые ошибки вида "could not convert string to UTF-8".

Hugo у вас уже установлен, если проходили предыдущую статью про установку Hugo + Blowfish - проверьте на всякий случай:
```bash
hugo version
```

**Чек-пойнт Фазы 3**: у Forgejo есть рабочая лошадка на вашем сервере, готовая выполнять сборку. ✅

---

## Фаза 4. Скрипт сборки и деплоя

### Шаг 4.1. Токен для чтения контент-репозитория

Тот же способ, что в Шаге 1.8 - можно переиспользовать тот же токен `prohomelab-ci` (если давали ему `write:repository` на все репозитории - этого достаточно, он покрывает и чтение). Если делаете отдельный - права `read:repository` достаточно для этой задачи.

### Шаг 4.2. Скрипт синхронизации контента

На сервере:

```bash
cd /home/prohomelab
mkdir -p scripts

cat > scripts/sync-content.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

export GIT_TERMINAL_PROMPT=0

CONTENT_REPO_HOST="forgejo.ваш-домен.ru/ваш-логин/prohomelab-content.git"
CONTENT_DIR="/tmp/prohomelab-content"
TARGET_DIR="content/posts"

if [ -n "${CONTENT_REPO_TOKEN:-}" ]; then
  CONTENT_REPO_URL="https://ваш-логин:${CONTENT_REPO_TOKEN}@${CONTENT_REPO_HOST}"
else
  echo "ERROR: CONTENT_REPO_TOKEN is not set" >&2
  exit 1
fi

rm -rf "$CONTENT_DIR"
git clone --depth 1 "$CONTENT_REPO_URL" "$CONTENT_DIR"

rsync -a --delete \
  --exclude='.git' \
  --exclude='Prohomelab.base' \
  --exclude='_Prohomelab-Index.md' \
  "$CONTENT_DIR/" "$TARGET_DIR/"

find "$TARGET_DIR" -type f -name '*.md' -print0 | xargs -0 sed -i -E 's/!\[\[([^]]+)\]\]/![](\1)/g'

echo "Content synced and converted."
EOF

chmod +x scripts/sync-content.sh
```

(В строке `CONTENT_REPO_HOST` подставьте свой домен Forgejo и логин вместо `forgejo.ваш-домен.ru/ваш-логин`.)

Разбор ключевых мест:
- `export GIT_TERMINAL_PROMPT=0` - запрещает git пытаться интерактивно спросить логин/пароль. Без этой строки, если токен по какой-то причине не пришёл, git может **зависнуть намертво** на команде `clone`, ожидая ввод с несуществующего терминала, вместо того чтобы сразу выдать ошибку. Мы словили это на практике - зависание длилось много минут, пока не отменили вручную.
- Явная проверка `if [ -n "${CONTENT_REPO_TOKEN:-}" ]` - если секрет не пришёл, скрипт сразу падает с понятной ошибкой `ERROR: CONTENT_REPO_TOKEN is not set`, а не тратит время на попытку подключения без авторизации.
- `git clone --depth 1` - скачивает только последнее состояние без истории, быстрее.
- `rsync -a --delete` - синхронизирует содержимое, удаляя на стороне сайта то, чего больше нет в контенте (иначе удалённые в Obsidian статьи продолжали бы висеть на сайте).
- `sed` в конце - конвертирует обсидиановский синтаксис вставки картинок `![[файл.png]]` в обычный markdown `![](файл.png)`, который Hugo понимает. Если позже найдёте другие непонятные Hugo конструкции (коллбауты `> [!note]`, внутренние wiki-ссылки `[[Заметка]]` между статьями) - добавляйте сюда ещё по одной строке `sed` по тому же принципу.

Проверьте скрипт вручную перед тем, как доверить его автоматике:

```bash
export CONTENT_REPO_TOKEN=ВАШ_ТОКЕН
bash scripts/sync-content.sh
unset CONTENT_REPO_TOKEN
ls content/posts
```

Должно отработать без вопросов о пароле и показать структуру папок со статьями.

Закоммитьте скрипт **сразу**, не откладывая - это частая причина ошибки "No such file or directory" при первом запуске через Actions: раннер всегда работает с чистым checkout из git, а не с тем, что физически лежит на диске:

```bash
git add scripts/sync-content.sh
git commit -m "Add content sync script"
git push
```

### Шаг 4.3. Файл workflow сборки и деплоя

```bash
mkdir -p .forgejo/workflows
cat > .forgejo/workflows/deploy.yml <<'EOF'
name: Build and Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: host
    steps:
      - name: Checkout site repo
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Sync content from Obsidian repo
        env:
          CONTENT_REPO_TOKEN: ${{ secrets.CONTENT_REPO_TOKEN }}
        run: bash scripts/sync-content.sh

      - name: Build with Hugo
        run: hugo -D --minify

      - name: Deploy via FTP
        env:
          FTP_HOST: ${{ secrets.FTP_HOST }}
          FTP_USER: ${{ secrets.FTP_USER }}
          FTP_PASS: ${{ secrets.FTP_PASS }}
        run: |
          lftp -u "$FTP_USER,$FTP_PASS" "$FTP_HOST" <<'INNEREOF'
          set ssl:verify-certificate no
          mirror -R --delete --verbose public/ /www/ВАШ_ДОМЕН
          bye
          INNEREOF
EOF
```

Разбор:
- `on:` - только `push` (на ваш собственный push в сайт, например правку темы) и `workflow_dispatch` (можно запустить вручную из UI, и именно так его будет дёргать второй репозиторий - см. Шаг 4.5). **Мы намеренно не используем `repository_dispatch`** - такого API-события в Forgejo нет, попытка его использовать даёт `404 page not found`.
- `runs-on: host` - выполнять на раннере с меткой `host` (левая часть лейбла из Шага 3.5).
- `submodules: recursive` - подтягивает тему Blowfish при checkout.
- `hugo -D --minify` - `-D` включает черновики (если не хотите публиковать черновики на боевом сайте - уберите флаг, когда будете готовы к полностью боевому режиму), `--minify` сжимает вывод.
- `set ssl:verify-certificate no` - многие shared-хостинги используют для FTPS сертификат, который не проходит строгую проверку доверия, хотя соединение всё равно шифруется. Без этой строки `lftp` упадёт с `Certificate verification: The certificate is NOT trusted`. Если у вашего хостинга сертификат нормальный - эту строку можно убрать.
- Путь `/www/ВАШ_ДОМЕН` - **не угадывайте** этот путь, проверьте его вручную (Шаг 4.4), прежде чем вписывать в workflow - от него зависит, куда `--delete` будет удалять файлы.

### Шаг 4.4. Проверьте реальный путь на хостинге, прежде чем гонять `--delete` вслепую

Зайдите в панель управления вашим хостингом и посмотрите поле "Корневая директория" для нужного сайта - часто оно выглядит как `www/ваш-домен.ru`, а не просто `ваш-домен.ru` или голое имя проекта без домена. Не полагайтесь на память о том, что было в FileZilla - проверьте заново, ошибка в пути с `--delete` может стереть не то.

Подключитесь вручную прямо с сервера:

```bash
lftp -u ВАШ_FTP_ЛОГИН ftp://АДРЕС_FTP_СЕРВЕРА
```

Если при первой же команде (`ls`) получите:
```
Fatal error: Certificate verification: The certificate is NOT trusted.
```
- выполните внутри той же сессии:
```
set ssl:verify-certificate no
```
и повторите `ls`.

Если после этого `530 Login incorrect` - перепроверьте пароль (без отображения на экране легко ошибиться), выйдите (`exit`) и зайдите заново.

Когда зашли - пройдите по структуре и убедитесь, что видите реальные файлы Hugo-сайта (`index.html`, `posts/`, `sitemap.xml`):

```
ls
cd www
ls
cd ВАШ_ДОМЕН
ls
```

Запомните точный путь (например `/www/prohomelab.com`) и подставьте его в `mirror -R --delete --verbose public/ ЭТОТ_ПУТЬ` в Шаге 4.3 вместо плейсхолдера. Выйдите: `exit`.

Закоммитьте `deploy.yml`:
```bash
cd /home/prohomelab
git add .forgejo/workflows/deploy.yml
git commit -m "Add deploy workflow"
git push
```

### Шаг 4.5. Второй workflow - "будильник" в репозитории контента

Push в `prohomelab-content` сам по себе не запускает workflow в `prohomelab-site` - это два независимых репозитория. Нужен маленький workflow, который через API Forgejo запускает конкретный workflow-файл (`deploy.yml`) во втором репозитории.

На Windows, в PowerShell, в папке контента:

```powershell
cd "C:\Users\ваш-пользователь\Documents\Obsidian\ваш-vault\01-Projects\Prohomelab"
mkdir .forgejo\workflows -Force

@"
name: Notify site repo

on:
  push:
    branches: [main]

jobs:
  notify:
    runs-on: host
    steps:
      - name: Trigger site build
        env:
          TOKEN: `${{ secrets.FORGEJO_DISPATCH_TOKEN }}
        run: |
          curl -X POST \
            -H "Authorization: token `$TOKEN" \
            -H "Content-Type: application/json" \
            "https://forgejo.ваш-домен.ru/api/v1/repos/ваш-логин/prohomelab-site/actions/workflows/deploy.yml/dispatches" \
            -d '{"ref":"main"}'
"@ | Out-File -Encoding utf8 .forgejo\workflows\notify.yml

Get-Content .forgejo\workflows\notify.yml
```

Обратите внимание на бэктики `` ` `` перед `${{` и `$TOKEN` - в PowerShell это экранирование, чтобы символы попали в файл буквально, а не были подставлены самим PowerShell. Проверьте вывод `Get-Content` - там должно быть ровно `${{ secrets.FORGEJO_DISPATCH_TOKEN }}` и `$TOKEN`, без искажений.

**Важно про сам эндпоинт**: используется `/actions/workflows/deploy.yml/dispatches` (запуск конкретного workflow по имени файла) с телом `{"ref":"main"}` - это правильный, рабочий способ в Forgejo. Путь `/repos/{owner}/{repo}/dispatches` с телом `{"event_type": "..."}"` (аналог GitHub `repository_dispatch`) в Forgejo **не существует** и даст 404 - не используйте его, даже если увидите в примерах для GitHub Actions.

Закоммитьте и запушьте:

```powershell
git add .forgejo/workflows/notify.yml
git commit -m "Add dispatch workflow"
git push
```

### Шаг 4.6. Секреты

**В `prohomelab-content`** (`Settings → Actions → Secrets`):
- `FORGEJO_DISPATCH_TOKEN` - токен из Шага 1.8/4.1 (нужны права как минимум на запуск workflow в целевом репозитории - токен с `write:repository` на все репозитории подходит).

**В `prohomelab-site`**:
- `CONTENT_REPO_TOKEN` - тот же токен, для чтения контент-репозитория.
- `FTP_HOST` - адрес FTP-сервера вашего хостинга.
- `FTP_USER` - логин FTP.
- `FTP_PASS` - пароль FTP.

**Чек-пойнт Фазы 4**: оба workflow-файла, скрипт и все секреты на месте. ✅

---

## Фаза 5. Сквозная проверка

### Шаг 5.1. Тестовое изменение

В Obsidian отредактируйте статью, сохраните, выполните коммит/синк вручную (палитра команд, Ctrl+P), не дожидаясь таймера.

### Шаг 5.2. Проверьте notify.yml

`https://forgejo.ваш-домен.ru/ваш-логин/prohomelab-content/actions` → должен быть новый прогон `notify.yml` со статусом **Success**.

### Шаг 5.3. Проверьте deploy.yml

`https://forgejo.ваш-домен.ru/ваш-логин/prohomelab-site/actions` → должен появиться новый прогон `deploy.yml`, запущенный через `workflow_dispatch` (не через push - обратите внимание на пометку триггера). Раскройте все шаги:

- **Checkout site repo** - просто отрабатывает.
- **Sync content from Obsidian repo** - должно занять секунды (не минуты - если висит долго, смотрите Troubleshooting ниже).
- **Build with Hugo** - вывод Hugo, сколько страниц собрано.
- **Deploy via FTP** - список файлов, которые `lftp` заливает.

Итоговый статус job - **Success**.

### Шаг 5.4. Проверка вживую

Откройте ваш сайт в браузере, убедитесь, что правка на месте.

---

## Раздел "если что-то не работает" (по нашему реальному опыту)

- **`git push` просит пароль и не принимает обычный пароль аккаунта.** Используйте Personal Access Token вместо пароля (Шаг 1.8), либо сразу пропишите его прямо в URL remote: `git remote set-url origin https://ваш-логин:ВАШ_ТОКЕН@forgejo.ваш-домен.ru/...`.

- **`docker exec forgejo cat /data/gitea/conf/app.ini` не показывает вашу правку `[actions]`.** Значит редактировали не тот файл на хосте - сверьте путь `volumes:` в `docker-compose.yml`, конфиг лежит по `<volume-host-path>/gitea/conf/app.ini`.

- **`/-/admin/actions/runners` даёт 404.** В части версий Forgejo путь без дефиса: `/admin/actions/runners`.

- **`curl ".../releases/latest/download/forgejo-runner..."` скачивает не бинарник, а HTML с текстом ошибки**, и при попытке его запустить получаете что-то вроде `Not: command not found`. У code.forgejo.org нет alias `/latest/download/`, как у GitHub. Смотрите точный номер версии на странице `https://code.forgejo.org/forgejo/runner/releases` и копируйте ссылку прямо оттуда. После скачивания всегда проверяйте `file forgejo-runner` - должно быть `ELF 64-bit LSB executable`.

- **Раннер зарегистрирован, но задания в workflow вечно "Waiting for a runner with the following label: host".** Проверьте `.runner`-файл (`cat /etc/forgejo-runner/.runner`) - в поле `labels` должно быть `"host:host"` (с двоеточием), а не просто `"host"`. Если без двоеточия - удалите `.runner` и зарегистрируйте раннер заново с `--labels host:host`.

- **`git clone` в скрипте синхронизации виснет на много минут вместо секунд.** Добавьте в скрипт `export GIT_TERMINAL_PROMPT=0` и явную проверку токена перед clone (см. Шаг 4.2) - тогда вместо зависания будет мгновенная понятная ошибка, если что-то не так с токеном.

- **`bash: scripts/sync-content.sh: No such file or directory` при первом запуске через Actions**, хотя скрипт точно есть на диске. Раннер при каждом запуске делает **чистый checkout** из git - если скрипт не был закоммичен и запушен, в свежей копии его физически нет. Коммитьте и пушьте скрипт сразу после создания, не откладывайте.

- **`curl` в notify.yml возвращает `404 page not found`.** Скорее всего используется несуществующий в Forgejo эндпоинт `/repos/{owner}/{repo}/dispatches` с `event_type` (аналог GitHub `repository_dispatch`). В Forgejo используйте `/repos/{owner}/{repo}/actions/workflows/{имя}.yml/dispatches` с телом `{"ref":"main"}` (см. Шаг 4.5), и уберите из `deploy.yml` неработающий триггер `repository_dispatch`, оставив только `push` и `workflow_dispatch`.

- **`lftp: command not found` на шаге деплоя.** Забыли установить `lftp` на сервере - `apt install -y lftp` (Шаг 3.8).

- **`lftp` выдаёт `could not convert string to UTF-8`.** На системе не сгенерирована локаль, хотя `LANG` на неё ссылается. Выполните `apt install -y locales && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8`.

- **`lftp: Certificate verification: The certificate is NOT trusted`.** Обычное дело для shared-хостинга с самоподписанным/недоверенным сертификатом FTPS. Добавьте `set ssl:verify-certificate no` первой строкой в блоке команд `lftp` - как в workflow, так и при ручной проверке.

- **`530 Login incorrect` в lftp.** Обычно просто опечатка в пароле при ручном вводе (пароль не отображается на экране). Выйдите (`exit`) и зайдите заново, вводя осторожно, или подставьте пароль из менеджера паролей копированием.

- **Деплой прошёл успешно, но файлы легли не в ту папку на хостинге / затёрли что-то не то.** Прежде чем доверять `--delete` автоматике, всегда вручную проверяйте реальный путь через `lftp` (Шаг 4.4) и сверяйте с "Корневой директорией" в панели управления хостингом - она может отличаться от того, что вы помните по работе в FileZilla.

- **Hugo падает с `ERROR the "published" front matter field is not a parsable date`.** В конкретной статье во фронтматтере в поле `published` стоит не дата, а, например, `true`/`false` (если у вас в конфиге сайта `published` настроено как алиас даты публикации, а не флаг черновика). Исправьте на настоящую дату вида `2026-08-09` без кавычек. Отдельно, предупреждение "has both draft and published settings... Using draft" - не ошибка, а просто уведомление о приоритете `draft` над `published`, когда оба поля заданы одновременно.

- **Картинки на сайте не отображаются.** Почти наверняка необработанный обсидиановский синтаксис вставки картинок. Проверьте markdown статьи - возможно, картинка вставлена не как `![[file.png]]` (это правило уже покрыто скриптом), а каким-то другим способом - тогда нужно добавить ещё одно `sed`-правило в `scripts/sync-content.sh` по аналогии.

- **Раннер выполняет только одно задание за раз, а вы отменили не тот прогон.** В `config.yaml` раннера по умолчанию `capacity: 1` - задания выполняются строго по очереди. Если запустили несколько прогонов подряд (например, тестируя), лишние встанут в очередь "Waiting" - это нормально, не пытайтесь запускать параллельно, дождитесь текущего или явно отмените (кнопка Cancel на странице прогона).

---

## Что делать дальше, когда всё настроено

Обычный рабочий цикл: открыли Obsidian → написали или отредактировали статью → сохранили → (по желанию) сразу выполнили коммит-и-синк, если не хотите ждать автопуш по таймеру. Дальше всё происходит само: Forgejo → раннер → сборка → заливка на хостинг. FileZilla и ручной `hugo -D` из этого процесса полностью исключены.

Если статья ещё не готова к публикации, но вы хотите закоммитить прогресс - держите `draft: true` во фронтматтере; при `hugo -D` она всё равно попадёт на сайт (это удобно для предпросмотра, но помните об этом - если хотите публиковать только готовое, уберите флаг `-D` из команды `hugo` в `deploy.yml`, тогда черновики не будут собираться вовсе).
