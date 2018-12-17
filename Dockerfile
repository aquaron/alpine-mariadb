FROM alpine:latest

ARG BUILD_DATE

LABEL maintainer="docker@aquaron.com" \
 org.label-schema.build-date=$BUILD_DATE \
 org.label-schema.docker.cmd="docker run --name -p 3316:3316 -v /var/lib/mysql:/var/lib/mysql -v /var/log/mysql:/var/log/mysql -v /etc/mysql:/etc/mysql -h mariadb -d aquaron/mariadb" \
 org.label-schema.description="MariaDB" \
 org.label-schema.name="mariadb" \
 org.label-schema.url="https://mariadb.org/" \
 org.label-schema.vcs-url="https://github.com/aquaron/mariadb" \
 org.label-schema.vendor="aquaron" \
 org.label-schema.version="5.5.5"


COPY data /data
ENV \
 _image=aquaron/mariadb \
 _etc=/etc/mysql \
 _root=/var/lib/mysql \
 _log=/var/log/mysql \
 _sock=/var/log/mysql/mysqld.sock

RUN addgroup -g 900 mysql \
 && adduser -h $_root -g "MySQL" -u 900 -G mysql -D mysql \
 && apk --no-cache -q add mariadb \
 && mkdir $_log \
 && chown -R mysql:mysql $_etc $_log $_root \
 && mv /data/bin/* /usr/bin

ONBUILD USER mysql
ONBUILD RUN apk --no-cache -q add mariadb-client

VOLUME [ $_etc, $_root, $_log ]
ENTRYPOINT [ "runme.sh" ]
CMD [ "daemon" ]
