#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

app_sanitized="${app//_/-}"
container_name="${app_sanitized}-container1"

setup_incus() {
    ynh_print_info "Configuring Incus..."

    # ci_user will be the one launching job, gives it permission to run incus commands
    usermod -a -G incus-admin "$app"

    incus admin init --auto # --storage-backend=dir

    ynh_exec_as_app incus remote add yunohost https://repo.yunohost.org/incus --protocol simplestreams --public
}


etc_hosts_add() {
    ip=$(ynh_exec_as_app "$install_dir/manage.sh" ip)
    line="$ip $app-container"
    if ! grep -qxF "$line" /etc/hosts; then
        echo "$line" >> /etc/hosts
    fi
}

etc_hosts_clear() {
    sed -i "/^.* $app-container$/d" /etc/hosts
}
