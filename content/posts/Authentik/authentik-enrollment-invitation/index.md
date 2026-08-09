---
title: Настройка процессов регистрации и приглашений пользователей в Authentik
published: 2026-01-13
pinned: false
description: Подробная инструкция по настройке процессов регистрации и приглашения пользователей в Authentik с разбором enrollment flow, invitation flow и связанных stages.
tags:
  - SSO
  - Docker
  - Self-Hosting
  - Authentik
slug: /authentik-enrollment-invitation
categories: SSO
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Authentik
youtube_id: hKGW2PKnZc8
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: "Руководство по настройке enrollment и invitation flow в Authentik: регистрация новых пользователей, приглашения, stages, flows и политики доступа."
---

> [!NOTE]
>**В случае, если вы нашли данную статью полезной и считаете возможным отблагодарить автора, то это можно сделать по соответствующей ссылке на** [**boosty**](https://boosty.to/stilicho2011)

Как администратор в Authentik вы можете вручную создавать, удалять пользователей, генерировать им сложные пароли и создавать для них правила входа с помощью TOTP-кодов или WebAuthn-устройств. Безусловно, это рабочий механизм, но что если таких пользователей много? Или если даже мы говорим о каком-то домашнем использовании, вы просто хотите автоматизировать процесс таким образом, чтобы вы занимались только управленческой работой?
В этой статье поговорим как настроить такую автоматизацию по регистрации и приглашения пользователей в Authentik.

> [!TIP]
>Для данной настройки, да и в принципе для правильной работы AUthentik в будущем, вы должны были настроить в файле переменных окружения `.env` данные вашего почтового сервера, с которого будут приходить уведомления как вам, так и пользователям. Проверить корректность настройки почтового сервера можно простой командой `docker exec authentik_worker ak test_email ваша_почта@домен.com`

> [!NOTE]
>Настройки приложения описанные в это статье актуальны на дату написания статьи

> [!NOTE]
>Видео гайд по ссылке ниже актуален на дату создания, но логика настройки не изменилась


<iframe width="100%" height="468" src="https://www.youtube.com/embed/hKGW2PKnZc8?si=AMZImO41FUH08q3z" title="YouTube video player" frameborder="0" allowfullscreen></iframe>

## Создание группы для обычных пользователей

В интерфейсе Authentik переходим в раздел `Directory > Groups > New Group`

В появившемся окне задаем название нашей группы. Так как это будут обычные пользователи, то мы не переключаем рычажок в положение `Superuser Privileges`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/0.png)

Жмем `Create`

Отвечая на незаданный вопрос "почему я так странно назвал группу: первое слово со строчной буквы, а потом заглавная?", поясню, что дефолтная группа для админов именно с таким написанием `authentik Admins`. Соблюдаю стиль.

## Создание этапов и потоков

### Этап Email Stage

Переходим во `Flows and Stages` > `Stages` > `Create`

В появившемся меню выбираем `Email Stage`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/1.png)

Жмем `Next` и в следующем окне задаем необходимые параметры: задаем название этапа, тему письма и шаблон, который будет использоваться. Жмем `Finish`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/2.png)

### Создание потока для приглашений

Переходим во `Flows` > `Create`

Описываем и задаем необходимые параметры примерно как на скриншоте ниже. Я активировал `compatibility mode` для лучшей работы с менеджерами паролей. В графе `Authentication` я не установил каких-то обязательных параметров. Сделал я это намеренно, в будущем я задам жесткое требование для всех пользователей без исключения создавать двухфакторную аутентификацию.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/3.png)

Теперь переходим в наш созданный поток `Enrollment` > `Stage Bindings` > `Bind existing stage` (как вы, наверное, поняли, создавать этапы можно и из этого меню, нажав `Create and Bind Stage`, но мне кажется, мой вариант более наглядный).

В появившемся меню заполняем по образу и подобию того, как у меня на скриншоте. Выбираем уже существующий этап `default-source-enrollment-prompt`, задаем порядок исполнения этого этапа.

:::note
Обратите внимание, что у меня активирован рычажок напротив `evaluate when flow is planned`. Если разбираетесь в вопросе, можете выбрать и другой пункт меню.
:::

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/4.png)

Теперь надо внести изменения во вновь созданный этап. Жмем `Edit Stage` и выбираем необходимые нам поля с данными, которые, в свою очередь, должны будут заполнять новые юзеры при регистрации.

Выбираем следующие значения `name` `email` `password` `repeat password`. Значение `username` уже выбрано по умолчанию. В разделе **Validation Policy** выбираем созданное нами `password complexity` (как задавать значения сложности пароля можно прочитать в статье, [посвященной восстановлению пароля](https://prohomelab.com/posts/authentik-password-recovery/)). Жмем `Update`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/5.png)

Теперь создаем новую привязку stage к flow, опять жмем `Bind existing stage` > `default-source-enrollment-write`, задаем порядок исполнения, жмем `Create`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/6.png)

Как и в предыдущий раз, внесем изменения в созданный этап > `Edit Stage`

Активируем опцию `Create users as inactive`. Это нужно для того, чтобы после того, как новые пользователи внесут свои данные и зарегистрируются в системе, их аккаунт будет неактивен, пока они не подтвердят свое действие по email.
В качестве `Group` выбираем созданную группу `authentik Users`. Обязательно в разделе `User type` выбираем `internal`

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/7.png)

Еще раз жмем `Bind existing stage`, выбираем `email-account-confirmation`, который мы с вами создавали ранее, задаем порядок исполнения, жмем `Create`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/8.png)

Можно проверить настройки этого этапа.
На самом деле редактировать тут особо нечего, просто проверяем, что у нас активирована функция **Activate pending users on success**.
В случае, если у вас не настроена почта с помощью переменных окружения, то деактивируйте функцию по использованию `global settings`. У вас появятся новые поля, которые вы должны будете заполнить соответствующими значениями, которые вы получили у вашего email-провайдера.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/9.png)

## Настройка default-authentication-flow

Переходим во `Flows`, выбираем наш поток аутентификации, в моем случае `default-authentication-flow`, переходим в меню `Stage Bindings` и вносим изменения в `default-authentication-identification` этап. Скроллим в самый низ, в меню `Flow Settings` в разделе `Enrollment Flow` выбираем вновь созданный поток и жмем `Update`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/10.png)

Выходим из нашего аккаунта и проверяем меню входа (безусловно, все это нужно делать в режиме инкогнито, как минимум необходимо почистить cookies браузера).

Видим, что у нас появилось новое меню по регистрации нового пользователя.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/11.png)

Можно проверить работоспособность меню: пусть новый (тестовый) пользователь (в вашем лице) зарегистрируется, придет почта с подтверждением, кликаете на ссылку в почтовом сообщении и дальнейшие действия интуитивно понятно. Если вы все сделали правильно, а автор статьи не напортачил (как у него бывает), то у вас появился новый пользователь, который сам создал аккаунт, пароль по заданным вами параметрам и политикам, и теперь он в группе обычных пользователей.

## Настройка приглашений пользователей в Authentik

Мы с вами создали возможность новым пользователям самостоятельно регистрироваться в нашем Authentik. Но это слишком большая вольница, когда любой залетный может просто так зайти на сайт с Authentik и зарегистрироваться там. Нам же это не надо? Ведь так? Мы хотим, чтобы только избранные пользователи могли зарегистрироваться и только по приглашению. Ну или устроим массовую рассылку приглашений, но в любом случае зарегистрироваться сможет только то лицо, которому мы направили приглашение. Давайте именно такой настройкой и займемся.

### User Write Stage

Идем в `Stages`, создаем новый этап `User Write Stage` (у меня из-за бага с переводом в версии приложения 2025.10.3, который не полностью отключен, данный этап называется `Этап записи пользователя`).

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/12.png)

Жмем `Next`. Задаем необходимые параметры: название этапа и его параметры, а также в какую группу будут определены новые юзеры. Поскольку предполагается, что мы знаем, кто у нас регистрируется, то можно деактивировать меню `Create users as inactive`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/13.png)

### Invitation Stage

Опять создаем новый этап, но в этот раз `Invitation Stage` (у меня он называется `Этап приглашения`).

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/14.png)

Жмем `Next`, задаем название этапу. В случае если у вас активировано меню `Continue flow without invitation` его необходимо деактивировать.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/15.png)

Дальше идем во `Flows` > `Create` и задаем необходимые параметры. Как и раньше, я активирую режим совместимости с менеджерами паролей.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/16.png)

Теперь переходим в `enrollment invitation flow`, который мы только что создали, и жмем `Bind existing stage`.

Тут мы с вами выбираем созданный этап, задаем ему порядок исполнения и выбираем `Evaluate when flow is planned` вместо `Evaluate when stage is run`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/17.png)

Еще раз жмем `Bind existing stage` и выбираем `default-source-enrollment-prompt`, задаем ему порядок исполнения и выбираем `Evaluate when flow is planned` вместо `Evaluate when stage is run`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/18.png)

Теперь редактируем этап `default-source-enrollment-prompt` и проверяем, что у нас все как на скриншоте. В принципе, тут все аналогично настройкам, которые описаны в начале этой статьи.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/19.png)

Еще раз жмем `Bind existing stage` и выбираем `enrollment-invitation-write`, задаем ему порядок исполнения и выбираем `Evaluate when flow is planned` вместо `Evaluate when stage is run`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/20.png)

Последний раз жмем `Bind existing stage` и выбираем `default-source-enrollment-login`, задаем ему порядок исполнения и выбираем `Evaluate when flow is planned` вместо `Evaluate when stage is run`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/21.png)

## Создание приглашений

Теперь идем в `Directory` > `Invitations` > `Create`

В появившемся меню задаем название нашего приглашения, указываем время действия приглашения (можно сделать его фактически бессрочным), а также решаем, будет оно разовое — `single use` — или для многократного использования.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/22.png)

Жмем `Create`.

Теперь, чтобы получить ссылку приглашения, достаточно нажать на указанный пункт в ниспадающем меню, и мы получим нашу ссылку приглашения, которую можем отправить нашим юзерам.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/23.png)

Теперь человек, который получит такую ссылку-приглашение, перейдя по ней, попадет в меню регистрации нового пользователя, как и в предыдущем пункте.

## Прикрываем лавочку по самостоятельной регистрации пользователей

Свобода — это хорошо, но в меру. Предположим, мы зарегистрировали всех кого надо и больше никого не ждем. Сейчас мы строго-настрого запретим регистрироваться новым пользователям без нашего четкого контроля.

Идем в `Stages` > `Create` и создаем новый этап `Deny Stage`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/24.png)

Жмем `Next` и задаем название нашему этапу и пишем сообщение, которое увидит незваный гость, когда его посетит шальная мысль попробовать зарегистрироваться в нашем Authentik.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/25.png)

Переходим во `Flows` > `main-page-enrollment`, переходим в `Bind existing stage`.
Выбираем наш `Deny Stage`. В качестве порядкового номера надо выбрать любой, но с обазательным условием чтобы этот этап обрабатывался первым, в моем случае это `0`, и выбираем `Evaluate when flow is planned` вместо `Evaluate when stage is run`, после чего нажимаем `Create`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/26.png)

Теперь в режиме инкогнито попробуем зарегистрироваться в нашем Authentik, и если мы с вами все сделали правильно, то пользователь (которого мы не ждали) получит не самое приятное для него сообщение.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-enrollment-invitation/27.png)

На этом статью, которая фактически представляет из себя веселые картинки, можно закончить.
