# trusty64-lamp
Build vagrant development using box trusty64, contained LAMP and redis server

## Server Info
+ Ubuntu 14.04.5 LTS (GNU/Linux 3.13.0-101-generic x86_64)
+ Apache/2.4.7
+ PHP 5.6 with xdebug & OPcache
+ MySQL
  - port : 3306
  - user : root
  - database : root
  - host : `%`, `localhost`
+ Redis Server v=3.2.5
  - port : 6379

## How to Build
```
git clone git@github.com:harryosmar/trusty64-lamp.git
cd trusty64-lamp
vagrant up --provision --provider virtualbox
```

## Now it's time to start Working
```
vagrant ssh
```
open [http://192.168.33.10](http://192.168.33.10) in your browser
