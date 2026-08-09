---
title: Настройка восстановления пароля в Authentik
published: 2026-01-12
pinned: false
description: "Пошаговая инструкция по настройке восстановления пароля в Authentik: flows, stages, policies и рекомендации по безопасности."
tags:
  - SSO
  - Docker
  - Self-Hosting
  - Authentik
slug: /authentik-password-recovery
categories: SSO
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Authentik
youtube_id: WUU9wFVNsvQ
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Подробное руководство по настройке восстановления пароля в Authentik с разбором flows, stages и policies, а также рекомендациями по защите от username enumeration атак.
---

> [!NOTE]
>**В случае, если вы нашли данную статью полезной и считаете возможным отблагодарить автора, то это можно сделать по соответствующей ссылке на** [**boosty**](https://boosty.to/stilicho2011)

# Восстановление пароля в Authentik

Как администратор (даже если мы говорим о homelab) прежде всего мы должны **заставить** (да, да) наших существующих или будущих пользователей создавать сложные пароли, а не столь любимые маглами простые пароли типа `12345` или `password123`. В этой статье мы поговорим как это сделать, а также настроим возможность для пользователей восстанавливать пароли самостоятельно (в случае если вы, как администратор, этого хотите).

Для данной настройки, да и в принципе для правильной работы AUthentik в будущем, вы должны были настроить в файле переменных окружения `.env` данные вашего почтового сервера, с которого будут приходить уведомления как вам, так и пользователям. Проверить корректность настройки почтового сервера можно простой командой `docker exec authentik_worker ak test_email ваша_почта@домен.com`

> [!NOTE]
>Настройки приложения описанные в это статье актуальны на дату написания статьи

> [!NOTE]
>Видео гайд по ссылке ниже актуален на дату создания, но логика настройки не изменилась


<iframe width="100%" height="468" src="https://www.youtube.com/embed/WUU9wFVNsvQ?si=cgu4AYumu9hpcyOo" title="YouTube video player" frameborder="0" allowfullscreen></iframe>

## Создание политики для настроек сложности пароля

Идем в раздел `Customisation` > `Policies`. Жмем кнопку `Create`. Выбираем политику `Password Policy`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/17.png)

Прежде всего задаете имя политики. Я предпочитаю в Authentik задавать имена с маленькой буквы, чтобы названия не выбивались из общего вида, так как дефолтные названия в Authentik начинаются со маленькой буквы. Предположим, наша политика будет называться `password-complexity`. Вы вправе задавать любое название на любом удобном вам языке. Скроллим ниже и в разделе `Static rules` задаем параметры сложности пароля, то есть длина пароля, количество символов и так далее.

В разделе `Error Message` указываем сообщение, которое будет отображаться в случае, если пользователь задает пароль, который не соответствует настроенной вами политике.

У меня получилось что-то вроде такого:

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/15.png)

Все остальные строки в этом меню оставляем по умолчанию.

Жмем `Finish`.

## Создание Flows и Stages

Теперь нам надо создать `Flow` (потоки) и `Stages` (этапы).

В разделе `Flow and Stages` выбираем `Stages`. Нам надо создать два этапа.

### Identification Stage

Первый — идентификация пользователя. Жмем `Create > Identification Stage`. К сожалению, из-за бага в версии приложения 2025.10.3 часть меню у меня отображается на русском языке, несмотря на прямой запрет в приложении автоматического перевода, но, думаю, смысл вы поняли.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/2.png)

Нажимаем `Next`. В следующем меню задаем название этапу, что-то вроде `recovery-authentication-identification`. 

В пользовательских данных выбираем `Username и Email`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/1.png)

Остальные разделы меню пока не трогаем, на данном этапе настройки они нам пока не понадобятся. Жмем `Finish`.

Следующий этап, который нам надо создать — восстановление пароля с подтверждением по почте.

### Email Stage

В разделе `Flow and Stages` выбираем `Stages > Create > Email Stage`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/16.png)

В теме письма можно указать что-то типа «Восстановление пароля». В качестве шаблона оставьте `Password Reset`. Жмем `Finish`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/11.png)

Теперь нам нужно создать поток восстановления пароля.

### Recovery Flow

В `Flow and Stages` выбираем `Flows > Create`.

Задаете значения по образу и подобию, как вы видите на скриншоте ниже. Я активировал `compatibility mode` — это улучшает совместимость с менеджерами паролей и мобильными устройствами.

Остальные значения я оставил по умолчанию, но если вам нужна дополнительная кастомизация каждого отдельного потока, вы вправе вносить соответствующие изменения.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/10.png)

В разделе `Flows` кликаем на тот поток, который мы только что создали, в моем случае он называется `recovery`, и выбираем `Stage Bindings`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/5.png)

Жмем `Bind existing stage` и в меню выбираем этап `recovery-authentication-identification`, который мы создали ранее (как вы, наверное, поняли, создавать этапы можно и из этого меню, нажав `Create and Bind Stage`, но мне кажется, мой вариант более наглядный).

В качестве порядкового номера обработки этапа оставляем `0`. Жмем `Finish`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/13.png)

Опять привязываем этап `Bind existing stage` и здесь выбираем этап по восстановлению пароля. Порядок обработки этапа я указал `10`, потому что удобнее работать такими значениями, чтобы всегда оставалось место для новых этапов, в случае если они понадобятся (да и разработчики сами так делают). Жмем `Finish`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/6.png)

Привязываем еще один этап, но уже существующий по умолчанию: `Bind existing stage > default-password-change-prompt`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/9.png)

И последний этап для этого потока — `Bind existing stage > default-password-change-write`. Опять обратите внимание на очередность обработки этапов.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/0.png)

В итоге у нас получается следующая картина:

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/14.png)

Еще раз обратите внимание на порядок обработки этапов.

Теперь в этом меню выбираем `default-password-change-prompt` и жмем `Edit Stage`. В разделе `Validation Policies` необходимо выбрать ранее созданную политику `password-complexity` и перетащить ее в меню справа. Жмем `Update`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/4.png)

## Настройка Authentication Flow

Переходим на основную страницу `Flows`, выбираем `default-authentication-flow > Stage bindings`.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/12.png)

На этой странице выбираем `Edit stage` напротив `default-authentication-identification`.

> [!TIP]
>В разделе `Password Stage` вы можете выбрать `default-authentication-password`. Как указано ниже: «Если этот параметр включён, поле ввода пароля отображается на той же странице, а не на отдельной. Это предотвращает атаки по перебору имён пользователей (username enumeration)». Вроде бы это хороший параметр, но если вы захотите в последующем отключить проверку для локальных адресов (в будущем я покажу, как это делать), то этот параметр нужно будет отключить. Поэтому в данном случае решение за вами.


Скроллим в самый низ меню и в разделе `Recovery Flow` выбираем тот поток для восстановления пароля, который мы создали ранее.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/19.png)

Жмем `Update`.

В случае если вы выбрали в разделе `Password Stage` — `default-authentication-password`, то в основном меню этого `Flow` вам надо удалить этап `default-authentication-password`. В противном случае он вступает в конфликт с выбранной настройкой.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/3.png)

## Результат

Выходим из-под нашего аккаунта, и на странице приветствия внизу появляется надпись с предложением по восстановлению логина или пароля пользователя. В случае если вы настроили отображение одновременно имени пользователя и пароля, то у вас уже появится меню по вводу пароля на этой странице.

![Authentik login screen](01-Projects/Prohomelab/Authentik/authentik-password-recovery/7.png)

Дальше все достаточно просто и интуитивно понятно. Выбираете соответствующее меню, вводите адрес почты пользователя, пароль которого вы забыли, на почту вам приходит соответствующее уведомление с предложением перейти по ссылке, где вам Authentik предложит создать новый пароль по заданной нами политике сложности пароля.

Теперь ваши будущие пользователи смогут самостоятельно регистрироваться в приложении или восстанавливать забытые пароли.
