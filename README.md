# alpine-mariadb

Running a simple MariaDB server on Alpine.
Container is focus on unify UID & GID to match permission on local machine.

Start container:

     docker run --name mariadb \
        -p 3316:3306 \
        -v /var/lib/mysql:/var/lib/mysql \
        -v /var/log/mysql:/var/log/mysql \
        -v /etc/mysql:/etc/mysql \
        -h mariadb -d \
        aquaron/mariadb

