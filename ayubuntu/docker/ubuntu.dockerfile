# UBUNTU_VERSION: 26.04, 24.04
ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION} AS base

ARG UBUNTU_VERSION=${UBUNTU_VERSION}
ARG TARGET_ARCH=amd64
ARG DISABLE_DEB822=0

LABEL maintainer="Ayakura Yuki"         \
      base.os="ubuntu"                  \
      base.arch="${TARGET_ARCH}"        \
      base.version="${UBUNTU_VERSION}"  \
      base.shell="zsh"                  \
      base.timezone="Asia/Shanghai"     \
      base.lang="zh_CN.UTF-8"

ENV TZ="Asia/Shanghai"
ENV LANG="zh_CN.UTF-8"
ENV LANGUAGE="zh_CN:zh"

# 设置加速镜像
# amd64   -> ubuntu-{UBUNTU_VERSION}.sources
# aarch64 -> ubuntu-ports-{UBUNTU_VERSION}.sources
RUN <<COMMANDS
apt-get update
apt-get install -y --no-install-recommends ca-certificates
apt-get clean
rm -rf /var/lib/apt/lists/*

find /var/log -mindepth 1 -type f -delete
find /var/log -mindepth 1 -type d -empty -delete
COMMANDS

COPY config/mirrors/ /opt/mirrors/

RUN <<COMMANDS
if [ "${DISABLE_DEB822}" -eq 0 ]; then
    if [ "${TARGET_ARCH}" = "aarch64" ]; then
        mirror_file="ubuntu-ports-${UBUNTU_VERSION}.sources"
    else
        mirror_file="ubuntu-${UBUNTU_VERSION}.sources"
    fi
    cp /opt/mirrors/${mirror_file} /etc/apt/sources.list.d/ubuntu.sources
else
    if [ "${TARGET_ARCH}" = "aarch64" ]; then
        sed -i 's|http://ports.ubuntu.com/|https://mirrors.aliyun.com/|g' /etc/apt/sources.list
    else
      sed -i 's|http://archive.ubuntu.com/|https://mirrors.aliyun.com/|g' /etc/apt/sources.list
    fi
    cat /etc/apt/sources.list
fi
rm -rf /opt/mirrors
COMMANDS

# 安装 zsh
COPY config/aliases.sh /opt/aliases.sh
RUN <<COMMANDS
apt-get update
apt-get install -y --no-install-recommends zsh
apt-get clean
rm -rf /var/lib/apt/lists/*

cat >> ~/.zshrc < /opt/aliases.sh
rm -f /opt/aliases.sh
chsh -s /bin/zsh
COMMANDS

SHELL ["/bin/zsh", "-lic"]

FROM base AS setup

# 配置时区、编码，安装基本工具链
COPY config/locale.sh /opt/locale.sh
RUN <<COMMANDS
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

apt-get update
apt-get install -y --no-install-recommends curl vim git telnet tree tzdata locales
apt-get clean
rm -rf /var/lib/apt/lists/*
dpkg-reconfigure -f noninteractive tzdata

locale-gen zh_CN.UTF-8
update-locale LANG=zh_CN.UTF-8
cat >> /etc/default/locale < /opt/locale.sh
rm -f /opt/locale.sh
COMMANDS

# 安装遥测工具btop++
# amd64   -> btop-x86_64-unknown-linux-musl.tar.gz
# aarch64 -> btop-aarch64-unknown-linux-musl.tar.gz
RUN <<COMMANDS
if [ "${TARGET_ARCH}" = "aarch64" ]; then
    btop_arch="aarch64"
else
    btop_arch="x86_64"
fi
curl -fL "https://github.com/aristocratos/btop/releases/download/v1.4.7/btop-${btop_arch}-unknown-linux-musl.tar.gz" -o /opt/btop.tar.gz
cd /opt
tar -zxvf /opt/btop.tar.gz
rm -f /opt/btop.tar.gz
chmod -R 755 /opt/btop
chmod +x /opt/btop/bin/btop
ln -s /opt/btop/bin/btop /usr/local/bin/btop

find /tmp -mindepth 1 -type f -delete
find /tmp -mindepth 1 -type d -empty -delete
COMMANDS

# 配置 zsh 及配套工具
COPY config/starship.toml /opt/starship.toml
RUN <<COMMANDS
mkdir -p ~/.config ~/.zsh
curl -sS https://starship.rs/install.sh | sh -s -- --yes
mv /opt/starship.toml ~/.config/starship.toml
chmod 777 ~/.config/starship.toml
echo 'eval "$(starship init zsh)"' >> ~/.zshrc
echo >> ~/.zshrc
find /tmp -mindepth 1 -type f -delete
find /tmp -mindepth 1 -type d -empty -delete

git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-completions.git ~/.zsh/zsh-completions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
echo 'fpath=(~/.zsh/zsh-completions/src $fpath)' >> ~/.zshrc
echo 'source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc
echo "source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
rm -f ~/.zcompdump; compinit
rm -f ~/.zcompdump*
COMMANDS

FROM setup

CMD ["/bin/zsh", "-li"]
