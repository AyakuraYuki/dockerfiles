# nginx 的 lua 动态模块构建指南

本目录包含一套已在 Docker 中实际验证的 `linux-amd64` 构建方案，生成：

- `ndk_http_module.so`
- `ngx_http_lua_module.so`

同时导出运行时 LuaJIT 共享库和 Resty Lua 文件。

本指南提供了利用基础镜像构建动态模块的环境、流程、产物部署的相关教程，提供了一套支持使用原始 nginx
镜像使用只读持久卷映射部署动态模块的方案。

## 1. 环境和版本

本指南基于 Debian 平台 nginx 主线版本 1.31.9 的环境。

| 组件               | 版本                                                                      | 
|--------------------|---------------------------------------------------------------------------|
| 基础镜像           | `nginx:1.31.9-trixie`                                                     |
| 镜像摘要           | `sha256:84f7876d21d154885f99554d7ae325d8c2213f9169726ea7ab60642f2573a787` |
| 系统               | Debian 13 trixie, amd64                                                   | 
| nginx              | 1.31.9                                                                    | 
| ngx_devel_kit      | v0.3.4                                                                    | 
| lua-nginx-module   | v0.10.29R2                                                                | 
| OpenResty LuaJIT   | v2.1-20261117                                                             | 
| lua-resty-core     | v0.1.32R1                                                                 | 
| lua-resty-lrucache | v0.15                                                                     | 

⚠️**警告**：`lua-nginx-module@v0.10.29R2` 和 `lua-resty-core@v0.1.32R1` 是实际通过验证的稳定组合。
Resty Core 会严格检查 Lua 模块版本，不能随意交叉升级。

## 2. 构建环境依赖

在 Debian 13 构建容器中，基础依赖安装命令是：

```shell
apt-get update
apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    libpcre2-dev \
    zlib1g-dev \
    libssl-dev
```

各包用途：

- `build-essential`：提供 GCC、G++、make、binutils 和 libc 开发头文件
- `libpcre2-dev`：nginx 使用 PCRE2 实现重写/正则功能，而不是 `libpcre3-dev`
- `zlib1g-dev`：gzip 等压缩功能
- `libssl-dev`：HTTP SSL、HTTP/3、mail SSL 和 stream SSL 等配置项
- `curl`、`ca-certificates`：通过 HTTPS 下载源代码

这些包仅在构建阶段使用，作为构建基础的原始 nginx 运行时镜像已经包含了 PCRE2、zlib 和 OpenSSL 运行库，不需要在生产镜像中安装 `build-essential`。

### 为什么没有 `libluajit-5.1-dev` ？

本指南使用由 OpenResty 维护的 LuaJIT 源代码构建，因此不需要安装 Debian 的 `libluajit-5.1-dev`。

如果改用 Debian 自带的 LuaJIT，则构建环境需要额外执行下列命令：

```shell
apt-get install -y --no-install-recommends libluajit-5.1-dev
export LUAJIT_INC=/usr/include/luajit-2.1
export LUAJIT_LIB=/usr/lib/x86_64-linux-gnu
```

相应的，运行环境安装 `libluajit-5.1-2`。

⚠️**警告**：不要在同一套构建中混用系统 LuaJIT 和 `/usr/local/luajit` 下的源代码版 LuaJIT。
本指南优先采用 OpenResty 维护的版本。

### 源代码验证

#### SHA-256 的来源与 nginx PGP 验证

如果你提前阅读了 `scripts/01-download-sources.sh`，你会在脚本里看到一些 SHA-256 值。这些值是在本指南的前期验证过程中，下载对应的归档后**在本地计算并固定**的，并非来自 nginx 或 GitHub 官方仓库的校验清单，因为
nginx 以及其他源代码所在 GitHub 官方仓库并未提供完整的 checksum 清单。

这些 SHA-256 值用于保证后续重复构建仍能够使用本指南已验证的同一份源代码，并能检测文件变化；但是 SHA-256 值和文件下载地址同时被替换后，哈希本身不能证明发布者的身份。

nginx 官方提供了 detached PGP 签名，本指南将它作为源代码发布者验证手段：

| 项目             | 官方地址或固定值                                     |
|------------------|------------------------------------------------------|
| 源码             | <https://nginx.org/download/nginx-1.31.9.tar.gz>     |
| detached 签名    | <https://nginx.org/download/nginx-1.31.9.tar.gz.asc> |
| 官方公钥索引     | <https://nginx.org/en/pgp_keys.html>                 |
| 本次源码签名公钥 | <https://nginx.org/keys/pluknet.key>                 |
| 公钥完整指纹     | `D6786CE303D9A9022998DC6CC8464D549AF75C0A`           |
| 签名者           | Sergey Kandaurov                                     |

> `nginx_signing.key` 是官方页面说明的软件包/软件仓库签名 keyring；本次 `nginx-1.31.9.tar.gz.asc` 使用的是上面列出的 `pluknet.key`，不要混用。

`scripts/download-sources.sh` 会按以下顺序验证 nginx 源代码：

1. 分别校验 `.tar.gz`、`.tar.gz.asc` 和 `pluknet.key` 的固定 SHA-256。
2. 用 `gpg --show-keys` 读取公钥，并要求完整指纹等于上面的固定值。
3. 在隔离的临时 GnuPG home 中把公钥转换为临时 keyring。
4. 使用 `gpgv` 验证 detached 签名，并检查 `VALIDSIG` 中的签名者完整指纹。
5. 验证成功后删除临时 keyring。

宿主机已安装 GnuPG 时，可直接运行完整校验：

```bash
cd /path/to/repo/nginx-lua
bash scripts/download-sources.sh "$PWD"
```

成功时包含：

```text
gpgv: 完好的签名，来自于 “Sergey Kandaurov <s.kandaurov@f5.com>”
[GNUPG:] VALIDSIG D6786CE303D9A9022998DC6CC8464D549AF75C0A ...
Nginx PGP 校验通过：D6786CE303D9A9022998DC6CC8464D549AF75C0A
```

也可单独查看待信任公钥的指纹：

```bash
gpg --no-options --batch --show-keys --with-fingerprint sources/nginx/pluknet.key
```

Docker 构建阶段也会独立执行相同的 SHA-256、完整指纹和 `gpgv` 检查；跳过下载脚本是无法绕过 nginx PGP 验证的。其余 GitHub 源码目前使用固定版本归档和本地固定的 SHA-256。

## 3. 构建过程

> 在任意非 `linux/amd64` 架构的设备上，必须指定 `--platform linux/amd64` 构建。

以下命令会生成 x86-64 文件：

```shell
cd /path/to/repo/nginx-lua

# 下载固定版本并检查 SHA-256；文件已存在时跳过下载，直接检查 SHA-256。
bash scripts/01-download-sources.sh "$PWD"

# 构建模块并在相同 nginx 镜像中执行加载和配置检查。
docker buildx build --platform linux/amd64 \
    -f build.dockerfile \
    --target runtime \
    -t nginx-lua-module-test:1.31.9 \
    .

# 导出模块和依赖文件
docker buildx build --platform linux/amd64 \
    -f build.dockerfile \
    --target export \
    --output type=local,dest=dist \
    .
```

产物清单示例：

```text
dist/
├── ndk_http_module.so
├── ngx_http_lua_module.so
╰── luajit/lib/
    ├── libluajit-5.1.so -> libluajit-5.1.so.2.1.1794898267
    ├── libluajit-5.1.so.2 -> libluajit-5.1.so.2.1.1794898267
    ├── libluajit-5.1.so.2.1.1794898267
    ╰── lua/5.1/
        ├── resty/
        ╰── ngx/
```

## 4. 关键步骤说明

完整的构建配置见 `build.dockerfile`，关键顺序如下。

### 4.1. 编译并安装 LuaJIT

```shell
make -j"$(nproc)"
make install PREFIX=/usr/local/luajit MULTILIB=lib

export LUAJIT_INC=/usr/local/luajit/include/luajit-2.1
export LUAJIT_LIB=/usr/local/luajit/lib
```

`lua-nginx-module` 的 `config` 脚本会读取这里的 `LUAJIT_INC` 和 `LUAJIT_LIB`，用户查找头文件和库。

### 4.2. 安装匹配的 Resty Lua 库

`lua-resty-core` 和 `lua-resty-lrucache` 这两个库不需要编译成 C 共享库，但必须安装到运行时可以搜索 的位置：

```shell
# 在 lua-resty-lrucache 源码目录中
make install PREFIX=/usr/local LUA_LIB_DIR=/usr/local/lib/lua/5.1
# 在 lua-resty-core 源码目录中
make install PREFIX=/usr/local LUA_LIB_DIR=/usr/local/lib/lua/5.1
```

主动设置 `LUA_LIB_DIR` 是很重要的，这些项目的 Makefile 不一定会自动补齐 `5.1` 子目录。

### 4.3. 使用原版 nginx 的完整配置参数

原版 nginx 完整的配置参数可以透过命令 `nginx -V` 导出，所以需要先检查目标可执行文件：

```shell
docker run --rm --platform linux/amd64 nginx:1.31.9-trixie nginx -V
```

将 `configure arguments:` 后的完整参数用于源代码 `./configure`，然后追加：

```shell
    --add-dynamic-module=/usr/src/build/ndk \
    --add-dynamic-module=/usr/src/build/lua-nginx-module
```

最后只编译模块，不替换运行时镜像中的 nginx 主程序：

```shell
make -j"$(nproc)" modules
```

### 4.4. 输出产物

输出产物位于 nginx 源代码目录的 `objs/` 下。

前面 **4.3.** 章里抓取的原始完整参数固定在 `build.dockerfile`，包含 `--with-compat`、线程、HTTP/2、HTTP/3、mail、stream、SSL 以及原始编译/链接参数。

## 5. 使用持久化映射部署到 Docker 容器

本教程采用持久化映射的方式，使用**原始**的 `nginx:1.31.9-trixie` 镜像，在不重新构建运行时镜像，也不在容器中安装文件的基础上，透过宿主机目录注入所有模块、LuaJIT 和 Resty 依赖。

### 5.1. 部署结构和重要限制

推荐的容器内布局：

```text
dist/                       ->  /opt/nginx-lua/
├── ndk_http_module.so          ├── ndk_http_module.so
├── ngx_http_lua_module.so      ├── ngx_http_lua_module.so
╰── luajit/lib/                 ╰── luajit/lib/
    ├── libluajit-5.1.so*           ├── libluajit-5.1.so*
    ╰── lua/5.1/                    ╰── lua/5.1/
```

还需要将宿主机上的 nginx 主配置挂载为 `/etc/nginx/nginx.conf`，并在创建容器时设置：

```shell
LD_LIBRARY_PATH=/opt/nginx-lua/luajit/lib
```

这样动态链接器会直接到挂载目录寻找 LuaJIT，**不依赖容器可写层中的 `ldconfig` 缓存**。因此即使删除并重新创建容器，只要复用相同挂载和环境变量，也不需要重新安装依赖。

⚠️**注意以下的 Docker 行为**：

- 不能通过 `docker update` 给已创建的容器追加持久化映射，首次接入时必须重建容器；
- 重建后，`docker restart`、`docker stop`、`docker start` 都会保留挂载和环境变量；
- 再次删除并创建容器时，必须在新容器重新声明相同的挂载和环境变量，挂载配置不会自动从旧容器继承；
- `--restart unless-stopped` 可以让正在运行的容器在 Docker 守护进程或宿主机重启后自动恢复，手动 `docker stop` 的容器仍需要手动 `docker start` 重新启动；
- 如果已有容器的其他配置、证书、站点文件也只存在于容器可写层，重建前必须一并备份并改成持久化映射。

### 5.2. 准备宿主机上的 nginx 配置

对于已有容器，先复制它当前使用的主配置。下面的命令在容器运行当中即可执行：

```shell
PROJECT=/path/to/repo/nginx-lua
TARGET="nginx-container-name"

docker cp "${TARGET}":/etc/nginx/nginx.conf "${PROJECT}/nginx-runtime.conf"
```

编辑宿主机上的 `${PROJECT}/nginx-runtime.conf` 文件，在文件开头添加下面两行：

```nginx configuration
load_module /opt/nginx-lua/ndk_http_module.so;
load_module /opt/nginx-lua/ngx_http_lua_module.so;
```

然后在现有的 `http {}` 块中添加：

```nginx configuration
lua_package_path "/opt/nginx-lua/luajit/lib/lua/5.1/?.lua;;";
```

NDK 必须先于 Lua 模块加载。末尾的 `;;` 用于保留 LuaJIT 默认搜索路径。

⚠️**警告**：本目录的 `test/nginx-bind-mount.conf` 是已验证过的**独立测试配置**，只提供 `8080` 端口和 `/lua` 测试接口。不要直接用它替换生产配置，否则可能丢失你原有的 server、upstream、TLS、日志等配置。

### 5.3. 创建使用持久化映射的容器

以下命令可以启动一个全新的验证容器。`src=` 使用宿主机绝对路径，两个挂载均为只读：

```shell
PROJECT=/path/to/repo/nginx-lua

docker run -d \
    --name nginx-lua-bind \
    --platform linux/amd64 \
    --restart unless-stopped \
    --mount "type=bind,src=$PROJECT/dist,dst=/opt/nginx-lua,readonly" \
    --mount "type=bind,src=$PROJECT/test/nginx-bind-mount.conf,dst=/etc/nginx/nginx.conf,readonly" \
    --env LD_LIBRARY_PATH=/opt/nginx-lua/luajit/lib \
    --publish 127.0.0.1:18081:8080 \
    nginx:1.31.9-trixie@sha256:84f7876d21d154885f99554d7ae325d8c2213f9169726ea7ab60642f2573a787
```

> 这里使用官方镜像默认的启动命令，因此不需要额外指定 `nginx -c`；默认读取的 `/etc/nginx/nginx.conf` 已经是挂载进来的配置。

部署已有业务容器时，应使用 `${PROJECT}/nginx-runtime.conf` 替代测试配置，并保留原来的容器名、端口、网络、其他卷和资源限制：

```shell
PROJECT=/path/to/repo/nginx-lua
TARGET="nginx-container-name"

# 1. 在维护窗口停止并保留旧容器作为回滚副本
docker stop "${TARGET}"
docker rename "${TARGET}" "${TARGET}-original"

# 2. 按原来的 docker run 配置创建同名新容器，并加入：
#    --platform linux/amd64
#    --restart unless-stopped
#    --mount type=bind,src=$PROJECT/dist,dst=/opt/nginx-lua,readonly
#    --mount type=bind,src=$PROJECT/nginx-runtime.conf,dst=/etc/nginx/nginx.conf,readonly
#    --env LD_LIBRARY_PATH=/opt/nginx-lua/luajit/lib
#
#    端口、网络、证书卷、站点目录和其他选项沿用原配置。
```

旧容器 `${TARGET}-original` 只用于回滚，确认新容器稳定运行后再按你的变更流程处理，**不要提前删除**。

如果使用 Docker Compose，在现有 nginx 服务上增加以下配置，然后执行 `docker compose up -d --force-recreate`:

```yaml
services:
  nginx:
    image: nginx:1.31.9-trixie@sha256:84f7876d21d154885f99554d7ae325d8c2213f9169726ea7ab60642f2573a787
    platform: linux/amd64
    restart: unless-stopped
    environment:
      LD_LIBRARY_PATH: /opt/nginx-lua/luajit/lib
    volumes:
      - ./dist:/opt/nginx-lua:ro
      - ./nginx-runtime.conf:/etc/nginx/nginx.conf:ro
    # 保留原有的 ports、networks 和其他 volumes。
```

Compose 中的 `./dist` 和 `./nginx-runtime.conf` 默认相对于 Compose 项目目录解析。

之后的 `docker compose restart` 或 `docker restart` 都会复用这些配置。

### 5.4. 检查挂载、动态库和真实 Lua 请求

以本节创建的 `nginx-lua-bind` 为例：

```shell
# 应输出 amd64 和 x86_64。
docker exec nginx-lua-bind dpkg --print-architecture
docker exec nginx-lua-bind uname -m

# 检查两个挂载，RW 应为 false。
docker inspect nginx-lua-bind --format \
    '{{range .Mounts}}{{println .Type .Source "->" .Destination "RW=" .RW}}{{end}}'

# 应显示 libluajit 来自 /opt/nginx-lua，且没有 not found。
docker exec nginx-lua-bind ldd /opt/nginx-lua/ngx_http_lua_module.so

docker exec nginx-lua-bind nginx -t

curl --noproxy '*' -fsS \
    --retry 15 \
    --retry-all-errors \
    --retry-connrefused \
    --retry-delay 1 \
    --max-time 5 \
    http://127.0.0.1:18081/lua
```

预期 LuaJIT 依赖解析结果包含：

```text
libluajit-5.1.so.2 => /opt/nginx-lua/luajit/lib/libluajit-5.1.so.2
```

预期 HTTP 响应：

```text
bind_mount_ok; LuaJIT 2.1.1794898267; ngx_lua=10029; resty_core=0.1.32
```

### 5.5. 验证重启后的功能完整性

```bash
docker restart nginx-lua-bind
# 容器恢复后再次请求 /lua。
curl --noproxy '*' -fsS \
    --retry 15 \
    --retry-all-errors \
    --retry-connrefused \
    --retry-delay 1 \
    --max-time 5 \
    http://127.0.0.1:18081/lua

docker stop nginx-lua-bind
docker start nginx-lua-bind
# 再次请求 /lua，响应应保持一致。
```

也可以运行本目录提供的自动验证脚本：

```bash
cd /path/to/repo/nginx-lua
bash test/verify-bind-mount.sh "$PWD" 18081
```

脚本始终使用原始 Nginx 镜像，依次验证：

1. 首次启动；
2. `docker restart`；
3. `docker stop` 和 `docker start`；
4. 删除容器后，使用同一宿主机目录重新创建；
5. 两种挂载均为只读、平台为 `amd64/x86_64`、LuaJIT 来自挂载目录，以及 `nginx -t`。

脚本最后会删除自己创建的测试容器。如果端口 18081 已占用，可把第二个参数改成其他空闲端口。

### 5.6 后续更新配置或模块

宿主机文件不会因容器重启而丢失。修改宿主机配置后执行：

```bash
docker exec nginx-lua-bind nginx -t
docker restart nginx-lua-bind
```

更新模块或 LuaJIT 时，先在宿主机准备完整且经过验证的新文件，避免直接截断、覆盖正在被 nginx 映射使用的 `.so`；完成后重启容器并再次执行 HTTP 验证。由于目录以只读方式挂载，容器内进程无法修改这些产物。
