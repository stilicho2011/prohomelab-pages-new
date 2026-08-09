---
title: Установка и настройка Cloud-Init образа в Proxmox
published: 2025-07-20
pinned: false
description: Как использовать cloudinit-образы в Proxmox VE для автоматизации настройки виртуальных машин. Полный гайд по созданию шаблона и запуску новых ВМ.
tags:
  - Proxmox
  - Cloudinit
slug: /cloud-init-install-in-proxmox
categories: Proxmox
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Proxmox
youtube_id: GzB8HWGh8qQ
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.webp
summary: Подробная инструкция по настройке CloudInit для автоматической конфигурации серверов. Рассмотрены ключевые файлы, параметры и примеры для быстрого развертывания Linux-систем с минимальными усилиями.
---

<iframe width="100%" height="468" src="https://www.youtube.com/embed/GzB8HWGh8qQ?si=q50aHz5LwoB1eU1z" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на бусти (ссылка в разделе контакты).

## Что такое Cloud-Init и зачем он нужен?

**Cloud-Init** — это инструмент автоматизации начальной настройки виртуальных машин. Он позволяет автоматически конфигурировать:

- имя хоста,
- сетевые интерфейсы,
- пользователей и пароли,
- SSH-ключи,
- запуск скриптов при первом старте.

В сочетании с **Proxmox VE**, Cloud-Init помогает быстро разворачивать однотипные ВМ с минимальными ручными действиями. Особенно полезен в **homelab**-средах, где важна скорость и воспроизводимость развертывания.

---

## Задачи, решаемые с помощью Cloud-Init образов

1. **Автоматизация**. Убирает необходимость ручной настройки каждой новой ВМ.
2. **Унификация**. Все машины разворачиваются из одного шаблона по стандарту.
3. **Безопасность**. Можно сразу задать SSH-ключи и отключить root-пароль.
4. **Масштабируемость**. Идеально для развёртывания десятков ВМ в кластере. Конечно дома такое вряд ли пригодится, но, если на работе вам это нужно, можно потренироваться на кошках.
5. **Совместимость с CI/CD**. Можно использовать образы для автоматического тестирования и доставки инфраструктуры. Но, как я сказал выше, для домашнего использования - это скорее тестовый полигон.

---

В Proxmox VE 8 Cloud-Init интегрирован на уровне GUI и CLI, что значительно упрощает работу.

## Как установить Cloud-Init образ в Proxmox

В видеоролике я показываю, как это все сделать с помощью графического интерфейса. Лично я считаю, что это намного удобнее, но ниже я привожу инструкцию в том виде, как это указано в документации на сайте Proxmox. Инструкция на сайте рабочая, но несколько устаревшая. Там в качестве примера используется образ Убунту из далекого 2016 года.

### Шаг 1. Скачайте официальный Cloud-Init образ

Перейдите на [cloud-images.ubuntu.com](https://cloud-images.ubuntu.com/) или аналогичный ресурс. Например:

```yaml
wget https://cloud-images.ubuntu.com/jammy/current/noble-server-cloudimg-amd64.img
```

### Шаг 2. Импортируйте образ в Proxmox

```yaml
# create a new VM with VirtIO SCSI controller
qm create 9000 --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci
```

```yaml
# import the downloaded disk to the local-lvm storage, attaching it as a SCSI drive
qm set 9000 --scsi0 local-lvm:0,import-from=/path/to/noble-server-cloudimg-amd64.img
```

### Шаг 3 Добавляем Cloud-Init образ как CD-ROM drive

Следующий шаг — настроить привод CD-ROM, который будет использоваться для установки Cloud-Init на виртуальную машину.

```yaml
qm set 9000 --ide2 local-lvm:cloudinit
```

Чтобы иметь возможность загружаться напрямую с образа Cloud-Init, установите параметр загрузки order=scsi0, чтобы разрешить BIOS загрузку только с этого диска. Это ускорит загрузку, поскольку BIOS виртуальной машины пропускает проверку наличия загрузочного CD-ROM.

```yaml
qm set 9000 --boot order=scsi0
```

Для многих образов Cloud-Init требуется настроить serial консоль и использовать её в качестве дисплея. Если эта конфигурация не подходит для конкретного образа, вернитесь к дисплею по умолчанию.

```yaml
qm set 9000 --serial0 socket --vga serial0
```

Ну и последним шагом конвертируем нашу виртуальную машину в шаблон 

```yaml
qm template 9000
```

Все, - шаблон готов.  Дальше уже вы спокойно можете создавать full клоны из этого шаблона и спокойно с ними работать.

## Особенности сети в Proxmox VE 8

Proxmox VE 8 использует systemd-networkd, поэтому важно корректно задать сетевые параметры:

Если оставить DHCP, Cloud-Init автоматически получит IP.

Для статического IP заполните поля IP Address, Gateway, DNS на вкладке Cloud-Init.

## Команды, которые использовались в ролике

Скачиваем образ

```yaml
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

Переименовываем образ

```yaml
mv noble-server-cloudimg-amd64.img noble-server-cloudimg-amd64.qcow2
```

Устанавливаем serial консоль в нужную нам виртуальную машину

```yaml
qm set 700 --serial0 socket --vga serial0
```

Укажем рабочий объем cloudinit диска виртуальной машины

```yaml
qemu-img resize noble-server-cloudimg-amd64.qcow2 32G
```

Импортируем cloudinit образ в виртуальную машину

```yaml
qm disk import 700 noble-server-cloudimg-amd64.qcow2 local
```

## Заключение

Установка Cloud-Init образа в Proxmox VE значительно упрощает развертывание инфраструктуры. Правильная подготовка образа и настройка Cloud-Init позволяют полностью автоматизировать процесс конфигурации виртуальных машин, что особенно актуально для DevOps и корпоративных окружений, но конечно может использоваться и в homelab.
