# X-UI
简体中文|[ENGLISH](./README_EN.md)  

> 声明：该项目仅供个人学习、交流，请遵守当地法律法规,勿用于非法用途;请勿用于生产环境  
> 声明：该项目已闭源，介意者请勿使用；如您需要开源代码，请附上您的Github Profile邮箱联系  

支持单端口多用户、多协议的 xray 面板，   
通过免费的Telegram bot方便快捷地进行监控、管理你的代理服务  
&#x26A1;`xtls-rprx-vision`与`reality`快速入手请看[这里](https://github.com/FranzKafkaYu/x-ui/wiki/%E8%8A%82%E7%82%B9%E9%85%8D%E7%BD%AE)  
欢迎大家使用并反馈意见或提交Pr,帮助项目更好的改善  
如果您觉得本项目对您有所帮助,不妨给个star:star2:支持我  

# 文档目录  
- [功能介绍](#功能介绍)  
- [一键安装](#一键安装)  
- [效果预览](#效果预览)  
- [快捷方式](#快捷方式)  
- [变更记录](#变更记录)

# 功能介绍

- 系统状态监控
- 支持单端口多用户、多协议，网页可视化操作
- 支持的协议：vmess、vless、trojan、shadowsocks、shadowsocks 2022、dokodemo-door、socks、http
- 支持配置更多传输配置：http、tcp、ws、grpc、kcp、quic
- 流量统计，限制流量，限制到期时间，一键重置与设备监控
- 可自定义 xray 配置模板
- 支持 https 访问面板（自备域名 + ssl 证书）
- 支持一键SSL证书申请且自动续签
- Telegram bot通知、控制功能
- 更多高级配置项，详见面板 

:bulb:具体**使用、配置细节以及问题排查**请点击这里:point_right:[WIKI](https://github.com/FranzKafkaYu/x-ui/wiki):point_left:  
 Specific **Usages、Configurations and Debug** please refer to [WIKI](https://github.com/FranzKafkaYu/x-ui/wiki)    
# 一键安装
在安装前请确保你的系统支持`bash`环境,且系统网络正常  


# 快捷方式
安装成功后，通过键入`x-ui`进入控制选项菜单，目前菜单内容：
```
  x-ui 面板管理脚本
  0. 退出脚本
————————————————
  1. 安装 x-ui
  2. 更新 x-ui
  3. 卸载 x-ui
————————————————
  4. 重置用户名密码
  5. 重置面板设置
  6. 设置面板端口
  7. 查看当前面板设置
————————————————
  8. 启动 x-ui
  9. 停止 x-ui
  10. 重启 x-ui
  11. 查看 x-ui 状态
  12. 查看 x-ui 日志
————————————————
  13. 设置 x-ui 开机自启
  14. 取消 x-ui 开机自启
————————————————
  15. 一键安装 bbr (最新内核)
  16. 一键申请SSL证书(acme申请)
 
面板状态: 已运行
是否开机自启: 是
xray 状态: 运行

请输入选择 [0-16]: 
```
# 配置要求  
## 内存  
- 128MB minimal/256MB+ recommend  
## OS  
- CentOS 7+
- Ubuntu 16+
- Debian 8+

# 变更记录   
- 2023.07.18：随机生成Reality dest与serverNames,去除微软域名;细化sniffing配置  
- 2023.06.10：开启TLS时自动复用面板证书与域名;增加证书热重载设定;优化设备限制功能  
- 2023.04.09：支持Reality;支持新的telegram bot控制指令  
- 2023.03.05：支持用户到期时间限制;随机用户名、密码与端口生成
- 2023.02.09：支持单端口内用户流量限制与统计；支持VLESS utls配置与分享链接导出  
- 2022.12.07：添加设备并发限制;细化tls配置,支持minVersion、maxVersion与cipherSuites选择    
- 2022.11.14：添加xtls-rprx-vision流控选项;定时自动更新geo与清除日志  
- 2022.10.23：实现全英文支持;增加批量导出分享链接功能；优化页面细节与Telegram通知    
- 2022.08.11：实现Vmess/Vless/Trojan单端口多用户；增加CPU使用超限提醒  
- 2022.07.28：增加acme standalone模式申请证书;增加x-ui自动保活机制;优化编译选项以适配更多系统  
- 2022.07.24：增加自动生成面板根路径，节点流量自动重置功能，设备IP接入变化通知功能
- 2022.07.21：增加节点IP接入变化提醒，Web面板增加停止/重启xray功能，优化部分翻译
- 2022.07.11：增加节点到期提醒、流量预警策略，增加Telegram bot节点复制、获取分享链接等
- 2022.07.03：重构Telegram bot功能，指令控制不再需要键盘输入;增加Trojan底层传输配置
- 2022.06.19：增加Shadowsocs2022新的Cipher，增加节点搜索、一键清除流量功能
- 2022.05.14：增加Telegram bot Command控制功能，支持关闭/开启/删除节点等
- 2022.04.25：增加SSH登录提醒、面板登录提醒
- 2022.04.23：增加更多Telegram bot提醒功能
- 2022.04.16：增加面板设置Telegram bot功能
- 2022.04.12：优化Telegram Bot通知提醒
- 2022.04.06：优化安装/更新流程，增加证书签发功能，添加Telegram bot机器人推送功能


# ubuntu安装x-ui，创建节点，并优化网络

-FinalShell下载地址 [FinalShell](https://dl.hostbuf.com/finalshell3/finalshell_windows_x64.exe)
 
更新以及安装防火墙放行端口
```
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt update && sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt install -y ufw && echo "y" | sudo ufw enable && sudo ufw allow 22/tcp && sudo ufw allow 5000/tcp && sudo ufw allow 7000/tcp && sudo ufw status
```  

安装x-ui面板
```
curl -Ls https://raw.githubusercontent.com/Firefly-xui/x-ui/master/install.sh -o install.sh && DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a bash install.sh && rm -f install.sh

```  

登录x-ui
```
0.0.0.0:5000
```  

修改根地址后登录x-ui
```
0.0.0.0:5000/start/xui
```  

修改根地址后登录x-ui
```
www.nvidia.com
```  


优化对列调度和启动bbr加速
```
echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" | sudo tee /etc/sysctl.d/99-custom-network.conf && sudo sysctl --system
```  

查找路径为：/etc/sysctl.conf的配置文件
```
# 启用 BBR 拥塞控制（优化 TCP 传输）
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP 窗口缓冲区优化
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 87380 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.optmem_max = 65536
net.ipv4.tcp_mem = 8388608 8388608 8388608

# 启用 TCP 快速打开（减少握手延迟）
net.ipv4.tcp_fastopen = 3

# 启用低延迟模式
net.ipv4.tcp_low_latency = 1

# TIME_WAIT 连接优化，减少僵尸连接占用
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1   # 适用于非 NAT 服务器
net.ipv4.tcp_fin_timeout = 10  # 释放连接更快
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 20

# SYN 处理优化（防止 SYN Flood）
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog

```  

windows客户端
-官方v2rayn [v2rayn](https://github.com/2dust/v2rayN/releases/download/7.12.7/v2rayN-windows-64-desktop.zip)

# 致谢

- [FranzKafkaYu](https://github.com/FranzKafkaYu/x-ui)
- [vaxilu/x-ui](https://github.com/vaxilu/x-ui)
- [XTLS/Xray-core](https://github.com/XTLS/Xray-core)
- [telegram-bot-api](https://github.com/go-telegram-bot-api/telegram-bot-api)  

