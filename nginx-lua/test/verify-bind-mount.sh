#!/usr/bin/env bash

set -euo pipefail

ROOT=${1:-"$PWD"}
PORT=${2:-18081}
NAME="nginx-lua-bind-persistent-$$"
IMAGE='nginx:1.31.9-trixie@sha256:84f7876d21d154885f99554d7ae325d8c2213f9169726ea7ab60642f2573a787'

cleanup() {
    exit_code=$?
    if docker container inspect "$NAME" >/dev/null 2>&1; then
        if [[ "$exit_code" -ne 0 ]]; then
            docker logs "$NAME" || true
        fi
        docker rm -f "$NAME" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

run_container() {
    docker run -d --platform linux/amd64 \
        --name "$NAME" \
        --restart unless-stopped \
        --mount "type=bind,src=$ROOT/dist,dst=/opt/nginx-lua,readonly" \
        --mount "type=bind,src=$ROOT/test/nginx-bind-mount.conf,dst=/etc/nginx/nginx.conf,readonly" \
        --env LD_LIBRARY_PATH=/opt/nginx-lua/luajit/lib \
        --publish "127.0.0.1:$PORT:8080" \
        "$IMAGE" >/dev/null
}

check_lua() {
    label=$1
    response=$(curl --noproxy '*' -fsS \
        --retry 15 --retry-all-errors --retry-connrefused \
        --retry-delay 1 --max-time 5 \
        "http://127.0.0.1:$PORT/lua")
    case "$response" in
        bind_mount_ok*) ;;
        *)
            printf 'unexpected response: %s\n' "$response" >&2
            return 1
            ;;
    esac
    printf '%s：%s\n' "$label" "$response"
}

printf '%s\n' '--- First Launch ---'
run_container
check_lua initial

architecture=$(docker exec "$NAME" dpkg --print-architecture)
machine=$(docker exec "$NAME" uname -m)
[[ "$architecture" == amd64 && "$machine" == x86_64 ]]
printf 'arch: %s/%s\n' "$architecture" "$machine"

printf '%s\n' '--- Mounting and LuaJIT Dynamic Linking ---'
docker inspect "$NAME" --format \
    '{{range .Mounts}}{{println .Type .Source "->" .Destination "RW=" .RW}}{{end}}'
docker inspect "$NAME" --format \
    'Restart policy：{{.HostConfig.RestartPolicy.Name}}'
docker exec "$NAME" sh -c 'printf "LD_LIBRARY_PATH=%s\n" "$LD_LIBRARY_PATH"'
docker exec "$NAME" ldd /opt/nginx-lua/ngx_http_lua_module.so

printf '%s\n' '--- docker restart ---'
docker restart "$NAME" >/dev/null
check_lua restart

printf '%s\n' '--- docker stop/start ---'
docker stop "$NAME" >/dev/null
docker start "$NAME" >/dev/null
check_lua stop_start

printf '%s\n' '--- Recreate the container using the same host directory after deletion ---'
docker rm -f "$NAME" >/dev/null
run_container
check_lua recreate

docker exec "$NAME" nginx -t
printf '%s\n' 'All bind mounts have been verified for persistence.'
