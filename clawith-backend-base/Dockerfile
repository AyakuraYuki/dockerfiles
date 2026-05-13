FROM python:3.12-slim

LABEL maintainer="caih.com" \
      base.python="3.12" \
      base.node="24.14.1"

WORKDIR /app

# System dependencies
RUN <<SHELL
sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources
apt-get update
apt-get install -y --no-install-recommends \
    gcc libpq-dev libpq5 curl wget \
    shadowsocks-libev gosu telnet tree vim \
    git xz-utils bash-completion

echo '. /etc/bash_completion' >> /etc/bash.bashrc

cat >> /root/.bashrc << 'EOF'

alias ll='ls -alhF --color'
alias grep='grep --color'
alias tree='tree -C'

EOF

rm -rf /var/lib/apt/lists/*
SHELL

# NodeJS and Node toolkits
RUN <<SHELL
curl -fL https://nodejs.org/dist/v24.14.1/node-v24.14.1-linux-x64.tar.xz -o /opt/node-v24.14.1-linux-x64.tar.xz
tar -xf /opt/node-v24.14.1-linux-x64.tar.xz -C /opt/
rm -f /opt/node-v24.14.1-linux-x64.tar.xz
mv /opt/node-v24.14.1-linux-x64 /opt/node
chmod -R 755 /opt/node
chmod -R o+rX /opt/node
chmod -R o+w /opt/node/lib/node_modules
chmod -R o+w /opt/node/bin
echo 'export PATH=/opt/node/bin:$PATH' > /etc/profile.d/node.sh
echo 'export PATH=/opt/node/bin:$PATH' >> /etc/profile
. /etc/profile
ln -s /opt/node/bin/node /usr/local/bin/node
ln -s /opt/node/bin/npm /usr/local/bin/npm
ln -s /opt/node/bin/npx /usr/local/bin/npx
ln -s /opt/node/bin/corepack /usr/local/bin/corepack
node -v
npm config set registry https://registry.npmmirror.com
npm install -g agent-browser --verbose
ln -s /opt/node/bin/agent-browser /usr/local/bin/agent-browser
agent-browser install
SHELL
