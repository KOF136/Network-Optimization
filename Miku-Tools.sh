echo "欢迎使用Miku的网络优化脚本"
echo "本脚本主要对TCP窗口进行优化放大"
echo "项目地址: https://github.com/KOF136/Network-Optimization/blob/main/Miku-Tools.sh"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 请使用root用户运行此脚本！\n" && exit 1

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

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

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

echo "系统配置检测完成，开始配置网络优化"

rm -rf /etc/sysctl.conf
cat >> /etc/sysctl.conf << EOF
net.core.rps_sock_flow_entries=32768 #rfs 设置此文件至同时活跃连接数的最大预期值
#net.ipv4.icmp_echo_ignore_all=1 #禁止ping
#net.ipv4.icmp_echo_ignore_broadcasts=1
fs.file-max=1000000 # 系统级别的能够打开的文件句柄的数量
fs.inotify.max_user_instances=65536

#开启路由转发
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1

net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1

net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2

net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.all.rp_filter=0

#ARP回应的级别
#net.ipv4.conf.all.arp_ignore=2
#net.ipv4.conf.default.arp_ignore=2
#net.ipv4.conf.all.arp_announce=2
#net.ipv4.conf.default.arp_announce=2

net.ipv4.neigh.default.gc_stale_time=60 #ARP缓存的存活时间

net.ipv4.tcp_syncookies=1 #开启SYN Cookies。当出现SYN等待队列溢出时，启用cookies来处理
net.ipv4.tcp_retries1=3
net.ipv4.tcp_retries2=8
net.ipv4.tcp_syn_retries=2 #SYN重试次数
net.ipv4.tcp_synack_retries=2 #SYNACK重试次数
net.ipv4.tcp_tw_reuse=1 #开启TIME-WAIT sockets重用
net.ipv4.tcp_fin_timeout=15 #保持在FIN-WAIT-2状态的时间
net.ipv4.tcp_max_tw_buckets=32768 #系统同时保持TIME_WAIT socket的数量
#net.core.busy_poll=50
#net.core.busy_read=50
net.core.dev_weight=4096
net.core.netdev_budget=65536
net.core.netdev_budget_usecs=4096
net.ipv4.tcp_max_syn_backlog=262144 #对于还未获得对方确认的连接请求，可保存在队列中的最大数目
net.core.netdev_max_backlog=32768 #网口接收数据包比内核处理速率快状态队列的数量
net.core.somaxconn=32768 #每个端口最大的监听队列的数量
net.ipv4.tcp_notsent_lowat=16384
net.ipv4_timestamps=0 #TCP时间戳的支持
net.ipv4.tcp_keepalive_time=600 #TCP发送keepalive探测消息的间隔时间（秒）
net.ipv4.tcp_keepalive_probes=5 #TCP发送keepalive探测确定连接已经断开的次数
net.ipv4.tcp_keepalive_intvl=15 #探测消息未获得响应时，重发该消息的间隔时间
vm.swappiness=1
net.ipv4.route.gc_timeout=100
net.ipv4.neigh.default.gc_thresh1=1024 #最小保存条数。当邻居表中的条数小于该数值，则 GC 不会做任何清理
net.ipv4.neigh.default.gc_thresh2=4096 #高于该阈值时，GC 会变得更激进，此时存在时间大于 5s 的条目会被清理
net.ipv4.neigh.default.gc_thresh3=8192 #允许的最大临时条目数。当使用的网卡数很多，或直连了很多其它机器时考虑增大该参数。
net.ipv6.neigh.default.gc_thresh1=1024
net.ipv6.neigh.default.gc_thresh2=4096
net.ipv6.neigh.default.gc_thresh3=8192

# TCP窗口
net.ipv4.tcp_fastopen=3 # 开启TCP快速打开
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_slow_start_after_idle=0 #关闭TCP的连接传输的慢启动
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_mem=262144 1048576 4194304
net.ipv4.udp_mem=262144 524288 1048576

# BBR
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
EOF

rm -rf /etc/sysctl.d
mkdir -p /etc/sysctl.d
cat >> /etc/sysctl.d/99-sysctl.conf << EOF
net.core.rps_sock_flow_entries=32768 #rfs 设置此文件至同时活跃连接数的最大预期值
#net.ipv4.icmp_echo_ignore_all=1 #禁止ping
#net.ipv4.icmp_echo_ignore_broadcasts=1
fs.file-max=1000000 # 系统级别的能够打开的文件句柄的数量
fs.inotify.max_user_instances=65536

#开启路由转发
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1

net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1

net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2

net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.all.rp_filter=0

#ARP回应的级别
#net.ipv4.conf.all.arp_ignore=2
#net.ipv4.conf.default.arp_ignore=2
#net.ipv4.conf.all.arp_announce=2
#net.ipv4.conf.default.arp_announce=2

net.ipv4.neigh.default.gc_stale_time=60 #ARP缓存的存活时间

net.ipv4.tcp_syncookies=1 #开启SYN Cookies。当出现SYN等待队列溢出时，启用cookies来处理
net.ipv4.tcp_retries1=3
net.ipv4.tcp_retries2=8
net.ipv4.tcp_syn_retries=2 #SYN重试次数
net.ipv4.tcp_synack_retries=2 #SYNACK重试次数
net.ipv4.tcp_tw_reuse=1 #开启TIME-WAIT sockets重用
net.ipv4.tcp_fin_timeout=15 #保持在FIN-WAIT-2状态的时间
net.ipv4.tcp_max_tw_buckets=32768 #系统同时保持TIME_WAIT socket的数量
#net.core.busy_poll=50
#net.core.busy_read=50
net.core.dev_weight=4096
net.core.netdev_budget=65536
net.core.netdev_budget_usecs=4096
net.ipv4.tcp_max_syn_backlog=262144 #对于还未获得对方确认的连接请求，可保存在队列中的最大数目
net.core.netdev_max_backlog=32768 #网口接收数据包比内核处理速率快状态队列的数量
net.core.somaxconn=32768 #每个端口最大的监听队列的数量
net.ipv4.tcp_notsent_lowat=16384
net.ipv4_timestamps=0 #TCP时间戳的支持
net.ipv4.tcp_keepalive_time=600 #TCP发送keepalive探测消息的间隔时间（秒）
net.ipv4.tcp_keepalive_probes=5 #TCP发送keepalive探测确定连接已经断开的次数
net.ipv4.tcp_keepalive_intvl=15 #探测消息未获得响应时，重发该消息的间隔时间
vm.swappiness=1
net.ipv4.route.gc_timeout=100
net.ipv4.neigh.default.gc_thresh1=1024 #最小保存条数。当邻居表中的条数小于该数值，则 GC 不会做任何清理
net.ipv4.neigh.default.gc_thresh2=4096 #高于该阈值时，GC 会变得更激进，此时存在时间大于 5s 的条目会被清理
net.ipv4.neigh.default.gc_thresh3=8192 #允许的最大临时条目数。当使用的网卡数很多，或直连了很多其它机器时考虑增大该参数。
net.ipv6.neigh.default.gc_thresh1=1024
net.ipv6.neigh.default.gc_thresh2=4096
net.ipv6.neigh.default.gc_thresh3=8192

# TCP窗口
net.ipv4.tcp_fastopen=3 # 开启TCP快速打开
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_slow_start_after_idle=0 #关闭TCP的连接传输的慢启动
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_mem=262144 1048576 4194304
net.ipv4.udp_mem=262144 524288 1048576

# BBR
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
EOF

sysctl -p && sysctl --system

echo "配置优化完成，请重启系统以应用优化"
read -p "是否现在重启 ? [Y/n] :" yn
[ -z "${yn}" ] && yn="y"
if [[ $yn == [Yy] ]]; then
	echo -e "${Info} VPS 重启中..."
	reboot
fi
