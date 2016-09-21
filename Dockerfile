FROM alpine
MAINTAINER Paul Pham <docker@aquaron.com>
EXPOSE 3306

RUN addgroup -g 900 mysql \
 && adduser -h /var/lib/mysql -g "MySQL" -u 900 -G mysql -D mysql \
 && apk --no-cache add mariadb \
 && chown -R mysql:mysql /etc/mysql \
 && chown -R mysql:mysql /var/lib/mysql \
 && mkdir /var/log/mysql; chown -R mysql:mysql /var/log/mysql

VOLUME /var/lib/mysql /var/log/mysql /etc/mysql/ /tmp
USER mysql

CMD [ "mysqld", "--user=mysql" ]
