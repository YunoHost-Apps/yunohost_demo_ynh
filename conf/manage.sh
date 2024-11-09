#!/usr/bin/env bash

APP=__APP_SANITIZED__
IMAGE="yunohost/bookworm-stable/demo"

container1="${APP}-container1"
container2="${APP}-container2"

_incus_exec() {
    incus exec "$container" -- "$@"
}

_customize() {
    container="$1"
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

download_image() {
    ynh_exec_as_app incus image copy "yunohost:$IMAGE" local: --copy-aliases --auto-update
}

start() {
    case "$1" in
        1) container="$container1" ;;
        2) container="$container2" ;;
        *) echo "Invalid container ID $1" ; return 1 ;;
    esac
    if incus list --format json | jq -r 'map(.name) | @sh' | grep "'$container'"; then
        incus delete "$container" --force
    fi
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
    stop: Stop the container 1, 2, or all (defaults to all)
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
