---
title: "Nextcloud в Proxmox: Полная установка в LXC без Docker"
published: 2025-10-25
pinned: false
description: Пошаговое руководство по установке Nextcloud на Ubuntu 24.04 LTS в LXC-контейнере Proxmox с Apache, MariaDB, PHP-FPM, Redis, OPCache и APCu. Интерактивный гайд с копируемыми командами.
tags:
  - Nextcloud
  - Docker
slug: /nextcloud-in-lxc
categories: Nextcloud
licenseName: CC BY 4.0
author: Stilicho2011
draft: false
series:
  - Nextcloud
youtube_id: dZ5qid6fS4g
toc: true
showDate: true
showDateUpdated: true
showReadingTime: true
showAuthor: true
cover: ./featured.png
summary: Подробная инструкция по установке и настройке Nextcloud внутри LXC-контейнера. Рассмотрены шаги по развертыванию, настройке пользователей, хранилища и веб-интерфейса, чтобы безопасно и эффективно управлять личным облачным сервером.
---


<iframe width="100%" height="468" src="https://www.youtube.com/embed/dZ5qid6fS4g?si=3FOX0dNO_0UdBFEo" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

# Установка полноценного Nextcloud в LXC контейнер в Proxmox {#установка-полноценного-nextcloud-в-lxc-контейнер-в-proxmox .relative .group}

Если вам понравилась настоящая статья, то можете поддержать автора став спонсором на бусти (ссылка в разделе контакты).

---
В этом видео я покажу, как с нуля установить Nextcloud — без Docker, на полноценный стек Apache, MariaDB и PHP. Безопасно и стабильно, стильно и молодежно. А также этот вариант, который я покажу сегодня, выдержит нагрузки даже малосреднего офиса, не говоря уже про домашнее использование.

Но прежде всего я хотел бы поблагодарить своих спонсоров на бусти. Ребята, огромное, большое вам спасибо за то что помогаете развитию этого канала. Канал живет исключительно с вашей помощью. А Ваша помощь идет исключительно на развитие этого канала. Ну а те кто не в курсе, на бусти, для спонсоров, я выкладываю ролики раньше, до месяца раньше, чем они появляются в открытом доступе, поэтому: если вам нравится контент, который выходит на этом канале; вы хотите поддержать развитие этого канала; может быть вы просто хотите посмотреть что-то пораньше, то ссылка на бусти и все остальные контакты, телеграмм, запасные каналы на отечественных площадках, будут в описании.

У меня на канале уже есть два ролика, посвященных непосредственно особенностям установки Nextcloud AIO и Nextcloud в докере. В том числе есть ролики про установку и связку OnlyOffice с Nextcloud, а также галереи Memories. Этот ролик будет финальным в серии. Но это не точно.

### Ссылки на другие варианты установки

<iframe width="560" height="315" src="https://www.youtube.com/embed/LOox1g4HfcU?si=f-ent8y1TRUyqqls" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/QNww--MNYqU?si=_kuFVYK6Lq6Aqj9h" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

В этом ролике установим полноценный Nextcloud, но с определенными особенностями. Однако сначала, по законам жанра, я должен рассказать неофитам, что такое Nextcloud.
Nextcloud — это самостоятельный облачный сервис с открытым исходным кодом, который позволяет хранить, синхронизировать и совместно использовать файлы, а также расширять функциональность за счёт встроенных приложений: календарей, видеозвонков, заметок, редакторов документов и т.д.
Поэтому когда вы слышите, что Nextcloud замена коммерческим облачным хранилищам, посмотрите на этого человека снисходительно, мол, молодой ты ищо, ничего не понимаешь, салага.
Некстклауд давно перешел тут границу нормальности, когда это было просто облачное хранилище. Сейчас это конкурент таким решениями как Google Workspace и аналоги.

Теперь поговорим об особенностях сегодняшней установки.
Официальных сборок Некстклада всего две. Это то, что мы установим сегодня и Nextcloud AIO (там по моему вообще один человек все это собирает). Все остальное это коммюнити.
В роликах про установку полноценного Nextcloud вы обычно видите, как люди ставят все в ВМ, устанавливают туда потом certbot, устанавливают nginx или ngrok, выпускают ssl сертификат. Все это мы делать не будем. Почему?
У нас есть свой обратный прокси и пользоваться мы будем именно им.
Устанавливать мы все будем в LXC контейнер. Сейчас суровые админы должны закричать на меня, мол, что ты делаешь, так нельзя. Нельзя, в продакшене нельзя, а дома можно.
Почему LXC? Потому что мы туда можем прокинуть встроенное в процессор видеоядро, и при этом еще можно будет это же видеоядро использовать и в других контейнерах. Как прокидывается видеоядро смотрите предыдущий ролик у меня на канале.

<iframe width="560" height="315" src="https://www.youtube.com/embed/y_SWcKEo_0g?si=RbWjPLWW5JELShlF" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

У меня уже создан lxc контейнер, и обратный прокси настроен на выпуск сертификата на айпи по которому находится наш контейнер и порт 80. Я предполагаю, что вы знаете как настраивать конкретно ваш обратный прокси.
Все, вступление закончилось.

Поехали.

### Шаг 1: Обновляем систему

1. Обновляем пакеты и настраиваем кодировку:

```yaml
sudo su
```

```yaml
apt update && apt upgrade -y
```

```yaml
dpkg-reconfigure locales
```

### Шаг 2: Устанавливаем Apache2 и PHP Modules

1. Устанавливаем Apache2:

```yaml
apt install apache2 -y
```

1. Устанавливаем зависимости:

```yaml
apt install php php-common libapache2-mod-php php-bz2 php-gd php-mysql php-curl php-mbstring php-imagick php-zip php-common php-curl php-xml php-json php-bcmath php-xml php-intl php-gmp zip unzip wget smbclient libmagickcore-6.q16-7-extra ffmpeg intel-media-va-driver-non-free ffmpeg va-driver-all ocl-icd-libopencl1 intel-opencl-icd vainfo intel-gpu-tools -y
```

1. Активируем необходимые модули Apache:

```yaml
a2enmod env rewrite dir mime headers setenvif ssl
```

1. Перезапускаем, включаем и проверяем работоспособность Apache.

```yaml
systemctl restart apache2
systemctl enable apache2
systemctl status apache2
```

1. Проверяем загрузку модулей Apache:

```yaml
apache2ctl -M
```

### Шаг 3: Устанавливаем и конфигурируем MariaDB сервер

1. Install mariadb-server package:

```yaml
apt install mariadb-server -y
```

1. Заходим в MariaDB:

```yaml
mysql
```

1. Создаем базу данных и пользователя для Nextcloud и задаем необходимые разрешения пользователю:

```yaml
CREATE USER 'ncloud'@'localhost' IDENTIFIED BY 'admin123';
CREATE DATABASE ncloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES ON ncloud.* TO 'ncloud'@'localhost';
FLUSH PRIVILEGES;
quit;
```

1. Перезапускаем и активируем MariaDB:

```yaml
systemctl restart mariadb
systemctl enable mariadb
```

1. Проверяем, что MariaDB запущенна:

```yaml
systemctl status mariadb
```

### Шаг 4: Загружаем, разархивируем и задаем разрешения Nextcloud

1. Загружаем и разархивируем в папку /var/www/html:

```yaml
cd /var/www/html
wget https://download.nextcloud.com/server/releases/latest.zip
unzip latest.zip
```

1. Удалем ненужный архив:

```yaml
rm -rf latest.zip
```

1. Задаем права на папку:

```yaml
chown -R www-data:www-data /var/www/html/nextcloud/
```

### Шаг 5: Устанавливаем Nextcloud из командной строки

1. Запускаем приведенную ниже команду для инсталяции nextcloud (нужно внести свои данные конечно)

```yaml
cd /var/www/html/nextcloud
```

```yaml
sudo -u www-data php occ  maintenance:install --database \
"mysql" --database-name "ncloud"  --database-user "ncloud" --database-pass \
'admin123' --admin-user "admin" --admin-pass "password"
```

1. Nextcloud разрешает доступ только с локального хоста, это может привести к ошибке «Доступ через недоверенный домен». Нам нужно разрешить доступ к Nextcloud, используя IP-адрес или доменное имя

```yaml
sudo nano /var/www/html/nextcloud/config/config.php

  'trusted_domains' =>
  array (
    0 => 'localhost',
    1 => 'nextcloud.your_domain.ru',   // we Included the Sub Domain
  ),
  'overwritehost' => 'nextcloud.your_domain.ru',
  'overwriteprotocol' => 'https',
  'overwrite.cli.url' => 'https://nextcloud.your_domain.ru',
  'trusted_proxies' => 
  array (
    0 => '192.168.0.0/16',
    1 => '172.16.0.0/12',
    2 => '10.0.0.0/8',
    3 => 'fc00::/7',
    4 => 'fe80::/10',
    5 => '2001:db8::/32',
   ),
  'default_phone_region' => 'RU',
  'allow_local_remote_servers' => true,
  
```

1. Настройте Apache для загрузки Nextcloud из папки /var/www/html/nextcloud:

```yaml
nano /etc/apache2/sites-enabled/000-default.conf

<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html/nextcloud
        
        <Directory /var/www/html/nextcloud>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
       
 ServerName nextcloud.yourdomain.ru
        <IfModule mod_headers.c>
            Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
        </IfModule>
        
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```

1. Перезапускаем Apache:

```yaml
systemctl restart apache2
```

1. Теперь перейдите в браузер и введите http://[ip или полное доменное имя] сервера. Появится страница входа в Nextcloud, показанная ниже.

### Шаг 6: Установка и настройка PHP-FPM с Apache

1. Установка PHP-FPM: #проверьте актуальную версию

```yaml
apt install php8.3-fpm 
```

1. Проверьте, запущен ли PHP-FPM, его версию и создан ли сокет:

```yaml
service php8.3-fpm status
php-fpm8.3 -v
ls -la /var/run/php/php8.3-fpm.sock
```

1. Отключите mod_php и модуль prefork:

```yaml
a2dismod php8.3
a2dismod mpm_prefork
```

1. Активируйте PHP-FPM:

```yaml
a2enmod mpm_event proxy_fcgi setenvif
a2enconf php8.3-fpm
```

1. Перезапустите Apache, чтобы перезагрузить все модули и конфигурации:

```yaml
systemctl restart apache2
```

Теперь, чтобы настроить размер загружаемого файла и производительность, нам нужно изменить некоторые параметры php.ini, перечисленные ниже в файле /etc/php/8.3/fpm/php.ini. Вы можете задать собственные значения в зависимости от вашей среды.

```yaml
upload_max_filesize = 64M
post_max_size = 96M
memory_limit = 512M
max_execution_time = 600
max_input_vars = 3000
max_input_time = 1000
```

1. Проверьте текущее значение:

```yaml
grep -E "upload_max_filesize|post_max_size|memory_limit|max_execution_time|max_input_vars|max_input_time" /etc/php/8.3/fpm/php.ini
```

1. Вместо ручного внесения изменений вы можете выполнить следующую команду для немедленного внесения изменений. Это сэкономит время.

```yaml
sed -i 's/^upload_max_filesize.*/upload_max_filesize = 64M/; s/^post_max_size.*/post_max_size = 96M/; s/^memory_limit.*/memory_limit = 512M/; s/^max_execution_time.*/max_execution_time = 600/; s/^;max_input_vars.*/max_input_vars = 3000/; s/^max_input_time.*/max_input_time = 1000/' /etc/php/8.3/fpm/php.ini
```

или

```yaml
sed -i 's/^upload_max_filesize.*/upload_max_filesize = 16G/; s/^post_max_size.*/post_max_size = 16G/; s/^memory_limit.*/memory_limit = 2048M/; s/^max_execution_time.*/max_execution_time = 3600/; s/^;max_input_vars.*/max_input_vars = 3600/; s/^max_input_time.*/max_input_time = 3600/' /etc/php/8.3/fpm/php.ini
```

Теперь нам нужно обновить конфигурации пула PHP-FPM в `/etc/php/8.3/fpm/pool.d/ www.conf`. Ниже приведены некоторые оптимальные значения, но вам следует задать свои собственные значения.

```yaml
pm.max_children = 64
pm.start_servers = 16
pm.min_spare_servers = 16
pm.max_spare_servers = 32
```

1. Проверим текущии значения:

```yaml
grep -E "pm.max_children|pm.start_servers|pm.min_spare_servers|pm.max_spare_servers" /etc/php/8.3/fpm/pool.d/www.conf
```

1. Измените все значения одновременно с помощью следующей команды:

```yaml
sed -i 's/^pm.max_children = .*/pm.max_children = 64/; s/^pm.start_servers = .*/pm.start_servers = 16/; s/^pm.min_spare_servers = .*/pm.min_spare_servers = 16/; s/^pm.max_spare_servers = .*/pm.max_spare_servers = 32/' /etc/php/8.3/fpm/pool.d/www.conf
```

или

```yaml
sed -i 's/^pm.max_children = .*/pm.max_children = 70/; s/^pm.start_servers = .*/pm.start_servers = 20/; s/^pm.min_spare_servers = .*/pm.min_spare_servers = 20/; s/^pm.max_spare_servers = .*/pm.max_spare_servers = 60/' /etc/php/8.3/fpm/pool.d/www.conf
```

1. Теперь перезапустите PHP-FPM, чтобы применить все изменения:

```yaml
service php8.3-fpm restart
```

Теперь вставьте приведенный ниже код в файл конфигурации сайта Apache по умолчанию /etc/apache2/sites-enabled/000-default.conf, он укажет Apache передать обработку PHP-файла PHP-FPM.

```yaml
    <FilesMatch ".php$">
         SetHandler "proxy:unix:/var/run/php/php8.3-fpm.sock|fcgi://localhost/"
    </FilesMatch>
```

---

1. После предоставления кода конфигурация сайта Apache по умолчанию будет выглядеть так, как показано ниже::

```yaml
nano /etc/apache2/sites-enabled/000-default.conf 
```

```
<VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        #ServerName www.example.com

        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html/nextcloud

        <Directory /var/www/html/nextcloud>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
           
        <FilesMatch ".php$"> 
            SetHandler "proxy:unix:/var/run/php/php8.3-fpm.sock|fcgi://localhost/"
        </FilesMatch>   
            
        ServerName nextcloud.your_domain.ru
        <IfModule mod_headers.c>
            Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
        </IfModule>

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with "a2disconf".
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>
```

1. Теперь перезапустите Apache, чтобы изменения вступили в силу:

```yaml
systemctl restart apache2
```

### Шаг 7: Создайте страницу info.php для проверки функций PHP (опционально. После завершения проверки, файл надо удалить)

Создайте страницу info.php, она покажет нам, включены ли PHP-FPM, OPCache, APCu в PHP..

```
cd /var/www/html/nextcloud
```

```yaml
nano info.php
```

```yaml
<?php phpinfo(); ?>
```

Теперь перейдите по адресу [URL]/info.php. Если PHP-FPM включён в PHP, будет показано «Server API FPM/FastCGI».

### Шаг 8: Включите OPCache в PHP

1. Включите OPCache в PHP:
Проверьте, запущен ли он, с помощью файла [URL]/info.php, который мы создали ранее.

JIT-компиляция (Just-In-Time) Opcache — важная функция. JIT-компиляция повышает производительность PHP, компилируя код в машинный язык во время выполнения, а не интерпретируя его при каждом запуске. Это может значительно повысить производительность ресурсоёмких задач. Поэтому её включение будет очень эффективным для повышения производительности Nextcloud.

```yaml
nano /etc/php/8.3/fpm/conf.d/10-opcache.ini

zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=12000
opcache.memory_consumption=512
opcache.save_comments=1
opcache.revalidate_freq=60
opcache.jit=on
opcache.jit = 1255
opcache.jit_buffer_size = 256M
```

1. Перезапустите PHP-FPM, чтобы изменения вступили в силу:

```yaml
service php8.3-fpm restart
```

### Шаг 9: Включите APCu в PHP

1. Включить APCu в PHP:

```yaml
apt install php8.3-apcu
```

```yaml
nano /etc/php/8.3/fpm/conf.d/20-apcu.ini
```

```yaml
extension=apcu.so
apc.enable_cli=1
```

Теперь перезапустите PHP-FPM и Apache.

```yaml
systemctl restart php8.3-fpm
systemctl restart apache2
```

Теперь проверьте [URL]/info.php еще раз, он покажет «Поддержка APCu включена» (“APCu support Enabled”).

1. Настройте Nextcloud на использование APCu для кэширования памяти:

```yaml
nano /var/www/html/nextcloud/config/config.php
```

```yaml
'memcache.local' => '\OC\Memcache\APCu',
```

### Шаг 10: Установка и настройка Redis Cache

1. Установка и настройка Redis Cache
В Nextcloud Redis используется для локального и распределенного кэширования, а также для транзакционной блокировки файлов. Для локального кэширования мы использовали APCu, который быстрее Redis. Redis будет использоваться для блокировки файлов. Механизм транзакционной блокировки файлов Nextcloud блокирует файлы, предотвращая их повреждение во время нормальной работы.

2. Установите Redis Server и расширение Redis php

```yaml
apt install redis-server php-redis -y
```

1. Запустите и включите службу Redis.

```yaml
systemctl start redis-server
systemctl enable redis-server
systemctl status redis-server
```

1. Настройте Redis для использования Unix Socket вместо портов

```yaml
nano /etc/redis/redis.conf
```

```yaml
port 0
unixsocket /var/run/redis/redis.sock
unixsocketperm 770
```

1. Добавьте пользователя Apache в группу Redis

```yaml
usermod -a -G redis www-data
```

1. Настройте Nextcloud для использования Redis для блокировки файлов

```yaml
nano /var/www/html/nextcloud/config/config.php
```

```yaml
'filelocking.enabled' => 'true',
'memcache.distributed' => '\\OC\\Memcache\\Redis',
'memcache.locking' => '\\OC\\Memcache\\Redis',
'redis' => [
     'host'     => '/var/run/redis/redis.sock',
     'port'     => 0,
     'dbindex'  => 0,
     'password' => '',
     'timeout'  => 1.5,
],
```

1. Включите блокировку сеанса Redis в PHP

```yaml
nano /etc/php/8.3/fpm/php.ini
```

```yaml
redis.session.locking_enabled=1
redis.session.lock_retries=-1
redis.session.lock_wait_time=10000
```

1. Перезапустите Redis, PHP-FPM и Apache

```yaml
systemctl restart redis-server
systemctl restart php8.3-fpm
systemctl restart apache2
```

1. Вы можете проверить, включены ли функции в PHP

```yaml
nextcloud-ubuntu-24.04-redis
Redis is Installed for Nextcloud
```

<https://help.nextcloud.com/t/installing-redis-for-memcache/162599/6>

1. Я предполагаю, что вы используете traefik в качестве обратного прокси-сервера, и вам не нужен certbot. Поэтому мы добавили соответствующие значения в /etc/apache2/sites-enabled/000-default.conf.

2. Включаем Pretty URL’s:

```yaml
nano /var/www/html/nextcloud/config/config.php
```

```yaml
'htaccess.RewriteBase' => '/',
```

Эта команда обновит файл .htaccess для переадресации

```yaml
sudo -u www-data php --define apc.enable_cli=1 /var/www/html/nextcloud/occ maintenance:update:htaccess
```

1. Другие необходимые команды

```yaml
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:repair --include-expensive
```

```yaml
sudo -u www-data php /var/www/html/nextcloud/occ db:add-missing-indices
```

```yaml
sudo -u www-data php /var/www/html/nextcloud/occ config:system:set maintenance_window_start --type=integer --value=1
```

```yaml
sudo crontab -u www-data -e
```

```yaml
*/5  *  *  *  * php -f /var/www/html/nextcloud/cron.php
```

```yaml
sudo -u www-data php /var/www/html/nextcloud/occ files:scan --all
```

```yaml
sudo -u www-data php /var/www/html/nextcloud/occ app:update --all
```
