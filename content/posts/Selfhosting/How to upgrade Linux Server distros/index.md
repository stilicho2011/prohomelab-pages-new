---
title: Как обновлять серверные варианты дистрибутивов Linux
published: 2025-12-12
pinned: false
description: Подробная инструкция по безопасному обновлению серверных дистрибутивов Debian, Ubuntu Server и Fedora Server с примерами команд
tags:
  - Server
  - Self-Hosting
  - Linux
  - Docker
slug: /update-linux-server
categories: Linux
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Self-Hosting
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Подробная инструкция по безопасному обновлению серверных дистрибутивов Debian, Ubuntu Server и Fedora Server с примерами команд
---


# Как обновлять серверные варианты дистрибутивов на базе Linux
## Обновление версий дистрибутивов Debian, Ubuntu Server и Fedora Server

Обновление операционной системы — важный шаг для поддержания безопасности, стабильности и получения новых функций. В этой статье рассмотрим, как безопасно обновлять версии популярных серверных дистрибутивов: Debian, Ubuntu Server и Fedora Server.

---

## 1. Debian

Debian известен своей стабильностью, но обновление до новой версии может потребовать некоторых подготовительных шагов.

### Порядок обновления

1. **Проверка текущей версии**

```yaml

lsb_release -a

```

или  
`cat /etc/debian_version`  
 

2. **Обновление текущих пакетов**

```yaml
sudo apt update
sudo apt upgrade -y
sudo apt full-upgrade -y
sudo apt autoremove -y
```

3. **Изменение источников пакетов**

Отредактируйте файл `/etc/apt/sources.list`, заменив старое название версии на новое:

```yaml
# Старое:
deb http://deb.debian.org/debian/bullseye main contrib non-free

# Новое:
deb http://deb.debian.org/debian/bookworm main contrib non-free
```

4. **Обновление до новой версии**

```yaml
sudo apt update
sudo apt upgrade -y
sudo apt full-upgrade -y
sudo reboot

```

5. **Проверка версии после обновления**

```yaml
lsb_release -a

```

## 2. Ubuntu Server

Ubuntu Server обновляется с помощью `do-release-upgrade`.

### Порядок обновления

1.  **Проверка текущей версии**

```yaml
lsb_release -a

```

  
**2. Обновление всех пакетов текущей версии**  
 

```yaml
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

```

**3. Запуск обновления версии**

```yaml
sudo do-release-upgrade

```

> Если обновление не запускается, убедитесь, что установлен пакет `update-manager-core`:

```yaml
sudo apt install update-manager-core

```

**4. Следуйте инструкциям мастера обновления**  
Обычно потребуется подтвердить замену конфигурационных файлов и перезагрузку.

**5. Проверка версии после обновления**

```yaml
lsb_release -a

```

## 3. Fedora Server

Fedora Server использует инструмент `dnf` для обновления до новой версии.

### Порядок обновления

1.  **Проверка текущей версии**

```yaml
cat /etc/fedora-release
```

2. **Обновление текущей системы**

```yaml
sudo dnf upgrade --refresh -y
sudo dnf autoremove -y

```

3. **Установка плагина для обновления версии**

```yaml
sudo dnf install dnf-plugin-system-upgrade -y

```

4. **Запуск скачивания новой версии**

```yaml
sudo dnf system-upgrade download --releasever=43
```

> Замените `43` на целевую версию Fedora.

5. **Применение обновления**

```yaml
sudo dnf system-upgrade reboot

```

6. **Проверка версии после обновления**

```yaml
cat /etc/fedora-release

```

## 4. Шпаргалка: обновление версий Debian, Ubuntu Server и Fedora Server

Эта таблица содержит основные команды для безопасного обновления серверных дистрибутивов Linux.

| Дистрибутив | Проверка версии | Обновление текущих пакетов | Обновление версии ОС | Примечания |
|-------------|----------------|----------------------------|--------------------|------------|
| **Debian** | `lsb_release -a`<br>`cat /etc/debian_version` | ```sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo apt autoremove -y ``` | 1. Изменить `/etc/apt/sources.list` на новую версию<br>2. ```sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo reboot ``` | Обновление через `apt` требует внимательного редактирования источников пакетов. |
| **Ubuntu Server** | `lsb_release -a` | ```sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo apt autoremove -y ``` | ```sudo do-release-upgrade ``` | Убедитесь, что установлен `update-manager-core`. Следуйте инструкциям мастера. |
| **Fedora Server** | `cat /etc/fedora-release` | ```sudo dnf upgrade --refresh -y && sudo dnf autoremove -y ``` | 1. ```sudo dnf install dnf-plugin-system-upgrade -y ```<br>2. ```sudo dnf system-upgrade download --releasever=<target_version> ```<br>3. ```sudo dnf system-upgrade reboot ``` | Замените `<target_version>` на нужную версию Fedora. |

 

## 5. Рекомендации по обновлению

*   Всегда делайте резервные копии важных данных перед обновлением.
*   Читайте официальные руководства и примечания к релизу выбранной версии.
*   На серверах с критичными сервисами лучше тестировать обновление на отдельной машине или виртуальной среде.
*   После обновления проверяйте состояние сервисов и логов (`systemctl status` и `journalctl`).

* * *

Таким образом, процесс обновления в Debian/Ubuntu и Fedora немного отличается, но основной принцип — сначала обновить текущие пакеты, затем перейти на новую версию безопасно, используя встроенные инструменты.