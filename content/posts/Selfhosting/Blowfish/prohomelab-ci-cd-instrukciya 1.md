# Автоматизация публикации ProHomelab: Obsidian → Forgejo → Hugo → хостинг

## Итоговая архитектура

```
[Windows, Obsidian]                [Forgejo: forgejo.vaultlab.ru]         [LXC Blowfish, 192.168.1.13]              [smartape]
Prohomelab (заметки)  --push-->    prohomelab-content (репо)                                                         
                                          |                                                                          
                                          | webhook / Forgejo Actions job запускается на push
                                          v
                                    prohomelab-site (репо, Hugo+Blowfish) --checkout--> act_runner на Blowfish LXC
                                                                                        1) git pull prohomelab-content
                                                                                        2) конвертация Obsidian->Hugo md
                                                                                        3) hugo -D
                                                                                        4) lftp/rsync public/ -> /www/prohomelab
```

Два репозитория в Forgejo, а не один:

- **prohomelab-content** — только сами статьи (то, что сейчас лежит в Obsidian в `01-Projects\Prohomelab`), без темы, без `public/`, без служебных файлов Obsidian (`.base`, `_Prohomelab-Index.md` и т.п.).
- **prohomelab-site** — весь Hugo-проект, который сейчас лежит на Blowfish LXC (тема Blowfish как git submodule, конфиги, layouts). Он уже частично инициализирован (`git status` это подтверждает), но ещё ни разу не запушен.

Разделение важно по двум причинам: во-первых, Obsidian Git плагин физически может версионировать только определённую папку, и мешать в неё Hugo-специфичные файлы (тему, `resources/`, `public/`) не нужно. Во-вторых, сборка и деплой должны запускаться от изменений в контенте, а не от вашей возни с темой/конфигами Hugo, и наоборот.

Сборка (`hugo -D`) и деплой будут выполняться **на самом Blowfish LXC** через self-hosted раннер Forgejo Actions — это тот же принцип, что и GitHub Actions, только раннер физически стоит у вас на 192.168.1.13, и никуда наружу лезть не нужно.

---

## Фаза 1. Привести в порядок Hugo-репозиторий на Blowfish LXC и запушить его в Forgejo

Сейчас на Blowfish (`/home/prohomelab`) есть незакоммиченный git-репозиторий без remote. Приводим его в порядок.

```bash
# на Blowfish LXC (192.168.1.13)
cd /home/prohomelab

git config user.name "Pavel"
git config user.email "you@example.com"

# .gitignore — public/ и resources/ пересобираются, в git их не держим
cat > .gitignore <<'EOF'
public/
resources/_gen/
.hugo_build.lock
EOF

git rm -r --cached public resources 2>/dev/null || true

git add .
git commit -m "Initial commit: Hugo + Blowfish site"
```

В Forgejo (веб-интерфейс `https://forgejo.vaultlab.ru`) создайте новый **пустой** репозиторий `prohomelab-site` (без README, без .gitignore — они уже есть локально).

```bash
git remote add origin https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-site.git
git branch -M main
git push -u origin main
```

Если используете SSH-ключи для Forgejo — замените URL на `git@forgejo.vaultlab.ru:<юзер>/prohomelab-site.git` и убедитесь, что публичный ключ Blowfish LXC добавлен в Forgejo (Settings → SSH Keys).

---

## Фаза 2. Создать репозиторий контента и настроить Obsidian Git для одной подпапки

### 2.1. Создать репозиторий в Forgejo

Создайте ещё один пустой репозиторий: `prohomelab-content`.

### 2.2. Подготовить папку в Obsidian как отдельный git-репозиторий

Плагин Obsidian Git по умолчанию версионирует весь vault, а вам нужна только `01-Projects\Prohomelab`. У плагина есть настройка **Advanced → Custom base path**, которая позволяет указать git-репозиторий не в корне vault, а в произвольной подпапке. Инициализируем git именно в этой подпапке:

```powershell
# на Windows, в PowerShell
cd "C:\Users\Pavel\Documents\Obsidian\claudvault2\01-Projects\Prohomelab"
git init
git config user.name "Pavel"
git config user.email "you@example.com"
```

Исключите из репозитория контента файлы, не предназначенные для сайта:

```powershell
@"
Prohomelab.base
_Prohomelab-Index.md
_resources/
"@ | Out-File -Encoding utf8 .gitignore
```

(`_resources` — если это ваши личные заметки/черновики, а не готовые к публикации; поправьте список под свою структуру).

```powershell
git add .
git commit -m "Initial content"
git remote add origin https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-content.git
git branch -M main
git push -u origin main
```

### 2.3. Настроить сам плагин Obsidian Git

В настройках плагина Git:

- **Advanced → Custom base path**: `01-Projects/Prohomelab`
- **Vault backup interval (minutes)**: например 10 — автокоммит каждые N минут, если есть изменения
- **Auto push interval (minutes)**: например 10, либо push вручную командой из палитры команд (`Obsidian Git: Commit and push`)
- **Pull updates on startup**: включить, чтобы подтягивать изменения, если правите с другого устройства

С этого момента сохранение статьи в Obsidian → автокоммит → автопуш в `prohomelab-content` происходит без FileZilla и ручного копирования.

---

## Фаза 3. Поднять self-hosted раннер Forgejo Actions на Blowfish LXC

### 3.1. Включить Actions в Forgejo

На сервере, где крутится Forgejo, в `app.ini`:

```ini
[actions]
ENABLED = true
```

Перезапустите Forgejo. В веб-интерфейсе репозитория `prohomelab-site` появится вкладка **Actions**.

### 3.2. Получить токен регистрации раннера

Instance-level: `https://forgejo.vaultlab.ru/-/admin/actions/runners` → **Create new runner** → скопируйте токен регистрации.

### 3.3. Установить act_runner на Blowfish LXC

Так как Blowfish — LXC-контейнер, вложенный Docker внутри него — лишняя головная боль. Ставим `act_runner` бинарником и запускаем в **host-режиме** (без Docker-исполнителя) — задания будут выполняться прямо в шелле контейнера, что нам и нужно, т.к. там уже стоит Hugo.

```bash
# на Blowfish LXC
cd /opt
curl -L https://code.forgejo.org/forgejo/runner/releases/latest/download/forgejo-runner-linux-amd64 -o forgejo-runner
chmod +x forgejo-runner
mv forgejo-runner /usr/local/bin/

mkdir -p /etc/forgejo-runner
cd /etc/forgejo-runner

forgejo-runner register \
  --instance https://forgejo.vaultlab.ru \
  --token <ТОКЕН_ИЗ_3.2> \
  --name blowfish-runner \
  --labels host \
  --no-interactive
```

Флаг `--labels host` даёт раннер без Docker-изоляции — job будет исполняться напрямую в системе.

Проверьте/поправьте `config.yaml`, чтобы исполнение шло без докера:

```yaml
runner:
  labels: []
container:
  # не используется в host-режиме
```

Создайте systemd-сервис, чтобы раннер жил постоянно:

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

Раннер должен появиться в списке `https://forgejo.vaultlab.ru/-/admin/actions/runners` со статусом Idle.

### 3.4. Подготовить окружение раннера

Убедитесь, что на Blowfish LXC установлены `git`, `hugo` (уже есть, раз вы им пользуетесь), и `lftp` (для загрузки на smartape):

```bash
apt update && apt install -y git lftp
```

---

## Фаза 4. Скрипт конвертации Obsidian → Hugo и деплой

У вас, судя по структуре, статьи уже оформлены как Hugo page bundle (папка-слаг + `featured.png`) с фронтматтером, уже заточенным под сайт (`title`, `published`, `tags`, `cover: ./featured.png` и т.д.) — это сильно упрощает дело. Единственное, что почти наверняка потребует конвертации — обсидиановские wiki-embed картинки вида `![](image.png)`, которые Hugo не понимает: их нужно превратить в обычный markdown `![](image.png)`.

Создайте скрипт конвертации прямо в `prohomelab-site`:

```bash
mkdir -p scripts
cat > scripts/sync-content.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONTENT_REPO_URL="https://forgejo.vaultlab.ru/<ваш-юзер>/prohomelab-content.git"
CONTENT_DIR="/tmp/prohomelab-content"
TARGET_DIR="content/posts"

rm -rf "$CONTENT_DIR"
git clone --depth 1 "$CONTENT_REPO_URL" "$CONTENT_DIR"

# синхронизируем, ничего лишнего (.gitignore-файлы) не тащим
rsync -a --delete \
  --exclude='.git' \
  --exclude='Prohomelab.base' \
  --exclude='_Prohomelab-Index.md' \
  --exclude='_resources' \
  "$CONTENT_DIR/" "$TARGET_DIR/"

# конвертация Obsidian wiki-embed картинок ![](file) -> ![](file)
find "$TARGET_DIR" -type f -name '*.md' -print0 | xargs -0 sed -i -E 's/!\[\[([^]]+)\]\]/![](\1)/g'

echo "Content synced and converted."
EOF
chmod +x scripts/sync-content.sh
```

Если позже обнаружите другие обсидиановские конструкции, которые Hugo не понимает (например, обычные wiki-ссылки `[[Заметка]]` между статьями, коллбаут-синтаксис `> [!note]` и т.п.), добавляйте под них ещё `sed`/`python`-правила в этот же скрипт — конвейер расширяемый.

### 4.1. Workflow-файл

В `prohomelab-site` создайте `.forgejo/workflows/deploy.yml`:

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]
  # запуск руками из UI, если нужно пересобрать без изменений в контенте
  workflow_dispatch:
  # позволяет триггерить job из другого репозитория через repository_dispatch,
  # см. Фазу 4.2
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
          lftp -u "$FTP_USER,$FTP_PASS" "$FTP_HOST" <<EOF
          set ftp:ssl-allow yes
          mirror -R --delete --verbose public/ /www/prohomelab
          bye
          EOF
```

Если хостер smartape поддерживает SFTP (загляните в панель хостинга — обычно есть отдельный порт/учётка) — используйте его вместо обычного FTP, это безопаснее: замените шаг деплоя на `lftp sftp://...` или на `rsync -avz -e ssh public/ user@host:/www/prohomelab`.

### 4.2. Триггер из репозитория контента

Push в `prohomelab-content` не запустит workflow в `prohomelab-site` автоматически — это два разных репозитория. Добавьте в `prohomelab-content` свой минимальный workflow, который просто "пинает" `prohomelab-site` через Forgejo API (`repository_dispatch`):

Создайте `.forgejo/workflows/notify.yml` в **prohomelab-content**:

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

`FORGEJO_DISPATCH_TOKEN` — personal access token с правом на API репозитория `prohomelab-site` (Forgejo → Settings → Applications → Generate New Token, scope `repo`/`write:repository`).

### 4.3. Секреты

В обоих репозиториях (Settings → Actions → Secrets):

- `prohomelab-content`: `FORGEJO_DISPATCH_TOKEN`
- `prohomelab-site`: `SMARTAPE_FTP_HOST`, `SMARTAPE_FTP_USER`, `SMARTAPE_FTP_PASS`

---

## Фаза 5. Проверка сквозного пайплайна

1. В Obsidian откройте/отредактируйте любую заметку в `01-Projects\Prohomelab`, сохраните.
2. Дождитесь автокоммита/автопуша плагина Git (или запустите вручную `Obsidian Git: Commit and push` из палитры команд, Ctrl+P).
3. В Forgejo → `prohomelab-content` → вкладка Actions — должен запуститься job `Notify site repo` и завершиться зелёным.
4. В Forgejo → `prohomelab-site` → вкладка Actions — должен запуститься job `Build and Deploy`: checkout, sync-content, hugo build, деплой на smartape.
5. Откройте prohomelab.com и убедитесь, что статья опубликована.

Если что-то падает — логи каждого шага видны прямо во вкладке Actions конкретного репозитория, включая вывод `hugo -D` и `lftp`, так что диагностировать несложно.

---

## Что вы получаете в итоге

Пишете статью в Obsidian → она автоматически коммитится и пушится → это триггерит сборку и деплой на Blowfish LXC → готовый сайт улетает на smartape. FileZilla и ручной hugo -D больше не нужны. Единственное ручное действие — написать статью и (если не включили автопуш) один раз нажать "commit and push" в Obsidian.
