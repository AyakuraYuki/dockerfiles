FROM ubuntu:24.04 AS base

LABEL maintainer="Ayakura Yuki"     \
      base.os="ubuntu"              \
      base.arch="amd64"             \
      base.version="24.04"          \
      base.shell="zsh"              \
      base.timezone="Asia/Shanghai" \
      base.lang="zh_CN.UTF-8"

ENV TZ="Asia/Shanghai"
ENV LANG="zh_CN.UTF-8"
ENV LANGUAGE="zh_CN:zh"

# 设置加速镜像
RUN <<COMMANDS
apt-get update
apt-get install -y --no-install-recommends ca-certificates
rm -rf /var/lib/apt/lists/*
COMMANDS
COPY config/mirrors/ubuntu-24.04.sources /etc/apt/sources.list.d/ubuntu.sources

# 安装 zsh
COPY config/aliases.sh /opt/aliases.sh
RUN <<COMMANDS
apt-get update
apt-get install -y --no-install-recommends zsh
rm -rf /var/lib/apt/lists/*
cat >> /root/.zshrc < /opt/aliases.sh
rm -f /opt/aliases.sh
chsh -s /bin/zsh
COMMANDS

SHELL ["/bin/zsh", "-lic"]

FROM base AS setup

# 配置时区、编码，安装基本工具链
COPY config/locale.sh /opt/locale.sh
RUN <<COMMANDS
apt-get update
apt-get install -y --no-install-recommends tzdata ca-certificates curl wget vim git telnet tree locales
rm -rf /var/lib/apt/lists/*

ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

locale-gen zh_CN.UTF-8
update-locale LANG=zh_CN.UTF-8
cat >> /etc/default/locale < /opt/locale.sh
rm -f /opt/locale.sh
COMMANDS

# 安装遥测工具btop++
RUN <<COMMANDS
curl -fL 'https://github.com/aristocratos/btop/releases/download/v1.4.7/btop-x86_64-unknown-linux-musl.tar.gz' -o /opt/btop.tar.gz
cd /opt
tar -zxvf /opt/btop.tar.gz
rm -f /opt/btop.tar.gz
chmod -R 755 /opt/btop
chmod +x /opt/btop/bin/btop
ln -s /opt/btop/bin/btop /usr/local/bin/btop
COMMANDS

# 配置 zsh 及配套工具
COPY config/starship.toml /opt/starship.toml
RUN <<COMMANDS
mkdir -p ~/.config ~/.zsh
curl -sS https://starship.rs/install.sh | sh -s -- --yes
mv /opt/starship.toml ~/.config/starship.toml
chmod 777 ~/.config/starship.toml
echo 'eval "$(starship init zsh)"' >> /root/.zshrc
echo >> /root/.zshrc

git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-completions.git ~/.zsh/zsh-completions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
echo 'fpath=(~/.zsh/zsh-completions/src $fpath)' >> /root/.zshrc
echo 'source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh' >> /root/.zshrc
echo "source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> /root/.zshrc
rm -f ~/.zcompdump; compinit
COMMANDS

FROM setup

CMD ["/bin/zsh", "-li"]
