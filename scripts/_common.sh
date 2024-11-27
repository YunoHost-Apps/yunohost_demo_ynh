#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

app_sanitized="${app//_/-}"
container_name_1="${app_sanitized}-container1"
container_name_2="${app_sanitized}-container2"


setup_incus() {
    ynh_print_info "Configuring Incus..."

    # ci_user will be the one launching job, gives it permission to run incus commands
    usermod -a -G incus-admin "$app"

    incus admin init --auto # --storage-backend=dir

    ynh_exec_as_app incus remote add yunohost https://repo.yunohost.org/incus --protocol simplestreams --public
}


etc_hosts_add() {
    # Add a dummy 127.0.0.42 IP to satisfy nginx
    for container in "$container_name_1" "$container_name_2" 127.0.0.42; do
        line="$container $app-containers"
        if ! grep -qxF "$line" /etc/hosts; then
            echo "$line" >> /etc/hosts
        fi
    done
}

etc_hosts_clear() {
    for container in "$container_name_1" "$container_name_2" 127.0.0.42; do
        line="$container $app-containers"
        sed -i "/^$line$/d" /etc/hosts
    done
}
