---
title: Установка Traefik в LXC-контейнер Proxmox как systemd-сервиса | Часть 3 — CrowdSec
published: 2026-08-07
lastmod: 2026-08-07
pinned: false
description: Установка CrowdSec рядом с Traefik в одном LXC — коллекции, профили реагирования, уведомления в Gotify, источники логов, AppSec-компонент и подключение bouncer-плагина к Traefik.
tags:
  - Traefik
  - CrowdSec
  - reverse-proxy
  - Homelab
  - Self-Hosting
slug: /traefik-in-lxc-part-3
categories: Traefik
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series: 
  - Traefik
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
summary: Третья часть серии про Traefik в LXC — установка CrowdSec в тот же контейнер, что и сам Traefik. Коллекции сценариев, профиль реагирования с уведомлениями в Gotify, источники логов (Traefik, syslog, AppSec), и подключение bouncer-плагина обратно к Traefik.
---

## Введение

В [части 2](https://prohomelab.com/posts/traefik-in-lxc-part-2/) в разделе "что осталось" я отложил установку CrowdSec на отдельный заход . Вот тот самый заход. CrowdSec ставится в тот же LXC, что и сам Traefik, а не отдельным контейнером в Docker, как было раньше. Это упрощает связность (никаких Docker DNS-имён, всё общается через `localhost`) и позволяет CrowdSec читать `access.log` напрямую с диска, без пробрасывания файла между разными окружениями.

---

## Установка

CrowdSec ставится через официальный скрипт добавления репозитория, дальше — обычным `apt`:

bash

```bash
curl -s https://install.crowdsec.net | sudo sh
apt update
apt list crowdsec
apt install crowdsec
```

`apt list crowdsec` - необязательный шаг, просто чтобы убедиться, что пакет реально появился в списке после добавления репозитория, прежде чем ставить.

---

## Коллекции

Коллекция - это готовый набор сценариев обнаружения под конкретный тип нагрузки. Перед установкой обновляю индекс хаба, чтобы точно ставить актуальные версии, а не то, что было зашито в пакет на момент сборки:

```bash
cscli hub update
```

Ставлю сразу пакет под HTTP-периметр (Traefik), плюс базовые сценарии для самой ОС:

```bash
cscli collections install crowdsecurity/traefik crowdsecurity/http-cve crowdsecurity/base-http-scenarios crowdsecurity/sshd crowdsecurity/linux crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-crs
```

- `crowdsecurity/traefik` - парсер access-логов конкретно под формат Traefik;
- `crowdsecurity/http-cve` + `base-http-scenarios` - обнаружение попыток эксплуатации известных CVE и типовых HTTP-атак;
- `crowdsecurity/sshd` + `linux` - раз CrowdSec теперь живёт в том же LXC, что и Traefik, заодно прикрываю и сам SSH-доступ к контейнеру;
- `appsec-generic-rules`, `appsec-virtual-patching`, `appsec-crs` - под AppSec-компонент (WAF-подобная защита на уровне запроса, до того как он дойдёт до бэкенда) - про него отдельно ниже.

```bash
systemctl reload crowdsec
```

### Автообновление hub по расписанию

Сценарии и парсеры в хабе периодически обновляются (новые CVE, поправки в существующих детекциях), а вручную про `cscli hub update` вспоминаешь редко. Выношу в cron-файл, чтобы обновление индекса и апгрейд установленных коллекций происходили сами раз в сутки, в полночь:

```bash
nano /etc/cron.d/crowdsec-hub-update
```

cron

```cron
0 0 * * * root /usr/bin/cscli hub update && /usr/bin/cscli hub upgrade
```

Файл в `/etc/cron.d/` не требует `crontab -e` и не привязан к пользовательскому crontab - подхватывается системным cron автоматически после сохранения, без дополнительной перезагрузки демона. `hub upgrade` подтягивает новые версии уже установленных коллекций/парсеров/сценариев (не ставит новые - только обновляет то, что уже включено). Если апгрейд что-то реально поменял, `cscli` сам попросит `systemctl reload crowdsec` - это можно либо добавить третьей командой в ту же строку cron, либо, как я предпочитаю, оставить на ручной контроль, чтобы не перезагружать конфигурацию боевого сервиса без просмотра, что именно обновилось.

---

## Профиль реагирования

Профиль определяет, что конкретно делать, когда CrowdSec принимает решение о блокировке - не просто "забанить", а по какой логике и куда уведомить.

`nano /etc/crowdsec/profiles.yaml`:

yaml

```yaml
name: default_ip_remediation
filters:
 - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
 - type: ban
   duration: 4h
notifications:
 - http_default
on_success: break

---

name: default_range_remediation
filters:
 - Alert.Remediation == true && Alert.GetScope() == "Range"
decisions:
 - type: ban
   duration: 4h
notifications:
 - http_default
on_success: break
```

Два профиля - один на бан конкретного IP, другой на бан целого диапазона (если атака идёт распределённо с одной подсети). Оба банят на 4 часа и шлют уведомление через плагин `http_default`, который настраивается отдельно.

---

## Уведомления через Gotify

Раз у меня в стеке уже есть Gotify (пуш-уведомления на телефон/десктоп) — логично заводить туда и алерты CrowdSec, вместо того чтобы заново поднимать email-интеграцию (другие варианты в России на дату написания статьи официально не работают).

`nano /etc/crowdsec/notifications/http.yaml`:

```yaml
type: http
name: http_default
log_level: info
format: |
  {{ range . -}}
  {{ $alert := . -}}
  {
    "extras": {
      "client::display": {
      "contentType": "text/markdown"
    }
  },
  "priority": 3,
  {{range .Decisions -}}
  "title": "{{.Type }} {{ .Value }} for {{.Duration}}",
  "message": "{{.Scenario}}  \n\n[crowdsec cti](https://app.crowdsec.net/cti/{{.Value -}})  \n\n[shodan](https://shodan.io/host/{{.Value -}})"
  {{end -}}
  }
  {{ end -}}
url: https://gotify.domain.ru/message
method: POST
headers:
  X-Gotify-Key: ваш_application_token
  Content-Type: application/json
```

Шаблон формирует Gotify-совместимый JSON: заголовок с типом и значением решения (IP/диапазон, длительность бана), тело сообщения со сценарием, который сработал, плюс сразу готовые ссылки на CrowdSec CTI и Shodan для быстрой проверки адреса вручную.

`X-Gotify-Key` - это application token конкретного приложения в Gotify (создаётся в его собственном UI), не токен пользователя.

---

## Источники логов (acquisition)

CrowdSec с версии, которую мы ставим, использует директорию `/etc/crowdsec/acquis.d/` - отдельный файл на каждый источник, вместо одного монолитного `acquis.yaml`. Логика та же, что и с разбивкой `dynamic/` у самого Traefik: читать и поддерживать проще, когда источники не свалены в одну кучу.

### Access-логи Traefik

```bash
touch /etc/crowdsec/acquis.d/traefik.yaml
```

```yaml
poll_without_inotify: false
filenames:
  - /var/log/traefik/*.log
labels:
  type: traefik
```

`poll_without_inotify: false` - использовать inotify (эффективнее, чем поллинг файла по таймеру) для отслеживания новых строк в логе.

Через маску `*.log` в этот источник попадает не только `access.log`, но и `traefik.log` (операционный лог самого Traefik - запуск, обновление конфигурации, выпуск TLS-сертификатов). Парсер `crowdsecurity/traefik-logs` рассчитан на формат access-лога, поэтому строки из `traefik.log` в `cscli metrics` будут честно показываться как "unparsed" - это ожидаемо, не ошибка конфигурации, и убирать `traefik.log` из источника необязательно.

### Системные логи

```bash
touch /etc/crowdsec/acquis.d/syslog.yaml
```

```yaml
filenames:
  - /var/log/auth.log
  - /var/log/syslog
labels:
  type: syslog
```

Это то, ради чего ставили коллекции `sshd`/`linux` - раз CrowdSec теперь в том же LXC, что принимает внешний трафик, разумно заодно приглядывать за попытками подбора SSH и подозрительной активностью на уровне ОС.

## Debian 13 (trixie): rsyslog не ставится по умолчанию

На Debian 13 этот источник сам по себе работать не будет. Начиная с bookworm `rsyslog` больше не ставится по умолчанию - `/var/log/auth.log` и `/var/log/syslog` просто не существуют или не пишутся, если пакет не установлен явно. Проверить:

```bash
ls -la /var/log/auth.log /var/log/syslog
```

Если `auth.log` отсутствует, а `syslog` есть, но нулевого размера - `rsyslog` не установлен:

```bash
apt install rsyslog
systemctl enable --now rsyslog
```

Дальше - ловушка конкретно для trixie: даже после установки пакет **не создаёт** файл с правилами маршрутизации `/etc/rsyslog.d/50-default.conf`, который раньше шёл "из коробки". Каталог `/etc/rsyslog.d/` после установки пуст (кроме, возможно, `postfix.conf`, если Postfix тоже стоит). Без этих правил `rsyslogd` слушает журнал, но не знает, куда писать `auth`/`authpriv`-сообщения - файлы остаются пустыми. Создаём вручную:

```bash
nano /etc/rsyslog.d/50-default.conf
```

Минимум, нужный CrowdSec:

```
auth,authpriv.*                /var/log/auth.log
*.*;auth,authpriv.none         -/var/log/syslog
```

```bash
systemctl restart rsyslog
```

Проверка - любое действие через `sudo` (например `sudo -k && sudo whoami`, чтобы сбросить кэш и заново пройти PAM) должно тут же появиться в `auth.log`:

```bash
ls -la /var/log/auth.log /var/log/syslog
```

Оба файла должны существовать и расти. После этого `systemctl restart crowdsec` и `cscli metrics` - в Acquisition Metrics должны появиться строки `file:/var/log/auth.log` и `file:/var/log/syslog` с ненулевым числом прочитанных строк.

```bash
systemctl reload crowdsec
cscli metrics
```

`cscli metrics` показывает, видит ли CrowdSec вообще какие-то строки из подключённых источников - если счётчики нулевые, то AppSec можно не начинать настраивать, сначала надо разобраться с acquisition.

---

## AppSec-компонент

AppSec - это WAF-подобная защита на уровне самого запроса (сигнатуры атак, virtual patching под известные CVE), работающая отдельно от классического anti-bruteforce анализа логов. Traefik обращается к нему напрямую через bouncer-плагин, до того как запрос уйдёт к реальному бэкенду.

```bash
touch /etc/crowdsec/acquis.d/appsec.yaml
```

```yaml
listen_addr: 127.0.0.1:7422
appsec_config: crowdsecurity/appsec-default
name: myAppSecComponent
source: appsec
labels:
    type: appsec
```

{{< alert >}} **Важно проверить перед стартом:** адрес обязательно `127.0.0.1`, не `127.0.0.0` - последний является адресом самой сети `127.0.0.0/8`, а не хостом, и не гарантированно забиндится корректно. В bouncer-плагине Traefik ниже используется `localhost:7422`, что резолвится в `127.0.0.1` - оба адреса должны совпадать буквально, иначе AppSec будет недоступен, а `crowdsecAppsecUnreachableBlock: true` в конфиге плагина заблокирует вообще весь трафик через Traefik, если компонент не отвечает. {{< /alert >}}

```bash
systemctl reload crowdsec
systemctl reload traefik
cscli metrics show acquisition
```

---

## Регистрация bouncer'а и подключение к Traefik

```bash
cscli bouncers add traefik-bouncer
```

Команда выведет API-ключ один раз - сохраните сразу, повторно посмотреть не получится (та же логика, что с токеном Cloudflare в части 2), только пересоздать заново.

Middleware в `dynamic/middlewares/crowdsec.yaml`:

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
          crowdsecAppsecHost: localhost:7422
          crowdsecAppsecFailureBlock: true
          crowdsecAppsecUnreachableBlock: true
          crowdsecLapiKey: ваш_ключ_из_cscli_bouncers_add
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
```

`localhost` вместо Docker-имени вроде `crowdsec:8080`, которое было бы в старой Docker-based установке - оба сервиса теперь в одном LXC, дополнительная сетевая связность не нужна вообще.

Последний шаг - раскомментировать middleware в static config (в части 2 он был закомментирован):

```yaml
entryPoints:
  web:
    http:
      middlewares:
        - crowdsec@file   # теперь можно раскомментировать
        - rate-limit@file
  websecure:
    http:
      middlewares:
        - crowdsec@file   # и здесь
        - rate-limit@file
```

```bash
systemctl restart traefik
```

---

## Проверка

```bash
cscli decisions list      # текущие активные баны
cscli metrics             # общая статистика по сценариям и bouncer'ам
cscli bouncers list        # подтверждение, что traefik-bouncer подключился и опрашивает LAPI
```

Если `cscli bouncers list` показывает bouncer, но с давним временем последнего запроса - проверьте связность между Traefik и `localhost:8080` (сам факт, что оба в одном LXC, ещё не гарантирует, что плагин смотрит на правильный порт/схему).

## Ссылки

- [Документация CrowdSec](https://doc.crowdsec.net/)
- [crowdsec-bouncer-traefik-plugin](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin)
- [Список коллекций CrowdSec Hub](https://app.crowdsec.net/hub/collections)
