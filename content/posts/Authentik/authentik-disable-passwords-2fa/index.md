---
title: Отключение паролей и двухфакторной аутентификации для локальных пользователей в Authentik
published: 2026-01-16
pinned: false
description: Подробное руководство по отключению парольной аутентификации и 2FA для локальных пользователей в Authentik с использованием flows, stages и policies.
tags:
  - SSO
  - Docker
  - Self-Hosting
  - Authentik
slug: /authentik-disable-passwords-2fa
categories: SSO
licenseName: CC BY 4.0
author: Stilicho2011
draft: true
series:
  - Authentik
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: "Пошаговое руководство по отключению паролей и двухфакторной аутентификации для локальных пользователей Authentik: настройка authentication flow, stages, policies и рекомендации по безопасному использованию"
---

# Отключение паролей и двухфакторной аутентификации для локальных пользователей в Authentik

В некоторых сценариях использование локальных паролей и двухфакторной аутентификации (2FA / MFA) в Authentik избыточно или даже нежелательно. Это может быть актуально для разных сценариев, но для дома постоянная аутентификация явно избыточна.

В это статье опишу процесс отключения **корректного отключения парольной аутентификацию и MFA для локальных пользователей в Authentik**, но при этом для внешних айпи все останется как было.

---

## Как Authentik обрабатывает аутентификацию

Аутентификация в Authentik строится на **Flows** и **Stages**:

- **Flow** — это сценарий входа;
- **Stage** — отдельный шаг внутри сценария;
- Stages выполняются строго в заданном порядке;
- Если этап отсутствует в flow — он **не выполняется вообще**.

Важно понимать:  
в Authentik **нет глобального переключателя “включить / выключить пароль”**. Всё управляется через flows.

---

## Роль Password Stage и MFA Stage

- **Password Stage** отвечает за проверку локального пароля;
- **MFA Stage** — за TOTP, WebAuthn и другие факторы.

Если:
- Password Stage отсутствует → пароль не запрашивается и не проверяется;
- MFA Stage отсутствует → второй фактор не используется.


---

## Отключение двухфакторной аутентификации в Authentik для локальных пользователей, которые заходят в Authentik по его айпи.

1. Идем **Customisation** - **Policies**
2. **Create** - **Expression Policy**
3. Задаем имя политике 
4. В разделе **Expression Policy** пишем `return ak_client_ip.is_private`.
5. **Create**
![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-disable-passwords-2fa/0.png)

> [!NOTE]
>Более подробно можно почитать официальную [документацию](https://next.goauthentik.io/customize/policies/expression?utm_source=authentik#comparing-ip-addresses)

6. Идем **Flows and Stages** - **Flows**
7. Выбираем наш `default-authentication-flow` > `Stage Bindings`
8. Кликаем на `default-authentication-mfa-validation`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-disable-passwords-2fa/1.png)

9. Жмем `Bind existing Policy`
10. В появившемся окне выбираем только что созданную в п. 4 политику
11. Обязательно включаем `enable` и `negate result`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-disable-passwords-2fa/2.png)

12. **Create**

Теперь в случае, если вы заходите в вашу инстанцию Authentik не по его поддоменному имени, а по айпи Authentik:порт, то вам не надо будет вводить логин и пароль пользователя.

## Отключение необходимости ввода пароля при авторизации локальных пользователей с локальных айпи в локальной сети.

Общий принцип такой же как и прошлом разделе

1. Идем **Flows and Stages** - **Flows**
2. Выбираем `default-authentication-flow` > `default-authentication-flow` > `Stage Bindings`.
3. Жмем **Edit Stage** напротив `default-authentication-identification`.
4. В разделе **Password Stage** убедитесь что стоит прочерк. Это нужно в случае если вы делали ввод имени пользователя и пароля на одной странице. Если делали, то деактивируйте эту функцию и восстановите соответствущий этап (`default-authentication-password`) 

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-disable-passwords-2fa/3.png)


5. Выбираем **Bind existing Stage**
6. В качестве `Stage` выбираем наш default-authentication-password


5. Теперь жмем стрелку напротив `default-authentication-password` > `Bind existing Policy`
6. Делаем как на скриншоте

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-disable-passwords-2fa/2.png)







