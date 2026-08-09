---
title: "Обновление с Proxmox VE 8 до Proxmox VE 9: пошаговое руководство"
published: 2025-08-06
pinned: false
description: Узнайте, как безопасно выполнить обновление Proxmox VE 8 до версии 9. Подробное руководство с проверкой совместимости, резервным копированием и пост-обслуживанием.
tags:
  - Proxmox
  - Cluster
slug: /upgrade-proxmox8-to-proxmox9
categories: Proxmox
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Proxmox
youtube_id: tayupB1eHuE
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Пошаговое руководство по безопасной миграции с Proxmox 8 на версию 9. Рассмотрены подготовка серверов, резервное копирование, обновление пакетов и проверка совместимости виртуальных машин и контейнеров для минимизации простоев.
---

<iframe width="100%" height="468" src="https://www.youtube.com/embed/tayupB1eHuE?si=1WhQOpOxij3Ack0K" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

## Введение

**Proxmox VE 9.0** вышла **5 августа 2025 года**, получив надёжную основу на **Debian 13 «Trixie»** и **ядро Linux 6.14.8‑2**  
Данная версия знаменует собой качественный шаг вперёд в возможностях виртуализации, хранилищ и сетевой инфраструктуры.

---

## 1. Обновлённое ядро и базовая система

- Переход на **Debian 13 “Trixie”** обеспечивает актуальные пакеты, улучшенную безопасность и совместимость с современным железом: PCIe 5.0, NVMe, новые чипсеты.  
- **Linux kernel 6.14.8‑2** оптимизирован для современных CPU и сетевых интерфейсов.  
- Доступны обновлённые версии **QEMU 10.0.2** и **LXC 6.0.4**, что улучшает миграцию VMs, изоляцию и поддержку cgroup v2. Старый cgroup v1 больше не поддерживается.

---

## 2. Хранение и снапшоты

- **Поддержка LVM‑снэпшотов на thick‑provisioned общих хранилищах** (iSCSI, Fibre‑Channel), что позволяет делать snapshot с минимальным уровнем дисков и откатом без внешних инструментов.  
- Включён **ZFS 2.3.3** с поддержкой **RAID‑Z expansion** — можно добавлять диски в RAID‑Z без простоя.  
- В качестве бэкап-решения по умолчанию используется **Ceph Squid версии 19.2.3**, с LZ4‑сжатием по умолчанию и улучшенной производительностью для многопользовательских сценариев.

---

## 3. Сетевая инфраструктура и SDN

- **SDN Fabrics** позволяют строить маршрутизируемые overlay-сети между узлами (OpenFabric, OSPF), без внешних коммутаторов — поддержка spine-leaf и full-mesh топологий для кластеров Proxmox и Ceph.  
- Новый инструмент **proxmox‑network‑interface‑pinning** позволяет привязывать MAC‑адреса к стабильным именам `nic0`, `nic1` и т. д., а также автоматически корректировать конфигурацию при переименовании NIC после обновлений.

---

## 4. HA, политики размещения и мобильный UI

- Новые **правила HA‑аффинности** позволяют задавать размещение ресурсов (VM/CT) по узлам или группам для минимизации задержек или повышения отказоустойчивости.  
- Новый **мобильный интерфейс**, построенный на Rust (фреймворк Yew), обеспечивает удобное управление через браузер смартфона: управление VM, задачи HA, мониторинг и т. д.

---

## 5. Интерфейс, удобство и удаление уязвимостей

- **Dark mode по умолчанию** — интерфейс теперь запускается в ночной теме; светлая тема доступна при явном выборе пользователя.
- Улучшено отображение ошибок, уведомлений и логов, исправлены проблемы с UI, OIDC‑окно и загрузкой шаблонов ISO — особенно в web-интерфейсе и уведомлениях backup‑задач.  
- **Удалена поддержка GlusterFS**: если вы используете GlusterFS, необходимо мигрировать на Ceph, ZFS или NFS до обновления.

---

## 6. Совместимость и миграция

- Контейнеры на **cgroup v1** (CentOS 7, Ubuntu 16.04) не поддерживаются — рекомендуется заранее мигрировать на современные ОС.  
- Для пользователей **NVIDIA GRID/vGPU** требуется драйвер **GRID 18.3+** (версия 570.158.02 или новее), совместимый с kernel ≥ 6.0. Без этого поддержка vGPU будет прервана.  

---

## 7. Команды из ролика

**Запуск pve8to9 чек-лист скрипта**

```yaml
pve8to9 --full
```

Если у вас никаких проблем не выявлено, то переходим к обновлению

**Обновление APT репозиториев**

Сначала обновим текущую конфигурацию до самой последней версии пакетов на текущем релизе

```yaml
apt update
apt dist-upgrade
pveversion
```

**Обновление Debian Base Repositories до версии Trixie**

Обновляем списки для энтерпайзного и обычного репозитория

```yaml
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/pve-enterprise.list
```

**Добавление пакетных репозиториев Proxmox VE 9**

Сначала обновляем данные энтерпрайзного репозитория

```yaml
cat > /etc/apt/sources.list.d/pve-enterprise.sources << EOF
Types: deb
URIs: https://enterprise.proxmox.com/debian/pve
Suites: trixie
Components: pve-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

Теперь тоже самое, но для нормальных людей

```yaml
cat > /etc/apt/sources.list.d/proxmox.sources << EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

**Обновление Ceph Package репозитория**

Сначала обновляем энтерпрайзный репозиторий

```yaml
cat > /etc/apt/sources.list.d/ceph.sources << EOF
Types: deb
URIs: https://enterprise.proxmox.com/debian/ceph-squid
Suites: trixie
Components: enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

Теперь для простых смертных

```yaml
cat > /etc/apt/sources.list.d/ceph.sources << EOF
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

**Обновляем данные репозиториев**

```yaml
apt update
```

**Обновляем ядро Proxmox**

```yaml
apt dist-upgrade
```

## Вывод

Proxmox VE 9.0 — это важный шаг вперёд: новая стабильная база Debian 13, мощные возможности хранения (ZFS, LVM, Ceph), гибкие SDN–настройки, контроль HA-размещения и современный мобильный UI. Однако перед обновлением обратите внимание на требования к контейнерам, сетевой конфигурации и совместимости vGPU.

---
