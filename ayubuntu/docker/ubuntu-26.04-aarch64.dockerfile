FROM ubuntu:26.04

LABEL maintainer="Ayakura Yuki"     \
      base.os="ubuntu"              \
      base.arch="aarch64"           \
      base.version="26.04"          \
      base.shell="zsh"              \
      base.timezone="Asia/Shanghai"

ENV TZ="Asia/Shanghai"

# 使用阿里云Ubuntu镜像仓库
RUN <<SHELL
apt-get update
apt-get install -y --no-install-recommends ca-certificates
SHELL
COPY config/mirrors/ubuntu-ports-26.04.sources /etc/apt/sources.list.d/ubuntu.sources

# 配置时区
RUN <<SHELL
apt-get update
apt-get install -y --no-install-recommends tzdata
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
rm -rf /var/lib/apt/lists/*
SHELL

# 安装基本工具链
RUN <<SHELL
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl wget vim git \
    telnet httpie htop iotop tree
rm -rf /var/lib/apt/lists/*
SHELL

# 安装遥测工具btop++
RUN <<SHELL
apt-get update
apt-get install -y --no-install-recommends curl gzip
curl -fL 'https://github.com/aristocratos/btop/releases/download/v1.4.7/btop-aarch64-unknown-linux-musl.tar.gz' -o /opt/btop-aarch64-unknown-linux-musl.tar.gz
mkdir -p /opt/btop
chmod -R 755 /opt/btop
chmod -R 755 /opt/btop/
tar -zxf /opt/btop-aarch64-unknown-linux-musl.tar.gz -C /opt/btop
rm -f /opt/btop-aarch64-unknown-linux-musl.tar.gz
chmod +x /opt/btop/bin/btop
ln -s /opt/btop/bin/btop /usr/local/bin/btop
tree /opt
rm -rf /var/lib/apt/lists/*
SHELL

# 配置Zsh+Starship
COPY config/starship.toml /opt/starship.toml
RUN <<SHELL
apt-get update
apt-get install -y --no-install-recommends zsh
chsh -s /bin/zsh
cat >> /root/.zshrc << 'EOF'
alias ll='ls -alhF --color'
alias grep='grep --color'
alias tree='tree -C'
EOF
rm -rf /var/lib/apt/lists/*

mkdir -p ~/.config
curl -sS https://starship.rs/install.sh | sh
cp /opt/starship.toml ~/.config/starship.toml
cat >> /root/.zshrc << 'EOF'
eval "$(starship init zsh)"
EOF
SHELL
