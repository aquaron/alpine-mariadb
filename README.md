# alpine-mariadb

Simple MariaDB server on Alpine.
The image tries to match UID & GID permission on local machine.

## Start Container

     docker run --name mariadb \
        -p 3316:3306 \
        -v /var/lib/mysql:/var/lib/mysql \
        -v /var/log/mysql:/var/log/mysql \
        -v /etc/mysql:/etc/mysql \
        -h mariadb -d \
            aquaron/mariadb

## runme.sh

Launches `mysqld` by default. If configuration is not found, initializes with default configuration.
`runme.sh` accepts these commands:

    init      - initialize directories if they're empty
    bootstrap - create new database
    daemon    - run in non-detached mode
    start     - start mariadb server
    stop      - quick mariadb shutdown (requires mysql-client)
    kill      - killall msyql

## Configurations

Default configuration files with some disabled by default.
