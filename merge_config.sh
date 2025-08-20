#!/bin/bash
# 将 /etc/sing-box/conf 目录下的JSON配置文件合并为单一config.json
# 用于支持 systemd 启动

SCRIPT_DIR="/etc/sing-box"
CONF_DIR="$SCRIPT_DIR/conf"
TARGET_CONFIG="$SCRIPT_DIR/config.json"

merge_json_configs() {
    local log_file="$CONF_DIR/00_log.json"
    local outbounds_file="$CONF_DIR/01_outbounds.json"
    local endpoints_file="$CONF_DIR/02_endpoints.json"
    local route_file="$CONF_DIR/03_route.json"
    local experimental_file="$CONF_DIR/04_experimental.json"
    local dns_file="$CONF_DIR/05_dns.json"
    local ntp_file="$CONF_DIR/06_ntp.json"
    
    # 收集所有入站配置
    local inbound_configs=""
    for inbound_file in "$CONF_DIR"/*_inbounds.json; do
        if [[ -f "$inbound_file" ]]; then
            local inbound_content=$(jq -r '.inbounds[]?' "$inbound_file" 2>/dev/null | jq -s '.')
            if [[ "$inbound_content" != "[]" && "$inbound_content" != "null" ]]; then
                if [[ -z "$inbound_configs" ]]; then
                    inbound_configs="$inbound_content"
                else
                    inbound_configs=$(echo "$inbound_configs" | jq ". + $inbound_content")
                fi
            fi
        fi
    done
    
    # 默认空入站配置
    if [[ -z "$inbound_configs" || "$inbound_configs" == "[]" ]]; then
        inbound_configs="[]"
    fi
    
    # 合并所有配置到一个JSON对象
    cat > "$TARGET_CONFIG" << EOF
{
  $(jq -r '.log' "$log_file" 2>/dev/null | sed 's/^/"log": /' | sed 's/$/,/' || echo '"log": {"level": "info", "disabled": false, "timestamp": true, "output": "/etc/sing-box/logs/box.log"},')
  "inbounds": $inbound_configs,
  $(jq -r '.outbounds' "$outbounds_file" 2>/dev/null | sed 's/^/"outbounds": /' | sed 's/$/,/' || echo '"outbounds": [{"type": "direct", "tag": "direct"}, {"type": "block", "tag": "block"}],')
  $(jq -r '.route' "$route_file" 2>/dev/null | sed 's/^/"route": /' | sed 's/$/,/' || echo '"route": {"rules": [{"outbound": "direct"}]},')
  $(jq -r '.experimental' "$experimental_file" 2>/dev/null | sed 's/^/"experimental": /' | sed 's/$/,/' || echo '"experimental": {"cache_file": {"enabled": true, "path": "/etc/sing-box/cache.db"}},')
  $(jq -r '.dns' "$dns_file" 2>/dev/null | sed 's/^/"dns": /' | sed 's/$/,/' || echo '"dns": {"servers": [{"tag": "google", "address": "tls://dns.google"}], "strategy": "prefer_ipv4"},')
  $(jq -r '.ntp' "$ntp_file" 2>/dev/null | sed 's/^/"ntp": /' || echo '"ntp": {"enabled": true, "server": "time.apple.com", "interval": "30m"}')
}
EOF

    # 验证JSON格式
    if ! jq . "$TARGET_CONFIG" >/dev/null 2>&1; then
        echo "生成的config.json格式错误，尝试修复..."
        # 简化配置
        cat > "$TARGET_CONFIG" << EOF
{
  "log": {
    "level": "info",
    "disabled": false,
    "timestamp": true,
    "output": "/etc/sing-box/logs/box.log"
  },
  "inbounds": $inbound_configs,
  "outbounds": [
    {"type": "direct", "tag": "direct"},
    {"type": "block", "tag": "block"}
  ],
  "route": {
    "rules": [
      {"outbound": "direct"}
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "/etc/sing-box/cache.db"
    }
  },
  "dns": {
    "servers": [
      {"tag": "google", "address": "tls://dns.google"}
    ],
    "strategy": "prefer_ipv4"
  },
  "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "interval": "30m"
  }
}
EOF
    fi
    
    echo "配置已合并到 $TARGET_CONFIG"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    merge_json_configs
fi