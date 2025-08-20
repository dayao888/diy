#!/bin/bash
# 生成 /etc/sing-box/conf 各类配置模板的脚本函数集合
# 被 install.sh 调用以生成初始配置文件

CONF_DIR="/etc/sing-box/conf"

mkdir -p "$CONF_DIR"

write_json() {
  local file="$1"
  local content="$2"
  echo "$content" > "$file"
}

create_00_log() {
  write_json "$CONF_DIR/00_log.json" '{
  "log": {
    "level": "info",
    "disabled": false,
    "timestamp": true,
    "output": "/etc/sing-box/logs/box.log"
  }
}'
}

create_01_outbounds() {
  write_json "$CONF_DIR/01_outbounds.json" '{
  "outbounds": [
    {"type": "direct", "tag": "direct"},
    {"type": "block", "tag": "block"}
  ]
}'
}

create_02_endpoints() {
  write_json "$CONF_DIR/02_endpoints.json" '{
  "experimental": {"cache_file": {"enabled": true, "path": "/etc/sing-box/cache.db"}},
  "endpoints": {
    "warp": {
      "enabled": false,
      "account": {
        "license": "",
        "token": ""
      }
    }
  }
}'
}

create_03_route() {
  write_json "$CONF_DIR/03_route.json" '{
  "route": {
    "rules": [
      {"rule_set": ["geosite-geolocation-!cn"], "outbound": "direct"},
      {"outbound": "direct"}
    ]
  }
}'
}

create_04_experimental() {
  write_json "$CONF_DIR/04_experimental.json" '{
  "experimental": {
    "cache_file": {"enabled": true, "path": "/etc/sing-box/cache.db"}
  }
}'
}

create_05_dns() {
  write_json "$CONF_DIR/05_dns.json" '{
  "dns": {
    "servers": [
      {"tag": "google", "address": "tls://dns.google"},
      {"tag": "local", "address": "https://223.5.5.5/dns-query"}
    ],
    "rules": [],
    "strategy": "prefer_ipv4"
  }
}'
}

create_06_ntp() {
  write_json "$CONF_DIR/06_ntp.json" '{
  "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "interval": "30m"
  }
}'
}

create_inbounds_placeholder() {
  # 先写空的 inbound 文件，后续按协议填充
  for f in 11_xtls-reality_inbounds 12_hysteria2_inbounds 13_tuic_inbounds 14_ShadowTLS_inbounds 15_shadowsocks_inbounds 16_trojan_inbounds 17_vmess-ws_inbounds 18_vless-ws-tls_inbounds 19_h2-reality_inbounds 20_grpc-reality_inbounds 21_anytls_inbounds; do
    write_json "$CONF_DIR/${f}.json" '{"inbounds": []}'
  done
}

create_all_conf_templates() {
  create_00_log
  create_01_outbounds
  create_02_endpoints
  create_03_route
  create_04_experimental
  create_05_dns
  create_06_ntp
  create_inbounds_placeholder
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  create_all_conf_templates
fi