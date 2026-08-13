---
title: "Forgejo + Komodo: версионируем и автоматически передеплоиваем все docker-стэки"
date: 2026-08-03
draft: true
tags: ["forgejo", "komodo", "docker", "self-hosting", "gitops"]
categories: ["homelab"]
---

# ProHomelab: автоматизация публикации статей — подробная инструкция

Эта заметка описывает, как настроить автопубликацию статей: вы пишете в Obsidian → статья сама уходит в Forgejo → это запускает сборку сайта на Hugo (тема Blowfish) → готовый сайт сам заливается на хостинг smartape. Ручной hugo -D и FileZilla больше не нужны.

Инструкция рассчитана на то, что вы делаете это первый раз — поэтому каждая команда с объяснением, что она делает и зачем.

---

## 0. Термины, которые встретятся ниже

Чтобы дальше не спотыкаться на словах:

- **git** — система контроля версий. Отслеживает изменения файлов и умеет их отправлять на сервер.
- **репозиторий (repo)** — папка, за которой следит git.
- **remote** — адрес удалённого сервера (в нашем случае Forgejo), куда репозиторий отправляет изменения.
- **commit** — "снимок" изменений с комментарием, сохранённый в истории git.
- **push** — отправка коммитов на remote-сервер.
- **pull / clone** — скачивание репозитория (или его изменений) с сервера к себе.
- **submodule** — репозиторий внутри репозитория (у вас так подключена тема Blowfish).
- **CI/CD, Forgejo Actions** — механизм "если в репозитории что-то поменялось — автоматически выполни набор команд" (у GitHub это называется GitHub Actions, у Forgejo — Forgejo Actions, по сути то же самое).
- **runner (раннер)** — программа, которая физически выполняет эти автоматические команды. Мы поставим её на ваш Blowfish LXC.
- **webhook** — уведомление "что-то произошло", которое один сервис посылает другому.
- **YAML** — текстовый формат файлов конфигурации (отступы важны, табы использовать нельзя, только пробелы).
- **secrets** — зашифрованные переменные (пароли, токены), которые Forgejo Actions подставляет в скрипт, не 10sпоказывая их в логах.
- **SSH** — протокол для подключения к серверу через терминал.
- **systemd-сервис** — способ в Linux запускать программу в фоне и держать её постоянно включённой, даже после перезагрузки.

---

## 1. Что в итоге получится (архитектура)

Будет **два репозитория** в Forgejo, а не один:

1. **prohomelab-content** — только сами статьи (то, что сейчас у вас лежит в Obsidian, папка `01-Projects\Prohomelab`). Без темы Hugo, без служебных файлов Obsidian.
2. **prohomelab-site** — весь Hugo-проект: тема Blowfish, конфиги, layouts. Он уже лежит на Blowfish LXC, просто ещё ни разу не был отправлен в Forgejo.

Почему не один репозиторий? Потому что Obsidian-плагин Git физически способен версионировать только одну конкретную папку, и мешать в неё файлы темы/сборки Hugo не нужно — это разные по смыслу вещи с разной частотой изменений.

Порядок событий при публикации статьи:

1. Вы сохраняете заметку в Obsidian.
2. Плагин Obsidian Git сам коммитит и отправляет изменение в **prohomelab-content**.
3. Это автоматически "будит" второй репозиторий — **prohomelab-site**.
4. На Blowfish LXC запускается раннер, который: скачивает свежий контент → конвертирует Obsidian-специфичные вещи в обычный Markdown → кладёт статьи в папку Hugo-проекта → выполняет `hugo -D` → полученную папку `public/` заливает на хостинг smartape по FTP.

Всё это займёт примерно 30–60 минут разовой настройки. Дальше публикация — это просто "сохранить заметку".

---

## Фаза 1. Приводим в порядок Hugo-репозиторий на Blowfish LXC

Сейчас на Blowfish (`/home/prohomelab`) уже есть начатый, но не отправленный никуда git-репозиторий (это видно по выводу `git status`, который вы прислали). Наведём в нём порядок и отправим в Forgejo.

### Шаг 1.1. Подключитесь к Blowfish LXC по SSH

С компьютера (или из веб-консоли Proxmox, если SSH не настроен):

```bash
ssh root@192.168.1.13
```

Если раньше не подключались — система спросит подтвердить fingerprint сервера, ответьте `yes`. Дальше введите пароль root от контейнера.

Дальше все команды этого раздела выполняются **внутри Blowfish LXC**, в этой SSH-сессии.

### Шаг 1.2. Перейдите в папку проекта

```bash
cd /home/prohomelab
```

Проверьте, что вы там, где нужно:

```bash
pwd
```

Должно вывести `/home/prohomelab`.

### Шаг 1.3. Укажите git, кто вы

Git требует имя и email для подписи коммитов (это просто метаданные, не привязаны к реальной почте):

```bash
git config user.name "Pavel"
git config user.email "pavel@prohomelab.local"
```

Эти настройки применятся только к этому репозиторию (без флага `--global`), это нормально — на будущее так безопаснее не путать личность в разных проектах.

### Шаг 1.4. Создайте файл `.gitignore`

Он говорит git, какие файлы/папки **не** нужно версионировать. Папки `public/` (результат сборки Hugo) и `resources/_gen` (кэш Hugo) — пересоздаются каждый раз заново командой `hugo`, хранить их в git бессмысленно и раздувает репозиторий.

```bash
cat > .gitignore <<'EOF'
public/
resources/_gen/
.hugo_build.lock
EOF
```

Поясню синтаксис: `cat > файл <<'EOF' ... EOF` — это способ создать файл с многострочным содержимым прямо из терминала, без текстового редактора. Всё, что между первой и второй `EOF`, попадёт в файл `.gitignore`.

Проверьте содержимое:

```bash
cat .gitignore
```

### Шаг 1.5. Уберите `public/` и `resources/` из git, если они уже туда попали

Судя по присланному вами `git status`, эти папки пока в статусе "untracked" (git их ещё не отслеживает), значит этот шаг, скорее всего, ничего не изменит — но выполнить стоит на всякий случай, ошибки не будет:

```bash
git rm -r --cached public resources 2>/dev/null || true
```

Разбор команды:

- `git rm -r --cached` — убрать из индекса git (но не удалить с диска),
- `2>/dev/null` — спрятать сообщение об ошибке, если таких папок в индексе и не было,
- `|| true` — сказать терминалу "даже если команда выше вернула ошибку, не останавливайся".

### Шаг 1.6. Добавьте всё остальное и сделайте первый коммит

```bash
git add .
git status
```

Командой `git status` посмотрите список того, что будет закоммичено — файлы должны быть зелёного цвета ("Changes to be committed"), `public/` и `resources/` в списке быть не должно.

```bash
git commit -m "Initial commit: Hugo + Blowfish site"
```

`-m` — комментарий к коммиту (обязателен).

> [!NOTE]
> `git add .` добавляет в git **всё содержимое текущей папки** (`/home/prohomelab`) и всех вложенных подпапок — кроме того, что вы явно исключили в `.gitignore` на шаге 1.4 (`public/`, `resources/_gen/`, `.hugo_build.lock`).
> 
> Применительно к вашей структуре, судя по присланному `tree`, "всё остальное" — это:
> 
> - `hugo.toml` — главный конфиг сайта
> - `config/_default/` — папка с доп. конфигами (языки, меню, параметры темы)
> - `content/` — все ваши статьи (`content/posts/...`) и `content/_index.md`, `content/about.md`
> - `layouts/` — ваши кастомные partials (`custom-head.html` и т.д.)
> - `assets/` — картинки фона, логотипы, `custom.css`
> - `static/` — favicon-ы, `robots.txt`, `site.webmanifest`
> - `archetypes/default.md`
> - `data/`, `i18n/` (даже если пустые — git пустые папки не отслеживает, это нормально)
> - `.gitmodules` — файл, который говорит git, что `themes/blowfish` — это submodule (ссылка на отдельный репозиторий темы [https://github.com/nunocoracao/blowfish.git](https://github.com/nunocoracao/blowfish.git)), а не обычная папка с файлами
> - `.gitignore` — файл, который вы только что создали
> 
> Папка `themes/blowfish` добавится не как обычные файлы, а как **ссылка на конкретный коммит** внешнего репозитория темы — это и есть смысл submodule: сама тема хранится в её собственном репозитории на GitHub, а ваш репозиторий просто запоминает "используй вот эту версию темы".
> 
> `.hugo_build.lock`, `public/`, `resources/_gen/` в `git status` попасть не должны — это как раз то, что вы исключили `.gitignore`, они останутся на диске, но git их игнорирует.
> 
> После `git add .` команда `git status` покажет список всех этих файлов зелёным цветом под заголовком "Changes to be committed" — это и есть "снимок" всего проекта, который `git commit` зафиксирует как первую точку в истории.

### Шаг 1.7. Создайте пустой репозиторий в Forgejo

В браузере откройте `https://forgejo.vaultlab.ru` и войдите под своим аккаунтом.

1. Нажмите иконку "+" в правом верхнем углу → **New Repository**.
2. Поле **Repository Name**: `prohomelab-site`.
3. **Visibility**: на ваше усмотрение (Private, если сайт содержит что-то не для чужих глаз, хотя тут только исходники — можно и Private).
4. **Важно**: НЕ ставьте галочки "Initialize Repository" / не добавляйте README, .gitignore или лицензию — репозиторий должен быть полностью пустым, иначе первый `git push` откажет из-за конфликта истории.
5. Нажмите **Create Repository**.

Forgejo покажет страницу с инструкциями и адресом репозитория вида:
`https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-site.git`

### Шаг 1.8. Привяжите Forgejo как remote

Вернитесь в SSH-сессию на Blowfish LXC:

```bash
git remote add origin https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-site.git
```

Замените `<ваш-юзер>` на ваш логин в Forgejo. Проверьте, что remote добавился:

```bash
git remote -v
```

Должны увидеть две строки (fetch и push) с указанным вами адресом.

### Шаг 1.9. Отправьте (push) репозиторий

```bash
git branch -M main
git push -u origin main
```

Разбор:
- `git branch -M main` — переименовать текущую ветку в `main` (стандартное имя главной ветки),
- `git push -u origin main` — отправить ветку `main` на remote с именем `origin`; флаг `-u` запоминает эту связку, чтобы дальше можно было писать просто `git push`.

Git запросит логин/пароль от Forgejo. Если у вас включена двухфакторка или Forgejo требует токен вместо пароля — создайте Personal Access Token: в Forgejo `Settings → Applications → Generate New Token`, дайте права на `repository`, и используйте этот токен вместо пароля при push.

Если у вас настроены SSH-ключи для Forgejo — используйте вместо этого:
```bash
git remote set-url origin git@forgejo.vaultlab.ru:<ваш-юзер>/prohomelab-site.git
git push -u origin main
```

### Шаг 1.10. Проверьте результат

Откройте в браузере `https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-site` — вы должны увидеть файлы проекта: `hugo.toml`, `content/`, `themes/` и так далее.

**Чек-пойнт Фазы 1**: репозиторий Hugo-сайта теперь существует и версионируется в Forgejo. ✅

---

## Фаза 2. Настраиваем Obsidian, чтобы статьи сами уходили в Forgejo

### Шаг 2.1. Создайте второй пустой репозиторий в Forgejo

Так же, как в шаге 1.7, но с именем `prohomelab-content`. Тоже без инициализации README.

### Шаг 2.2. Инициализируйте git прямо в папке со статьями (не во всём vault!)

На Windows откройте PowerShell (Пуск → введите "PowerShell" → Enter).

```powershell
cd "C:\Users\Pavel\Documents\Obsidian\claudvault2\01-Projects\Prohomelab"
```

Проверьте, что вы в нужной папке:

```powershell
Get-Location
```

Инициализируйте git:

```powershell
git init
git config user.name "Pavel"
git config user.email "pavel@prohomelab.local"
```

Если PowerShell пишет "git не является внутренней или внешней командой" — значит Git for Windows не установлен. Скачайте и установите с `https://git-scm.com/download/win` (при установке можно оставить все настройки по умолчанию), затем перезапустите PowerShell и повторите шаг.

### Шаг 2.3. Исключите служебные файлы Obsidian из репозитория

В эту папку не должны попасть `Prohomelab.base` (файл настроек Bases) и `_Prohomelab-Index.md` (ваш служебный индекс) — они не предназначены для публикации на сайте.

```powershell
@"
Prohomelab.base
_Prohomelab-Index.md
"@ | Out-File -Encoding utf8 .gitignore
```

Если в папке есть ещё какие-то не предназначенные для сайта заметки/черновики — допишите их в этот файл, каждую с новой строки. Проверить содержимое:

```powershell
Get-Content .gitignore
```

### Шаг 2.4. Первый коммит и push

```powershell
git add .
git status
```

Посмотрите список файлов — `.base` и `_Prohomelab-Index.md` быть не должно.

```powershell
git commit -m "Initial content"
git remote add origin https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-content.git
git branch -M main
git push -u origin main
```

Как и в Фазе 1 — если попросит логин/пароль, используйте Personal Access Token вместо пароля.

### Шаг 2.5. Настройте плагин Obsidian Git на эту конкретную папку

Откройте Obsidian → Settings (шестерёнка) → в левом меню найдите **Git** (плагин должен быть уже установлен, раз вы упомянули, что он есть; если нет — установите через Community Plugins).

В настройках плагина Git найдите раздел **Advanced**, и в нём поле **Custom base path**. Впишите туда путь относительно корня vault:

```
01-Projects/Prohomelab
```

(со слэшем `/`, даже на Windows — плагин ожидает такой формат).

Это ключевая настройка: она говорит плагину "репозиторий не в корне vault, а вот в этой подпапке" — именно поэтому плагин будет коммитить и пушить только вашу папку со статьями, а не весь vault с юридическими заметками, каталогом книг и прочим.

Дальше в тех же настройках плагина:

- **Vault backup interval (minutes)** — например `10`. Это значит: раз в 10 минут плагин сам проверяет, есть ли несохранённые изменения, и если да — делает коммит.
- **Auto push interval (minutes)** — например `10`. Аналогично, но для отправки (push) уже сделанных коммитов на Forgejo.
- **Pull updates on startup** — включите (Enable). Это подтянет изменения с сервера при открытии Obsidian, полезно, если вы правите заметки с двух устройств.

Сохранять отдельно не нужно — настройки применяются сразу.

### Шаг 2.6. Проверьте, что автокоммит работает

Откройте любую статью в папке Prohomelab, допишите пробел или любой символ, сохраните файл (Ctrl+S, хотя Obsidian и так автосохраняет).

Откройте палитру команд (Ctrl+P), введите "Git", выберите **Git: Commit and push** — это выполнит коммит и push немедленно, не дожидаясь таймера.

Проверьте в браузере `https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-content` — должен появиться новый коммит с вашим изменением.

**Чек-пойнт Фазы 2**: сохранение заметки в Obsidian теперь долетает до Forgejo без вашего участия (кроме, возможно, ожидания таймера). ✅

---

## Фаза 3. Ставим "раннер" на Blowfish LXC — то, что будет выполнять сборку

Раннер — это фоновая программа. Она сидит и ждёт сигнала от Forgejo "в репозитории что-то поменялось, запусти вот эти команды". Мы ставим её именно на Blowfish LXC, потому что там уже есть Hugo, и туда не нужно ничего пересылать по сети для сборки.

### Шаг 3.1. Включите Forgejo Actions в самом Forgejo

Подключитесь по SSH к серверу, где физически крутится Forgejo (не Blowfish — это отдельный сервер/контейнер).

Найдите файл конфигурации `app.ini`. Обычно он лежит в одном из этих мест:
```
/etc/forgejo/app.ini
/var/lib/forgejo/custom/conf/app.ini
```
Если не уверены, где именно — выполните:
```bash
find / -name "app.ini" 2>/dev/null
```

Откройте файл в редакторе (например nano):
```bash
nano /путь/к/app.ini
```

Найдите (или добавьте, если нет) секцию:
```ini
[actions]
ENABLED = true
```

Сохраните файл (в nano: Ctrl+O, Enter, потом Ctrl+X для выхода).

Перезапустите Forgejo, чтобы настройка применилась. Если Forgejo запущен как systemd-сервис:
```bash
systemctl restart forgejo
```
Если в Docker-контейнере:
```bash
docker restart <имя-контейнера-forgejo>
```

Проверьте: зайдите в веб-интерфейс, откройте любой из ваших репозиториев (`prohomelab-site`) — сверху должна появиться вкладка **Actions**, которой раньше не было.

### Шаг 3.2. Получите токен для регистрации раннера

В браузере откройте:
```
https://forgejo.vaultlab.ru/-/admin/actions/runners
```
(это доступно только администратору Forgejo — если вы единственный пользователь, это вы).

Нажмите **Create new runner**. Forgejo покажет одноразовый токен регистрации — длинную строку символов. Скопируйте её, она понадобится в следующем шаге (действует ограниченное время, если не успеете — сгенерируйте заново).

### Шаг 3.3. Установите программу-раннер на Blowfish LXC

Вернитесь в SSH-сессию на Blowfish (`ssh root@192.168.1.13`).

```bash
cd /opt
curl -L https://code.forgejo.org/forgejo/runner/releases/latest/download/forgejo-runner-linux-amd64 -o forgejo-runner
```

Разбор: `curl -L` скачивает файл по ссылке (флаг `-L` — следовать редиректам), `-o forgejo-runner` — сохранить под этим именем.

Сделайте файл исполняемым и переместите в системную папку для программ:
```bash
chmod +x forgejo-runner
mv forgejo-runner /usr/local/bin/
```

`chmod +x` — дать файлу право на выполнение (без этого Linux откажется его запускать).

### Шаг 3.4. Зарегистрируйте раннер

```bash
mkdir -p /etc/forgejo-runner
cd /etc/forgejo-runner

forgejo-runner register \
  --instance https://forgejo.vaultlab.ru \
  --token ВСТАВЬТЕ_СЮДА_ТОКЕН_ИЗ_ШАГА_3.2 \
  --name blowfish-runner \
  --labels host \
  --no-interactive
```

Разбор флагов:
- `--instance` — адрес вашего Forgejo,
- `--token` — токен из предыдущего шага,
- `--name` — как раннер будет называться в списке (для вашего удобства),
- `--labels host` — говорит раннеру "выполняй задания напрямую в системе, без Docker". Это важно: Blowfish — LXC-контейнер, а запускать Docker внутри LXC-контейнера — отдельная головная боль (вложенная виртуализация), которой мы таким образом избегаем. В host-режиме раннер просто выполняет bash-команды прямо на этой машине, где уже стоит Hugo.
- `--no-interactive` — не задавать дополнительных вопросов в терминале.

После успешной регистрации появится файл `/etc/forgejo-runner/.runner` с учётными данными и `config.yaml`.

### Шаг 3.5. Создайте systemd-сервис, чтобы раннер работал постоянно

Без этого раннер работает только пока вы вручную его не остановите в текущей сессии терминала — а нам нужно, чтобы он крутился в фоне всегда, в том числе после перезагрузки контейнера.

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
```

Разбор ключевых строк:
- `ExecStart` — какую команду запускать,
- `Restart=always` — если процесс упадёт, systemd перезапустит его сам,
- `WantedBy=multi-user.target` — запускать автоматически при загрузке системы.

Примените и запустите:

```bash
systemctl daemon-reload
systemctl enable --now forgejo-runner
```

`daemon-reload` — заставить systemd перечитать список сервисов (мы же только что добавили новый файл). `enable --now` — одновременно "включить автозапуск при загрузке" и "запустить прямо сейчас".

Проверьте, что всё работает:

```bash
systemctl status forgejo-runner
```

Вы должны увидеть зелёную надпись `active (running)`. Если там ошибка — читайте текст ошибки, чаще всего это опечатка в пути к бинарнику или в файле сервиса.

Проверьте также в веб-интерфейсе: `https://forgejo.vaultlab.ru/-/admin/actions/runners` — раннер `blowfish-runner` должен появиться в списке со статусом **Idle** (зелёная точка). Если статус не появляется — подождите минуту и обновите страницу, раннер отправляет "heartbeat" не мгновенно.

### Шаг 3.6. Установите недостающие программы

Проверьте, что на Blowfish LXC есть `git` и `lftp` (последний нужен для заливки файлов на smartape по FTP):

```bash
apt update
apt install -y git lftp
```

Hugo у вас уже установлен (вы им и так пользуетесь вручную), но на всякий случай проверьте версию:
```bash
hugo version
```

**Чек-пойнт Фазы 3**: у Forgejo теперь есть "рабочая лошадка", которая по команде сможет выполнять сборку прямо на Blowfish LXC. ✅

---

## Фаза 4. Пишем сам сценарий сборки и деплоя

### Шаг 4.1. Скрипт синхронизации контента

Этот скрипт: скачивает свежие статьи из репозитория `prohomelab-content`, копирует их в папку Hugo-проекта `content/posts`, и попутно чинит обсидиановский синтаксис картинок, который Hugo не понимает.

На Blowfish LXC:

```bash
cd /home/prohomelab
mkdir -p scripts
```

Создайте файл скрипта:

```bash
cat > scripts/sync-content.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONTENT_REPO_URL="https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-content.git"
CONTENT_DIR="/tmp/prohomelab-content"
TARGET_DIR="content/posts"

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
```

Замените `<ваш-юзер>` на ваш логин Forgejo.

Разбор построчно:
- `set -euo pipefail` — стандартная "страховка" для bash-скриптов: остановиться при любой ошибке, а не продолжать вслепую.
- `rm -rf "$CONTENT_DIR"` — удалить старую временную копию контента, если осталась с прошлого раза.
- `git clone --depth 1 ...` — скачать репозиторий контента заново; `--depth 1` значит "скачай только последнее состояние, без истории коммитов" — быстрее и меньше весит, история нам тут не нужна.
- `rsync -a --delete ...` — скопировать файлы из скачанного контента в `content/posts` Hugo-проекта. `-a` — сохранить структуру папок и атрибуты файлов. `--delete` — если какую-то статью удалили в Obsidian, она удалится и здесь (иначе старые статьи копились бы вечно). `--exclude` — не копировать служебные файлы (на случай, если `.gitignore` в контент-репозитории всё же что-то пропустил).
- `find ... | xargs sed -i -E 's/!\[\[([^]]+)\]\]/![](\1)/g'` — пройтись по всем `.md`-файлам и заменить обсидиановский синтаксис вставки картинок `![[имя.png]]` на обычный markdown `![](имя.png)`, который Hugo умеет отображать. Если в будущем встретите ещё какие-то не отображающиеся элементы (например, обычные wiki-ссылки `[[Название заметки]]` между статьями или коллбауты `> [!note]`) — сюда же дописывается ещё одна строка с `sed`.

Сделайте скрипт исполняемым:
```bash
chmod +x scripts/sync-content.sh
```

Можно сразу проверить скрипт вручную, не дожидаясь настройки Actions:
```bash
bash scripts/sync-content.sh
```
Посмотрите, появились ли/обновились файлы в `content/posts`:
```bash
ls content/posts
```

Если всё в порядке — закоммитьте скрипт в git (это часть репозитория `prohomelab-site`, не контента):
```bash
git add scripts/sync-content.sh
git commit -m "Add content sync script"
git push
```

### Шаг 4.2. Файл workflow — что именно должен делать раннер

Forgejo Actions читает специальные YAML-файлы из папки `.forgejo/workflows/` в репозитории. Создадим такой файл в `prohomelab-site`.

```bash
mkdir -p .forgejo/workflows
cat > .forgejo/workflows/deploy.yml <<'EOF'
name: Build and Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:
  repository_dispatch:
    types: [content-updated]

jobs:
  deploy:
    runs-on: host
    steps:
      - name: Checkout site repo
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Sync content from Obsidian repo
        run: bash scripts/sync-content.sh

      - name: Build with Hugo
        run: hugo -D --minify

      - name: Deploy to smartape via FTP
        env:
          FTP_HOST: ${{ secrets.SMARTAPE_FTP_HOST }}
          FTP_USER: ${{ secrets.SMARTAPE_FTP_USER }}
          FTP_PASS: ${{ secrets.SMARTAPE_FTP_PASS }}
        run: |
          lftp -u "$FTP_USER,$FTP_PASS" "$FTP_HOST" <<'INNEREOF'
          set ftp:ssl-allow yes
          mirror -R --delete --verbose public/ /www/prohomelab
          bye
          INNEREOF
EOF
```

Построчный разбор, что означает каждый блок:

- `on:` — список событий-триггеров: `push` на ветку `main` (то есть сработает, когда вы сами что-то запушите в этот репозиторий — например, поправите тему), `workflow_dispatch` (кнопка "запустить вручную" в веб-интерфейсе Forgejo, полезно для тестов), `repository_dispatch` с типом `content-updated` — именно этим событием второй репозиторий (`prohomelab-content`) будет "будить" этот пайплайн (настроим в шаге 4.3).
- `runs-on: host` — выполнять задание на раннере с меткой `host` — том самом, что мы зарегистрировали в Фазе 3.
- `steps:` — последовательность действий сверху вниз:
  1. **Checkout site repo** — скачать (сделать git checkout) текущий репозиторий `prohomelab-site` во временную рабочую папку раннера, включая submodule (тему Blowfish, `submodules: recursive`).
  2. **Sync content** — запустить наш скрипт из шага 4.1.
  3. **Build with Hugo** — собственно сборка сайта; `-D` включает черновики (draft-статьи тоже попадут на сайт — если не хотите этого в проде, потом уберите флаг), `--minify` сжимает HTML/CSS/JS.
  4. **Deploy** — залить получившуюся папку `public/` на хостинг. `secrets.SMARTAPE_FTP_HOST/USER/PASS` — эти значения мы зададим отдельно (шаг 4.4), они не хранятся в самом файле и не будут видны в открытом виде. `lftp mirror -R` — означает "reverse mirror", то есть загрузить файлы С локального диска НА сервер (а не наоборот). `--delete` — удалить на сервере файлы, которых больше нет локально (чтобы не копились старые версии). `set ftp:ssl-allow yes` — разрешить шифрование соединения, если хостинг его поддерживает.

### Шаг 4.3. Второй workflow — "будильник" в репозитории контента

Push в `prohomelab-content` сам по себе не запускает workflow в `prohomelab-site` — это два разных, независимых репозитория. Поэтому в контент-репозитории добавляем свой маленький workflow, единственная задача которого — сказать через API Forgejo "эй, prohomelab-site, у тебя есть новый контент, пересобери сайт".

Сначала создайте токен доступа: в Forgejo зайдите в `Settings → Applications → Generate New Token`, назовите его например `content-dispatch`, выберите право `write:repository`, нажмите Generate. Скопируйте токен — он покажется только один раз.

Теперь на Windows, в папке контента:

```powershell
cd "C:\Users\Pavel\Documents\Obsidian\claudvault2\01-Projects\Prohomelab"
mkdir .forgejo\workflows -Force
```

Создайте файл `.forgejo\workflows\notify.yml` любым текстовым редактором (Блокнот подойдёт) со следующим содержимым:

```yaml
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
          TOKEN: ${{ secrets.FORGEJO_DISPATCH_TOKEN }}
        run: |
          curl -X POST \
            -H "Authorization: token $TOKEN" \
            -H "Content-Type: application/json" \
            "https://forgejo.vaultlab.ru/api/v1/repos/<ваш-юзер>/prohomelab-site/dispatches" \
            -d '{"event_type":"content-updated"}'
```

Замените `<ваш-юзер>` на свой логин. Сохраните файл (в Блокноте: Файл → Сохранить как → тип файла "Все файлы", имя `notify.yml`, следите, чтобы Блокнот не добавил `.txt` в конце).

Закоммитьте и запушьте (можно сразу через Obsidian Git — палитра команд → Commit and push — или через PowerShell):

```powershell
git add .forgejo/workflows/notify.yml
git commit -m "Add dispatch workflow"
git push
```

### Шаг 4.4. Заполните секреты в обеих репозиториях

Секреты — это способ передать пароль/токен в workflow, не вписывая его открытым текстом в YAML-файл (который лежит в git и виден всем, у кого есть доступ к репозиторию).

**В репозитории `prohomelab-content`**: откройте `https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-content/settings/actions/secrets` (или через UI: Settings репозитория → вкладка Actions → Secrets).

Нажмите **Add Secret**:
- Name: `FORGEJO_DISPATCH_TOKEN`
- Value: токен из шага 4.3

**В репозитории `prohomelab-site`**: аналогично, на странице Settings → Actions → Secrets добавьте три секрета — данные для FTP-подключения к smartape (посмотрите их в панели управления хостингом, там же где смотрели для FileZilla):
- Name: `SMARTAPE_FTP_HOST`, Value: адрес FTP-сервера smartape (например `ftp.smartape.ru`, у вас он уже настроен в FileZilla — скопируйте оттуда)
- Name: `SMARTAPE_FTP_USER`, Value: логин FTP
- Name: `SMARTAPE_FTP_PASS`, Value: пароль FTP

**Чек-пойнт Фазы 4**: оба workflow-файла и все секреты на месте. ✅

---

## Фаза 5. Проверка всей цепочки целиком

### Шаг 5.1. Внесите тестовое изменение

В Obsidian откройте любую статью в папке `01-Projects\Prohomelab`, впишите какой-нибудь безобидный текст (например добавьте пробел в конце абзаца), сохраните.

### Шаг 5.2. Убедитесь, что Obsidian отправил изменение

Через палитру команд (Ctrl+P) выполните **Git: Commit and push**, чтобы не ждать таймера.

### Шаг 5.3. Проверьте первый workflow (в content-репозитории)

Откройте `https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-content` → вкладка **Actions**. Должен появиться новый запуск workflow "Notify site repo". Кликните на него — увидите живой лог выполнения шага "Trigger site build". Он должен завершиться зелёной галочкой.

Если красный крестик — откройте лог, там будет видно текст ошибки (чаще всего — неверный токен или опечатка в URL API).

### Шаг 5.4. Проверьте второй workflow (в site-репозитории)

Откройте `https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-site` → вкладка **Actions**. Должен запуститься "Build and Deploy". Раскройте каждый шаг:

- **Checkout site repo** — должен просто отработать без ошибок.
- **Sync content from Obsidian repo** — в логе увидите вывод git clone и rsync, в конце — "Content synced and converted.".
- **Build with Hugo** — увидите стандартный вывод Hugo (сколько страниц собрано, сколько времени заняло).
- **Deploy to smartape via FTP** — увидите список файлов, которые lftp загружает на сервер.

Если весь job зелёный — сайт уже обновлён.

### Шаг 5.5. Откройте сайт и проверьте вживую

Зайдите на prohomelab.com, откройте изменённую статью, убедитесь, что правка на месте.

---

## Раздел "если что-то не работает" (типичные проблемы)

- **`git push` просит пароль и не принимает обычный пароль аккаунта** — Forgejo (как и большинство git-хостингов) требует Personal Access Token вместо пароля для операций по HTTPS. Создайте его в `Settings → Applications` и используйте вместо пароля.
- **Раннер не появляется в списке `admin/actions/runners`** — проверьте `systemctl status forgejo-runner` на Blowfish LXC; если сервис не запущен, смотрите `journalctl -u forgejo-runner -n 50` для деталей ошибки.
- **Workflow не запускается вообще** — убедитесь, что в `app.ini` Forgejo стоит `ENABLED = true` в секции `[actions]`, и что Forgejo был перезапущен после правки файла.
- **Шаг "Deploy to smartape via FTP" падает с ошибкой соединения** — проверьте, что данные FTP (host/user/pass) в секретах совпадают с теми, что работают в FileZilla; также проверьте, не блокирует ли smartape подключения не с "белого списка" IP (маловероятно для обычного FTP, но встречается).
- **Картинки на сайте не отображаются** — почти наверняка это необработанный обсидиановский синтаксис вставки картинок; проверьте фактический markdown исходной заметки (например, картинка вставлена не как `![[file.png]]`, а каким-то другим способом — тогда нужно добавить ещё одно `sed`-правило в `scripts/sync-content.sh`, аналогично уже существующему).
- **Статья не появляется на сайте, хотя всё "зелёное"** — проверьте фронтматтер статьи: возможно `draft: true` и при этом в workflow вы убрали флаг `-D` у команды `hugo`, либо не проставлена дата публикации (`published`) в будущем.

---

## Что делать дальше, когда всё настроено

Обычный рабочий цикл теперь выглядит так: открыли Obsidian → написали или отредактировали статью → сохранили → (по желанию) сразу выполнили Commit and push, если не хотите ждать автопуш по таймеру. Дальше всё происходит само: Forgejo → раннер на Blowfish → сборка → заливка на smartape. FileZilla и ручной `hugo -D` из этого процесса полностью исключены.
