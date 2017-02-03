#!/bin/bash

_service="docker-${name}.service"
_cwd=$(dirname $0)
_cwd=$(cd "$_cwd"; pwd)
_file="${_cwd}/${_service}"

if [ ! "${_file}" ]; then
    echo "${_file} does not exist"
    exit 1
fi

if [ ! "$(whoami)" = "root" ]; then
    echo "Usage: sudo $0"
    exit 1
fi

_args=$(grep 'ExecStart=' $_service | sed -e 's/^[^-]*-v/-v /')
IFS=' ' read -r -a vols <<< "$_args"
for _idx in "${!vols[@]}"; do
    if [ "${vols[$_idx]}" = "-v" ]; then
        _path=$(echo "${vols[$_idx + 1]}" | sed -e 's/:.*$//')
        if [ -d "$_path" ]; then
            echo "$_path OK"
        else
           echo -e "'${_path}' path not found\nCheck your '${_service}' file for correct parameters"
           exit 1
        fi
    fi
done

while true; do
    read -p "Install systemd ${_service}? " yn
    case $yn in
        [Yy]* ) 
            systemctl enable ${_file}
            systemctl daemon-reload
            exit 0
            ;;
        * ) exit 1
            ;;
    esac
done
