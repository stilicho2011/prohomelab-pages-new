---
title: Установка SSL-сертификатов в Proxmox с помощью встроенного ACME
published: 2025-07-14
pinned: false
description: Пошаговое руководство по настройке SSL-сертификатов Let's Encrypt через встроенную систему ACME в Proxmox VE.
tags:
  - Proxmox
  - Автоматизация
slug: /ssl-termination-in-Proxmox
categories: Proxmox
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Proxmox
youtube_id: ysFRT9dIHo0
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.jpg
summary: Подробная инструкция по настройке SSL в Proxmox для безопасного доступа к веб-интерфейсу и API. Рассмотрены генерация и установка сертификатов, настройка HTTPS и рекомендации по поддержанию безопасности кластера.
---

<iframe width="100%" height="468" src="https://www.youtube.com/embed/ysFRT9dIHo0?si=kMrO0MNONVQAFVAB" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

Proxmox VE имеет встроенную поддержку **ACME-клиента**, что позволяет автоматически получать и обновлять SSL-сертификаты от [Let's Encrypt](https://letsencrypt.org/). Это значительно упрощает защиту веб-интерфейса и API Proxmox.

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на бусти (ссылка в разделе контакты).

## 📋 Требования

- **Публичный домен**, привязанный к IP-адресу сервера с Proxmox.
- **Доступ к DNS-записям** (DNS challenge).
- **Proxmox VE** версии **6.2 и выше**.

## 🔐 Почему стоит использовать ACME

- Автоматическое обновление сертификатов.
- Бесплатно.
- Устраняет предупреждения браузера о небезопасном соединении.
- Увеличивает безопасность доступа к веб-интерфейсу Proxmox.

---

> [!NOTE]
>Достаточно иметь публичный домен, размещенный на доступных dns серверах. Не нужно никаких белых ip. Нам просто нужен сертификат для локального разрешения доменных имен

## Введение

Proxmox VE с версии 6.3 включает встроенную поддержку **ACME** — автоматического получения SSL-сертификатов от Let's Encrypt. Одним из надёжных и универсальных способов верификации домена является **DNS Challenge**, особенно если вы не хотите или не можете открывать порты 80/443 в интернет.

В этой статье мы пошагово рассмотрим настройку ACME-клиента в Proxmox для получения SSL-сертификата с использованием **DNS API-провайдера**.

---

## Требования

- **Публичный домен**, привязанный к IP-адресу сервера с Proxmox.
- **Доступ к DNS-записям** (DNS challenge).
- **Proxmox VE** версии **6.3 и выше**.
- **DNS-провайдер**, поддерживающий API (например, Cloudflare, DuckDNS, DigitalOcean и др.)
- Доступ к **Proxmox** по SSH или через веб-интерфейс

---

## Шаг 1: Включение ACME в Proxmox

### Создание аккаунта

Откройте веб-интерфейс Proxmox и перейдите в **Datacenter** → **ACME** - **Accounts**

В разделе **Accounts** создайте аккаут, заполнив все необходмые поля.

### Регистрация плагина

В разделе **Datacenter** → **ACME** → **DNS Plugin** нажмите Add и выберите нужный DNS-хостинг, например Cloudflare.
В ниспадающем меню внести необходимые данные, которые вы получили от своего dns хостера

## Шаг 2: Выпуск сертификата

Перейдите в:

**Datacenter** → **node_name** → **System** → **Certificates**

Нажмите **ACME** → **Add**

Параметры:

**Domains**: proxmox.example.com

**ACME Account**: имя вашего аккаунта, который вы создали в шаге 1
**Plugin**: имя, которое вы присвоили вашему плагину
Нажмите **Create**

Proxmox автоматически запустит верификацию и, при успешном завершении процесса, установит сертификат.

## Заключение

Использование DNS Challenge для выпуска SSL-сертификата — безопасный и гибкий способ защитить интерфейс Proxmox, особенно если он не доступен извне. Интеграция ACME в Proxmox делает этот процесс простым и полностью автоматическим.

Если вы используете публичные DNS-провайдеры с поддержкой API, настройка займёт не более 5 минут.

## Полезные ссылки

- [Документация Proxmox ACME](https://pve.proxmox.com/wiki/Certificate_Management)
- [Список поддерживаемых DNS-плагинов](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)
- [Let's Encrypt](https://letsencrypt.org/)
