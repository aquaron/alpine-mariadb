# MariaDB on Alpine

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

## `runme.sh`

Launches `mysqld` by default. If configuration is not found, initializes with default configuration.
`runme.sh` accepts these commands:

| Command   | Description                                      |
| --------- | ------------------------------------------------ |
| init      | initialize directories if they're empty          |
| bootstrap | create new database (calls `init`)               |
| daemon    | run in non-detached mode                         |
| start     | start mariadb server                             |
| stop      | quick mariadb shutdown (requires `mysql-client`) |
| kill      | killall msyql                                    |

## Configurations

### Enabled configurations

#### `system.cnf`

Holds all system configuration that pertain to the container, you should only change this
if you have multiple instances of the container running.

#### `master-slave.cnf`

Container is set as a master as default.

### Disabled configurations

To enable, remove `-disabled` from the filename.

#### `large.cnf-disabled`

For larger systems, enable this file.

#### `small.cnf-disabled`

Systems smaller than 1GB memory.

#### `secured.cnf-disabled`

Encrypt log file.

### Auto generated configurations

#### `passwd.cnf`

Contains the auto-generated root password.

#### `keybufsiz.cnf`

Sets configuration `key_buffer_size` to 125% of the current system's memory per MariaDB's 
[recommendation](https://mariadb.com/kb/en/mariadb/optimizing-key_buffer_size/).

# Auto Start Container

Bootstraping the server also yield 2 files `install-systemd.sh` and `docker-mariadb.service` they're
located in where you map your directory to `/etc/mysql`. After configuration, check this directory
and run `install-systemd.sh` it will use `systemd`. 

This script is based on Docker's 
[documentation](https://docs.docker.com/engine/admin/host_integration/) on auto starting containers.

Installing the service by running:

    ./install-systemd.sh

Follow instruction. After everything looks good you can enable the service by running:

    systemctl enable docker-mariadb.service


