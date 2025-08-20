#!/bin/bash
# sing-box 各协议配置生成函数
# 包含 Reality、Hysteria2、TUIC、ShadowTLS、Shadowsocks、Trojan、VMess、VLESS 等协议

# 协议函数由 install.sh 引入并复用其中的工具函数

# 生成私钥和公钥
generate_reality_keys() {
    local keys=$($SCRIPT_DIR/sing-box generate reality-keypair)
    PRIVATE_KEY=$(echo "$keys" | grep "PrivateKey" | awk '{print $2}')
    PUBLIC_KEY=$(echo "$keys" | grep "PublicKey" | awk '{print $2}')
}

# 生成short_id
generate_short_id() {
    openssl rand -hex 8
}

# Reality XTLS-Vision 配置
configure_reality_vision() {
    log "配置 Reality XTLS-Vision 协议..."
    
    # 智能端口分配（无TLS证书需求）
    smart_config_setup "reality" "443" "false" "_"
    local default_port=${reality_port:-443}
    read -p "请输入监听端口 [${default_port}]: " reality_port
    reality_port=${reality_port:-$default_port}
    
    read -p "请输入目标域名 [www.microsoft.com]: " target_domain
    target_domain=${target_domain:-www.microsoft.com}
    
    read -p "请输入用户UUID (回车自动生成): " user_uuid
    user_uuid=${user_uuid:-$(generate_uuid)}
    
    generate_reality_keys
    short_id=$(generate_short_id)
    
    cat > "$SCRIPT_DIR/conf/11_xtls-reality_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-reality-vision",
      "listen": "::",
      "listen_port": $reality_port,
      "users": [
        {
          "uuid": "$user_uuid",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$target_domain",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$target_domain",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["$short_id"]
        }
      }
    }
  ]
}
EOF

    cat > "$SCRIPT_DIR/list" << EOF
Reality XTLS-Vision:
端口: $reality_port
UUID: $user_uuid
Public Key: $PUBLIC_KEY
Short ID: $short_id
目标域名: $target_domain
EOF

    info "Reality XTLS-Vision 配置完成！"
    info "端口: $reality_port"
    info "UUID: $user_uuid"
    info "Public Key: $PUBLIC_KEY"
    info "Short ID: $short_id"

    if command -v qrencode >/dev/null 2>&1; then
        bash "$BASE_DIR/subscribe.sh" >/dev/null 2>&1 || true
        generate_vless_reality_qr "$(get_public_ip)" "$reality_port" "$user_uuid" "$PUBLIC_KEY" "$short_id"
    fi
}

# Hysteria2 配置
configure_hysteria2() {
    log "配置 Hysteria2 协议..."
    
    # 智能端口和证书
    smart_config_setup "hy2" "443" "true" "domain_name"
    local default_port=${hy2_port:-443}
    read -p "请输入监听端口 [${default_port}]: " hy2_port
    hy2_port=${hy2_port:-$default_port}
    
    read -p "请输入密码 (回车自动生成): " hy2_password
    hy2_password=${hy2_password:-$(generate_random 32)}
    
    if [[ -z "$domain_name" ]]; then
        error "域名或证书未配置"
        return 1
    fi
    
    cat > "$SCRIPT_DIR/conf/12_hysteria2_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $hy2_port,
      "users": [
        {
          "password": "$hy2_password"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$domain_name",
        "certificate_path": "/etc/sing-box/cert/cert.pem",
        "key_path": "/etc/sing-box/cert/private.key"
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

Hysteria2:
端口: $hy2_port
密码: $hy2_password
域名: $domain_name
EOF

    info "Hysteria2 配置完成！"
    info "端口: $hy2_port"
    info "密码: $hy2_password"
}

# TUIC v5 配置
configure_tuic() {
    log "配置 TUIC v5 协议..."
    
    smart_config_setup "tuic" "443" "true" "tuic_domain"
    local default_port=${tuic_port:-443}
    read -p "请输入监听端口 [${default_port}]: " tuic_port
    tuic_port=${tuic_port:-$default_port}
    
    read -p "请输入用户UUID (回车自动生成): " tuic_uuid
    tuic_uuid=${tuic_uuid:-$(generate_uuid)}
    
    read -p "请输入密码 (回车自动生成): " tuic_password
    tuic_password=${tuic_password:-$(generate_random 16)}
    
    if [[ -z "$tuic_domain" ]]; then
        error "域名或证书未配置"
        return 1
    fi
    
    cat > "$SCRIPT_DIR/conf/13_tuic_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "tuic",
      "tag": "tuic-in",
      "listen": "::",
      "listen_port": $tuic_port,
      "users": [
        {
          "uuid": "$tuic_uuid",
          "password": "$tuic_password"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$tuic_domain",
        "certificate_path": "/etc/sing-box/cert/cert.pem",
        "key_path": "/etc/sing-box/cert/private.key"
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

TUIC v5:
端口: $tuic_port
UUID: $tuic_uuid
密码: $tuic_password
域名: $tuic_domain
EOF

    info "TUIC v5 配置完成！"
}

# ShadowTLS 配置
configure_shadowtls() {
    log "配置 ShadowTLS 协议..."
    
    smart_config_setup "stls" "443" "false" "_"
    local default_port=${stls_port:-443}
    read -p "请输入监听端口 [${default_port}]: " stls_port
    stls_port=${stls_port:-$default_port}
    
    read -p "请输入密码 (回车自动生成): " stls_password
    stls_password=${stls_password:-$(generate_random 16)}
    
    read -p "请输入握手域名 [www.microsoft.com]: " stls_handshake
    stls_handshake=${stls_handshake:-www.microsoft.com}
    
    cat > "$SCRIPT_DIR/conf/14_ShadowTLS_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "shadowtls",
      "tag": "st-in",
      "listen": "::",
      "listen_port": $stls_port,
      "users": [
        {
          "password": "$stls_password"
        }
      ],
      "handshake": {
        "server": "$stls_handshake",
        "server_port": 443
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

ShadowTLS:
端口: $stls_port
密码: $stls_password
握手域名: $stls_handshake
EOF

    info "ShadowTLS 配置完成！"
}

# Shadowsocks 配置
configure_shadowsocks() {
    log "配置 Shadowsocks 协议..."
    
    smart_config_setup "ss" "8388" "false" "_"
    local default_port=${ss_port:-8388}
    read -p "请输入监听端口 [${default_port}]: " ss_port
    ss_port=${ss_port:-$default_port}
    
    read -p "请输入密码 (回车自动生成): " ss_password
    ss_password=${ss_password:-$(generate_random 16)}
    
    echo "请选择加密方法:"
    echo "1. aes-128-gcm"
    echo "2. aes-256-gcm"
    echo "3. chacha20-poly1305"
    read -p "请选择 [1-3]: " method_choice
    
    case $method_choice in
        1) ss_method="aes-128-gcm" ;;
        2) ss_method="aes-256-gcm" ;;
        3) ss_method="chacha20-poly1305" ;;
        *) ss_method="aes-256-gcm" ;;
    esac
    
    cat > "$SCRIPT_DIR/conf/15_shadowsocks_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "::",
      "listen_port": $ss_port,
      "method": "$ss_method",
      "password": "$ss_password"
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

Shadowsocks:
端口: $ss_port
密码: $ss_password
加密方法: $ss_method
EOF

    info "Shadowsocks 配置完成！"
}

# Trojan 配置
configure_trojan() {
    log "配置 Trojan 协议..."
    
    smart_config_setup "trojan" "443" "true" "trojan_domain"
    local default_port=${trojan_port:-443}
    read -p "请输入监听端口 [${default_port}]: " trojan_port
    trojan_port=${trojan_port:-$default_port}
    
    read -p "请输入密码 (回车自动生成): " trojan_password
    trojan_password=${trojan_password:-$(generate_random 16)}
    
    if [[ -z "$trojan_domain" ]]; then
        error "域名或证书未配置"
        return 1
    fi
    
    cat > "$SCRIPT_DIR/conf/16_trojan_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": $trojan_port,
      "users": [
        {
          "password": "$trojan_password"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$trojan_domain",
        "certificate_path": "/etc/sing-box/cert/cert.pem",
        "key_path": "/etc/sing-box/cert/private.key"
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

Trojan:
端口: $trojan_port
密码: $trojan_password
域名: $trojan_domain
EOF

    info "Trojan 配置完成！"
}

# VMess + WebSocket 配置
configure_vmess_ws() {
    log "配置 VMess + WebSocket 协议..."
    
    smart_config_setup "vmess" "80" "false" "_"
    local default_port=${vmess_port:-80}
    read -p "请输入监听端口 [${default_port}]: " vmess_port
    vmess_port=${vmess_port:-$default_port}
    
    read -p "请输入用户UUID (回车自动生成): " vmess_uuid
    vmess_uuid=${vmess_uuid:-$(generate_uuid)}
    
    read -p "请输入WebSocket路径 [/ws]: " ws_path
    ws_path=${ws_path:-/ws}
    
    cat > "$SCRIPT_DIR/conf/17_vmess-ws_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $vmess_port,
      "users": [
        {
          "uuid": "$vmess_uuid",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$ws_path"
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

VMess + WebSocket:
端口: $vmess_port
UUID: $vmess_uuid
路径: $ws_path
EOF

    info "VMess + WebSocket 配置完成！"
}

# VLESS + WebSocket + TLS 配置
configure_vless_ws_tls() {
    log "配置 VLESS + WebSocket + TLS 协议..."
    
    smart_config_setup "vless" "443" "true" "vless_domain"
    local default_port=${vless_port:-443}
    read -p "请输入监听端口 [${default_port}]: " vless_port
    vless_port=${vless_port:-$default_port}
    
    read -p "请输入用户UUID (回车自动生成): " vless_uuid
    vless_uuid=${vless_uuid:-$(generate_uuid)}
    
    read -p "请输入WebSocket路径 [/ws]: " vless_path
    vless_path=${vless_path:-/ws}
    
    if [[ -z "$vless_domain" ]]; then
        error "域名或证书未配置"
        return 1
    fi
    
    cat > "$SCRIPT_DIR/conf/18_vless-ws-tls_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-ws-in",
      "listen": "::",
      "listen_port": $vless_port,
      "users": [
        {
          "uuid": "$vless_uuid"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$vless_domain",
        "certificate_path": "/etc/sing-box/cert/cert.pem",
        "key_path": "/etc/sing-box/cert/private.key"
      },
      "transport": {
        "type": "ws",
        "path": "$vless_path"
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

VLESS + WebSocket + TLS:
端口: $vless_port
UUID: $vless_uuid
路径: $vless_path
域名: $vless_domain
EOF

    info "VLESS + WebSocket + TLS 配置完成！"
}

# Reality HTTP/2 配置
configure_reality_h2() {
    log "配置 Reality HTTP/2 协议..."
    
    smart_config_setup "reality_h2" "443" "false" "_"
    local default_port=${reality_h2_port:-443}
    read -p "请输入监听端口 [${default_port}]: " reality_h2_port
    reality_h2_port=${reality_h2_port:-$default_port}
    
    read -p "请输入目标域名 [www.microsoft.com]: " h2_target_domain
    h2_target_domain=${h2_target_domain:-www.microsoft.com}
    
    read -p "请输入用户UUID (回车自动生成): " h2_user_uuid
    h2_user_uuid=${h2_user_uuid:-$(generate_uuid)}
    
    generate_reality_keys
    h2_short_id=$(generate_short_id)
    
    cat > "$SCRIPT_DIR/conf/19_h2-reality_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-reality-h2",
      "listen": "::",
      "listen_port": $reality_h2_port,
      "users": [
        {
          "uuid": "$h2_user_uuid"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$h2_target_domain",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$h2_target_domain",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["$h2_short_id"]
        }
      },
      "transport": {
        "type": "http",
        "path": "/",
        "headers": {"User-Agent": ["Mozilla/5.0"]}
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

Reality HTTP/2:
端口: $reality_h2_port
UUID: $h2_user_uuid
Public Key: $PUBLIC_KEY
Short ID: $h2_short_id
目标域名: $h2_target_domain
EOF

    info "Reality HTTP/2 配置完成！"
}

# Reality gRPC 配置
configure_reality_grpc() {
    log "配置 Reality gRPC 协议..."
    
    smart_config_setup "reality_grpc" "443" "false" "_"
    local default_port=${reality_grpc_port:-443}
    read -p "请输入监听端口 [${default_port}]: " reality_grpc_port
    reality_grpc_port=${reality_grpc_port:-$default_port}
    
    read -p "请输入目标域名 [www.microsoft.com]: " grpc_target_domain
    grpc_target_domain=${grpc_target_domain:-www.microsoft.com}
    
    read -p "请输入用户UUID (回车自动生成): " grpc_user_uuid
    grpc_user_uuid=${grpc_user_uuid:-$(generate_uuid)}
    
    generate_reality_keys
    grpc_short_id=$(generate_short_id)
    
    cat > "$SCRIPT_DIR/conf/20_grpc-reality_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-reality-grpc",
      "listen": "::",
      "listen_port": $reality_grpc_port,
      "users": [
        {
          "uuid": "$grpc_user_uuid"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$grpc_target_domain",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$grpc_target_domain",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["$grpc_short_id"]
        }
      },
      "transport": {
        "type": "grpc",
        "service_name": "GunService"
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

Reality gRPC:
端口: $reality_grpc_port
UUID: $grpc_user_uuid
Public Key: $PUBLIC_KEY
Short ID: $grpc_short_id
目标域名: $grpc_target_domain
EOF

    info "Reality gRPC 配置完成！"
}

# AnyTLS 配置
configure_anytls() {
    log "配置 AnyTLS 协议..."
    
    smart_config_setup "anytls" "443" "false" "_"
    local default_port=${anytls_port:-443}
    read -p "请输入监听端口 [${default_port}]: " anytls_port
    anytls_port=${anytls_port:-$default_port}
    
    read -p "请输入用户UUID (回车自动生成): " anytls_uuid
    anytls_uuid=${anytls_uuid:-$(generate_uuid)}
    
    read -p "请输入密码 (回车自动生成): " anytls_password
    anytls_password=${anytls_password:-$(generate_random 16)}
    
    read -p "请输入目标域名 [www.microsoft.com]: " anytls_domain
    anytls_domain=${anytls_domain:-www.microsoft.com}
    
    cat > "$SCRIPT_DIR/conf/21_anytls_inbounds.json" << EOF
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "anytls-in",
      "listen": "::",
      "listen_port": $anytls_port,
      "users": [
        {
          "uuid": "$anytls_uuid"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$anytls_domain",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$anytls_domain",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["$(generate_short_id)"]
        }
      }
    }
  ]
}
EOF

    cat >> "$SCRIPT_DIR/list" << EOF

AnyTLS:
端口: $anytls_port
UUID: $anytls_uuid
目标域名: $anytls_domain
EOF

    info "AnyTLS 配置完成！"
}

# 批量配置所有协议
configure_all_protocols() {
    warning "这将配置所有协议，请确保端口不冲突"
    configure_reality_vision
    configure_reality_h2
    configure_reality_grpc
    configure_hysteria2
    configure_tuic
    configure_shadowtls
    configure_shadowsocks
    configure_trojan
    configure_vmess_ws
    configure_vless_ws_tls
    configure_anytls
}
    info "配置信息已保存到 $SCRIPT_DIR/list"
}