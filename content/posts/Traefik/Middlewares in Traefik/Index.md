---
title: Middlewares в Traefik — что это, зачем нужны и полный список для homelab
published: 2026-08-06
lastmod: 2026-08-06
pinned: false
description: Разбор механизма middlewares в Traefik — что это такое, как применяются к роутерам, что такое chain, и обзор всех доступных middleware open-source версии с примерами конфигурации.
tags:
  - Traefik
  - reverse-proxy
  - Homelab
  - Self-Hosting
slug: /traefik-middlewares-overview
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
summary: Middleware — второй по значимости строительный блок Traefik после роутеров. В этой статье разбираю, что это такое, зачем нужно, как применяется, что такое chain, и прохожусь по всем middleware из открытой версии Traefik с примерами конфигурации, которые использую у себя.
cover: ./featured.webp
---

## Что такое middleware в Traefik

Когда запрос долетает до обратного прокси Traefik, он проходит через цепочку обработки, прежде чем попасть к реальному сервису (вашему приложению за прокси) — или вместо этого сразу получить ответ от самого Traefik, не дойдя до бэкенда. Middleware — это как раз тот механизм, который позволяет вмешаться в запрос или ответ на этом пути: изменить заголовки, отклонить запрос, ограничить частоту обращений, потребовать аутентификацию, переписать путь и так далее.

<iframe width="560" height="315" src="https://www.youtube.com/embed/YxAvrlG3GMA?si=CbCR32n0gW8DQ96M" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>


По сути, middleware в Traefik — прямой аналог middleware в любом веб-фреймворке (Express, Django, ASP.NET) — только на уровне реверс-прокси, а не приложения. Разница важная: middleware Traefik работает **до** того, как запрос вообще доедет до вашего сервиса, а значит может защитить приложение, которое само по себе никакой защиты не имеет (не умеет в аутентификацию, не ограничивает частоту запросов, не проверяет заголовки).

## Зачем это нужно, если можно настроить всё в самом приложении

Формально — многое из того, что делает middleware, можно реализовать и на стороне приложения. Но есть причины, почему делать это на уровне прокси удобнее и более правильно с точки зрения управления и безопасности:

- **Централизация.** Ограничение частоты запросов, базовая аутентификация, security-заголовки — если всё это настраивается один раз в Traefik, не нужно повторять логику в каждом отдельном приложении, часть из которых вообще не даёт такой возможности.
- **Единообразие.** Одна и та же политика (например, security headers) применяется ко всем сервисам сразу, без риска, что где-то забыли.
- **Защита того, что само не умеет защищаться.** Многие self-hosted приложения (дашборды, простые утилиты) не имеют встроенной аутентификации вообще — middleware вроде `forwardAuth` или `basicAuth` перед таким сервисом закрывает эту дыру, не трогая код самого приложения.
- **Разделение ответственности.** Приложение занимается своей прямой задачей, вопросы вроде "кто имеет право сюда зайти" и "как часто можно стучаться" — решаются на уровне инфраструктуры.

## Как middleware применяется к запросу

Middleware не работает сам по себе — он объявляется в dynamic config, а затем **подключается** к конкретному роутеру по имени:

```yaml
http:
  routers:
    my-service:
      rule: "Host(`app.example.com`)"
      middlewares:
        - default-headers
        - rate-limit
      service: my-service

  middlewares:
    default-headers:
      headers:
        frameDeny: true
    rate-limit:
      rateLimit:
        average: 100
```

**Порядок в списке имеет значение.** Middleware применяются последовательно, сверху вниз — запрос проходит через `default-headers`, затем через `rate-limit`, и только после этого (если ни один middleware его не отклонил) доходит до сервиса. Ответ идёт в обратном порядке. Это важно, например, для аутентификации — middleware, проверяющий доступ, обычно должен стоять раньше тех, что просто модифицируют заголовки, иначе неавторизованный запрос может успеть что-то затронуть до отказа.

Один и тот же middleware можно переиспользовать в любом количестве роутеров — объявляете один раз, подключаете где угодно по имени. При использовании нескольких providers (file provider, Docker provider) к имени добавляется суффикс провайдера: `authentik@file`, `redirect@docker` — это то, как Traefik различает одноимённые middleware, объявленные в разных бекэндах.

## Определение и применение — не одно и то же

Middleware **всегда определяется** в dynamic config — его тип и параметры (`headers`, `rateLimit`, `forwardAuth` и т.д.) невозможно описать в static config (`traefik.yaml`) напрямую, такой возможности там просто нет. А вот **применяться** уже определённый middleware может двумя разными способами.

**Точечно, к конкретному роутеру** — то, что было в примере выше:

```yaml
# dynamic config
http:
  routers:
    my-service:
      middlewares:
        - default-headers
        - authentik
```

В указанном примере мы сначала применяем стандартный заголовки запросов, а потом перенаправляем запрос на [Authentik](https://goauthentik.io/)

**Глобально, через entryPoint в static config.** В `traefik.yaml` можно сослаться на middleware по имени (с суффиксом провайдера), и тогда он применится **ко всем** запросам, которые проходят через этот entrypoint, ещё до того, как Traefik разберётся, к какому роутеру относится запрос:

```yaml
# traefik.yaml (static config)
entryPoints:
  websecure:
    address: ":443"
    http:
      middlewares:
        - rate-limit@file
```

Middleware по-прежнему **определён** в dynamic config — в static config лежит только ссылка на его имя. Такой способ удобен для того, что должно действовать на весь трафик одинаково (rate limit, CrowdSec bouncer) — не нужно перечислять их в `middlewares:` каждого отдельного сервисного роутера, они и так применяются глобально через привязку к entrypoint.

## Что такое Chain

`Chain` — это middleware, который сам состоит из других middleware:

```yaml
http:
  middlewares:
    secured:
      chain:
        middlewares:
          - default-whitelist
          - default-headers
```

Подключаете `secured` цепочку (chain) к роутеру — и получаете применение сразу обоих (`default-whitelist`, затем `default-headers`) в заданном порядке, одной строкой. Удобно, когда одна и та же комбинация из нескольких middleware повторяется на многих роутерах — вместо того чтобы каждый раз перечислять весь список, ссылаетесь на один `chain`.

## Открытая версия vs Traefik Hub

Часть middleware из документации Traefik помечены как доступные только в **Traefik Hub** (платная надстройка/Enterprise) — например, `JWT`, `OIDC`, `OAuth2`, `OPA`, `WAF`, `LDAP`, `HMAC`, `APIKey`, Distributed RateLimit. Ниже — только те middleware, что доступны в open-source версии, которую использует большинство homelab-инсталляций (включая мою).

---

## Полный список middleware

### AddPrefix

Добавляет префикс к пути запроса перед тем, как он уйдёт к бэкенду. Полезно, когда бэкенд ожидает путь вида `/api/...`, а снаружи хочется без префикса.

```yaml
http:
  middlewares:
    add-prefix-example:
      addPrefix:
        prefix: "/api"
```

### BasicAuth

Классическая HTTP Basic Authentication — логин/пароль в диалоговом окне браузера. Хеш пароля генерируется через `htpasswd` (пакет `apache2-utils`):

```bash
htpasswd -nB username
```

```yaml
http:
  middlewares:
    basic-auth-example:
      basicAuth:
        users:
          - "username:$2y$05$..."
        realm: "Restricted"
```

Использую для защиты dashboard самого Traefik — простой и надёжный fallback, не зависящий от доступности внешнего identity-провайдера.

### Buffering

Буферизует тело запроса/ответа перед передачей дальше — полезно для приложений с большими файлами (загрузка документов, фото, видео) и для настройки повторных попыток при сетевых ошибках.

```yaml
http:
  middlewares:
    middlewares-buffering:
      buffering:
        maxRequestBodyBytes: 10485760
        memRequestBodyBytes: 2097152
        maxResponseBodyBytes: 10485760
        memResponseBodyBytes: 2097152
        retryExpression: "IsNetworkError() && Attempts() <= 2"
```

Держу как заготовку под сервисы с большими аплоадами (Nextcloud, Immich, OnlyOffice), пока не подключена ни к одному напрямую.

### Chain

Уже разобрали выше — объединяет несколько middleware под одним именем.

```yaml
http:
  middlewares:
    secured:
      chain:
        middlewares:
          - default-whitelist
          - default-headers
```

### CircuitBreaker

Автоматически отключает трафик от сервиса, если тот начинает массово отдавать ошибки или тормозить — защищает остальную систему от каскадного эффекта одного упавшего бэкенда.

```yaml
http:
  middlewares:
    circuit-breaker-example:
      circuitBreaker:
        expression: "NetworkErrorRatio() > 0.30 || ResponseCodeRatio(500, 600, 0, 600) > 0.25"
        checkPeriod: "10s"
        fallbackDuration: "30s"
        recoveryDuration: "30s"
```

### Compress

Сжимает тело ответа (gzip) перед отправкой клиенту — экономит трафик. Стоит исключать уже сжатые форматы (изображения, видео), сжимать их повторно бессмысленно, там уже все сжато до нас, и тратит мощность CPU впустую.

```yaml
http:
  middlewares:
    compress:
      compress:
        excludedContentTypes:
          - "image/png"
          - "image/jpeg"
          - "image/webp"
          - "video/mp4"
```

### ContentType

В Traefik v3 автоопределение `Content-Type` включено по умолчанию — этот middleware нужен, только если хотите явно **отключить** автоопределение для конкретного сервиса.

```yaml
http:
  middlewares:
    content-type-example:
      contentType: {}
```

### DigestAuth

Похож на BasicAuth, но пароль не передаётся в открытом виде даже в рамках HTTP-схемы (используется хеш-based challenge-response).

```yaml
http:
  middlewares:
    digest-auth-example:
      digestAuth:
        users:
          - "username:Restricted:ha1_hash"
        realm: "Restricted"
```

### Errors (Custom Error Pages)

Подменяет стандартную страницу ошибки Traefik/бэкенда на свою — отдаёт её с отдельного сервиса (например, статическая страница).

```yaml
http:
  middlewares:
    error-pages-example:
      errors:
        status:
          - "500-599"
        service: error-pages-service
        query: "/{status}.html"
```

### ForwardAuth

Один из самых полезных middleware для homelab с SSO. Перенаправляет каждый входящий запрос на внешний сервис аутентификации (в моём случае — Authentik) перед тем, как пропустить его дальше. Если внешний сервис отвечает успехом — запрос идёт к реальному бэкенду, с добавленными заголовками из ответа (имя пользователя, группы и т.д.); если нет — Traefik сам отдаёт ответ аутентификации (редирект на логин), не трогая бэкенд вообще. 

```yaml
http:
  middlewares:
    authentik:
      forwardAuth:
        address: "http://10.10.10.10:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        maxResponseBodySize: 1048576
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
```

Важный нюанс: нужен только для приложений, которые сами не умеют говорить с identity-провайдером напрямую (по OIDC). Если приложение само поддерживает OIDC-клиент (как многие современные self-hosted сервисы) — `forwardAuth` не нужен, приложение настраивается напрямую на Authentik как Identity Provider, без участия Traefik в цепочке аутентификации.

Необходимо отметить, что не все сервисы аутентификации могут работать с `forwardAuth` напрямую. Authentik и Authelia могут, Keycloak таким коробочным функционалом на дату написания статьи не обладает.

### GrpcWeb

Актуально только если проксируете `grpc-web` клиента к обычному gRPC-бэкенду — конвертирует протокол на лету.

```yaml
http:
  middlewares:
    grpc-web-example:
      grpcWeb:
        allowOrigins:
          - "*"
```

### Headers

Один из самых часто используемых middleware — управляет HTTP-заголовками запроса и ответа: security headers (HSTS, X-Frame-Options, CSP), кастомные заголовки, CORS.

```yaml
http:
  middlewares:
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
```

Держу два варианта baseline — облегчённый для большинства сервисов и усиленный (со скрытием версии сервера, более длинным HSTS для preload-листа) для более чувствительных случаев — плюс отдельные варианты под конкретные приложения, где нужен нестандартный CSP (например, для встраивания редактора документов в iframe с другого домена).

### InFlightReq

Ограничивает число **одновременных** соединений (в отличие от rate limit, который ограничивает частоту запросов в секунду). Полезно для ресурсоёмких эндпоинтов — например, при транскодировании видео, например Immich (Plex или Jellyfin и так могут ограничивать одновременные потоки).

```yaml
http:
  middlewares:
    in-flight-req-example:
      inFlightReq:
        amount: 20
```

### IPAllowList

Ограничивает доступ по списку разрешённых IP/подсетей.

```yaml
http:
  middlewares:
    default-whitelist:
      IPAllowList:
        sourceRange:
          - "10.0.0.0/8"
          - "192.168.0.0/16"
          - "172.16.0.0/12"
```

У меня все сервисы закрыты аутентификацией, поэтому этот middleware сейчас нигде не подключён — держу как готовый инструмент про запас.

### PassTLSClientCert

Актуально для mTLS-сценариев, где бэкенд сам хочет видеть клиентский сертификат в заголовке.

```yaml
http:
  middlewares:
    pass-tls-client-cert-example:
      passTLSClientCert:
        pem: true
```

### RateLimit

Ограничивает частоту запросов от одного клиента (по умолчанию — по source IP), защита от флуда/DDoS.

```yaml
http:
  middlewares:
    rate-limit:
      rateLimit:
        average: 100
        burst: 50
```

Подключён у меня глобально на оба entrypoint (`web`/`websecure`), а не точечно к отдельным сервисам — общая линия защиты для всего трафика.

### RedirectScheme

Редиректит запрос с одной схемы на другую — чаще всего HTTP → HTTPS.

```yaml
http:
  middlewares:
    https-redirect:
      redirectScheme:
        scheme: https
        permanent: true
```

### RedirectRegex

То же самое, но с произвольным regex-паттерном для более сложных редиректов, не только смены схемы.

```yaml
http:
  middlewares:
    redirect-regex-example:
      redirectRegex:
        regex: "^https://(.*)/old-path"
        replacement: "https://${1}/new-path"
        permanent: true
```

### ReplacePath

Полностью заменяет путь запроса перед передачей бэкенду.

```yaml
http:
  middlewares:
    replace-path-example:
      replacePath:
        path: "/new/path"
```

### ReplacePathRegex

То же самое через regex, с возможностью захватывать и переиспользовать части исходного пути.

```yaml
http:
  middlewares:
    replace-path-regex-example:
      replacePathRegex:
        regex: "^/old/(.*)"
        replacement: "/new/$${1}"
```

### Retry

Повторяет запрос при сетевой ошибке до заданного числа попыток — в отличие от `retryExpression` внутри `buffering`, это отдельный, более общий механизм.

```yaml
http:
  middlewares:
    retry-example:
      retry:
        attempts: 3
        initialInterval: "100ms"
```

### StripPrefix

Убирает указанный префикс из пути перед передачей бэкенду — обратная операция к `AddPrefix`.

```yaml
http:
  middlewares:
    strip-prefix-example:
      stripPrefix:
        prefixes:
          - "/api"
```

### StripPrefixRegex

То же самое, но по regex-паттерну.

```yaml
http:
  middlewares:
    strip-prefix-regex-example:
      stripPrefixRegex:
        regex:
          - "^/api/v[0-9]+"
```

---

## Как я организовал middleware у [себя](https://prohomelab.com/posts/traefik-in-lxc-part-2/)

Каждый middleware — отдельный `.yaml` файл по пути `/etc/traefik/dynamic/middlewares/`, имя файла соответствует его назначению. Часть middleware реально подключена к сервисам (`default-headers`, `rate-limit`, `https-redirect`, `authentik` forwardAuth), часть держу как готовую библиотеку про запас — на случай, когда понадобится конкретный сценарий (whitelist для админок, buffering для аплоадов, in-flight limit для транскодирования), не изобретая конфиг с нуля в моменте.

Ключевой плюс такого подхода — при добавлении нового сервиса не нужно думать, "а как вообще пишется этот middleware" — просто беру готовый файл, копирую нужные строки в `services/<новый-сервис>.yaml`, подключаю по имени.

## Ссылки

- [Официальный список middleware Traefik](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/overview/)
- [ForwardAuth](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/)
- [Headers](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/headers/)