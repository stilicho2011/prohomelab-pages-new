---
title: Настройка домашнего NAS на Fedora Server 44 с OpenZFS, Cockpit и Samba
published: 2026-07-15
pinned: false
description: Пошаговая инструкция по созданию домашнего NAS на Fedora Server 44 с использованием OpenZFS, Cockpit и Samba. Настройка пула ZFS, общего доступа по SMB и SELinux.
tags:
  - Fedora
  - NAS
  - Self-Hosting
  - Homelab
slug: /fedora-server-nas
categories: Self-Hosting
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
summary: Собираем современный домашний NAS на Fedora Server 44 с файловой системой OpenZFS, веб-интерфейсом Cockpit и файловым сервером Samba. Полная пошаговая инструкция по установке, настройке ZFS, SELinux и публикации SMB-шары.
---

## Введение

В этой статье мы соберём современный домашний NAS на базе **Fedora Server 44**, файловой системы **OpenZFS** и файлового сервера **Samba**.

Долгое время я использовал TrueNAS в качестве операционной системы для хранения данных. Это отличная система, однако со временем пришёл к выводу, что в моём случае она избыточна. NAS у меня выполняет одну задачу - хранение файлов, поэтому многие возможности TrueNAS остались невостребованными. При этом всё остальное оказалось интереснее и удобнее настроить самостоятельно..

В качестве основы я выбрал Fedora Server. Мы получим полноценную Linux-систему, веб-интерфейс Cockpit, файловую систему ZFS и привычный общий доступ по SMB.

## Почему Fedora Server, а не TrueNAS?

Перед тем как перейти к настройке, хочу ответить на вполне логичный вопрос: почему вообще Fedora Server, если уже используешь TrueNAS, или почему не попробовать любые другие готовые операционные системы для nas?

На протяжении долгого времени я использовал TrueNAS в качестве основной операционной системы для домашнего NAS. Это отличное решение с удобным веб-интерфейсом и большим количеством встроенных возможностей. Однако со временем я понял, что использую лишь небольшую часть его функциональности, а некоторые особенности Truenas начали раздражать.

Для меня NAS — это прежде всего надежное хранилище данных. Все остальные сервисы — Nextcloud, Immich, Jellyfin, Grafana, Docker и другие — работают на отдельных серверах и виртуальных машинах. В результате большинство возможностей TrueNAS оказалось просто невостребованным.

Fedora Server, наоборот, предоставляет чистую и современную Linux-систему без лишних компонентов. Это дает несколько преимуществ:

- полный контроль над операционной системой;
- всегда актуальные версии программного обеспечения, но без нюансов arch-подобных систем;
- возможность самостоятельно выбрать необходимые сервисы;
- удобное администрирование через Cockpit;
- полноценную поддержку OpenZFS;
- отсутствие ограничений, характерных для специализированных NAS-дистрибутивов.

Согласен, что такой подход требует немного больше времени на первоначальную настройку и наличие знаний чуть выше базовых умений кликать мышкой. Зато в дальнейшем вы получаете максимально гибкую систему, которую легко адаптировать под свои задачи, не завися от особенностей конкретной NAS-платформы.

Именно поэтому в качестве основы для домашнего файлового сервера я выбрал Fedora Server 44.

--------------------------------------------------------------------

## Подготовка Fedora Server

### Обновление системы

``` bash
sudo dnf update -y
```

В современных RPM-дистрибутивах команда `dnf update` уже включает функциональность прежнего `dnf upgrade`.

### Установка необходимых пакетов

``` bash
sudo dnf install -y \
tar gzip curl unzip git procps-ng findutils nano \
cockpit-bridge coreutils attr hostname iproute glibc-common \
systemd nfs-utils samba samba-client samba-common-tools
```

### Дополнительные инструменты

``` bash
sudo dnf install -y lm_sensors cockpit-sosreport
sudo sensors-detect
```

``` bash
sudo systemctl restart cockpit.socket
```

### Установка [Cockpit Sensors](<https://github.com/ocristopfer/cockpit-sensors>)

``` bash
sudo wget https://github.com/ocristopfer/cockpit-sensors/releases/latest/download/cockpit-sensors.tar.xz
# 
sudo mkdir -p /usr/share/cockpit/sensors
# 
tar -xf cockpit-sensors.tar.xz cockpit-sensors/dist
# 
sudo cp -r cockpit-sensors/dist/* /usr/share/cockpit/sensors/
#
rm -rf cockpit-sensors cockpit-sensors.tar.xz
```

``` bash
sudo systemctl restart cockpit.socket
```

---
  
## Установка [OpenZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/Fedora/index.html)

Добавляем репозиторий:

``` bash
sudo dnf install -y https://zfsonlinux.org/fedora/zfs-release-3-1$(rpm --eval "%{dist}").noarch.rpm
```

Устанавливаем заголовки текущего ядра:

``` bash
sudo dnf install -y kernel-devel-$(uname -r | awk -F'-' '{print $1}')
```
  
Устанавливаем OpenZFS:

``` bash
sudo dnf install -y zfs
```

Загружаем модуль:

``` bash
sudo modprobe zfs
# Указываем системе, чтобы модуль загружался при перезагрузке 
echo zfs | sudo tee /etc/modules-load.d/zfs.conf
```

На всякий случай проверяем, что zfs у нас будет работать после перезагрузки системы:

```bash
sudo reboot
```

Проверяем установку:

``` bash
zfs version
```

--------------------------------------------------------------------

## Создание пула ZFS

Создадим зеркальный пул из двух дисков:

```bash
lsblk # вывод списка дисков
```

``` bash
sudo zpool create -m /srv data mirror /dev/sda /dev/sdb
```

> **Важно:** не используйте в качестве точки монтирования ZFS каталог  `/mnt` для публикации через Samba. На Fedora Server 44 с OpenZFS 2.4.x Samba может выдавать ошибку > `canonicalize_connect_path failed`. У меня с директорией `/mnt` расшаривание по самбе не работало. При использовании `/srv` все заработало с полпинка.


> [!warning]
> В идеале крайне желательно монтировать по id диска, чтобы избежать проблем, когда при перезагрузке буквы дисков съезжают
>
> ```bash
> sudo zpool create -m /srv data mirror /dev/disk/by-id/ata-XXXX /dev/disk/by-id/ata-YYYY
> ```

Создадим датасет:

``` bash
sudo zfs create data/media
```

Проверяем, что пул и датасет созданы:

```bash
zpool status
zfs list
```

Включим сжатие:

``` bash
sudo zfs set compression=lz4 data
```

Назначим владельца:

``` bash
sudo chown -R stilicho:stilicho /srv/media
```

Здесь я вставлю небольшую ремарку (прости меня Эрих Мария).
На твоем месте я бы перезагрузил систему и проверил бы еще раз, что пул и датасет смонтируются после перезагрузки:

```bash
sudo reboot
zpool status
zfs list
```

В случае, если после перезагрузки пул не смонтировался, то введи следующие команды:

```bash
sudo systemctl enable zfs-import-cache.service
sudo systemctl enable zfs-import-scan.service
sudo systemctl enable zfs-mount.service
sudo systemctl enable zfs.target
```

Теперь:

```bash
sudo reboot
```

и проверяй результат

---

## Настройка SELinux

```bash
sudo semanage fcontext -a -t samba_share_t "/srv/media(/.*)?"
sudo restorecon -Rv /srv/media
```

Эта команда добавляет правило SELinux, которое назначает тип контекста `samba_share_t` каталогу `/srv/media` и всему его содержимому. Благодаря этому Samba получает право предоставлять доступ к этому каталогу по сети.

Разберем команду по частям:

```bash
sudo semanage fcontext -a -t samba_share_t "/srv/media(/.*)?"
```

- `sudo` — выполнить команду с правами администратора.
- `semanage` — утилита для управления политиками SELinux.
- `fcontext` — управление контекстами файлов.
- `-a` — добавить новое правило.
- `-t samba_share_t` — назначить тип SELinux `samba_share_t`, предназначенный для общих папок Samba.
- `"/srv/media(/.*)?"` — регулярное выражение:
  - `/srv/media` — сам каталог;
  - `(/.*)?` — все файлы и подкаталоги внутри него.

После добавления правила необходимо применить новый контекст к существующим файлам:

```bash
sudo restorecon -Rv /srv/media
```

  - `restorecon` — применяет контексты SELinux в соответствии с правилами.
- `-R` — рекурсивно обрабатывает все вложенные каталоги и файлы.
- `-v` — выводит информацию обо всех изменениях.

Проверка:

``` bash
ls -Zd /srv/media
```

  Ожидаемый результат:

``` text
system_u:object_r:samba_share_t:s0 /srv/media
```

---

## Настройка Samba

Создаем отдельного локального пользователя Linux, который будет использоваться для доступа к SMB-шаре.:

``` bash
sudo useradd samba
#
sudo smbpasswd -a samba
```

Зададим права пользователю samba на датасет, который мы будем расшаривать

```bash
sudo groupadd media # создаем отдельную группу для шаринга
# добавляем туда наших пользователей
sudo usermod -aG media stilicho 
sudo usermod -aG media samba
# задаем права на датасет для пользователей группы media
sudo chown -R stilicho:media /srv/media
sudo chmod -R 775 /srv/media
sudo find /srv/media -type d -exec chmod g+s {} \;
```

Создаем samba шару
Добавьте в `/etc/samba/smb.conf`:

``` text
[share]

    comment = Shared Network Folder
    path = /srv/media
    browseable = yes
    read only = no
    valid users = samba
    force group = media
    create mask = 0644
    directory mask = 2755
```

Запускаем службы:

``` bash
sudo systemctl enable --now smb nmb
sudo systemctl status smb
```

Проверяем:

``` bash
smbclient //localhost/share -U samba
```

Если всё настроено правильно, откроется консоль Samba.

--------------------------------------------------------------------

## Подключение из Windows

Откройте проводник и введите:

``` text
\\IP-АДРЕС-СЕРВЕРА\share
```

 Введите логин и пароль пользователя Samba.

Создайте тестовую папку и файл, затем убедитесь, что они успешно создаются и после перезапуска сервера остаются доступными.

--------------------------------------------------------------------

## Заключение

В результате мы получили полноценный домашний NAS на Fedora Server 44 с файловой системой OpenZFS, веб-интерфейсом Cockpit и файловым сервером Samba.
Такой подход обеспечивает полный контроль над системой, хранение данных без привязки к специализированным NAS-дистрибутивам.
При этом Fedora остается обычной Linux-системой, которую легко расширить любыми сервисами по мере необходимости, что мы с вами и сделаем в следующих статьях.


