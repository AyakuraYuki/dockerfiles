#!/usr/bin/env bash

set -euo pipefail

ROOT=${1:-"$PWD"}

fetch() {
    local url=$1
    local relative_path=$2
    local expected=$3
    local output="$ROOT/sources/$relative_path"
    local actual

    mkdir -p "$(dirname "$output")"
    if [[ ! -f "$output" ]]; then
        curl --proto '=https' --tlsv1.2 -fL --retry 3 \
            "$url" -o "$output"
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$output")
    else
        actual=$(shasum -a 256 "$output")
    fi
    actual=${actual%% *}

    if [[ "$actual" != "$expected" ]]; then
        printf 'Mismatched SHA-256: %s\n  - Expected: %s\n  - Actual: %s\n' \
            "$output" "$expected" "$actual" >&2
        return 1
    fi
    printf 'ok: %s\n' "$relative_path"
}

verify_nginx_pgp() (
    local archive="$ROOT/sources/nginx/nginx-1.31.9.tar.gz"
    local signature="$archive.asc"
    local key="$ROOT/sources/nginx/pluknet.key"
    local expected_fingerprint='D6786CE303D9A9022998DC6CC8464D549AF75C0A'
    local actual_fingerprint
    local gnupg_home
    local verify_output

    for command_name in gpg gpgv; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf 'Nginx PGP verification requires %s; please install GnuPG (Debian/Ubuntu packages: gnupg, gpgv).\n' \
                "$command_name" >&2
            return 1
        fi
    done

    gnupg_home=$(mktemp -d "${TMPDIR:-/tmp}/nginx-pgp.XXXXXX")
    chmod 700 "$gnupg_home"
    trap 'rm -rf -- "$gnupg_home"' EXIT

    # 只接受官方发布公钥的完整指纹，不接受仅匹配短 key ID 的其他密钥。
    actual_fingerprint=$(
        gpg --no-options --batch --homedir "$gnupg_home" \
            --with-colons --show-keys "$key" |
            awk -F: '$1 == "fpr" && !seen { print $10; seen = 1 }'
    )
    if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
        printf 'Nginx public key fingerprint mismatch.\n  - Expected: %s\n  - Actual: %s' \
            "$expected_fingerprint" "$actual_fingerprint" >&2
        return 1
    fi

    # 将固定的 ASCII armored 公钥转换成 gpgv 使用的临时 keyring。
    gpg --no-options --batch --yes --homedir "$gnupg_home" \
        --output "$gnupg_home/nginx-release-keyring.gpg" \
        --dearmor "$key"

    if ! verify_output=$(
        gpgv --status-fd 1 \
            --keyring "$gnupg_home/nginx-release-keyring.gpg" \
            "$signature" "$archive" 2>&1
    ); then
        printf 'Nginx PGP signature verification failed:\n%s\n' "$verify_output" >&2
        return 1
    fi
    printf '%s\n' "$verify_output"

    # 除 gpgv 返回成功外，再明确检查签名者的完整指纹。
    if ! grep -F "[GNUPG:] VALIDSIG $expected_fingerprint " \
        >/dev/null <<<"$verify_output"; then
        printf 'The signature is valid, but the signer is not the established Nginx release public key.\n' >&2
        return 1
    fi
    printf 'Nginx PGP verification passed: %s\n' "$expected_fingerprint"
)

fetch \
    'https://nginx.org/download/nginx-1.31.9.tar.gz' \
    'nginx/nginx-1.31.9.tar.gz' \
    'a11c5eeee2e257f4478f0e649f84b0040787d277d2d3e5233952aa6b6dcb80ad'
fetch \
    'https://nginx.org/download/nginx-1.31.9.tar.gz.asc' \
    'nginx/nginx-1.31.9.tar.gz.asc' \
    '25f51b4d4b1836a7c85ecf72fa5a6367210e82e4a1e07957a71434d60b2c7cb8'
fetch \
    'https://nginx.org/keys/pluknet.key' \
    'nginx/pluknet.key' \
    '9a70c136946c1d18d5355c41516f1bdc95d4321938919e69065533e2aeb51e0e'
verify_nginx_pgp

fetch \
    'https://codeload.github.com/vision5/ngx_devel_kit/tar.gz/refs/tags/v0.3.4' \
    'ndk/ngx_devel_kit-0.3.4.tar.gz' \
    '14a28063294f645d457b1eb10e3c23bbba44398f1c5f021421b58b6f8ab31662'
fetch \
    'https://codeload.github.com/openresty/lua-nginx-module/tar.gz/refs/tags/v0.10.29R2' \
    'lua-nginx-module-0.10.29R2/lua-nginx-module-0.10.29R2.tar.gz' \
    '2435bb65900d556a9175c77548ff0ef4cb507b786f57f7d1c4a7904a7f5063fd'
fetch \
    'https://codeload.github.com/openresty/luajit2/tar.gz/refs/tags/v2.1-20261117' \
    'luajit/luajit2-2.1-20261117.tar.gz' \
    'dcc413a1bef46447cbd9172a38c02618c2bb9cb6b193c91d28ae197a347b693c'
fetch \
    'https://codeload.github.com/openresty/lua-resty-core/tar.gz/refs/tags/v0.1.32R1' \
    'lua-resty-core/lua-resty-core-0.1.32R1.tar.gz' \
    '7d36188261f44d489acc1671ced73207e2f7adba70663d3f32804509873f3370'
fetch \
    'https://codeload.github.com/openresty/lua-resty-lrucache/tar.gz/refs/tags/v0.15' \
    'lua-resty-lrucache/lua-resty-lrucache-0.15.tar.gz' \
    '8cf1a22e0d5b8f35cb0b2e14c58fcb3aa505a8fb6e956817f0cdb1f06593f072'
