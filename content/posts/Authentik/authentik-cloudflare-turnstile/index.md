---
title: Настройка Cloudflare Turnstile для защиты формы входа в Authentik без CAPTCHA
published: 2026-01-15
pinned: false
description: Подробная инструкция по настройке Cloudflare Turnstile — современной альтернативы CAPTCHA для защиты форм входа, регистрации и восстановления пароля.
tags:
  - SSO
  - Docker
  - Self-Hosting
  - Authentik
slug: /authentik-cloudflare-turnstile
categories: SSO
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Authentik
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Подробное руководство по настройке Cloudflare Turnstile — современной альтернативы CAPTCHA для защиты форм входа, регистрации и восстановления пароля без ухудшения пользовательского опыта.
---

# Настройка Cloudflare Turnstile в Authentik

Cloudflare Turnstile — это современная альтернатива CAPTCHA, которая позволяет защищать формы аутентификации от ботов и атак перебора, **не заставляя пользователей разгадывать картинки или вводить символы**. 

> [!NOTE]
>**В случае, если вы нашли данную статью полезной и считаете возможным отблагодарить автора, то это можно сделать по соответствующей ссылке на** [**boosty**](https://boosty.to/stilicho2011)

> [!NOTE]
>Cloudflare Turnstile это аналог технологии Captcha, но для пользователей Cloudflare. Если вам нужно настроить именно Captcha, - более подробно можете ознакомиться с настройкой на странице официальной [**документации**](https://docs.goauthentik.io/add-secure-apps/flows-stages/stages/captcha/)

> [!NOTE]
>С 1 июля 2025 года в России вступили в силу изменения в законодательстве о персональных данных (ФЗ №152), согласно которым использование Google reCAPTCHA или их аналогов на сайтах, передающих данные за границу, становится нарушением. Необходимо учитывать это ограничение, если вы собираетесь использовать данный сервис в предпринимательской деятельности.

---

## Зачем использовать Cloudflare Turnstile в Authentik

По умолчанию Authentik уже обладает неплохой защитой от:

- brute-force атак;
- username enumeration;
- автоматических попыток входа.

Однако при публикации IdP в интернет этого часто бывает недостаточно.

Cloudflare Turnstile позволяет:

- отсекать ботов ещё **до выполнения flow**;
- снизить нагрузку на Authentik;
- улучшить пользовательский опыт по сравнению с классическими CAPTCHA;
- повысить общий уровень безопасности без усложнения логики flows.

То есть кроме тех способов аутентификации и авторизации, которые мы с вами уже настроили в предыдущих статьях, добавляется еще один способ проверки.

Визуально это выглядит как-то так

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/0.png)

---

## Требования

Перед началом убедитесь, что:

- у вас есть аккаунт в Cloudflare;
- домен, на котором доступен Authentik, добавлен в Cloudflare.

К сожалению обязательные требования для использования этой технологии.

---

## Создание Turnstile в Cloudflare

1. Перейдите в панель Cloudflare.
2. Откройте раздел **Protect & Connect** > **Turnstile**.
3. Нажмите **Add Widget**.
4. Укажите:
   - **Widget name** — произвольное имя (например `authentik-login`);
   - **Add Hostname** > **Domains** — домен, на котором работает Authentik;
   - **Widget mode** — Managed (рекомендуется для дома).
   - **Pre-Clearance Mode** - **Yes**
   - **Level of pre-clearance** - interactive

> [!NOTE]
>Последние два пункта меняйте так как вы считаете нужным в зависимости от ваших потребностей и паранойи.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/1.png)

После создания вы получите:
- **Site Key**
- **Secret Key**

Можете их скопировать, но Cloudlfare заботливо указывает, что вы всегда сможете повторно получить к ним доступ

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/2.png)

## Создание Captcha Stage в Authentik

### Настройка этапа в Authentik

Теперь переходим к настройке в Authentik.

1. Откройте админ-панель Authentik.
2. Перейдите в **Flows and Stages** → **Stages**.
3. Нажмите **Create**.
4. Выберите **Captcha Stage**.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/3.png)

5. Задайте имя этапу 
6. В типе проверки выберите **Cloudflare Turnstile**.
7. В разделе `Public key` и `Private Key` укажите значения, которые мы получили у **Cloudflare**.
8. Галку `Interactive` можно оставить включенной, если Turnstile у вас сконфигурирован как `Invisible` или `Managed`
![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/4.png)

В разделе **Advanced Settings** ничего не трогаем. В актуальной на дату написания статьи версии Authentik корректные значения уже автоматом прописаны. Раньше нужно было их вставлять руками. Более подробно можно ознакомиться на сайте с официальной [**документацией**](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/widget-configurations/)

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/5.png)

9. **Finish**


### Интеграция Turnstile этапа в основной поток аутентификации и авторизации

1. Откройте админ-панель `Authentik`.
2. Перейдите в **Flows and Stages** → **Flows** → **default-authentication-flow**.
3. Выберите **Stage Bindings** → **Bind Existing Stage**
4. Выбираем вновь созданный этап.
5. Выбираем порядок обработки Turnstile этапа после этапа аутентификации, но до этапа ввода пароля.
6. Выберите `evaluate when flow is planned`.
7. **Create**

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/6.png)

Теперь мы интегрировали этап "капчи" при аутентификации в Authentik.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/9.png)

> [!TIP]
>В панели `Turnstile` на сайте `Cloudflare` вы сможете посмотреть аналитику по работе этого виджета

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/7.png)

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-cloudflare-turnstile/8.png)