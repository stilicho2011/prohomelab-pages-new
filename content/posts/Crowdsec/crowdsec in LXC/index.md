---
title: Установка и настройка CrowdSec в LXC-контейнере вместе с Traefik
published: 2025-08-18
pinned: false
description: Пошаговая инструкция по установке CrowdSec в LXC-контейнере на Proxmox. Централизованная защита Linux-серверов от атак и брутфорса.
tags:
  - CrowdSec
  - Security
  - Firewall
slug: /crowdsec-in-LXC
categories: Crowdsec
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Crowdsec
youtube_id: Gf458aOxtMI
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Подробная инструкция по установке и настройке CrowdSec внутри LXC-контейнера. Рассмотрены ключевые шаги от развертывания до интеграции с защитой сервера и мониторингом активности, чтобы быстро обеспечить безопасность виртуализированного окружения.
---

<iframe width="100%" height="468" src="https://www.youtube.com/embed/Gf458aOxtMI?si=HKddw7-pQc5Fevv8" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

**CrowdSec** — современное решение для кибербезопасности, способное защитить ваш сервер от атак, сканеров и брутфорсов. В этом руководстве рассмотрим установку CrowdSec в **LXC-контейнере** в среде **Proxmox VE**.

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на бусти (ссылка в разделе контакты).

Вы меня спросите, слушай, stilicho2011, ты же уже одну статью [написал](https://stilicho2011.ru/posts/crowdsec/). Все так, но, как говорится, есть нюанс. Статья, которую вы можете найти по ссылке, описывает ситуацию, когда мы все устанавливаем в докер.

Сейчас же поговорим ситуации, когда у нас наш обратный прокси установлен в LXC контейнер, о чем я рассказывал [тут](https://stilicho2011.ru/posts/traefik-in-lxc-part-1/) и [тут](https://stilicho2011.ru/posts/traefik-in-lxc-part-2/).

Но раз мы с вами начали заниматься такими странными вещами, то останавливаться на полпути было бы неправильно. Поэтому если мы с вами установили **Traefik** в LXC контейнер, то надо нам озаботиться и современной защитой, которую нам предоставляет **Crowdsec**.

Безусловно, общий принцип работы **Crowdsec** остается неизменным вне зависимости от варианта установки, поэтому, в целях сокращения текста, в данной статье я опишу ключевые вещи, которые касаются исключительно особенностей установки Crowdsec в LXC контейнер и его связки с обратным прокси Traefik 


## Что такое **CrowdSec**?

**CrowdSec** — это, как было указано выше, современная open-source система безопасности с принципами, схожими с «коллективным фаерволом» (crowdsourced firewall). Она анализирует логи, выявляет подозрительную активность (например, brute-force, сканирование портов, DDoS) и автоматически применяет решения для блокировки или ограничения доступа IP-адресов злоумышленников. 

Главная особенность CrowdSec — это **обмен данными о вредоносных IP-адресах между всеми пользователями системы**, с помощью которой создается коллективная база знаний, которая формируется на основе данных всех участников. Таким образом, если один сервер зафиксировал атаку, остальные участники могут заблокировать злоумышленника заранее.

Поскольку на сайте уже есть более чем подробная статья о функционале приложения, то на всех особенностях **Crowdsec** я, с вашего позволения, останавливаться не буду.

Но по законам жанра я обязан рассказать о ключевых архитектурных особенностях **Crowdsec**

---

## Архитектура CrowdSec

**CrowdSec** построен на модульной архитектуре и глобально разделён на два уровня:

1. **Agent (движок анализа)** — анализирует журналы логов (Nginx, Traefik, SSH, Postfix, системные логи и т.д.).

2. **Bouncers (модули блокировки)** — применяют решения о блокировке (ban, captcha, throttle) для защиты или разрешения доступа (например, iptables, Nginx middleware, Traefik bouncer).


Agent занимается только определением (выявлением) нехороших айпи, а блокировка выполняется с помощью bouncers.


Таким образом **CrowdSec** можно легко интегрировать в любую инфраструктуру, не вмешиваясь напрямую в сетевые правила.

---

У нас с вами уже есть установленный и настроенный обратный прокси **Traefik** в LXC контейнер. В этот же контейнер на базе ОС Debian мы с вами установим **Crowdsec**.  Еще раз повторюсь, - на сайте есть подробная статья о настройке Crowdsec в связке с Traefik в докере.

---

## Установка **Crowdsec** в Linux


Первое, что нам надо сделать, это установить в систему репозиторий **Crowdsec**. Это можно сделать руками, но это долго и муторно. Поэтому мы воспользуемся официальным скриптом, подготовленным разработчиками **Crowdsec**. Этот репозиторий содержит последнюю стабильную версию **Crowdsec**, и это рекомендованный разработчиком способ установки.


```bash
curl -s https://install.crowdsec.net | sudo sh
```

Проверим, что репозитории установились и система видит версии **Crowdsec**.

```yaml
apt list crowdsec
```

Установим **Crowdsec** неожиданной командой

```yaml
apt install crowdsec
```

На всякий случай повторюсь, что сам по себе так называемый security engine может только обнаруживать подозрительную/зловредную деятельность, но не банить айпи, которые служат источником такой деятельности.. Поэтому нам надо установить соответствующие bouncers. 

Есть один немаловажный момент. Если вы все устанавливаете в привилегированный LXC контейнер, то прежде чем настраивать нашу с вами связку и проверять ее работоспособность, нам сначала, недожидаясь перитонитов, нужно установить самостоятельный bouncer для iptables. Этот bouncer будет защищать непосредственно наш LXC контейнер от brute-force атак. Сделаем это командой

```yaml
apt install crowdsec-firewall-bouncer-iptables
```

Нужно делать, если у вас по каким-то необъяснимым причинам есть желание рисковать и устанавливать что-либо в привилегированный LXC контейнер. В противном случае, устанавливать bouncer для ip tables нет необходимости (но это не точно). 
И теперь давайте перейдем к окончательной настройке.

---

После того, как мы установили **Crowdsec** 

Проверяем статус crowdsec

```yaml
systemctl status crowdsec
```

Создаем белый список адресов, которые Crowdsec не должен проверять. Как правило это частные сети, но, в случае, если у вас есть потребность в более тонкой настройке, то можно точечно вносить доверенные ip адреса.

Создаем список командой

```yaml
nano /etc/crowdsec/parsers/s02-enrich/01-my-whitelist.yaml
```

и вносим туда соответствующие значения

```yaml
name: crowdsecurity/my-whitelists
description: "Whitelist events from my ipv4 addresses"
#it's a normal parser, so we can restrict its scope with filter
filter: "1 == 1"
whitelist:
  reason: "my ipv4 ranges"
  ip: 
    - "127.0.0.1"
  cidr:
    - "192.168.0.0/16"
    - "10.0.0.0/8"
    - "172.16.0.0/12"
```

Таким образом все запросы, которые приходят с частных айпи адресов не будут проверяться **crowdsec**. Это снимает лишнюю нагрузку с приложения, и исключает варианты, когда crowdsec забанит наши частные айпи из-за того, что частые запросы могут рассматриваться как brute-force атака.

Чтобы изменения были применены перезагрузим сервис

```bash
systemctl restart crowdsec
```

---

Следующим этапом надо подключиться к консоли **Crowdsec** у них на сайте.

Это простая процедура, там все логически понятно.

[Пошаговый гайд у Crowdsec на сайте](https://docs.crowdsec.net/u/getting_started/post_installation/console)

Это нужно для того, чтобы мы могли подключиться к глобальной сети обмена вредоносных айпи. Один из неоспоримых плюсов **Crowdsec**.  

Да, разработчики будут получать информацию о том, подверглись ли вы атаке. Но это не самая конфиденциальная информация из всех, и с учетом принципов работы **Crowdsec**, я думаю подключение к консоли стоит того.

Все сделали по инструкции: зарегистрировались; выбрали ОС на которой работаете (в нашем случае Linux); получили enrollment key и команду, которую нужно будет ввести в командной строке нашего контейнера; перезагрузили сервис; вернулись на сайт **Crowdsec** и можем увидеть, что мы можем выбрать 3 бесплатных блоклиста.

Самое интересное, это конечно информация о crowdsec hub и список коллекций в зависимости от сервиса, который мы хотим защитить.

Давайте проверим какие коллекции у нас сейчас присутствуют в системе, и проверим значения в acquis.yaml файле, чтобы понять готова ли наша инстанция crowdsec к парсингу логов

Проверка списка коллекций

```yaml
cscli collections list
```

Проверка списка логов, которые парсит **Crowdsec**

```yaml
cscli metrics show acquisition
```

Абсолютно точно там нет коллекций, которые нам нужны. Вот давайте их и установим 

В этом гайде будем использовать следующие коллекции:

[crowdsecurity/traefik](https://app.crowdsec.net/hub/author/crowdsecurity/collections/traefik) traefik support: parser and generic http scenarios

[crowdsecurity/http-cve](https://app.crowdsec.net/hub/author/crowdsecurity/collections/http-cve)  Detect CVE exploitation in http logs

[crowdsecurity/base-http-scenarios](https://app.crowdsec.net/hub/author/crowdsecurity/collections/base-http-scenarios) http common : scanners detection

[crowdsecurity/sshd](https://app.crowdsec.net/hub/author/crowdsecurity/collections/sshd) support : parser and brute-force detection

[crowdsecurity/linux](https://app.crowdsec.net/hub/author/crowdsecurity/collections/linux) core linux support : syslog+geoip+ssh

[crowdsecurity/appsec-generic-rules](https://app.crowdsec.net/hub/author/crowdsecurity/collections/appsec-generic-rules) A collection of generic attack vectors for additional protection 

[crowdsecurity/appsec-virtual-patching](https://app.crowdsec.net/hub/author/crowdsecurity/collections/appsec-virtual-patching) a generic virtual patching collection, suitable for most web servers. 

[crowdsecurity/appsec-crs](https://app.crowdsec.net/hub/author/crowdsecurity/collections/appsec-crs) Appsec: Modsecurity core rule set rules


Установим коллекции командой

```yaml
cscli collections install crowdsecurity/traefik crowdsecurity/http-cve crowdsecurity/base-http-scenarios crowdsecurity/sshd crowdsecurity/linux crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-crs
```
Теперь мы должны подсказать **Crowdsec** как и где парсить локальные логи нашей Линукс машины и логи обратного прокси **Traefik**. Для этого мы должны отредактировать конфигурационный файл **acquis.yaml** по соответствующему пути `sudo nano /etc/crowdsec/acquis.yaml`. Также мы указываем порт по которому у нас будет работать WAF.

Создаем примерный файл следующего вида:

```yaml
filenames:
    - /var/log/traefik/*.log
labels:
    type: traefik
---
filenames:
    - /var/log/syslog
    - /var/log/auth.log
labels:
    type: syslog
---
listen_addr: 0.0.0.0:7422
appsec_config: crowdsecurity/appsec-default
name: myAppSecComponent
source: appsec
labels:
    type: appsec
#
#filenames:
# - /var/log/authentik.log
#labels:
#  type: authentik
#---
#filenames:
# - /var/www/nextcloud/data/nextcloud.log
#labels:
#  type: Nextcloud
```

Ради чистоты эксперимента перезагружаем сервис

```yaml
systemctl restart crowdsec
```

Проверка списка логов, которые парсит **Crowdsec**

```yaml
cscli metrics show acquisition
```

Устанавливаем bouncer для нашего обратного прокси **Traefik**

Если вы следовали моей инструкции по установке Traefik в LXC контейнер, то соответствующий bouncer в виде плагина у вас уже прописан в статической конфигурации обратного прокси, скачан и установлен. Просто он пока еще не знает, что ему делать.

Сначала мы получим соответствущий api ключ, чтобы bouncer мог общаться c Crowdsec

Сделаем это командой 

```yaml
cscli bouncers add traefik-bouncer
```

Скопируем полученное значение в блокнот. Значения ключа мы увидим только один раз, не забывайте об этом.

Теперь переходим в динамическую конфигурацию нашего обратного обратного прокси по адресу

```yaml
nano /etc/traefik/dynamic/config.yaml
```

Если вы следовали моей статье о настройке **Traefik** в LXC контейнер, то у вас файл динамической конфигурации имеет примерно следующий вид.

```yaml
http:
# https://doc.traefik.io/traefik/routing/routers/
  routers:
   # harden dashboard access: can only be accessed with a username/password
    dashboard:
      entryPoints:
        - websecure 
      rule: "Host(`traefik-dashboard.domain.ru`)"
      service: api@internal
      middlewares:
        - auth
      tls:
        certResolver: cloudflare  

    radarr:
      entryPoints:
        - "websecure"
      rule: "Host(`radarr.domain.ru`)"        
      middlewares:
        - default-headers
        - https-redirect
      tls:
        certResolver: cloudflare
      service: radarr

# https://doc.traefik.io/traefik/routing/services/
  services: 
    radarr:
      loadBalancer:
        servers:
          - url: "http://192.168.x.x:7878" # Change IP Address to your radarr instance
        passHostHeader: true

# https://doc.traefik.io/traefik/middlewares/http/overview/
  middlewares:
# Middleware for Redirection
# This can be used instead of global redirection
#
    auth:
      basicAuth:
        users:    # users and their MD5 hashed passwords, granted access to the traefik dashboard 
          - "admin:hashedpassword" # openssl passwd -1 "hashedpassword"
#
    https-redirect:
      redirectScheme:
        scheme: https
        permanent: true
#
    default-headers:
      headers:
        frameDeny: true
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 15552000
        customFrameOptionsValue: SAMEORIGIN
        customRequestHeaders:
          X-Forwarded-Proto: https
#
    crowdsec:
      plugin:
        bouncer:
          enabled: true
          logLevel: INFO
          updateIntervalSeconds: 15
          updateMaxFailure: 0
          defaultDecisionSeconds: 15
          httpTimeoutSeconds: 10
          crowdsecMode: stream
          crowdsecAppsecEnabled: true
          crowdsecAppsecHost: localhost:7422
          crowdsecAppsecFailureBlock: true
          crowdsecAppsecUnreachableBlock: true
          crowdsecLapiKey: yourlapikey # Replace CrowdSec API key (docker exec crowdsec cscli bouncers add crowdsecBouncer)
          crowdsecLapiHost: localhost:8080
          crowdsecLapiScheme: http
          forwardedHeadersTrustedIPs:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16                                                        
          clientTrustedIPs:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16

# https://doc.traefik.io/traefik/https/tls/
tls:
 options:
   default:
     minVersion: VersionTLS12    # change to a lower version if you expect to service Internet traffic from around the world
     curvePreferences:   # below priority sequence can be changed
       - X25519     # the most commonly used 128-bit
       - CurveP256  # the next most commonly used 128-bit
       - CurveP384  # 192-bit
       - CurveP521  # 256-bit
     sniStrict: true     # true if our own certificates should be enforced
     cipherSuites:
       - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
       - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
       - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
       - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
       - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
#  certificates:
#    - certFile: /etc/traefik/domain.cert
#      keyFile: /etc/traefik/domain.key
#    - certFile: /etc/traefik/certificate.pem
#      keyFile: /etc/traefik/private_key.pem
#### Traefik uses its own default certificate for connections without SNI, or without a matching domain.
#### However, we can provide our own default certificate, instead of using the Traefik default.
#  stores:
#    default:
#      defaultCertificate:
#        certFile: /etc/traefik/cert.crt
#        keyFile: /etc/traefik/cert.key
#### Alternatively, we can use an ACME generated default certificate.
stores:
  default:
    defaultGeneratedCert:
      resolver: cloudflare
      domain:
        main: domain.ru
        sans:
          - "*.domain.ru"
```


Как вы видите, мы с вами задали определенные параметры в middleware. При этом, как я указывал выше, вариантов настроек намного, намного больше. Подробнее об этом можно узнать в [официальной документации](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin).


Обязательно внесите в соответствующее поле значения вашего api key, который мы создали ранее.

Также обратите внимание, что мы задали значение `forwardedHeadersTrustedIPs` и `clientTrustedIPs`. Тем самым мы определяем подсети IPv4 частного класса как доверенные IP-адреса.

Это необходимо, поскольку мы хотим доверять HTTP-заголовкам нашего обратного прокси-сервера **Traefik**, таким как **X-Forwarded-For** и **X-Real-IP**. Эти заголовки обычно определяют реальные IP-адреса посетителей нашего сайта, ну и злоумышленников конечно, которые CrowdSec использует для принятия решений и блокировки.

Вы можете сделать более тонкую настройку и добавить точный IP-адрес Traefik в диапазоне /32. Однако добавление всех диапазонов частных классов в белый список — более удобный подход. Особенно это касается динамических IP-адресов подсетей Docker, которые могут меняться при перезагрузке контейнера. 

С помощью переменной clientTrustedIPs мы указываем доверенные IP-адреса или диапазоны IP-адресов, которые мы считаем заслуживающими доверия. Эти IP-адреса или диапазоны сетей не будут заблокированы или запрещены CrowdSec. По сути, это вариант с использованием белого списка, который мы уже создали. В определенной степени у нас тут дублирование задач, но я обязан показать все опции.

В моём случае я доверяю локальной сети LAN, что отражается в добавлении всех диапазонов частных классов в белый список. Вы можете ограничить их диапазоном вашей текущей подсети LAN (CIDR) в случае необходимости.

Так как это динамические настройки **Traefik**, то нет нужды его перезагружать. Он их подхватит автоматом.

---

Теперь, мы можем защищить с помощью **Crowdsec** наши сервисы выборочно, указывая соответствующую middleware `- crowdsec@file` в разделе routers нашего обратного прокси, но можно это сделать на глобальном уровне. То есть все входящие запросы на наш обратный прокси будут обработаны Crowdsec. Мне кажется это будет более правильно. 

Например, файл статической конфигурации **Traefik** может иметь следующий вид

```yaml
# Traefik entrypoints (network ports) configuration
entryPoints:
  web:
    address: :80
    forwardedHeaders:
      trustedIPs: &trustedIps
        # Start of Cloudlare's public IP list
        - 103.21.244.0/22
        - 103.22.200.0/22
        - 103.31.4.0/22
        - 104.16.0.0/13
        - 104.24.0.0/14
        - 108.162.192.0/18
        - 131.0.72.0/22
        - 141.101.64.0/18
        - 162.158.0.0/15
        - 172.64.0.0/13
        - 173.245.48.0/20
        - 188.114.96.0/20
        - 190.93.240.0/20
        - 197.234.240.0/22
        - 198.41.128.0/17
        - 2400:cb00::/32
        - 2606:4700::/32
        - 2803:f800::/32
        - 2405:b500::/32
        - 2405:8100::/32
        - 2a06:98c0::/29
        - 2c0f:f248::/32
        # End of Cloudlare public IP list
    http:
      redirections:
        entryPoint:
          to: web
          scheme: https

  # HTTPS endpoint, with domain wildcard
  websecure:
    address: :443
    forwardedHeaders:
      # Reuse the list of Cloudflare's public IPs from above
      trustedIPs: *trustedIps
    http:
      middlewares:
        - crowdsec@file # reference to a dynamic middleware for enabling crowdsec bouncer
```

Более подробно вы можете прочитать об этом в статье, которая посвящена настройке Crowdsec в докере, так как я хочу избежать дублирования информации, которая уже есть на сайте.

Теперь остался вопрос проверки работоспособности нашей схемы.

Команда покажет нам метрики нашего Crowdsec. Главное, чтобы Crowdsec парсил логи обратного прокси. В случае если это не так, то перезапустите **Traefik** и проверьте еще раз

```bash
cscli metrics
```

Давайте теперь забаним наш адрес из частной сети

```yaml
cscli decisions add --ip 192.168.x.x
```

Проверим внесли ли нас в бан-лист

```bash
cscli decisions list
```

В списке должен быть указан наш айпи, который мы руками внесли в бан. 

Обратите внимание, что фактически он может быть не забанен, потому что этот айпи у нас еще и в whitelists.

Теперь разбаним его не дожидаясь 4 часов

```bash
cscli decisions delete --ip 192.168.x.x
```

Проверим результат

```bash
cscli decisions list
```

Нашего айпи в списке забаненных быть не должно.

Все - Crowdsec настроен. Но в любом случае я рекомендую почитать статью у меня на сайте про Corwdsec в докере, где более подробно описаны некоторые команды. Как я уже написал выше, в целях избегания дублежа информации я не хочу копировать одно и тоже из статьи в статью.
