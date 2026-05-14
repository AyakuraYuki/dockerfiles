FROM python:3.12-slim

LABEL maintainer="caih.com" \
      base.python="3.12" \
      base.node="24.15.0"

WORKDIR /app

RUN <<SHELL
sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources
apt-get update

# System dependencies
apt-get install -y --no-install-recommends \
    gcc libpq-dev libcairo2 libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf-2.0-0 shared-mime-info pango1.0-tools
apt-get install -y --no-install-recommends \
    libpq5 curl shadowsocks-libev gosu bubblewrap libcairo2 libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf-2.0-0 shared-mime-info pango1.0-tools fonts-wqy-microhei fonts-wqy-zenhei
apt-get install -y --no-install-recommends \
    curl wget telnet tree vim git xz-utils bash-completion

rm -rf /var/lib/apt/lists/*

echo '. /etc/bash_completion' >> /etc/bash.bashrc
cat >> /root/.bashrc << 'EOF'

alias ll='ls -alhF --color'
alias grep='grep --color'
alias tree='tree -C'

EOF

# NodeJS and Node toolkits
curl -fL https://nodejs.org/dist/v24.15.0/node-v24.15.0-linux-x64.tar.xz -o /opt/node-v24.15.0-linux-x64.tar.xz
tar -xf /opt/node-v24.15.0-linux-x64.tar.xz -C /opt/
rm -f /opt/node-v24.15.0-linux-x64.tar.xz
mv /opt/node-v24.15.0-linux-x64 /opt/node
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
agent-browser install --with-deps
SHELL
