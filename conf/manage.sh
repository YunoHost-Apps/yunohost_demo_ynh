#!/usr/bin/env bash

IMAGE="yunohost/bookworm-stable/demo"
container1="__CONTAINER_NAME_1__"
container2="__CONTAINER_NAME_2__"

_incus_exec() {
    incus exec "$container" -- "$@"
}

_customize() {
    container="$1"
    mapfile -t apps < <(_incus_exec yunohost app list --output-as json | jq -r '.[] | map(.id) | .[]' )

    if [[ "$domain" != "demo.yunohost.org" ]]; then
        _incus_exec yunohost domain add "$domain"
        for _app in "${apps[@]}"; do
            _path=$(_incus_exec yunohost app info "$_app" --output-as json | jq -r '.domain_path' | sed 's|.*/\(.*\)|/\1|')
            _incus_exec yunohost app change-url "$_app" -d "$domain" -p "$_path"
        done
        _incus_exec yunohost domain main-domain -n "$domain"
        _incus_exec yunohost domain remove "demo.yunohost.org"
    fi
}

download_image() {
    ynh_exec_as_app incus image copy "yunohost:$IMAGE" local: --copy-aliases --auto-update
}

start() {
    case "$1" in
        1) container="$container1" ;;
        2) container="$container2" ;;
        *) echo "Invalid container ID $1" ; return 1 ;;
    esac
    download_image
    incus launch "$IMAGE" "$container"
    _customize "$container"
}

stop() {
    case "$1" in
        1) container="$container1" ;;
        2) container="$container2" ;;
        all) stop 1 ; stop 2 ; return ;;
        *) echo "Invalid container ID $1" ; return 1 ;;
    esac
    incus stop "$container"
    incus delete "$container" --force
}

swap() {
    if incus list --format json | jq -r 'map(select(.status == "Running").name) | @sh' | grep "'$container1'"; then
        to_stop=1
        to_start=2
    else
        to_stop=2
        to_start=1
    fi

    start "$to_start"
    stop "$to_stop"
}


help() {
    cat <<EOF
Usage: $0 <command> [<container>]
Available <command>s:
    start: Start the container 1 or 2 (defaults to 1) and customize it for the configured domain
    stop: Stop and delete the container 1, 2, or all (defaults to all)
    swap: Start a new (clean) container customize it, then stop the old one.
EOF
}

main() {
    if (( $# == 0 )); then
        echo "You need to pass a command!"
        help
        exit 1
    fi
    case "$1" in
        start) start "${2:-1}" ;;
        stop) stop "${2:-all}" ;;
        swap) swap ;;
        -h|--help|help) help; exit 0 ;;
        *) echo "Unknown command $1" ; help; exit 1 ;;
    esac
}

main "$@"
