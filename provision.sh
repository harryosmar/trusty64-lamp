#!/bin/bash

apache_config_file="/etc/apache2/envvars"
apache_vhost_front="/etc/apache2/sites-available/kurir.conf"
apache_vhost_api="/etc/apache2/sites-available/api.kurir.conf"
php_config_file="/etc/php5/apache2/php.ini"
xdebug_config_file="/etc/php5/mods-available/xdebug.ini"
mysql_config_file="/etc/mysql/my.cnf"
WORKSPACE_FRONT="var/www/html/web/kurir"
WORKSPACE_API="var/www/html/web/api.kurir"

# This function is called at the very bottom of the file
main() {
	update_go
	network_go
	tools_go
	git_go
	prepare_project_go
	apache_go
	php_go
	mysql_go
	redis_go
	start_project_go
	autoremove_go
	#node_npm_go
}

prepare_project_go()
{
    if [[ ! -e "/var/www/html/web" ]]; then
        mkdir /var/www/html/web
    fi

    // setup front
    if [[ ! -e "/var/www/html/web/kurir" ]]; then
        cd /var/www/html/web && git clone https://github.com/harryosmar/kurir.git
        cd kurir
    else
        cd /var/www/html/web/kurir
        git pull origin master
    fi

    cp -u .env.example .env
    sed -i "s/localhost:8000/kurir.dev/g" /var/www/html/web/kurir/.env
    sed -i "s/localhost:8001/api.kurir.dev/g" /var/www/html/web/kurir/.env

    // setup api
    if [[ ! -e "/var/www/html/web/api.kurir" ]]; then
        cd /var/www/html/web && git clone https://github.com/harryosmar/api.kurir.git
        cd api.kurir
    else
        cd /var/www/html/web/api.kurir
        git pull origin master
    fi
    cp -u .env.example .env
    sed -i "s/secret/root/g" /var/www/html/web/api.kurir/.env
}

start_project_go() {
    cd /var/www/html/web/kurir && composer install --no-dev
    cd /var/www/html/web/api.kurir && composer install --no-dev
    echo "CREATE DATABASE IF NOT EXISTS kurir" | mysql -u root --password=root
    cd /var/www/html/web/api.kurir && php artisan migrate:refresh --seed
}

node_npm_go() {
	apt-get install nodejs
	apt-get install npm
	npm install npm@latest -g
	npm install -g bower
	npm install -g gulp
	npm install -g grunt
}

git_go() {
	# install git
	sudo apt-get -y install git
}

redis_go() {
	apt-get -y install make

    if [[ ! -e "/opt/redis" ]]; then
	    mkdir /opt/redis
    fi

	cd /opt/redis
	# Use latest stable
	wget -q http://download.redis.io/redis-stable.tar.gz
	# Only update newer files
	tar -xz --keep-newer-files -f redis-stable.tar.gz

	cd redis-stable
	make
	make test
	make install
	if [[ -e "/etc/redis.conf" ]]; then
		rm /etc/redis.conf
	fi

	if [[ ! -e "/etc/redis" ]]; then
  		mkdir -p /etc/redis
	fi

	if [[ ! -e "/var/redis" ]]; then
		mkdir /var/redis
	fi

	chmod -R 777 /var/redis
	useradd redis

	if [ ! -f "/etc/redis/6379.conf" ]; then
		cp -u /var/www/html/redis.conf /etc/redis/6379.conf
	fi

	if [ ! -f "/etc/init.d/redis_6379" ]; then
		cp -u /var/www/html/redis.init.d /etc/init.d/redis_6379
	fi

	update-rc.d redis_6379 defaults

	chmod a+x /etc/init.d/redis_6379
	/etc/init.d/redis_6379 start
}

update_go() {
    # Add PHP 5.6 package sources
    sudo add-apt-repository ppa:ondrej/php

	# Update the server
	sudo apt-get install python-software-properties
	sudo apt-get update
    sudo apt-get upgrade
}

autoremove_go() {
	apt-get -y autoremove
}

network_go() {
	IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')
	sed -i "s/^${IPADDR}.*//" /etc/hosts
	echo ${IPADDR} ubuntu.localhost >> /etc/hosts			# Just to quiet down some error messages
}

tools_go() {
	# Install basic tools
	apt-get -y install build-essential binutils-doc git subversion
}

apache_go() {
	# Install Apache
	apt-get -y install apache2

	#sed -i "s/^\(.*\)www-data/\1vagrant/g" ${apache_config_file}
	chown -R vagrant:vagrant /var/log/apache2

	#if [ ! -f "${apache_vhost_front}" ]; then
	#fi

	cp -u /var/www/html/vhost/kurir.conf $apache_vhost_front
	cp -u /var/www/html/vhost/api.kurir.conf $apache_vhost_api

	a2ensite kurir.conf && a2ensite api.kurir.conf
    a2dissite 000-default
	a2enmod rewrite

	service apache2 reload
	update-rc.d apache2 enable
}

php_go() {
    # setup locale
    sudo locale
    sudo locale-gen "en_US.UTF-8"
    sudo dpkg-reconfigure locales

	# apt-get -y --force-yes install php5 php5-curl php5-mysql php5-sqlite php5-xdebug php-pear
	apt-get -y install php5.6 php5.6-mcrypt php5.6-mbstring php5.6-curl php5.6-cli php5.6-mysql php5.6-gd php5.6-intl php5.6-xsl php5.6-zip php5.6-sqlite php5.6-xdebug php-pear libapache2-mod-php5.6

	sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${php_config_file}
	sed -i "s/display_errors = Off/display_errors = On/g" ${php_config_file}

	if [ ! -f "{$xdebug_config_file}" ]; then
		cat << EOF > ${xdebug_config_file}
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
xdebug.remote_host=10.0.2.2
EOF
	fi

	service apache2 reload

	# Install latest version of Composer globally
	if [ ! -f "/usr/local/bin/composer" ]; then
		curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
	fi

	# Install PHP Unit 4.8 globally
	if [ ! -f "/usr/local/bin/phpunit" ]; then
		curl -O -L https://phar.phpunit.de/phpunit-old.phar
		chmod +x phpunit-old.phar
		mv phpunit-old.phar /usr/local/bin/phpunit
	fi
}

mysql_go() {
	# Install MySQL
	echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
	echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections
	apt-get -y install mysql-client mysql-server

	sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" ${mysql_config_file}

	# Allow root access from any host
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION" | mysql -u root --password=root
	echo "GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION" | mysql -u root --password=root

	#if [ -d "/vagrant/provision-sql" ]; then
	#	echo "Executing all SQL files in /vagrant/provision-sql folder ..."
	#	echo "-------------------------------------"
	#	for sql_file in /vagrant/provision-sql/*.sql
	#	do
	#		echo "EXECUTING $sql_file..."
	#  		time mysql -u root --password=root < $sql_file
	#  		echo "FINISHED $sql_file"
	#  		echo ""
	#	done
	#fi

	service mysql restart
	update-rc.d apache2 enable
}

main
exit 0