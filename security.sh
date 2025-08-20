#!/bin/bash
# 安全加固和IP保护机制

# 启用BBR拥塞控制算法
enable_bbr() {
    info "启用BBR拥塞控制算法..."
    
    # 检查当前拥塞控制算法
    current_congestion=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    
    if [[ "$current_congestion" == "bbr" ]]; then
        info "BBR已启用"
        return 0
    fi
    
    # 检查内核是否支持BBR
    if ! modinfo tcp_bbr >/dev/null 2>&1; then
        warning "内核不支持BBR，跳过配置"
        return 1
    fi
    
    # 启用BBR
    echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
    echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
    sysctl -p
    
    # 验证配置
    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        info "BBR启用成功"
    else
        warning "BBR启用失败"
    fi
}

# 防止端口扫描和暴力破解
configure_port_security() {
    info "配置端口安全机制..."
    
    # 安装fail2ban
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        apt update && apt install -y fail2ban
    fi
    
    # 配置fail2ban
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 7200

[sing-box-scan]
enabled = true
port = 20000:50000
protocol = tcp
filter = sing-box-scan
logpath = /var/log/kern.log
maxretry = 2
bantime = 86400
findtime = 300
EOF

    # 创建sing-box扫描过滤器
    cat > /etc/fail2ban/filter.d/sing-box-scan.conf << 'EOF'
[Definition]
failregex = .*kernel:.*IN=.*DST=<HOST>.*DPT=(2[0-4][0-9][0-9][0-9]|[3-4][0-9][0-9][0-9][0-9]|50000).*
ignoreregex =
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban
    info "端口安全配置完成"
}

# 配置防火墙规则
configure_firewall() {
    info "配置UFW防火墙..."
    
    # 重置UFW
    ufw --force reset
    
    # 基础规则
    ufw default deny incoming
    ufw default allow outgoing
    
    # 允许SSH
    ufw allow ssh
    
    # 允许HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # 允许代理端口范围
    ufw allow 20000:50000/tcp
    ufw allow 20000:50000/udp
    
    # 限制连接频率
    ufw limit ssh/tcp
    
    # 启用防火墙
    ufw --force enable
    
    info "防火墙配置完成"
}

# IP地址隐私保护
configure_ip_protection() {
    info "配置IP保护机制..."
    
    # 禁用IPv6（可选）
    read -p "是否禁用IPv6以减少攻击面? (y/N): " disable_ipv6
    if [[ $disable_ipv6 =~ ^[Yy]$ ]]; then
        echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
        echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
        sysctl -p
        info "IPv6已禁用"
    fi
    
    # 配置网络安全参数
    cat >> /etc/sysctl.conf << 'EOF'

# 网络安全加固
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.ip_forward=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.tcp_rfc1337=1
kernel.randomize_va_space=2
EOF
    
    sysctl -p
    info "IP保护配置完成"
}

# 隐藏服务指纹
configure_service_stealth() {
    info "配置服务隐身..."
    
    # 修改SSH端口（可选）
    read -p "是否修改SSH端口? (y/N): " change_ssh
    if [[ $change_ssh =~ ^[Yy]$ ]]; then
        read -p "请输入新的SSH端口(1024-65535): " new_ssh_port
        if [[ $new_ssh_port =~ ^[0-9]+$ ]] && [ $new_ssh_port -ge 1024 ] && [ $new_ssh_port -le 65535 ]; then
            sed -i "s/^#Port 22/Port $new_ssh_port/" /etc/ssh/sshd_config
            sed -i "s/^Port 22/Port $new_ssh_port/" /etc/ssh/sshd_config
            ufw allow $new_ssh_port/tcp
            systemctl restart sshd
            info "SSH端口已修改为: $new_ssh_port"
        fi
    fi
    
    # 禁用不必要的服务
    services_to_disable=(
        "telnet"
        "rsh"
        "rlogin"
        "vsftpd"
        "xinetd"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            systemctl disable "$service"
            info "已禁用服务: $service"
        fi
    done
}

# 定期清理日志
configure_log_rotation() {
    info "配置日志轮转..."
    
    cat > /etc/logrotate.d/sing-box << 'EOF'
/etc/sing-box/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    postrotate
        systemctl reload sing-box 2>/dev/null || true
    endscript
}
EOF
    
    # 清理系统日志
    journalctl --vacuum-time=7d
    
    info "日志轮转配置完成"
}

# 主安全配置函数
apply_security_hardening() {
    info "开始应用安全加固..."
    
    enable_bbr
    configure_port_security
    configure_firewall
    configure_ip_protection
    configure_service_stealth
    configure_log_rotation
    
    info "安全加固完成！"
    warning "建议重启系统以确保所有配置生效"
}

# 检查BBR状态
check_bbr_status() {
    echo "当前拥塞控制算法: $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')"
    echo "可用拥塞控制算法: $(sysctl net.ipv4.tcp_available_congestion_control | cut -d' ' -f3-)"
    
    if lsmod | grep -q tcp_bbr; then
        echo "BBR模块状态: 已加载"
    else
        echo "BBR模块状态: 未加载"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "此脚本应由 install.sh 调用"
fi