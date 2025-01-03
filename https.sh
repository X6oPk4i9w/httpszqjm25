#!/bin/bash

check_root() {
   if [[ $EUID -ne 0 ]]; then
       echo "错误: 请使用 root 权限运行此脚本" >&2
       exit 1
   }
}

generate_credentials() {
   # 生成随机端口 (40000-65530)
   PORT=$((RANDOM % 25531 + 40000))
   
   # 生成用户名 (大写字母开头,15位)
   USERNAME=$(cat /dev/urandom | tr -dc 'A-Z' | head -c1)$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c14)
   
   # 生成密码 (小写字母开头,20位) 
   PASSWORD=$(cat /dev/urandom | tr -dc 'a-z' | head -c1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c19)
}

check_port() {
   if netstat -ntlp | grep -q ":$PORT "; then
       echo "错误: 端口 $PORT 被占用"
       exit 1
   }
}

install_caddy() {
   local temp_file=$(mktemp)
   if ! wget -q https://github.com/yeahwu/image/raw/refs/heads/master/caddy.tar.gz -O "$temp_file"; then
       echo "错误: 下载 Caddy 失败"
       rm -f "$temp_file"
       exit 1
   }
   tar -xzf "$temp_file" -C /usr/local/
   rm -f "$temp_file"
}

setup_config() {
   local domain="$1"
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

   cat > /etc/systemd/system/caddy.service << EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=root
ExecStart=/usr/local/caddy run --environ --config /etc/caddy/https.caddyfile
ExecReload=/usr/local/caddy reload --config /etc/caddy/https.caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
}

print_config() {
   local domain="$1"
   
   cat << EOF
=============== 配置信息 ===============
代理类型: HTTPS 正向代理
域名: ${domain}
端口: ${PORT}
用户名: ${USERNAME}
密码: ${PASSWORD}
TLS版本: 1.3
=======================================

配置字符串:
http=${domain}:${PORT}, username=${USERNAME}, password=${PASSWORD}, over-tls=true, tls-verification=true, tls-host=${domain}, udp-relay=false, tls13=true, tag=https
EOF
}

main() {
   check_root
   generate_credentials
   check_port
   
   timedatectl set-timezone Asia/Shanghai
   
   read -p "请输入已解析的域名: " domain
   if [ -z "$domain" ]; then
       echo "错误: 域名不能为空"
       exit 1
   }
   
   install_caddy
   setup_config "$domain"
   
   if ! systemctl enable caddy.service && systemctl restart caddy.service; then
       echo "错误: Caddy 服务启动失败"
       exit 1
   }
   
   print_config "$domain"
}

main "$@"
