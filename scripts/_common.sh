#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

container_name="$app"
container_ip=""


setup_incus() {
    ynh_print_info "Configuring Incus..."

    # ci_user will be the one launching job, gives it permission to run incus commands
    usermod -a -G incus-admin "$app"

    if [ "$cluster" -eq 1 ]; then
        yunohost firewall allow TCP 8443

        free_space=$(df --output=avail / | sed 1d)
        btrfs_size=$(( free_space * 90 / 100 / 1024 / 1024 ))
        incus_network=$((1 + RANDOM % 254))
        ynh_add_config --template="incus-preseed.yml" --destination="$install_dir/incus-preseed.yml"
        incus admin init --preseed < "$install_dir/incus-preseed.yml"
        rm "$install_dir/incus-preseed.yml"

        incus config set core.https_address "[::]"
    else
        incus admin init --auto # --storage-backend=dir
    fi

    ynh_exec_as "$app"  incus remote add yunohost https://repo.yunohost.org/incus --protocol simplestreams --public
}
