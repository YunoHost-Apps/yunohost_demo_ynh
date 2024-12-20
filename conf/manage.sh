#!/usr/bin/env bash

IMAGE="yunohost/bookworm-stable/demo"
DOMAIN="__DOMAIN__"
container="__CONTAINER_NAME__"
snapshot="$container-configured"

_incus_exec() {
    incus exec "$container" -- "$@"
}

_customize() {
    container="$1"
    mapfile -t apps < <(_incus_exec yunohost app list --output-as json | jq -r '.[] | map(.id) | .[]' )

    if [[ "$DOMAIN" != "demo.yunohost.org" ]]; then
        _incus_exec yunohost domain add "$DOMAIN"
        for _app in "${apps[@]}"; do
            _path=$(_incus_exec yunohost app info "$_app" --output-as json | jq -r '.domain_path' | sed 's|.*/\(.*\)|/\1|')
            _incus_exec yunohost app change-url "$_app" -d "$DOMAIN" -p "$_path"
        done
        _incus_exec yunohost domain main-domain -n "$DOMAIN"
        _incus_exec yunohost domain remove "demo.yunohost.org"
    fi
}

initialize() {
    remote_url="https://repo.yunohost.org/incus"
    if ! incus remote list --columns u -f compact | grep "$remote_url"; then
        incus remote add yunohost "$remote_url" --protocol simplestreams --public
    fi

    incus image copy "yunohost:$IMAGE" local: --copy-aliases --auto-update
    incus launch "$IMAGE" "$container"
    _customize "$container"
    incus snapshot create "$container" "$snapshot" --no-expiry

    echo "The container was rebuilt, its IPv4 probably changed. Don't forget to update the /etc/hosts!!"
}

ip() {
    incus exec "$container" -- ip -4 address show dev eth0 scope global  | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
}

start() {
    incus snapshot restore "$container" "$snapshot"
    incus start "$container"
}

clear() {
    incus stop "$container"
    incus delete --force "$container"
}

help() {
    cat <<EOF
Usage: $0 <command>
Available <command>s:
    initialize: Start the container, customize it for the configured domain, and create a snapshot
    ip: prints the IP address of the (started) container
    start: Start the container from the snapshot
    clear: Stop and delete the container and its snapshots
EOF
}

main() {
    if (( $# == 0 )); then
        echo "You need to pass a command!"
        help
        exit 1
    fi
    case "$1" in
        initialize|ip|start|clear) "$1" ;;
        -h|--help|help) help; exit 0 ;;
        *) echo "Unknown command $1" ; help; exit 1 ;;
    esac
}

main "$@"
