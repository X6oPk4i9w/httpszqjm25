#!/bin/bash

wget -q https://github.com/yeahwu/image/raw/refs/heads/master/caddy.tar.gz -O caddy.tar.gz
tar -xzf caddy.tar.gz -C /usr/local/

PORT=$((RANDOM % 25531 + 40000))
USERNAME=$(cat /dev/urandom | tr -dc 'A-Z' | head -c1)$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c14)
PASSWORD=$(cat /dev/urandom | tr -dc 'a-z' | head -c1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c19)

read -p "请输入域名: " domain

mkdir -p /etc/caddy
cat >/etc/caddy/https.caddyfile <<EOF
:$PORT, \$domain {
    tls {
        protocols tls1.3
    }
    route {
        forward_proxy {
            basic_auth \$USERNAME \$PASSWORD
            hide_ip
            hide_via
        }
        file_server
    }
}
EOF

cat >/etc/systemd/system/caddy.service <<EOF
[Unit]
Description=Caddy
After=network.target

[Service]
ExecStart=/usr/local/caddy run --config /etc/caddy/https.caddyfile
Type=simple
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable caddy
systemctl restart caddy

echo "端口: $PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
