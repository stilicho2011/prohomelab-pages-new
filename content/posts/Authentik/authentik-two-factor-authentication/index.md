---
title: Настройка двухфакторной аутентификации в Authentik
published: 2026-01-14
pinned: false
description: "Подробная инструкция по настройке двухфакторной аутентификации в Authentik: TOTP, WebAuthn, flows, stages и рекомендации по безопасности."
tags:
  - SSO
  - Docker
  - Self-Hosting
  - Authentik
slug: /authentik-two-factor-authentication
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
summary: Руководство по настройке двухфакторной аутентификации в Authentik с использованием TOTP и WebAuthn, разбором flows, stages и best practices по безопасности.
---

> [!NOTE]
>**В случае, если вы нашли данную статью полезной и считаете возможным отблагодарить автора, то это можно сделать по соответствующей ссылке на** [**boosty**](https://boosty.to/stilicho2011)


В предыдущих статьях мы с вами поговорили о том как создавать и восстанавливать пароли по заданной нами политике, организовать автоматизированную регистрацию пользователей. В настоящей статье поговорим о настройке двухфакторной аутентификации, причем настроим ее таким образом, чтобы все пользователи были вынуждены настраивать в обязательно порядке двухфакторную аутентификацию. Я расскажу как настроить аутентификацию с помощью TOTP кодов и WebAuthn приложений, а также настроем passwordless login. 

> [!TIP]
>Самая безопасная аутентификация  - это использование решений от Yubikey, но это дорогое удовольствие, всегда надо иметь запасной ключ на случай утери первого, и у меня к сожалению нет такого оборудования для демонстрации. А сервис компании Cisco Duo на дату написания статьи на территории РФ временно не работает.


> [!NOTE]
>На сайте уже опубликована статья, посвященная различиям TOTP, WebAuthn и Passwordless Login. Ознакомится с ней можно по [ссылке](https://prohomelab.com/posts/totp-webauthn-passwordless/). Поэтому я предполагаю, что вы знаете что такое TOTP, WebAuthn и Passwordless Login.


Прежде всего необходимо отметить, что в этой статье я описываю автоматизацию процесса, с моей точки зрения это наиболее оптимальный вариант. Но в тоже время все можно сделать в ручную. Для этого каждый юзер переходит в личные настройки нажав значок шестеренки в верхнем правом углу, выбирает раздел `MFA Devices` > `Enroll`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/0.png)

в ниспадающем меню выбираем TOTP или WebAuthn устройство и дальше следуем инструкциям. 

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/1.png)


Мы сделаем тоже самое, но на глобальном уровне, таким образом, что любой пользователь Authentik обязан будет настроить двухфакторную аутентификацию.
Для правильной работы TOTP кодов у вас должно быть установлено любое удобное вам приложение аутентификатор: Google Authenticator, Vaultwarden, Bitwarden, Яндекс.Ключ или даже Kaspersky Password Manager. Выбирайте наиболее удобное и комфортное решение для вас.  
Для WebAuthn и Passwordless Login подойдет любое устройство со входом по отпечатку пальца или Windows Hello (уверен что аналог на Маке тоже работает). Сам я пользуюсь связкой Vaultwarden + Google Authenticator + Windows Hello.
Все действия я выполняю из под аккаунта администратора.

## Настройка TOTP кодов

В принципе, как и в предыдущих статьях, мы можем с вами создать все необходимые потоки с нуля. Но для упрощения давайте воспользуемся дефолтным потоком.
Переходим в `Flow and Stages` > `Flows` > `default-authentication-flow`. В `default-authentication-flow` переходим в `Stage Bindings`. 

В настоящий момент наши этапы выглядят следующим образом

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/2.png)

Теперь нам надо внести изменения в дефолтный этап `default-authentication-mfa-validation`. Дело в том, что он есть в списке этапов потока `default-authentication-flow`, но не настроен и не работает. Не беспокойтесь мои юные зрители, сейчас мы это исправим.

В появившемся списке в разделе `not configured action` выбираем `force the user to configure an authenticator`. Тем самым мы принудительно заставим пользователя использовать двухфакторную аутентификацию. В появившемся меню `configure stages` выбираем `TOTP Authenticator Setup Stage` и жмем `Update`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/3.png)

>[!TIP]
>Мое личное мнение, что у админа должно быть несколько вариантов двухфакторной аутентификации на случай отказа одного из вариантов.



Теперь выходим из нашего аккаунта (крайне желательно все делать в браузере в режиме инкогнито во избежании последующего удивления почему ничего не работает). Заходим заново под нашей учетной записью и после того, как вы введем наш логин и пароль нас поприветствует окно регистрации устройства с TOTP. Сканируем код со смартфоном с вашим приложением для TOTP кодов, вводим полученный шестизначный код. Все, устройство зарегистрировано. Теперь при каждом логине, после введения логина и пароля нам надо будет ввести 6-значный код и нашего приложения аутентификатора. 

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/4.png)

>[!WARNING}
>6-значный код, который генерирует приложение на смартфоне действует как правило 30 секунд. Поэтому крайне важно чтобы у вас везде был правильно настроен часовой пояс, в особенности в Authentik. В противном случае при рассинхронизации устройств, есть риск, что ваш код устареет до того, как вы его попробуете ввести его в Authentik


## Настройка WebAuthn

WebAuthn (Web Authentication API) — это стандарт от W3C и FIDO Alliance, который позволяет входить в систему с помощью криптографических ключей, встроенных в устройство. Это отпечаток пальца, Windows Hello, Face ID и т.д

На самом деле весь порядок действий абсолютно идентичен тому, что мы с вами делали с TOTP, кроме того одного.
Переходим `Flow and Stages` > `Flows` > `default-authentication-flow`. В `default-authentication-flow` переходим в `Stage Bindings`,  вносим изменения в дефолтный этап `default-authentication-mfa-validation`. К существующему TOTP добавляем  `WebAuthn Authenticator Setup Stage`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/5.png)

В разделе `not configured action` оставляем `force the user to configure an authenticator`.

Выходим из под аккаунта и теперь когда мы с вами попробуем зайти с нашего мобильного устройства или компа с помощью отпечатка пальца или лица, то у нас будет выбор: totp или webauthn. Обратите внимание, что если на вашем аккаунте уже зарегистрирован какой-то из вариантов "двухфакторки", то вас не будет списка из которого нужно выбрать метод аутентификации, так как вы уже сделали выбор в пользу какого-то одного метода раньше. Поэтому если хотите добавить еще один вариант к уже существующему, то тут уже придется руками добавлять в настройках пользователя. Теперь, в следующий раз у вас уже будет варианты "двухфакторки" на выбор.


## Passwordless Login

Как я указывал выше, на сайте есть статья рассказывающая об особенностях passwordless login и почему не надо противопоставлять webauthn и passwordless login. Конкретно в нашем случае, Passwordless login позволит нам не вводить логин и пароль, а потом сканировать отпечаток пальца или лицо, а сразу сканировать. Скан выступает как подтверждение и логина и пароля.

> [!NOTE]
>Для настройки passwordless login обязательно предварительно настроить WebAuthn метод входа


Переходим `Flow and Stages` > `Flows` > `Create`.

Создаем новый поток. Задаете имя потока которое вы считаете подходящим. В качестве `Designation` выбираем `Authentication` и `Create`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/6.png)


В разделе `Flows` кликаем на наш новый `flow` > `Stage Bindings` > `Create and bind stage` > `Authenticator Validation Stage`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/7.png)


`Next`. Опять задаем имя нашему этапу. В разделе `Device Classes` выбираем WebAuthn. Это нужно потому что пока есть поддержка только ключей безопасности, типа Yubikey, или биометрии.

В разделе `not configured action` оставляем `force the user to configure an authenticator`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/8.png)

Опускаемся немного вниз и в поле `WebAuthn User verification` выбираем тот вариант который нужен именно вам. Я выбираю `User verification must occur`. В разделе `Configuration Stages` выбираем `WebAuthn Authenticator Setup Stage`.


![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/9.png)

Жмем `Next` и в следующем меню выбираем порядок исполнения этапа и `evaluate when stage is run`. 

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/10.png)

Это еще не все. Теперь нам надо привязать существующий этап входа в систему.

`Bind existing stage`, выбираем `default-authentication-login` и порядок выполнения этого этапа, который в обязательном порядке должен исполняться после созданного в этом разделе нового этапа. Обязательно выбираем `evaluate when stage is run`, затем `Create`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/11.png)

Переходим во `Flows` > `default-authentication-flow` > `Stage Bindings` > `default-authentication-identification` > `Edit Stage`. Идем в самый низ и в качестве `Passwordless flow` выбираем созданный поток, в моем случае `passwordless-web-authn` > `Update`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/12.png)

Выходим из приложения, теперь все зависит от того за каким устройством вы сидите. Если за ноутбуком, то вам предложат вставить юсб ключ, спокойно жмете cancel и дальше выбираете тот метод который вы предпочитаете. То же самое с мобильными устройствами. 
В любом случае у вас окне входа в приложении появилась новая кнопка по использованию ключа.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-two-factor-authentication/13.png)


