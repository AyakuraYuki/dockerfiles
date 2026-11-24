FROM nginx:1.31.9-trixie@sha256:84f7876d21d154885f99554d7ae325d8c2213f9169726ea7ab60642f2573a787 AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        gnupg \
        gpgv \
        libpcre2-dev \
        libssl-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/archives

COPY sources/nginx/nginx-1.31.9.tar.gz ./
COPY sources/nginx/nginx-1.31.9.tar.gz.asc ./
COPY sources/nginx/pluknet.key ./
COPY sources/ndk/ngx_devel_kit-0.3.4.tar.gz ./
COPY sources/luajit/luajit2-2.1-20261117.tar.gz ./
COPY sources/lua-nginx-module-0.10.29R2/lua-nginx-module-0.10.29R2.tar.gz ./
COPY sources/lua-resty-core/lua-resty-core-0.1.32R1.tar.gz ./
COPY sources/lua-resty-lrucache/lua-resty-lrucache-0.15.tar.gz ./

# 每个下载归档都放在独立的空目录中展开。
RUN printf '%s  %s\n' \
        'a11c5eeee2e257f4478f0e649f84b0040787d277d2d3e5233952aa6b6dcb80ad' 'nginx-1.31.9.tar.gz' \
        '25f51b4d4b1836a7c85ecf72fa5a6367210e82e4a1e07957a71434d60b2c7cb8' 'nginx-1.31.9.tar.gz.asc' \
        '9a70c136946c1d18d5355c41516f1bdc95d4321938919e69065533e2aeb51e0e' 'pluknet.key' \
        '14a28063294f645d457b1eb10e3c23bbba44398f1c5f021421b58b6f8ab31662' 'ngx_devel_kit-0.3.4.tar.gz' \
        'dcc413a1bef46447cbd9172a38c02618c2bb9cb6b193c91d28ae197a347b693c' 'luajit2-2.1-20261117.tar.gz' \
        '2435bb65900d556a9175c77548ff0ef4cb507b786f57f7d1c4a7904a7f5063fd' 'lua-nginx-module-0.10.29R2.tar.gz' \
        '7d36188261f44d489acc1671ced73207e2f7adba70663d3f32804509873f3370' 'lua-resty-core-0.1.32R1.tar.gz' \
        '8cf1a22e0d5b8f35cb0b2e14c58fcb3aa505a8fb6e956817f0cdb1f06593f072' 'lua-resty-lrucache-0.15.tar.gz' \
        | sha256sum -c - \
    && mkdir -p /tmp/nginx-gnupg \
    && chmod 700 /tmp/nginx-gnupg \
    && test "$(gpg --no-options --batch --homedir /tmp/nginx-gnupg --with-colons --show-keys pluknet.key | awk -F: '$1 == "fpr" && !seen { print $10; seen = 1 }')" = 'D6786CE303D9A9022998DC6CC8464D549AF75C0A' \
    && gpg --no-options --batch --yes --homedir /tmp/nginx-gnupg \
        --output /tmp/nginx-gnupg/nginx-release-keyring.gpg \
        --dearmor pluknet.key \
    && gpgv --status-fd 3 \
        --keyring /tmp/nginx-gnupg/nginx-release-keyring.gpg \
        nginx-1.31.9.tar.gz.asc nginx-1.31.9.tar.gz \
        3>/tmp/nginx-gpgv.status \
    && grep -F '[GNUPG:] VALIDSIG D6786CE303D9A9022998DC6CC8464D549AF75C0A ' /tmp/nginx-gpgv.status \
    && rm -rf /tmp/nginx-gnupg /tmp/nginx-gpgv.status \
    && mkdir -p \
        /usr/src/build/nginx \
        /usr/src/build/ndk \
        /usr/src/build/lua-nginx-module \
        /usr/src/build/luajit \
        /usr/src/build/lua-resty-core \
        /usr/src/build/lua-resty-lrucache \
    && tar -xzf nginx-1.31.9.tar.gz -C /usr/src/build/nginx --strip-components=1 \
    && tar -xzf ngx_devel_kit-0.3.4.tar.gz -C /usr/src/build/ndk --strip-components=1 \
    && tar -xzf lua-nginx-module-0.10.29R2.tar.gz -C /usr/src/build/lua-nginx-module --strip-components=1 \
    && tar -xzf luajit2-2.1-20261117.tar.gz -C /usr/src/build/luajit --strip-components=1 \
    && tar -xzf lua-resty-core-0.1.32R1.tar.gz -C /usr/src/build/lua-resty-core --strip-components=1 \
    && tar -xzf lua-resty-lrucache-0.15.tar.gz -C /usr/src/build/lua-resty-lrucache --strip-components=1


# 使用 OpenResty 维护的 LuaJIT 2.1。运行镜像也需要对应的 libluajit 共享库。
WORKDIR /usr/src/build/luajit
RUN make -j"$(nproc)" && make install PREFIX=/usr/local/luajit MULTILIB=lib


# lua-nginx-module 0.10.29R2 与 lua-resty-core 0.1.32R1 匹配；两个 Resty 库都是纯 Lua 文件。
WORKDIR /usr/src/build/lua-resty-lrucache
RUN make install PREFIX=/usr/local LUA_LIB_DIR=/usr/local/lib/lua/5.1

WORKDIR /usr/src/build/lua-resty-core
RUN make install PREFIX=/usr/local LUA_LIB_DIR=/usr/local/lib/lua/5.1


# 以下参数来自目标镜像的 `nginx -V`，只在末尾添加两个动态模块。
# lua-nginx-module 通过这两个变量定位非系统路径中的 LuaJIT 头文件和库。
ENV LUAJIT_LIB=/usr/local/luajit/lib \
    LUAJIT_INC=/usr/local/luajit/include/luajit-2.1

WORKDIR /usr/src/build/nginx
RUN ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/run/nginx.pid \
        --lock-path=/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-control-api \
        --with-file-aio \
        --with-threads \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_json_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_realip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-cc-opt='-g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/home/builder/debuild/nginx-1.31.9/debian/debuild-base/nginx-1.31.9=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
        --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
        --add-dynamic-module=/usr/src/build/ndk \
        --add-dynamic-module=/usr/src/build/lua-nginx-module \
    && make -j"$(nproc)" modules

RUN mkdir -p /out/luajit/lib/lua \
    && cp objs/ndk_http_module.so objs/ngx_http_lua_module.so /out/ \
    && cp -a /usr/local/luajit/lib/libluajit-5.1.so* /out/luajit/lib/ \
    && cp -a /usr/local/lib/lua/5.1 /out/luajit/lib/lua/

# 使用完全相同的 Nginx 运行镜像验证动态加载，不把编译工具带入最终测试镜像。
FROM nginx:1.31.9-trixie@sha256:84f7876d21d154885f99554d7ae325d8c2213f9169726ea7ab60642f2573a787 AS runtime
COPY --from=build /out/ndk_http_module.so /usr/lib/nginx/modules/ndk_http_module.so
COPY --from=build /out/ngx_http_lua_module.so /usr/lib/nginx/modules/ngx_http_lua_module.so
COPY --from=build /out/luajit/lib/ /usr/local/luajit/lib/
COPY --from=build /out/luajit/lib/lua/5.1/ /usr/local/lib/lua/5.1/
RUN printf '/usr/local/luajit/lib\n' > /etc/ld.so.conf.d/openresty-luajit.conf \
    && ldconfig \
    && ldd /usr/lib/nginx/modules/ngx_http_lua_module.so
COPY runtime/nginx.conf /etc/nginx/nginx-lua.conf
RUN nginx -t -c /etc/nginx/nginx-lua.conf
CMD ["nginx", "-c", "/etc/nginx/nginx-lua.conf", "-g", "daemon off;"]

# docker build --target export --output type=local,dest=dist 可导出这两个模块和 LuaJIT 运行库。
FROM scratch AS export
COPY --from=build /out/ /
