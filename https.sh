#!/bin/bash
# TLS 1.3 Only HTTPS Proxy Setup Script with AES-256-GCM

# 检查是否以root权限运行
if [[ $EUID -ne 0 ]]; then
   clear
   echo "错误: 此脚本必须以root权限运行!" 1>&2
   exit 1
fi

# 设置时区
timedatectl set-timezone Asia/Shanghai

# 清屏并显示欢迎信息
clear
echo "========================================================"
echo "      TLS 1.3 专用 HTTPS 代理服务器安装脚本"
echo "      (使用最强加密套件 TLS_AES_256_GCM_SHA384)"
echo "========================================================"
echo ""

# 生成随机用户名和密码
username=$(echo -n $(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 9))
password=$(echo -n $(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 14))

# 检查并安装依赖
echo "正在检查并安装依赖..."
if ! command -v wget &> /dev/null; then
    apt update
    apt install -y wget || yum install -y wget
fi

# 下载并安装Caddy
echo "正在下载安装Caddy..."
wget https://github.com/yeahwu/image/raw/refs/heads/master/caddy.tar.gz -O - | tar -xz -C /usr/local/

# 获取域名
echo ""
echo "====请输入已经DNS解析好的域名===="
read domain

# 验证域名格式
if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    echo "错误: 无效的域名格式!"
    exit 1
fi

# 获取端口号
echo ""
echo "====请输入要使用的端口号 [默认: 443]===="
read port
# 如果未输入，使用默认端口443
if [ -z "$port" ]; then
    port=443
fi

# 验证端口格式
if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "错误: 无效的端口号! 端口必须是1-65535之间的数字。"
    exit 1
fi

# 检查端口占用
isPort=$(netstat -ntlp | grep -E ":$port ")
if [ "$isPort" != "" ]; then
   clear
   echo " ================================================== "
   echo " 端口 $port 已被占用，请选择其他端口或先释放该端口"
   echo
   echo " 端口占用信息如下："
   echo "$isPort"
   echo " ================================================== "
   exit 1
fi

# 创建Caddy配置目录
mkdir -p /etc/caddy

# 创建Caddy配置文件，强制使用TLS 1.3且只使用最强加密套件
echo "配置Caddy服务器，强制仅使用TLS 1.3和AES-256-GCM加密，端口: $port..."
cat >/etc/caddy/https.caddyfile<<EOF
:$port, $domain {
    tls {
        protocols tls1.3
        ciphers TLS_AES_256_GCM_SHA384
    }
    route {
        forward_proxy {
            basic_auth $username $password
            hide_ip
            hide_via
        }
        file_server
    }
}
EOF

# 创建Caddy服务
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

# 启动Caddy服务
echo "启动Caddy服务..."
systemctl enable caddy.service && systemctl restart caddy.service

# 等待服务启动
sleep 2

# 检查服务状态
serviceStatus=$(systemctl is-active caddy.service)
if [ "$serviceStatus" != "active" ]; then
    echo "错误: Caddy服务启动失败，请检查日志: journalctl -u caddy.service"
    exit 1
fi

systemctl status --no-pager caddy.service

# 保存配置信息
cat >/etc/caddy/https.json<<EOF
{
===========配置参数=============
代理模式：Https正向代理 (仅TLS 1.3 + AES-256-GCM)
地址：${domain}
端口：${port}
用户：${username}
密码：${password}
加密套件：TLS_AES_256_GCM_SHA384
====================================
http=${domain}:${port}, username=${username}, password=${password}, over-tls=true, tls-verification=true, tls-host=${domain}, udp-relay=false, tls13=true, tag=https-tls13-aes256
}
EOF

# 清理安装文件
rm -f tls13-proxy.sh

# 显示配置信息
echo ""
echo "========================================================"
echo "              安装已完成！"
echo "========================================================"
echo ""
echo "===========HTTPS代理配置参数============"
echo ""
echo "代理模式：仅TLS 1.3 + AES-256-GCM（最高安全级别）"
echo "地址：${domain}"
echo "端口：${port}"
echo "用户：${username}"  
echo "密码：${password}"
echo "加密套件：TLS_AES_256_GCM_SHA384"
echo ""
echo "=========客户端配置字符串=========="
echo "http=${domain}:${port}, username=${username}, password=${password}, over-tls=true, tls-verification=true, tls-host=${domain}, udp-relay=false, tls13=true, tag=https-tls13-aes256"
echo ""
echo "配置文件已保存至：/etc/caddy/https.json"
echo "========================================================"
