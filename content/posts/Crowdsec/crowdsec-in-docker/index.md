---
title: "Принципы работы CrowdSec: коллективная защита серверов"
published: 2025-07-27
pinned: false
description: Разбираем архитектуру и принципы работы CrowdSec — современного решения для анализа логов и защиты серверов от атак.
tags:
  - CrowdSec
  - Security
  - Firewall
slug: /crowdsec-in-docker
categories: Crowdsec
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Crowdsec
youtube_id: Eq5IJo1yd_I
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Подробная инструкция по установке и настройке CrowdSec в Docker-контейнере. Рассмотрены шаги от развертывания до интеграции с защитой сервера и мониторингом активности, чтобы быстро обезопасить ваш хостинг и сервисы.
---

<iframe width="100%" height="468" src="https://www.youtube.com/embed/Eq5IJo1yd_I?si=QGKlvbrHTGoqDdO6" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

## Что такое CrowdSec?

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на бусти (ссылка в разделе контакты).

**CrowdSec** — это современная open-source система безопасности с принципами, схожими с «коллективным фаерволом» (crowdsourced firewall). Она анализирует логи, выявляет подозрительную активность (например, brute-force, сканирование портов, DDoS) и автоматически применяет решения для блокировки или ограничения доступа IP-адресов злоумышленников. 

Главная особенность CrowdSec — это **обмен данными о вредоносных IP-адресах между всеми пользователями системы**, с помощью которой создается коллективная база знаний, которая формируется на основе данных всех участников. Таким образом, если один сервер зафиксировал атаку, остальные участники могут заблокировать злоумышленника заранее.

---

## Архитектура CrowdSec

CrowdSec построен на модульной архитектуре и глобально разделён на два уровня:

1. **Agent (движок анализа)** — анализирует журналы логов (Nginx, Traefik, SSH, Postfix, системные логи и т.д.).
2. **Bouncers (модули блокировки)** — применяют решения о блокировке (ban, captcha, throttle) для защиты или разрешения доступа (например, iptables, Nginx middleware, Traefik bouncer).

Agent занимается только определением (выявлением) нехороших айпи, а блокировка выполняется bouncers.

Таким образом, CrowdSec можно легко интегрировать в любую инфраструктуру, не вмешиваясь напрямую в сетевые правила.

---

## Как работает CrowdSec?

Давайте теперь рассмотрим работу Crowdsec более детально.

### 1. Сбор и анализ логов

CrowdSec подключается к логам сервисов (SSH, Nginx, Traefik, Postfix, системные журналы).  
Для анализа используются **парсеры**, которые приводят логи к единому формату.

### 2. Применение сценариев

CrowdSec использует **scenarios** — наборы правил, описанных в YAML.  
Например, сценарий `ssh-bf` определяет, что 5 неудачных попыток входа за 1 минуту считаются атакой.

### 3. Создание решений (Decisions)

Если сценарий срабатывает, агент генерирует **решение** (decision), например:
- `ban` — заблокировать IP.
- `captcha` — требовать проверку.
- `throttle` — ограничить скорость запросов.

### 4. Передача решения на Bouncer

Bouncers — это отдельные компоненты, которые реализуют блокировку.  
Примеры:
- `iptables`-bouncer добавляет IP в firewall.
- `traefik-bouncer` подключается к Traefik как middleware.
- `nginx-bouncer` использует ACL в Nginx.

### 5. Коллективная защита (Crowd Threat Intelligence)

Агент может отправлять анонимизированные данные о злоумышленниках на центральный сервер CrowdSec.  
В ответ сервер присылает **глобальный список IP-адресов с плохой репутацией**, повышая защиту для всех пользователей.

---

## Преимущества CrowdSec
- **Коллективная база угроз** — защита в реальном времени от IP-адресов, известных в сообществе.
- **Гибкость** — поддержка десятков интеграций (Docker, Kubernetes, Traefik, Nginx).
- **Простота** — готовые сценарии для популярных сервисов.
- **Совместимость с DevOps** — легко встраивается в CI/CD, работает в контейнерах.

---

# Почему CrowdSec лучше Fail2Ban

### 1. Современная архитектура

- **Fail2Ban** — классическое решение, написанное на Python, работает на уровне анализа логов и блокирует IP через firewall.  
- **CrowdSec** — современный инструмент, основанный на микросервисной архитектуре и написанный на Go, что делает его более производительным и масштабируемым.

### 2. Коллективная защита (crowdsourcing)

- **Fail2Ban** блокирует только те IP, которые атакуют конкретный сервер.  
- **CrowdSec** делится данными о вредоносных IP с глобальной сетью пользователей, формируя **динамическую репутационную базу**. Ваш сервер защищён не только от атак, которые уже произошли, но и от IP, замеченных в атаках на другие серверы.

### 3. Поддержка множества источников данных

- **Fail2Ban** в основном анализирует системные логи.  
- **CrowdSec** поддерживает:
  - логи различных сервисов (Nginx, SSH, Postfix и др.);
  - сетевые потоки (Netfilter, nftables);
  - интеграции с облачными сервисами и API.

### 4. Гибкая система сценариев (Scenarios)

- **CrowdSec** использует **YAML-сценарии**, которые описывают сигнатуры атак (brute force, порт-сканирование и т.д.).  
- Добавить новые сценарии можно **в 1 клик** из официального хаба, без ручного написания фильтров.

### 5. Производительность

- **Fail2Ban** плохо масштабируется при большом количестве логов, особенно на загруженных серверах.  
- **CrowdSec** написан на Go и обрабатывает логи асинхронно, что делает его **значительно быстрее** и менее ресурсоёмким.

### 6. Модульная структура

- **CrowdSec** разделяет **движок анализа (agent)** и **механизмы блокировки (bouncers)**.  
- Можно гибко настраивать, куда отправлять блокировки: iptables, nginx, Cloudflare, HAProxy и т.д.

### 7. Удобные инструменты визуализации

- **CrowdSec** предоставляет **консольный CLI** с понятной статистикой, есть возможность интеграции с **Metabase для графиков и аналитики** Также есть понятная графическая консоль для анализа происходящего на сервера (требуется регистрация на сайте разработчика).  
- **Fail2Ban** ограничивается логами и простыми командами.

### 8. Простота управления и обновлений

- **CrowdSec** имеет централизованный репозиторий сценариев и автоматические обновления.  
- В **Fail2Ban** часто нужно самостоятельно обновлять фильтры и regex для новых атак.

---

**Вывод:**  

**CrowdSec** — это не просто современный аналог Fail2Ban, а **следующее поколение систем защиты**, которое сочетает в себе коллективный опыт, высокую производительность и гибкость.
Использование **CrowdSec** — как более современное решение для серверной безопасности, которое сочетает локальный анализ логов с коллективной базой знаний, вместе с обратным прокси (например, **Traefik**) позволяет создать **динамическую и умную защиту** для любых веб-приложений.

---

## Возможности обнаружения атаки

Давайте более подробно поговорим о принципах обнаружения атак.
**CrowdSec** использует трехуровневый подход к обнаружению для защиты систем от известных и новых угроз:

### 1. Локальное принятие решений.

- Возможности локального принятия решений **CrowdSec** позволяют обнаруживать атаки и реагировать на них в режиме реального времени по мере их возникновения. Когда подозрительная активность, например, подбор пароля или принудительное HTTP-зондирование, соответствует одному из предопределенных сценариев обнаружения CrowdSec, система запускает локальное решение. Это действие, например, блокировка или ограничение IP-адреса, напрямую устраняет атаки, обнаруженные в системе. Локальные решения гарантируют немедленную блокировку любых новых или ранее неизвестных злоумышленников до того, как они смогут усилить свою активность. Обычно это делается путем анализа файлов журналов. Наконец, метаданные решения, такие как IP-адрес злоумышленника, передаются сообществу CrowdSec через систему анализа киберугроз (CTI) CrowdSec.

### 2. Удалённое принятие решений.

- Функция удалённого принятия решений поддерживается глобальным сообществом CrowdSec и CTI. Когда любой экземпляр CrowdSec по всему миру обнаруживает злоумышленника, эта информация передается в базу данных CrowdSec Cyber Threat Intelligence (CTI) . Такие известные вредоносные IP-адреса затем помечаются для превентивной блокировки во всех других защищённых системах CrowdSec посредством удалённого принятия решений. Этот проактивный уровень позволяет CrowdSec блокировать входящие угрозы на основе коллективных знаний, останавливая известных злоумышленников ещё до того, как они получат доступ к вашим сервисам. Это реализуется с помощью баунсера CrowdSec (например, для обратного прокси-сервера Traefik).

### 3. AppSec (WAF). 

- CrowdSec можно настроить в качестве промежуточного ПО (middlewares) в качестве WAF. В этом случае каждый HTTP-запрос ретранслируется на конечную точку AppSec CrowdSec по протоколу TCP/7422, которая анализирует запрос на наличие вредоносных шаблонов. Эти шаблоны могут представлять собой полезную нагрузку для эксплуатации SQL-инъекций, XSS-уязвимостей или командных инъекций. При желании можно использовать известный набор правил OWASP (CRS), который наиболее известен по открытому WAF ModSecurity и используется многими другими поставщиками WAF. Настройка WAF требует времени и часто требует особой настройки для каждого проксируемого приложения.

Как указано выше, для принятия решений на локальном уровне **CrowdSec** поддерживает различные **Сценарии**. Они обычно поставляются в так называемых **Коллекциях**. 

Следуя настоящему гайду (простите за высокопарный слог), вы сможете реализовать более 100 сценариев локального принятия решений. Ваши HTTP-сервисы, работающие за **Traefik**, будут защищены от достаточного большого количества угроз.

---

В этом гайде будем использовать следующие коллекции:

[crowdsecurity/traefik](https://app.crowdsec.net/hub/author/crowdsecurity/collections/traefik) traefik support: parser and generic http scenarios
[crowdsecurity/http-cve](https://app.crowdsec.net/hub/author/crowdsecurity/collections/http-cve)  Detect CVE exploitation in http logs
[crowdsecurity/base-http-scenarios](https://app.crowdsec.net/hub/author/crowdsecurity/collections/base-http-scenarios) http common : scanners detection
[crowdsecurity/sshd](https://app.crowdsec.net/hub/author/crowdsecurity/collections/sshd) support : parser and brute-force detection
[crowdsecurity/linux](https://app.crowdsec.net/hub/author/crowdsecurity/collections/linux) core linux support : syslog+geoip+ssh
[crowdsecurity/appsec-generic-rules](https://app.crowdsec.net/hub/author/crowdsecurity/collections/appsec-generic-rules) A collection of generic attack vectors for additional protection 
[crowdsecurity/appsec-virtual-patching](https://app.crowdsec.net/hub/author/crowdsecurity/collections/appsec-virtual-patching) a generic virtual patching collection, suitable for most web servers. 
[crowdsecurity/appsec-crs](https://app.crowdsec.net/hub/author/crowdsecurity/collections/appsec-crs) Appsec: Modsecurity core rule set rules

---

## Запуск **Crowdsec**

**Crowdsec** может быть установлен и запущен как нативно на базе разных ОС, так и как контейнер в Docker. В этой статье будем говорить о запуске контейнера в Docker, но в будущем рассмотрим возможность запуска Crowdsec нативно вместе с нативной инсталляцией Traefik.

### Docker Compose файл

Сначала давайте составим docker-compose.yml файл, в котором опишем основные параметры Crowdsec

```yaml
services:
    crowdsec: # Название сервиса
        image: crowdsecurity/crowdsec:latest # указываем, что нам нужен последний образ 
        container_name: crowdsec # имя контейнера
        environment: # переменные окружения
            GID: "${GID-1000}" # права юзера:группы
            COLLECTIONS: "crowdsecurity/traefik crowdsecurity/http-cve crowdsecurity/base-http-scenarios crowdsecurity/sshd crowdsecurity/linux crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-crs" # наименование коллекций, которые будут загружены 
            TZ: Europe/Moscow # часовой пояс. Очень важная настройка, чтобы время событий отображалось правильно
        volumes: # тома для корректной работы Crowdsec
            - /home/path/to/crowdsec/acquis.yaml:/etc/crowdsec/acquis.yaml # Прописываем путь для файл acqius.yaml
            - /home/path/to/crowdsec/db:/var/lib/crowdsec/data/ # путь до базы данных crowdsec
            - /home/path/to/crowdsec/config:/etc/crowdsec/ # путь до конфига crowdsec 
            - /home/path/to/traefik/logs:/var/log/traefik/:ro # прописываем пути до логов, которые должен парсить crowdsec. Обратите внимание, что права только на чтение 
            - /var/log/auth.log:/var/log/auth.log:ro # 
            - /var/log/syslog:/var/log/syslog:ro #
        ports:
            - 127.0.0.1:9876:8080 # смапим порт для локальных firewall баунсеров #
        expose: # открываем порты под соответствующие задачи
            - 8080 # http api for bouncers 
            - 6060 # metrics endpoint for prometheus
            - 7422 # appsec waf endpoint
        networks: # указываем сеть в которой у нас работает одновременно и обратный прокси traefik, и crowdsec
            - proxy #
        security_opt: # задаем ограничения по правам
            - no-new-privileges:true #
        restart: unless-stopped # указываем, что в случае падения контейнера, он всегда будет пытаться перезапуститься

networks: # указываем что соответствующая сеть у нас внешняя и ее не надо создавать
    proxy: #
        external: true #
```

### Создаем конфигурацию для парсинга логов

Теперь мы должны подсказать **Crowdsec** как и где парсить локальные логи нашей Линукс машины и логи обратного прокси **Traefik**. Для этого мы должны создать конфигурационный файл **acquis.yaml** по пути, который мы указали раннее в **docker-compose.yml** Crowdsec. Также мы указываем порт, по которому у нас будет работать WAF.

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
--- 

### Создание API Token для нашего Bouncer

Так как надо будет в дальнейшем связать наш обратный прокси **Traefik**, то нам надо получить соответствующий токен, с помощью которого мы разрешаем доступ **Traefik** к Bouncer.

Создаем токен простой командой в командной строке

```bash
docker exec crowdsec cscli bouncers add traefik-bouncer
```

Обязательно скопируйте полученный токен в какое-то надежное место, потому что он выводится на экран один раз, и в случае утери токена вам придется все делать с нуля.
Это токен мы потом укажем в соответствующем разделе middlewares в динамической конфигурации **Traefik**.

---

### Настройка уведомлений

В этой статье я не буду рассказывать как создать свою web панель на сайте разработчика.
[Документация простая и интуитивно понятная](https://app.crowdsec.net/). Регистрируетесь на сайте и следуете инструкциям в зависимости от вашей операционной системы. Ошибиться практически невозможно, кроме как в случае, когда Вы специально хотите ошибиться.

Но я расскажу как моментально получать уведомления о событиях в Crowdsec, что на мой взгляд намного важнее, чем иметь визуальный контроль над статистикой.

Я покажу настройку уведомлений в телеграмме, но вы можете использовать любой сервис для получения уведомлений: e-mail, Gotify, Telegramm и так далее.

Полный список можно посмотреть [тут](https://docs.crowdsec.net/docs/notification_plugins/intro)

В принципе вам просто надо настроить два файла:

Сначала вам нужно расскомментировать две строки `http_default` в файле **profiles.yaml**, которая находится по пути `/path/to/crowdsec/config/profiles.yaml`

Выглядит это все примерно так:

```yaml
name: default_ip_remediation
#debug: true
filters:
 - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
 - type: ban
   duration: 4h
#duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)
notifications:
#   - slack_default  # Set the webhook in /etc/crowdsec/notifications/slack.yaml before enabling this.
#   - splunk_default # Set the splunk url and token in /etc/crowdsec/notifications/splunk.yaml before enabling this.
 - http_default   # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
#   - email_default  # Set the required email parameters in /etc/crowdsec/notifications/email.yaml before enabling this.
on_success: break
---
name: default_range_remediation
#debug: true
filters:
 - Alert.Remediation == true && Alert.GetScope() == "Range"
decisions:
 - type: ban
   duration: 4h
#duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)
notifications:
#   - slack_default  # Set the webhook in /etc/crowdsec/notifications/slack.yaml before enabling this.
#   - splunk_default # Set the splunk url and token in /etc/crowdsec/notifications/splunk.yaml before enabling this.
 - http_default   # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
#   - email_default  # Set the required email parameters in /etc/crowdsec/notifications/email.yaml before enabling this.
on_success: break
```

Если вы хотите получать уведомления по почте или указанными мессенджерами, то раскомментуруйте соответствующие строки.

После этого необходимо отредактировать файл `notifications/http.yaml`, который находится по пути `/path/to/crowdsec/config/notifications`

В случае с телеграммом файл выглядит так:

```yaml
type: http          # Don't change
name: http_default  # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: info

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the http request body

# Replace XXXXXXXXX with your Telegram chat ID
format: |
  {
   "chat_id": "-XXXXXXXXX", 
   "text": "
     {{range . -}}  
     {{$alert := . -}}  
     {{range .Decisions -}}
     {{.Value}} will get {{.Type}} for next {{.Duration}} for triggering {{.Scenario}}.
     {{end -}}
     {{end -}}
   ",
   "reply_markup": {
      "inline_keyboard": [
          {{ $arrLength := len . -}}
          {{ range $i, $value := . -}}
          {{ $V := $value.Source.Value -}}
          [
              {
                  "text": "See {{ $V }} on shodan.io",
                  "url": "https://www.shodan.io/host/{{ $V -}}"
              },
              {
                  "text": "See {{ $V }} on crowdsec.net",
                  "url": "https://app.crowdsec.net/cti/{{ $V -}}"
              }
          ]{{if lt $i ( sub $arrLength 1) }},{{end }}
      {{end -}}
      ]
  }

url: https://api.telegram.org/botXXX:YYY/sendMessage # Replace XXX:YYY with your API key

method: POST
headers:
  Content-Type: "application/json"
```

Все что вам нужно заменить xxxxxx на свои значения соответственно.

Ддя того, чтобы настройки вступили в силу, **crowdsec** необходимо перезапустить с помощью команды `docker compose up -d --force-recreate`.

Можете потестировать работу нотификаций

```yaml
# list notifications
docker exec crowdsec cscli notifications list

# test a notification channel
docker exec crowdsec cscli notifications test http_default
```
Давайте уже закончим с предварительной настройкой **Crowdsec** и перейдем к настройке **Traefik** 

## Настройка обратного прокси **Traefik**

Основные принципы настройки обратного прокси **Traefik** можете почитать в статье на сайте. Там же есть ссылка на видео для, скажем так, визуального контроля.

Поэтому будем считать, что вы знаете что такое обратный прокси **Traefik** и понимаете принципы его работы.

После настройки докер контейнера с Crowdsec, активирования парсеров логов, получения api токен от нашего **bouncer**, нам надо связать наш bouncer с нашим обратным прокси и настроить соответствующие middlewares в Traefik.

Добавить баунсер Crowdsec в **Traefik** можно несколькими способами. Раньше это делали с помощью **forward-auth middleware** и установкой отдельного контейнера с баунсером. На просторах интернета вы встретите именно такой, "старый", или вернее устаревший, способ. Сейчас все можно сделать с помощью соответствующего плагина для **Traefik**.

Прежде всего проверьте настроены ли у вас логи в обратном прокси **Traefik**.

### Настройка логов в обратном прокси **Traefik**

Особенно нас интересует access.log, потому что именно он **Crowdsec** и нужен.

Приведу выдержку кода из статьи про **Traefik**, где я описывал параметры статической конфигурации обратного прокси в файле `traefik.yaml`

```yaml
log: # определяем уровень логирования и путь для логов
  level: "INFO"
  filePath: "/var/log/traefik/traefik.log"
accessLog:
  filePath: "/var/log/traefik/access.log"
```
но теперь зададим более широкие параметры для логирования и работы с ними со стороны **Traefik**.

Теперь наш раздел в части описания логов будет выглядеть примерно так

```yaml
log:
    level: "INFO"
    filePath: "/var/log/traefik/traefik.log"
    noColor: false # Recommended to be true when using common. When using the 'common' format, disables the colorized output
    maxSize: 100 # In megabytes. Maximum size in megabytes of the log file before it gets rotated.
    compress: true # gzip compression when rotating. Determines if the rotated log files should be compressed using gzip.
#
accessLog:
    addInternals: true #Enables access logs for internal resources (e.g.: ping@internal)
    filePath: "/var/log/traefik/access.log"
    bufferingSize: 100 # number of log lines Traefik will keep in memory before writing them to the selected output
    fields:
        names:
            StartUTC: drop # Write logs in Container Local Time instead of UTC. The time at which request processing started.
    filters:
        statusCodes:
            - "204-299"
            - "400-599"
```

Я хочу, чтобы `access.log` фильтровал ответы на запросы по соответствующим кодам. Это сильно ускорит работу. Безусловно вы можете задавать те настройки, которые подходят именно вам.

Кстати, можно заставить **Traefik** писать логи в json формате, - это еще больше ускорит работу **Crowdsec** по чтению логов.

### Особенности настройки при использовании **Cloudflare**

Если ваш обратный прокси-сервер Traefik работает за сетью CDN CloudFlare, вам необходимо указать IP-адреса CloudFlare в Traefik как доверенные IP-адреса. Это необходимо, так как запросы к HTTP-сервису, по сути, передаются через два обратных прокси-сервера — **CloudFlare** и нашим **Traefik**. Благодаря этому реальный IP-адрес посетителя будет от нас скрыт, и **Traefik** будет видеть только запросы, приходящие с серверов CloudFlare.

Таким образом, логи Traefik будут содержать только IP-адреса CloudFlare, что не поможет CrowdSec проанализировать и заблокировать настоящего субъекта угрозы перед CloudFlare.

Чтобы исправить это и видеть реальные IP-адреса пользователей, мы определяем все IPv4- и IPv6-адреса сети CDN CloudFlare как доверенные. Таким образом, Traefik будет доверять таким IP-адресам и анализировать специальные заголовки запросов CloudFlare (X-Forwarded-For), содержащие реальный IP-адрес пользователя.

Для того, чтобы реализовать эту задачу есть несколько методов. Сам я использую специальный плагин для **Traefik** под названием cloudflarewarp. Есть еще и другие, аналогичные по функционалу плагины, но чтобы не усложнять и так достаточно сложную для восприятия статью, я покажу более понятный метод.

Мы в ручную определим IP-адреса CloudFlare как доверенные в определениях для точек входа Traefik.

Откройте статический файл конфигурации Traefik `traefik.yaml` и определите все IPv4- и IPv6-адреса CloudFlare как доверенные IP-адреса для ваших точек входа. Я приведу только часть `traefik.yaml` файла, которая имеет непосредственное отношение к теме статьи. 

Должно выглядеть примерно так:

```yaml
entryPoints:
  http:
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
        # End of Cloudlare's public IP list
    http:
      redirections:
        entryPoint:
          to: https
          scheme: https

  # HTTPS endpoint, with domain wildcard
  https:
    address: :443
    forwardedHeaders:
      # Reuse the list of Cloudflare's public IPs from above
      trustedIPs: *trustedIps
    http:
      tls:
       .....
       .....
```
{{< alert >}}
**Внимание!** С помощью параметра **&trustedIps** мы можем сохранить определение - что такое trustedIPs - как переменную. Это позволит нам повторно использовать это определение в разделе *trustedIps* в точке входе **https** без необходимости заново прописывать все IP-адреса CloudFlare еще раз.
{{< /alert >}}

После этого перезапускаем **Traefik** и смотрим `access.log` Traefik. В журнале вы теперь не должны видеть обезличенные IP-адреса CloudFlare. 


## Плагин CrowdSec Bouncer

Сначала нам нужно установить соответствующий плагин, конфигруацию которого можете посмотреть [здесь](https://plugins.traefik.io/plugins/6335346ca4caa9ddeffda116/crowdsec-bouncer-traefik-plugin)

Данный плагин обладает обширными возможностями по настройке, но я буду рассказывать только об одной из функций - блокировка "нехороших" айпи.

Открываем файл статической конфигурации Traefik `traefik.yaml`и добавляем в него определение плагина:


```yaml
# crowdsec bouncer
experimental:
  plugins:
    bouncer: # это название плагина, которое мы ему присвоили, чтобы в будущем связать это определение со значениями в динамической конфигурации Traefik
      moduleName: github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin
      version: v1.4.4
```

Можете перезагрузить **Traefik** и посмотреть в `traefik.log` загрузился ли плагин.

### Middleware CrowdSec Bouncer в Traefik

После скачивания и включения плагина CrowdSec bouncer в файле статической конфигурации **Traefik** нам необходимо связать его с конкретным middleware для того, чтобы все заработало. Потому что в данный момент, несмотря на то, что плагин скачан и включен, он не функционирует. Сравним это как с работой автомобиля на холостом ходу. Вроде бы двигатель и работает, но мы никуда не едем, только бензин жжем, ну или электроэнергию, если у вас "электричка". 

Определение соответствующему middleware будет задано в файле динамической конфигурации `config.yaml` (у вас он может называться по другому). В нем мы укажем все необходимые настройки для нашей реализации CrowdSec. Для этого отредактируем файл динамической конфигурации **Traefik** и определим следующее middleware:

```yaml
http:
  middlewares:
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
          crowdsecAppsecHost: crowdsec:7422
          crowdsecAppsecFailureBlock: true
          crowdsecAppsecUnreachableBlock: true
          crowdsecLapiKey: yourlapikey # Replace CrowdSec API key (docker exec crowdsec cscli bouncers add crowdsecBouncer)
          crowdsecLapiHost: crowdsec:8080
          crowdsecLapiScheme: http
          forwardedHeadersTrustedIPs:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16                                                        
          clientTrustedIPs:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16
```

Как вы видите, мы с вами задали определенные параметры в middleware. При этом, как я указывал выше, вариантов настроек намного, намного больше. Подробнее об этом можно узнать в [официальной документации](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin).

Обязательно внесите в соответствующее поле значения вашего api key, который мы создали ранее.

Также обратите внимание, что мы задали значение `forwardedHeadersTrustedIPs` и `clientTrustedIPs`. Тем самым мы определяем подсети IPv4 частного класса как доверенные IP-адреса.
Это необходимо, поскольку мы хотим доверять HTTP-заголовкам нашего обратного прокси-сервера **Traefik**, таким как **X-Forwarded-For** и **X-Real-IP**. Эти заголовки обычно определяют реальные IP-адреса посетителей нашего сайта, ну и злоумышленников конечно, которые CrowdSec использует для принятия решений и блокировки.

Вы можете сделать более тонкую настройку и добавить точный IP-адрес Traefik в диапазоне /32. Однако добавление всех диапазонов частных классов в белый список — более удобный подход. Особенно это касается динамических IP-адресов подсетей Docker, которые могут меняться при перезагрузке контейнера.

С помощью переменной clientTrustedIPs мы указываем доверенные IP-адреса или диапазоны IP-адресов, которые мы считаем заслуживающими доверия. Эти IP-адреса или диапазоны сетей не будут заблокированы или запрещены CrowdSec. По сути, это вариант с использованием белого списка.

В моём случае я доверяю локальной сети LAN, что отражается в добавлении всех диапазонов частных классов в белый список. Вы можете ограничить их диапазоном вашей текущей подсети LAN (CIDR) в случае необходимости.

### Защита веб-сервисов Traefik

Несмотря на тот факт, что мы с вами загрузили плагин, связали его с соответствующим middleware, в котором мы определели соответствующие настройки, наши сервисы пока не защищены. То есть наш обратный прокси знает, что есть кaкой-то плагин, и он даже может защищать сервисы, но вот какие сервисы надо защитить **Ttraefik** пока не знает. Давайте этим и займемся/

### Защита индивидуальных сервисов с помощью labels

По общему правилу можно активировать недавно добавленное middleware CrowdSec индивидуально для каждого контейнера через метки (labels) Traefik. Я покажу это на примере тестового контейнера, который был создан разработчиками Traefik как раз для тестовых задач. 

```yaml
  whoami:
    image: traefik/whoami
    container_name: whoami-crowdsec-test
    command:
       - --name=whoami
    networks:
      - proxy
    labels:
      - traefik.enable=true
      - traefik.docker.network=proxy
      - traefik.http.routers.whoami.rule=Host(`whoami.мойдомен.ru`)
      - traefik.http.routers.whoami.service=whoami
      - traefik.http.services.whoami.loadbalancer.server.port=80
      ** - traefik.http.routers.whoami.middlewares=crowdsec@file**

networks:
  proxy:
    external: true
```

Как вы можете увидеть, в последней метке мы определяем тут самую, нужную нам middleware, которая говорит **Traefik**, что он должен применить соответствующую middleware и говорим, что данные о middleware надо смотреть в файле динамической конфигурации.

### Защита на уровне entrypoints

Но более правильно, как мне кажется, защитить все сервисы, которые у нас работают за обратным прокси **Traefik**.

Преимущество данного решения в том, что мы на глобальном уровне все защищаем и спим спокойно, как будто налоги заплатили. Голова не болит какой сервис под защитой, а какой нет. Они все под защитой. Речь конечно о сервисах, которые спрятаны за **Traefik**.

Соответственно я отредктирую файл статической конфигурации **Traefik** `traefik.yaml`, который у нас примет следующий вид.

```yaml
# Traefik entrypoints (network ports) configuration
entryPoints:
  http:
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
          to: https
          scheme: https

  # HTTPS endpoint, with domain wildcard
  https:
    address: :443
    forwardedHeaders:
      # Reuse the list of Cloudflare's public IPs from above
      trustedIPs: *trustedIps
    http:
      middlewares:
        - crowdsec@file # reference to a dynamic middleware for enabling crowdsec bouncer
```
Как вы видите я применил соответствующее middleware на порту 443, но можно применить соответствующее middleware и по порту 80.

После это перезагрузите контейнер **Traefik**

## Проверка работоспособности Crowdsec.

Мы с вами долго все настраивали, но давайте теперь проверим работоспособность всей это конструкции. А то вдруг все было "зазря".

Ниже я приведу список команд, которые нам с вами точно понадобятся.

Сначала проверим, видит ли наш **Crowdsec** наш **Traefik**

---
Эта команда показывает метрики нашего Crowdsec, а также мы узнаем, видит ли Crowdsec логи Traefik и парсит ли он их

```yaml
docker exec crowdsec cscli metrics # For Metrics and log read checking
```
После ввода, указанной выше команды, вы увидите, или должны увидеть большое количество таблиц, которые показывают нам о том, какие коллекции были загружены, но самая верхняя таблица покажет нам видит ли наш Crowdsec `access.log` обратного прокси. Если не видит, то перезагрузите сначала Crowdsec, а потом Traefik.

---

Данная команда обновляет все списки наших коллекций.

```yaml
docker exec crowdsec cscli hub update && docker exec crowdsec cscli hub upgrade                               # Security List update command
```
Вместо того, что бы руками каждый раз обновлять списки, имеет смысл настроить cronjob по команде

`crontab -e`  если вы пользуетесь дебиано/убунту подобным дистрибутивом.

```yaml
* * * * * docker exec crowdsec cscli hub update && docker exec crowdsec cscli hub upgrade
```
Укажите ту периодичность обновления, которую вы считаете нужным. Можно свериться с любым cronjob калькулятором

---

Ну и самое важное. Надо проверить, а может ли наш Crщwdsec банить нехорошие ip адреса.

Тем, кто работает в сфере it безопасности не составит труда симулировать атаку, но мы люди от сохи, простые, поэтому сделаем следующее.

Сначала надо закомментировать в middleware доверенные частные подсети, потому что мы работаем из локальной сети и для теста нам надо, чтобы Corwdsec проверял по умолчанию все ip адреса без исключения.

Потом мы с вами в ручном режиме забаним ip нашего рабочего компьютера следующей командой

```yaml
docker exec crowdsec cscli decisions add --ip 192.168.x.x  # add ip to crowdsec decisions block list
```

Теперь мы можем посмотреть список забаненных адресов с помощью команды

```yaml
docker exec crowdsec cscli decisions list  # List crowdsec ip decisions
```

В этом списке вы должны увидеть свой ip адрес. Теперь попробуйте зайти на сайт дэшборда вашего обратного прокси **Traefik**, но только в режиме инкогнито вашего браузера.

Если все нормально, то в доступе вам будет отказано. По умолчанию бан действует 4 часа. Но конечно не надо ждать эти 4 часа, а разбаним себя в ручном режиме.

```yaml
docker exec crowdsec cscli decisions delete --ip 192.168.x.x # delete ip from crowdsec decisions block list
```
Так как у нас все в порядке, а я надеюсь, что все в порядке, то теперь можете разкомментировать наши частные подсети в middlewares

Если вы просто хотите посмотреть весь список предупреждений, который выдает ваш **Crowdsec**, то сделать это можно с помощью команды

```yaml
docker exec crowdsec cscli alerts list 
```

Ну а на этом все, дорогие друзья.

Если вам понравилась данная статья, то можете поддержать меня boosty.


