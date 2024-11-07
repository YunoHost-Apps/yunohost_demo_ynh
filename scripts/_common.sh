#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

image_name="yunohost/bookworm-stable/demo"
container_name="${app//_/-}"

setup_incus() {
    ynh_print_info "Configuring Incus..."

    # ci_user will be the one launching job, gives it permission to run incus commands
    usermod -a -G incus-admin "$app"

    incus admin init --auto # --storage-backend=dir

    ynh_exec_as_app incus remote add yunohost https://repo.yunohost.org/incus --protocol simplestreams --public
}

start_instance() {
    ynh_exec_as_app incus image copy "yunohost:$image_name" local: --copy-aliases
    ynh_exec_as_app incus launch "$image_name" "$container_name"
}

get_instance_ipv4() {
    _get_instance_ipv4() {
        ynh_exec_as_app incus list --format json \
            | jq -r ' .[] | select(.name == "'"$container_name"'") | .state.network.eth0.addresses[] | select(.family == "inet") | .address'
    }
    for _ in $(seq 0 20); do
        ip=$(_get_instance_ipv4)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return
        fi
        sleep 1
    done
}


_incus_exec() {
    ynh_exec_as_app incus exec "$container_name" -- "$@"
}

customize_instance() {
    mapfile -t apps < <(_incus_exec yunohost app list --output-as json | jq -r '.[] | map(.id) | .[]' )

    if [[ "$domain" != "demo.yunohost.org" ]]; then
        _incus_exec yunohost domain add "$domain"
        for app in "${apps[@]}"; do
            path=$(_incus_exec yunohost app info "$app" --output-as json | jq -r '.domain_path' | sed 's|.*/\(.*\)|/\1|')
            _incus_exec yunohost app change-url -d "$domain" -p "$path"
        done
        _incus_exec yunohost domain main-domain -n "$domain"
        _incus_exec yunohost domain remove "demo.yunohost.org"
    fi
}
