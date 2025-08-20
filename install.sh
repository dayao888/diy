#!/bin/bash

# Sing-box 科学上网一键安装交互式脚本
# 适用于 Ubuntu 22.04 AMD64
# 作者: dayao888
# 版本: 1.0.0
# 库地址: https://github.com/dayao888/diy

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR="/etc/sing-box"
GITHUB_REPO="https://github.com/dayao888/diy"
SING_BOX_VERSION="1.8.0"
CLOUDFLARE_VERSION="2023.8.2"
CURRENT_LANG="C"
# 脚本所在目录
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要 root 权限运行，请使用 sudo 或切换到 root 用户"
        exit 1
    fi
}

# 检查系统信息
check_system() {
    log "正在检查系统信息..."
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
    else
        error "无法检测操作系统信息"
        exit 1
    fi
    
    # 检查架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) error "不支持的架构: $ARCH"; exit 1 ;;
    esac
    
    info "操作系统: $OS_NAME $OS_VERSION"
    info "系统架构: $ARCH"
    
    # 检查Ubuntu版本
    if [[ "$ID" != "ubuntu" ]] || [[ $(echo "$VERSION_ID >= 22.04" | bc) -ne 1 ]]; then
        warning "建议使用 Ubuntu 22.04 或更高版本"
        read -p "是否继续安装? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 检查网络连接
check_network() {
    log "正在检查网络连接..."
    if ! ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        error "网络连接失败，请检查网络设置"
        exit 1
    fi
    info "网络连接正常"
}

# 更新系统包
update_system() {
    log "正在更新系统包..."
    apt update -y
    apt upgrade -y
    apt install -y curl wget unzip jq nginx certbot python3-certbot-nginx bc dnsutils
}

# 创建目录结构
create_directories() {
    log "正在创建目录结构..."
    
    mkdir -p $SCRIPT_DIR/{cert,conf,logs,subscribe/{qr,shadowrocket,proxies,clash,clash2,sing-box-pc,sing-box-phone,sing-box2,v2rayn,neko}}
    
    # 设置权限
    chmod -R 755 $SCRIPT_DIR
    chown -R root:root $SCRIPT_DIR
    
    info "目录结构创建完成"
}

# 下载sing-box程序
download_sing_box() {
    log "正在下载 sing-box 程序..."
    
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-linux-${ARCH}.tar.gz"
    
    cd /tmp
    wget -O sing-box.tar.gz "$download_url"
    
    if [[ $? -ne 0 ]]; then
        error "下载 sing-box 失败"
        exit 1
    fi
    
    tar -xzf sing-box.tar.gz
    mv sing-box-*/sing-box $SCRIPT_DIR/
    chmod +x $SCRIPT_DIR/sing-box
    
    # 创建systemd服务
    create_systemd_service
    
    info "sing-box 下载安装完成"
}

# 创建systemd服务
create_systemd_service() {
    cat > /etc/systemd/system/sing-box.service << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=$SCRIPT_DIR/sing-box run -c $SCRIPT_DIR/config.json
Restart=on-failure
RestartSec=1800s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

# 下载jq和qrencode
download_tools() {
    log "正在下载工具程序..."
    
    # 下载jq
    local jq_url="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
    wget -O $SCRIPT_DIR/jq "$jq_url"
    chmod +x $SCRIPT_DIR/jq
    
    # 安装qrencode
    apt install -y qrencode
    ln -sf /usr/bin/qrencode $SCRIPT_DIR/qrencode
    
    info "工具程序下载完成"
}

# 生成随机字符串
generate_random() {
    local length=${1:-16}
    openssl rand -hex $length
}

# 生成UUID
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# 获取公网IP
get_public_ip() {
    local ip
    ip=$(curl -s https://ipv4.icanhazip.com || curl -s https://ipv4.ip.sb || curl -s https://api.ipify.org)
    echo "$ip"
}

# 检查端口是否被占用
is_port_in_use() {
    local port="$1"
    ss -tulpn | grep ":$port " >/dev/null 2>&1
}

# 获取随机可用端口(20000-50000)
get_random_port() {
    local port
    local max_attempts=50
    local attempts=0
    
    while [ $attempts -lt $max_attempts ]; do
        port=$((RANDOM % 30001 + 20000))
        if ! is_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
        ((attempts++))
    done
    
    # 如果随机分配失败，使用默认端口
    error "无法找到可用端口，将使用默认端口"
    return 1
}

# 自动生成SSL证书
auto_generate_certificate() {
    local domain="$1"
    local cert_dir="/etc/sing-box/cert"
    
    mkdir -p "$cert_dir"
    
    if [[ -z "$domain" ]]; then
        # 生成自签名证书
        info "未提供域名，生成自签名证书..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$cert_dir/private.key" \
            -out "$cert_dir/cert.pem" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
            2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            chmod 600 "$cert_dir/private.key"
            chmod 644 "$cert_dir/cert.pem"
            info "自签名证书生成成功"
            return 0
        else
            error "自签名证书生成失败"
            return 1
        fi
    else
        # 尝试使用Let's Encrypt生成域名证书
        info "使用域名 $domain 申请Let's Encrypt证书..."
        
        # 检查域名解析
        domain_ip=$(dig +short "$domain" 2>/dev/null | tail -n1)
        server_ip=$(get_public_ip)
        
        if [[ "$domain_ip" != "$server_ip" ]]; then
            warning "域名 $domain 未正确解析到本服务器IP ($server_ip)"
            warning "域名当前解析IP: $domain_ip"
            
            read -p "是否继续尝试申请证书? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "改为生成自签名证书..."
                auto_generate_certificate ""
                return $?
            fi
        fi
        
        # 使用certbot申请证书
        if certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email; then
            cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$cert_dir/cert.pem"
            cp "/etc/letsencrypt/live/$domain/privkey.pem" "$cert_dir/private.key"
            chmod 600 "$cert_dir/private.key"
            chmod 644 "$cert_dir/cert.pem"
            info "Let's Encrypt证书申请成功"
            
            # 设置自动续期
            (crontab -l 2>/dev/null; echo "0 2 * * * certbot renew --quiet --post-hook 'systemctl reload sing-box'") | crontab -
            
            return 0
        else
            warning "Let's Encrypt证书申请失败，改为生成自签名证书..."
            auto_generate_certificate ""
            return $?
        fi
    fi
}

# 智能端口和证书配置
smart_config_setup() {
    local protocol="$1"
    local default_port="$2"
    local need_tls="$3"
    local domain_var="$4"
    
    # 端口配置
    info "配置 $protocol 协议端口..."
    read -p "使用随机端口(20000-50000)? (Y/n): " use_random
    
    if [[ ! $use_random =~ ^[Nn]$ ]]; then
        local random_port
        random_port=$(get_random_port)
        if [[ $? -eq 0 ]]; then
            eval "${protocol}_port=$random_port"
            info "已分配随机端口: $random_port"
        else
            read -p "请手动输入端口 [$default_port]: " manual_port
            eval "${protocol}_port=\${manual_port:-$default_port}"
        fi
    else
        read -p "请输入端口 [$default_port]: " manual_port
        eval "${protocol}_port=\${manual_port:-$default_port}"
    fi
    
    # 证书配置
    if [[ "$need_tls" == "true" ]]; then
        info "配置 $protocol 协议TLS证书..."
        read -p "请输入域名(直接回车生成自签名证书): " domain_input
        
        if [[ -n "$domain_input" ]]; then
            eval "$domain_var=\"$domain_input\""
            auto_generate_certificate "$domain_input"
        else
            eval "$domain_var=\"localhost\""
            auto_generate_certificate ""
        fi
    fi
}

# 主菜单
show_main_menu() {
    clear
    echo "======================== Sing-Box 管理面板 ========================"
    echo "1. 安装 sing-box"
    echo "2. 配置协议"
    echo "3. 管理服务"
    echo "4. 查看配置"
    echo "5. 更新程序"
    echo "6. 卸载程序"
    echo "7. 语言设置"
    echo "8. 安全加固与IP保护"
    echo "9. 检查BBR状态"
    echo "0. 退出脚本"
    echo "================================================================="
}

handle_main_menu_choice() {
    read -rp "请输入选项: " choice
    case "$choice" in
        1) install_sing_box ;;
        2) protocol_menu ;;
        3) manage_service ;;
        4) view_config ;;
        5) update_program ;;
        6) uninstall_program ;;
        7) language_settings ;;
        8) source ./security.sh && apply_security_hardening ;;
        9) source ./security.sh && check_bbr_status ;;
        0) exit 0 ;;
        *) echo "无效选项，请重试" ;;
    esac
}

# 协议配置菜单
show_protocol_menu() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}                        协议配置菜单                            ${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    echo -e "${GREEN}请选择要配置的协议:${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC}  Reality (XTLS-Vision)"
    echo -e "  ${YELLOW}2.${NC}  Reality (HTTP/2)"
    echo -e "  ${YELLOW}3.${NC}  Reality (gRPC)"
    echo -e "  ${YELLOW}4.${NC}  Hysteria2"
    echo -e "  ${YELLOW}5.${NC}  TUIC v5"
    echo -e "  ${YELLOW}6.${NC}  ShadowTLS"
    echo -e "  ${YELLOW}7.${NC}  Shadowsocks"
    echo -e "  ${YELLOW}8.${NC}  Trojan"
    echo -e "  ${YELLOW}9.${NC}  VMess + WebSocket"
    echo -e "  ${YELLOW}10.${NC} VLESS + WebSocket + TLS"
    echo -e "  ${YELLOW}11.${NC} AnyTLS"
    echo -e "  ${YELLOW}12.${NC} 配置所有协议"
    echo -e "  ${YELLOW}0.${NC}  返回主菜单"
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# 安装sing-box
install_sing_box() {
    log "开始安装 sing-box..."
    
    check_root
    check_system
    check_network
    update_system
    create_directories
    download_sing_box
    download_tools

    # 安装快捷脚本
    install -m 755 "$BASE_DIR/sb.sh" "$SCRIPT_DIR/sb.sh" || cp "$BASE_DIR/sb.sh" "$SCRIPT_DIR/sb.sh" && chmod +x "$SCRIPT_DIR/sb.sh"
    ln -sf "$SCRIPT_DIR/sb.sh" /usr/local/bin/sb || true

    # 生成初始配置模板
    bash "$BASE_DIR/templates_conf.sh" || true

    # 生成初始 config.json
    bash "$BASE_DIR/merge_config.sh" || true
    systemctl enable --now sing-box || true
    
    # 可选：部署订阅服务 Nginx
    read -p "是否部署订阅服务(Nginx)以便生成的订阅可被客户端访问? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_nginx_subscribe
    fi

    log "sing-box 安装完成！"
    
    read -p "是否现在配置协议? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        protocol_menu
    fi
}

# 协议配置处理
protocol_menu() {
    while true; do
        show_protocol_menu
        read -p "请输入选项 [0-12]: " choice
        
        case $choice in
            1) configure_reality_vision ;;
            2) configure_reality_h2 ;;
            3) configure_reality_grpc ;;
            4) configure_hysteria2 ;;
            5) configure_tuic ;;
            6) configure_shadowtls ;;
            7) configure_shadowsocks ;;
            8) configure_trojan ;;
            9) configure_vmess_ws ;;
            10) configure_vless_ws_tls ;;
            11) configure_anytls ;;
            12) configure_all_protocols ;;
            0) break ;;
            *) error "无效选项，请重新选择" ;;
        esac
        # 每次配置后合并并重启
        bash "$BASE_DIR/merge_config.sh" && systemctl restart sing-box || warning "配置合并或重启失败，请检查"

    done
}

# 主循环
main() {
    while true; do
        show_main_menu
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1) install_sing_box ;;
            2) protocol_menu ;;
            3) manage_service ;;
            4) show_config ;;
            5) update_program ;;
            6) uninstall_program ;;
            7) language_settings ;;
            8) source ./security.sh && apply_security_hardening ;;
            9) source ./security.sh && check_bbr_status ;;
            0) 
                log "感谢使用 sing-box 安装脚本！"
                exit 0 
                ;;
            *) error "无效选项，请重新选择" ;;
        esac
        
        echo ""
        read -p "按回车键继续..." -r
    done
}

# 引入协议配置函数
source "$BASE_DIR/protocols.sh"

manage_service() {
    clear
    echo -e "${CYAN}================== 服务管理 ==================${NC}"
    echo "1) 启动 sing-box"
    echo "2) 停止 sing-box"
    echo "3) 重启 sing-box"
    echo "4) 查看状态"
    echo "5) 查看日志"
    echo "6) 查看节点链接信息"
    echo "7) 查看订阅信息"
    echo "0) 返回"
    read -p "选择: " svc
    case $svc in
      1) systemctl start sing-box ;;
      2) systemctl stop sing-box ;;
      3) systemctl restart sing-box ;;
      4) systemctl status sing-box --no-pager ;;
      5) journalctl -u sing-box -f -n 200 --no-pager ;;
      6) show_node_links ;;
      7) show_subscribe_info ;;
      0) return ;;
      *) error "无效选择" ;;
    esac
}

show_node_links() {
    clear
    echo -e "${CYAN}================= 节点链接信息 ==================${NC}"
    
    # 检查订阅目录是否存在
    if [[ -d "$SCRIPT_DIR/subscribe" ]]; then
        echo "可用的节点配置文件:"
        find "$SCRIPT_DIR/subscribe" -name "*.txt" -o -name "*.json" | while read -r file; do
            echo "  - $(basename "$file")"
        done
        echo ""
        
        # 显示分享链接
        if [[ -f "$SCRIPT_DIR/subscribe/share_links.txt" ]]; then
            echo -e "${GREEN}分享链接:${NC}"
            cat "$SCRIPT_DIR/subscribe/share_links.txt"
        else
            warning "未找到分享链接文件，请先配置协议"
        fi
        
        # 显示二维码文件
        echo ""
        echo -e "${GREEN}二维码文件:${NC}"
        find "$SCRIPT_DIR/subscribe/qr" -name "*.png" 2>/dev/null | while read -r qr_file; do
            echo "  - $(basename "$qr_file")"
        done || echo "  暂无二维码文件"
        
    else
        warning "订阅目录不存在，请先配置协议"
    fi
    
    echo ""
    read -p "按回车键返回..." -r
}

show_subscribe_info() {
    clear
    echo -e "${CYAN}================= 订阅信息 ==================${NC}"
    
    local public_ip
    public_ip=$(get_public_ip)
    
    if [[ -f "/etc/nginx/sites-enabled/sing-box-subscribe.conf" ]]; then
        local sub_port
        sub_port=$(grep -oP 'listen \K\d+' /etc/nginx/sites-enabled/sing-box-subscribe.conf | head -1)
        
        echo -e "${GREEN}订阅服务状态:${NC} 已部署"
        echo -e "${GREEN}订阅地址:${NC} http://${public_ip}:${sub_port}/"
        echo ""
        echo -e "${GREEN}可用订阅链接:${NC}"
        
        # 检查各客户端订阅文件
        local clients=("shadowrocket" "clash" "v2rayn" "neko")
        for client in "${clients[@]}"; do
            if [[ -d "$SCRIPT_DIR/subscribe/$client" ]]; then
                echo "  - $client: http://${public_ip}:${sub_port}/$client/"
            fi
        done
        
    else
        warning "订阅服务未部署"
        echo "运行安装程序时选择部署订阅服务，或手动配置 Nginx"
    fi
    
    echo ""
    read -p "按回车键返回..." -r
}
show_config() {
    echo "配置文件目录: $SCRIPT_DIR/conf"
    ls -l $SCRIPT_DIR/conf || true
}

update_program() {
    log "更新 sing-box..."
    download_sing_box
    systemctl restart sing-box
    log "更新完成"
}

uninstall_program() {
    warning "这将卸载 sing-box 并删除 /etc/sing-box/ 目录"
    read -p "确认卸载? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 停止并禁用服务
        systemctl stop sing-box || true
        systemctl disable sing-box || true
        rm -f /etc/systemd/system/sing-box.service
        
        # 移除 Nginx 订阅站点
        rm -f /etc/nginx/sites-enabled/sing-box-subscribe.conf
        rm -f /etc/nginx/sites-available/sing-box-subscribe.conf
        systemctl reload nginx || true
        
        # 移除快捷命令
        rm -f /usr/local/bin/sb
        
        # 删除主目录
        rm -rf "$SCRIPT_DIR"
        
        # 重新加载 systemd
        systemctl daemon-reload
        
        log "已完全卸载 sing-box 及相关组件"
    fi
}

language_settings() {
    echo "暂未实现多语言切换，保留为中文"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

setup_nginx_subscribe() {
    echo "配置订阅服务(Nginx)"
    read -p "请输入订阅服务监听端口 [8080]: " sub_port
    sub_port=${sub_port:-8080}

    cat > "$SCRIPT_DIR/nginx.conf" <<EOF
server {
    listen ${sub_port} default_server;
    listen [::]:${sub_port} default_server;
    server_name _;

    access_log /var/log/nginx/sing-box_subscribe.access.log;
    error_log  /var/log/nginx/sing-box_subscribe.error.log;

    location / {
        autoindex on;
        alias $SCRIPT_DIR/subscribe/;
        add_header Access-Control-Allow-Origin '*';
        add_header Access-Control-Allow-Methods 'GET, OPTIONS';
        add_header Access-Control-Allow-Headers 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type';
    }
}
EOF

    # 写入到 sites-available 并启用
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    cp "$SCRIPT_DIR/nginx.conf" /etc/nginx/sites-available/sing-box-subscribe.conf
    ln -sf /etc/nginx/sites-available/sing-box-subscribe.conf /etc/nginx/sites-enabled/sing-box-subscribe.conf

    nginx -t && systemctl reload nginx && info "订阅服务已部署: http://$(get_public_ip):${sub_port}/" || warning "Nginx 配置测试失败，请检查"
}