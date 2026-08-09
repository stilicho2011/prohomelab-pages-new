---
title: Настройка email-уведомлений в Authentik
published: 2026-02-05
pinned: false
description: "Подробное руководство по настройке email-уведомлений в Authentik: SMTP, шаблоны писем, события, тестирование и типичные ошибки."
tags:
  - SSO
  - Docker
  - Self-Hosting
  - Authentik
slug: /authentik-email-notifications
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
summary: "Пошаговое руководство по настройке email-уведомлений в Authentik: подключение SMTP, включение уведомлений о событиях, настройка шаблонов писем и проверка доставки."
---

> [!NOTE]
>**В случае, если вы нашли данную статью полезной и считаете возможным отблагодарить автора, то это можно сделать по соответствующей ссылке на** [**boosty**](https://boosty.to/stilicho2011)

В этой статье я расскажу о настройке почтовых уведомлений в Authentik. Они позволяют получать уведомления о важных событиях в системе — таких как вход пользователей, выход из системы и ошибки аутентификации. Это полезно для мониторинга безопасности и своевременного реагирования на подозрительную активность.

> [!TIP]
>Для данной настройки, а также для корректной работы Authentik в целом, необходимо предварительно настроить параметры почтового сервера в файле переменных окружения `.env`.

Проверить корректность настройки SMTP можно следующей командой:

```yaml
docker exec authentik_worker ak test_email ваша_почта@домен.com
```

Контейнер authentik_worker должен быть запущен, а переменные AUTHENTIK_EMAIL_* — корректно заданы.

> [!NOTE]
>Настройки приложения описанные в это статье актуальны на дату написания статьи

Авторизуемся в Authentik под учётной записью администратора и переходим в раздел:

`Events` → `Notification Rules`

![Notifications Rules](01-Projects/Prohomelab/Authentik/authentik-email-notifications/0.png)

В рамках данной статьи я покажу настройку уведомлений только для трёх базовых событий, которые, на мой взгляд, являются наиболее важными с точки зрения безопасности. При необходимости вы можете настроить любые другие события по своему усмотрению.

Нажимаем `Create`. В появившемся окне задаём название правила, которое имеет для вас смысл. В моём случае это правило для мониторинга входов в Authentik.

В разделе `Groups` указываем, пользователям какой группы будут приходить уведомления. В моём случае это authentik Admins.

В разделе `Transport` выбираем механизм доставки уведомлений. В данном случае используется почтовый сервис.

В разделе `Severity` выбираем уровень важности события. Я использую значение `Alert`, после чего нажимаем `Create`.

![Create Notifications Rules](01-Projects/Prohomelab/Authentik/authentik-email-notifications/1.png)

Переходим в только что созданное правило и нажимаем `Create and Bind Policy`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-email-notifications/2.png)


В появившемся окне выбираем `Event Matcher Policy`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-email-notifications/3.png)

Задаём название политики (например, `login`). В разделе `Action` выбираем событие, для которого будет срабатывать уведомление. В моём случае это `Login`.

Остальные параметры зависят от ваших требований. Если цель — просто получать уведомления о событии, их можно оставить без изменений. Более подробно доступные параметры описаны в [официальной документации](https://docs.goauthentik.io/sys-mgmt/events/notifications/)
Но если вы хотите просто получать уведомления, то можно оставить как у меня на скрине.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-email-notifications/5.png)


В следующем окне задаём порядок обработки политики. Я начинаю со значения 10 и нажимаю `Finish`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-email-notifications/6.png)


Для контроля основных действий пользователей (или потенциальных злоумышленников) я создаю ещё две аналогичные политики. Отличие заключается только в типе события:

- `Logout`

- `Failed Login`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-email-notifications/7.png)

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-email-notifications/8.png)


В результате список привязанных политик выглядит примерно следующим образом:

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-email-notifications/9.png)

После завершения настройки рекомендуется выполнить проверку. Для этого можно выйти из системы и снова войти в Authentik, а также попытаться выполнить вход с неверными учётными данными. Если всё настроено корректно, на каждое соответствующее событие будет приходить email-уведомление.