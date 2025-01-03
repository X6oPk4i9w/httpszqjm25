#!/bin/bash
wget https://raw.githubusercontent.com/yeahwu/image/raw/refs/heads/master/caddy.tar.gz -O caddy.tar.gz
tar -xzf caddy.tar.gz -C /usr/local/

PORT=$((RANDOM % 25531 + 40000))
USERNAME=$(cat /dev/urandom | tr -dc 'A-Z' | head -c1)$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c14)
PASSWORD=$(cat /dev/urandom | tr -dc 'a-z' | head -c1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c19)

read -p "请输入域名: " domain
if [ -z "$domain" ]; then
    echo "错误: 域名不能为空"
    exit 1
fi

mkdir -p /etc/caddy
cat > /etc/caddy/https.caddyfile << EOF
:$PORT, $domain
{
    tls {
        protocols tls1.3
    }
    route {
        forward_proxy {
            basic_auth $USERNAME $PASSWORD
            hide_ip
            hide_via
        }
        file_server
    }
}
EOF

systemctl stop caddy 2>/dev/null
cat > /etc/systemd/system/caddy.service << EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=root
ExecStart=/usr/local/caddy run --config /etc/caddy/https.caddyfile
ExecReload=/usr/local/caddy reload --config /etc/caddy/https.caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable caddy
systemctl start caddy

echo "============配置信息============"
echo "域名: ${domain}"
echo "端口: ${PORT}"
echo "用户名: ${USERNAME}"
echo "密码: ${PASSWORD}"
echo "TLS版本: 1.3"
echo "==============================="
