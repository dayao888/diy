#!/bin/bash
# 订阅与二维码生成模块

SUB_DIR="/etc/sing-box/subscribe"
mkdir -p "$SUB_DIR/qr" "$SUB_DIR/shadowrocket" "$SUB_DIR/proxies" "$SUB_DIR/clash" "$SUB_DIR/clash2" "$SUB_DIR/sing-box-pc" "$SUB_DIR/sing-box-phone" "$SUB_DIR/sing-box2" "$SUB_DIR/v2rayn" "$SUB_DIR/neko"

# 生成简单的VLESS Reality分享链接与二维码
generate_vless_reality_qr() {
  local domain="$1"
  local port="$2"
  local uuid="$3"
  local public_key="$4"
  local short_id="$5"
  local sni="$domain"
  local url="vless://${uuid}@${domain}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp#VLESS-REALITY"
  echo "$url" > "$SUB_DIR/sing-box-phone/vless-reality.txt"
  qrencode -t svg -o "$SUB_DIR/qr/vless-reality.svg" "$url"
  echo "$url"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "此脚本作为模块被 install.sh 调用"
fi