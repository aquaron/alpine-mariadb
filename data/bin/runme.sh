#!/bin/sh

_this=aquaron/mariadb

getvols() { 
    local _file="/proc/self/mountinfo"

    _localetc=$(grep $_etc $_file | grep -v '/volumes/' | cut -f 4 -d" ")
    _locallog=$(grep $_log $_file | grep -v '/volumes/' | cut -f 4 -d" ")
    _localdata=$(grep $_root $_file | grep -v '/volumes/' | cut -f 4 -d" ")

    if [[ "$_localetc" ]] && [[ "$_locallog" ]] && [[ "$_localdata" ]]; then
        echo "-v $_localetc:$_etc -v $_locallog:$_log -v $_localdata:$_root"
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
Usage: docker run -t --rm ${_vols} ${_ports} ${_this} <command>

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

write_systemd_file() {
    local _name="$1"
    local _map="$2"
    local _port="$3"

    local _service_file="${_etc}/docker-${_name}.service"
    local _script="${_etc}/install-systemd.sh"

    cat ${_datadir}/templ/systemd.service \
        | write_template.sh name \""${_name}"\" map \""${_map}"\" port \""${_port}"\" \
        > ${_service_file}

    echo "Created ${_service_file}"

    cat ${_datadir}/templ/install.sh \
        | write_template.sh name \""$1"\" \
        > ${_script}

    chmod 755 ${_script}

    echo "Created ${_script}"
}

run_init() {
    if [ "$(is_empty ${_etc})" ]; then
        cp -R ${_datadir}/etc/* ${_etc}/
        chown -R mysql:mysql $_etc $_root $_log

        apk --no-cache add bash
        write_systemd_file "mariadb" "${_vols}" "${_ports}" 
        apk del bash
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

        echo "CREATE USER 'root'@'172.17.0.1' IDENTIFIED BY '${_pw}'" | mysql mysql

        hint "Shutting down mysql"
        mysqladmin shutdown

        hint "DONE!"
        echo "Check install.sh in etc dir"
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

