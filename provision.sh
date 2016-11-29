#!/bin/bash

apache_config_file="/etc/apache2/envvars"
apache_vhost_file="/etc/apache2/sites-available/vagrant_vhost.conf"
php_config_file="/etc/php5/apache2/php.ini"
xdebug_config_file="/etc/php5/mods-available/xdebug.ini"
mysql_config_file="/etc/mysql/my.cnf"

# This function is called at the very bottom of the file
main() {
	update_go
	network_go
	tools_go
	apache_go
	mysql_go
	php_go
	git_go
	redis_go
	autoremove_go
	#node_npm_go
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

	mkdir /opt/redis

	cd /opt/redis
	# Use latest stable
	wget -q http://download.redis.io/redis-stable.tar.gz
	# Only update newer files
	tar -xz --keep-newer-files -f redis-stable.tar.gz

	cd redis-stable
	make
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
		cp -u /var/www/redis.conf /etc/redis/6379.conf
	fi

	if [ ! -f "/etc/init.d/redis_6379" ]; then
		cp -u /var/www/redis.init.d /etc/init.d/redis_6379
	fi

	update-rc.d redis_6379 defaults

	chmod a+x /etc/init.d/redis_6379
	/etc/init.d/redis_6379 start
}

update_go() {
	# Update the server
	apt-get update
	# apt-get -y upgrade
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

	if [ ! -f "${apache_vhost_file}" ]; then
		cat << EOF > ${apache_vhost_file}
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        ServerName sulleyweb.test
        DocumentRoot /var/www/sulleyweb/public

        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>

        <Directory /var/www/sulleyweb>
                Options FollowSymLinks
                AllowOverride All
                Order allow,deny
                allow from all
        </Directory>


        ErrorLog /var/log/apache2/sulleyweb.error.log

        # Possible values include: debug, info, notice, warn, error, crit, alert, emerg.
        LogLevel warn

        SetEnvIfNoCase ^X-HTTPS$ .+ HTTP_X-HTTPS
        CustomLog /var/log/apache2/sulleyweb.access.log combined env=!HTTP_X-HTTPS
        CustomLog /var/log/apache2/ssl.sulleyweb.access.log combined env=HTTP_X-HTTPS

        ServerSignature Off
        AllowEncodedSlashes On

</VirtualHost>
EOF
	fi

	a2dissite 000-default
	a2ensite vagrant_vhost

	a2enmod rewrite

	service apache2 reload
	update-rc.d apache2 enable
}

php_go() {
	apt-get -y install php5 php5-curl php5-mysql php5-sqlite php5-xdebug php-pear

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