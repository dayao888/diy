#!/bin/bash
# sing-box 快捷管理脚本
# 使用: sb.sh {start|stop|restart|status|log}

SERVICE=sing-box
LOG_FILE=/etc/sing-box/logs/box.log

case "$1" in
  start)
    systemctl start $SERVICE
    ;;
  stop)
    systemctl stop $SERVICE
    ;;
  restart)
    systemctl restart $SERVICE
    ;;
  status)
    systemctl status $SERVICE --no-pager
    ;;
  log)
    journalctl -u $SERVICE -f -n 200 --no-pager
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status|log}"
    exit 1
    ;;
fi