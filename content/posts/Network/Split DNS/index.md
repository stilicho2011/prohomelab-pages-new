---
title: Раздельный DNS - гайд от LinuxServer.io
published: 2025-11-04
pinned: false
description: Разбираемся, зачем нужен split dns, как его организовать и как избежать проблем
tags:
  - OPNsense
  - pfSense
  - Pi-hole
  - AdGuard
slug: /split-dns
categories: Сетевые технологии
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Network
youtube_id: J3FmDKI67e0
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Split DNS — настройка доменных имён с разным разрешением для внутренней сети и интернета. Принципы работы, преимущества и примеры применения.
---

<iframe width="100%" height="468" src="https://www.youtube.com/embed/J3FmDKI67e0?si=fmnTQFFth9x53ae3" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

# Раздельный DNS - LinuxServer.io
## Что такое **Split DNS** кратко

Термин **Split DNS** обычно переводят на русский как **«разделённый DNS»** или **«разделённая система доменных имён»**.

Смысл концепции такой: один и тот же домен (например, `stilicho.ru`) разрешается по-разному в зависимости от того, с какой сети обращается клиент: внутренней (LAN) или внешней (Интернет).

Примеры перевода и использования:

*   **Split DNS** → **Разделённый DNS**
*   **Split-horizon DNS** → иногда тоже **Разделённый DNS** или **DNS с разделённым горизонтом**

## Что такое **Split DNS** более подробно

Ниже приведен перевод статьи с [https://docs.linuxserver.io/general/split-dns/](https://LinuxServer.io)

![Раздельный DNS](01-Projects/Prohomelab/Network/Split%20DNS/0.png)

Раздельный DNS позволяет давать разные ответы на DNS-запросы для внутренних и внешних пользователей, поэтому локальным запросам к вашему серверу не придется проходить через маршрутизатор. Это имеет несколько преимуществ:

*   Быстрее, так как не нужно проходить через маршрутизатор.
*   Обратный прокси-сервер может легко различать внутренние и внешние запросы, разрешая/запрещая их, поскольку NAT отсутствует.
*   При отсутствии интернета все продолжает работать.
*   Система продолжает работать, даже если DNS-сервер верхнего уровня (ваш интернет-провайдер/Google/OpenDNS и т. д.) недоступен.

## Требования[¶](https://docs.linuxserver.io/general/split-dns/#requirements)

*   Внутренний обратный прокси-сервер, **прослушивающий порт 80/443** .
*   Внутренний DNS-резолвер, поддерживающий перезапись или размещение полных DNS-зон.

## Популярные конфигурации DNS[¶](https://docs.linuxserver.io/general/split-dns/#popular-dns-configurations)

В этих примерах предполагается, что `domain.com` — ваш домен и `10.10.10.10`— ваш обратный прокси-сервер.

### OPNSense[¶](https://docs.linuxserver.io/general/split-dns/#opnsense)

Перейдите в раздел Services > Unbound DNS > Overrides > Host Overrides > Добавить:

*   Host: `*`
*   Domain: `domain.com`
*   Type: `A or AAAA`
*   IP: `10.10.10.10`

### PFSense[¶](https://docs.linuxserver.io/general/split-dns/#pfsense)

Перейдите в раздел Services > DNS Resolver > General Setting > Host Overrides > «Добавить».

*   Host: `*`
*   Domain: `domain.com`
*   IP Address: `10.10.10.10`

### **Pihole** и **DNS-Masq**[¶](https://docs.linuxserver.io/general/split-dns/#pihole-dnsmasq)

Включите `dnsmasq.d`на pihole (требуется только для версии 6 или выше. Ролик был снят на пятой версии) с помощью следующей команды:

```yaml
sudo pihole-FTL --config misc.etc_dnsmasq_d true

```

Создайте файл `/etc/dnsmasq.d/domain.conf`с таким содержимым:

```yaml
address=/domain.com/10.10.10.10

```

### **AdguardHome**[¶](https://docs.linuxserver.io/general/split-dns/#adguardhome)

Перейдите в Filters > DNS rewrites > Add DNS rewrite:

*   Domain name: `*.domain.com`
*   IP Address: `10.10.10.10`

## **Проблемы с Wireguard**[¶](https://docs.linuxserver.io/general/split-dns/#wireguard-issues)

При предоставлении доступа к серверу Wireguard поддомен Wireguard не должен быть разделен, в противном случае соединение будет разорвано при переключении между Wi-Fi и мобильными данными.

Например, вы можете исключить `wg.domain.com` в AdguardHome, создав еще одну перезапись DNS - с `wg.domain.com` на `wg.domain.com`, что исключит его из разделения.

## **NAT Reflection / NAT Loopback / Hairpin NAT**¶

NAT Reflection является альтернативным вариантом разделения DNS, который может предоставить некоторые, но не все,  преимущества разделения DNS. Оно позволяет устройствам локальной сети использовать внешний IP-адрес и получать переадресацию портов без NAT.

Обычно это настройка на определенных маршрутизаторах, которую можно включить с помощью соответствующего флага.

Обратите внимание, что использование прокси-сервера Cloudflare (это то самое оранжевое облако, которое сейчас блокируется РКН) позволит обойти его и по-прежнему отправлять трафик наружу.