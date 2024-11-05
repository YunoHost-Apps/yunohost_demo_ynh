#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

image_name="yunohost/bookworm/demo"
container_name="$app"

setup_incus() {
    ynh_print_info "Configuring Incus..."

    # ci_user will be the one launching job, gives it permission to run incus commands
    usermod -a -G incus-admin "$app"

    incus admin init --auto # --storage-backend=dir

    ynh_exec_as "$app" incus remote add yunohost https://repo.yunohost.org/incus --protocol simplestreams --public
}

start_instance() {
    incus image copy "yunohost:$image_name" local: --copy-aliases
    incus launch "$image_name" "$container_name"
}

get_instance_ipv4() {
    incus list --format json \
        | jq -r ' .[] | select(.name == "'"$container_name"'") | .state.network.eth0.addresses[] | select(.family == "inet") | .address'
}

customize_instance() {
    mapfile -t apps < <( incus exec "$container_name" -- yunohost app list --output-as json | jq -r '.[] | map(.id) | .[]' )

    if [[ "$domain" != "demo.yunohost.org" ]]; then
        incus exec "$container_name" -- yunohost domain add "$domain"
        for app in "${apps[@]}"; do
            path=$(incus exec "$container_name" -- yunohost app info "$app" --output-as json | jq -r '.domain_path' | sed 's|.*/\(.*\)|/\1|')
            incus exec "$container_name" -- yunohost app change-url -d "$domain" -p "$path"
        done
        incus exec "$container_name" -- yunohost domain main-domain -n "$domain"
        incus exec "$container_name" -- yunohost domain remove "demo.yunohost.org"
    fi
}
