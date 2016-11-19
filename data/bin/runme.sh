#!/bin/sh

_this=aquaron/mariadb

getvols() { 
    local _file="/proc/self/mountinfo"

    local _p1=$(grep $_etc $_file | cut -f 4 -d" ")
    local _p2=$(grep $_log $_file | cut -f 4 -d" ")
    _vol=$(grep $_root $_file | cut -f 4 -d" ")

    if [[ "$_p1" ]] && [[ "$_p2" ]] && [[ "$_vol" ]]; then
        echo "-v $_p1:$_etc -v $_p2:$_log -v $_vol:$_root"
    fi
}

_vols=$(getvols)
_ports="-p 3306:3306"

is_empty() { if [[ ! -d "$1" ]] || [[ ! "$(ls -A $1)" ]]; then echo "yes"; fi }

if [ ! "${_vols}" ]; then 
    echo "ERROR: you need run Docker with the -v parameter (see documentation)"
    exit 1
fi

_run="docker run -t --rm ${_vols} ${_ports} ${_this}"

HELP=`cat <<EOT
Usage: docker run -t --rm ${_ports} -v /data:${_root} -v /etc/mysql:${_etc} -v /var/log:${_log} ${_this} <command>

   init      - initialize directories if they're empty
   bootstrap - create new database (run -it)
   daemon    - run in non-detached mode
   start     - start mariadb server
   stop      - quick mariadb shutdown

`

if [[ $# -lt 1 ]] || [[ ! "${_vols}" ]]; then echo "$HELP"; exit 1; fi

hint() {
    local hint="| $* |"
    local stripped="${hint//${bold}}"
    stripped="${stripped//${normal}}"
    local edge=$(echo "$stripped" | sed -e 's/./-/g' -e 's/^./+/' -e 's/.$/+/')
    echo "$edge"
    echo "$hint"
    echo "$edge"
}

_cmd=$1
_host=$2
_datadir=/data

_start="docker run ${_vols} ${_ports} -d ${_this}"

assert_ok() { if [ "$?" = 1 ]; then hint "Abort"; exit 1; fi; }

run_init() {
    if [ "$(is_empty ${_etc})" ]; then
        cp -R ${_datadir}/etc/* ${_etc}/
        chown -R mysql:mysql $_etc $_root $_log
    fi
}

get_pw() {
    local _pw=$(echo $(openssl rand -base64 128) | sed 's/[[:space:]"]//g')
    _pw=${_pw:0:60}
    echo $_pw
}

get_mem_25pc() {
    local _free=$(free -m | grep -i Mem | sed -e 's/^mem:[[:space:]]\+\([0-9]\+\).*$/\1/i')
    echo $((($_free/25)+$_free))M
}

mysqld_is_running() {
    if [ "$(mysqladmin status 2>&1 | grep -i uptime)" ]; then echo "1"; fi
}

install_client() {
    run_init

    if [ "$(is_empty ${_root})" ]; then
        hint "Geting mysql-client, openssl"
        apk add --no-cache mysql-client openssl

        hint "Installing default DB"
        mysql_install_db --user=mysql

        assert_ok

        if [ ! "$(mysqld_is_running)" ]; then
            hint "Starting mysql"
            mysqld --user=mysql &
 
            for _i in $(seq 0 9); do
                if [ "$(mysqld_is_running)" = "1" ]; then
                    break
                fi
                sleep 1
            done
        fi

        local _pw=$(get_pw)
        local _keybuf=$(get_mem_25pc)
 
        if [[ ! "$_pw" ]] || [[ ! "$_keybuf" ]]; then hint "Abort!"; exit 1; fi

        echo $_pw
        echo $_keybuf

        (echo -e "\nY\n${_pw}\n${_pw}\nY\nY") | mysql_secure_installation -S $_sock

        hint "Creating cfgs"
        echo -e "[mysql]\npassword=$_pw\n[client]\npassword=$_pw" > $_etc/conf.d/passwd.cnf
        echo -e "[mysqld]\nkey_buffer_size=${_keybuf}" > $_etc/conf.d/keybufsiz.cnf

        chown -R mysql:mysql $_etc $_root $_log

        hint "Shutting down mysql"
        mysqladmin shutdown

        hint "DONE!"
        echo "Run container normally to start MariaDB!"
    fi
}

case "${_cmd}" in
    init)
        hint "initializing server"
        run_init
        ;;

    bootstrap)
        install_client
        ;;

    start) 
        hint "starting server"
        mysqld --user=mysql &
        ;;

    daemon)
        run_init
        mysqld --user=mysql
        ;;

    stop) 
        hint "${_cmd} server"
        _pw=$(cat $_etc/conf.d/passwd.cnf | grep -e '^password' | uniq | sed -e 's/^[^=]\+=//')
        mysqladmin shutdown --user=root --password="$_pw"
        ;;

    kill)
        killall mysqld
        ;;

    *) 
        echo "ERROR: Command '${_cmd}' not recognized"
        ;;
esac

