#!/bin/sh
if [[ $EUID -ne 0 ]]; then
   clear
   echo "Error: This script must be run as root!" 1>&2
   exit 1
fi

PORT=$((RANDOM % 22001 + 40000))
USERNAME=$(cat /dev/urandom | tr -dc 'A-Za-z' | head -c 1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 14)
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 19)

timedatectl set-timezone Asia/Shanghai
wget https://github.com/yeahwu/image/raw/refs/heads/master/caddy.tar.gz -O - | tar -xz -C /usr/local/
echo "====输入已经DNS解析好的域名===="
read domain

isPort=`netstat -ntlp| grep -E ":$PORT "`
if [ "$isPort" != "" ];then
   clear
   echo " ================================================== "
   echo " 端口 $PORT 被占用，请重新运行脚本"
   echo " 端口占用信息如下："
   echo $isPort
   echo " ================================================== "
   exit 1
fi

mkdir -p /etc/caddy
cat >/etc/caddy/https.caddyfile<<EOF
:$PORT, $domain
route {
   forward_proxy {
       basic_auth $USERNAME $PASSWORD
       hide_ip
       hide_via
   }
   file_server
}
EOF

cat >/etc/systemd/system/caddy.service<<EOF
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

systemctl enable caddy.service && systemctl restart caddy.service && systemctl status --no-pager caddy.service
rm -f https.sh

cat >/etc/caddy/https.json<<EOF
{
===========配置参数=============
代理模式：Https正向代理
地址：${domain}
端口：$PORT
用户：$USERNAME
密码：$PASSWORD
====================================
http=$domain:$PORT, username=$USERNAME, password=$PASSWORD, over-tls=true, tls-verification=true, tls-host=$domain, udp-relay=false, tls13=true, tag=https
}
EOF

echo
echo "安装已经完成"
echo
echo "===========Https配置参数============"
echo
echo "地址：${domain}"
echo "端口：$PORT" 
echo "用户：$USERNAME"
echo "密码：$PASSWORD"
echo
echo "========================================="
echo "http=$domain:$PORT, username=$USERNAME, password=$PASSWORD, over-tls=true, tls-verification=true, tls-host=$domain, udp-relay=false, tls13=true, tag=https"
