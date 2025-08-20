# Sing-box 科学上网一键安装脚本

适用于 Ubuntu 22.04 AMD64 系统的完整科学上网解决方案。

## 系统要求

- **操作系统**: Ubuntu 22.04+ (推荐)
- **架构**: AMD64/ARM64
- **权限**: Root 用户权限
- **网络**: 具备公网 IP 的服务器
- **域名**: (可选) 用于 TLS 协议

## 快速开始

### 1. 下载脚本
```bash
git clone https://github.com/dayao888/diy
cd diy
```

### 2. 运行安装
```bash
sudo chmod +x install.sh
sudo ./install.sh


### 直接在线安装的命令 运行安装
- bash -c "$(curl -fsSL https://raw.githubusercontent.com/dayao888/diy/main/install.sh )"

- 或 curl -fsSL https://raw.githubusercontent.com/dayao888/diy/main/install.sh | bash
```

### 3. 选择安装选项
- 选择 `1` 进行初始安装
- 选择 `2` 配置代理协议
- 后续可通过菜单管理服务

## 支持的协议

### 无需域名的协议
1. **Reality XTLS-Vision** (推荐) - 最新抗封锁技术
2. **Reality HTTP/2** - 基于 HTTP/2 的 Reality
3. **Reality gRPC** - 基于 gRPC 的 Reality  
4. **ShadowTLS** - 伪装 TLS 流量
5. **Shadowsocks** - 经典协议
6. **VMess + WebSocket** - V2Ray 协议

### 需要域名和证书的协议
7. **Hysteria2** - 基于 QUIC 的高速协议
8. **TUIC v5** - 低延迟 UDP 协议
9. **Trojan** - 伪装 HTTPS 流量
10. **VLESS + WebSocket + TLS** - 轻量级协议
11. **AnyTLS** - 通用 TLS 伪装

## 目录结构

```
/etc/sing-box/
├── sing-box                    # 主程序
├── jq                         # JSON 处理工具
├── qrencode                   # 二维码生成工具
├── sb.sh                      # 快捷管理脚本
├── config.json                # 主配置文件
├── list                       # 协议配置信息
├── nginx.conf                 # 订阅服务配置
├── cert/                      # SSL 证书目录
│   ├── cert.pem
│   └── private.key
├── conf/                      # 配置文件模板
│   ├── 00_log.json           # 日志配置
│   ├── 01_outbounds.json     # 出站配置
│   ├── 02_endpoints.json     # 端点配置
│   ├── 03_route.json         # 路由配置
│   ├── 04_experimental.json  # 实验性功能
│   ├── 05_dns.json           # DNS 配置
│   ├── 06_ntp.json           # 时间同步配置
│   └── 1*_*_inbounds.json    # 各协议入站配置
├── logs/                      # 日志目录
│   ├── box.log               # sing-box 日志
└── subscribe/                 # 订阅文件目录
    ├── qr/                   # 二维码文件
    ├── shadowrocket/         # Shadowrocket 订阅
    ├── clash/                # Clash 订阅
    ├── v2rayn/               # V2rayN 订阅
    ├── sing-box-pc/          # sing-box PC 客户端
    ├── sing-box-phone/       # sing-box 手机客户端
    └── neko/                 # NekoBox 订阅
```

## 快捷管理命令

安装完成后，可使用以下快捷命令：

```bash
sb start     # 启动 sing-box
sb stop      # 停止 sing-box
sb restart   # 重启 sing-box
sb status    # 查看状态
sb log       # 查看日志
```

## 详细功能说明

### 1. 安装功能 (菜单选项1)
- 系统兼容性检查
- 自动安装依赖包 (nginx, certbot, jq 等)
- 下载最新版 sing-box
- 创建完整目录结构
- 配置 systemd 服务自启动
- 可选部署 Nginx 订阅服务

### 2. 协议配置 (菜单选项2)
- 支持 11 种主流代理协议
- 自动生成配置文件
- 自动合并配置并重启服务
- 生成分享链接和二维码

### 3. 服务管理 (菜单选项3)
- 启动/停止/重启服务
- 查看运行状态
- 实时查看日志

### 4. 查看配置 (菜单选项4)
- 显示配置文件目录
- 列出已生成的配置

### 5. 程序更新 (菜单选项5)
- 自动下载最新版本
- 保留现有配置
- 重启服务应用更新

### 6. 完全卸载 (菜单选项6)
- 停止所有相关服务
- 删除 systemd 配置
- 清理所有文件和目录
- 移除 Nginx 站点配置
- 删除快捷命令

### 7. 语言设置 (菜单选项7)
- 当前版本为中文界面
- 预留多语言支持接口

## SSL 证书配置

### 对于需要证书的协议 (Hysteria2, TUIC, Trojan, VLESS+TLS)

#### 方法1: 使用 Let's Encrypt (推荐)
```bash
# 确保域名已解析到服务器IP
certbot certonly --nginx -d yourdomain.com

# 复制证书到 sing-box 目录
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem /etc/sing-box/cert/cert.pem
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem /etc/sing-box/cert/private.key
```

#### 方法2: 手动上传证书
```bash
# 将证书文件放置到指定位置
cp your-cert.pem /etc/sing-box/cert/cert.pem
cp your-private.key /etc/sing-box/cert/private.key

# 设置正确权限
chmod 600 /etc/sing-box/cert/private.key
chmod 644 /etc/sing-box/cert/cert.pem
```

## 订阅服务部署

### Nginx 订阅服务
安装时可选择部署订阅服务，支持：
- 自定义监听端口 (默认8080)
- CORS 跨域支持
- 自动文件索引
- 访问日志记录

### 客户端订阅格式
脚本自动生成多种客户端订阅：
- **Shadowrocket** (iOS)
- **Clash** (Windows/Mac/Android)
- **V2rayN** (Windows)
- **sing-box** (PC/Mobile)
- **NekoBox** (Android)

## 故障排除

### 常见问题

#### 1. 服务启动失败
```bash
# 检查配置文件语法
/etc/sing-box/sing-box check -c /etc/sing-box/config.json

# 查看详细错误日志
journalctl -u sing-box -f
```

#### 2. 端口冲突
```bash
# 检查端口占用
netstat -tlnp | grep :443

# 修改配置中的端口号
```

#### 3. SSL 证书问题
```bash
# 检查证书有效性
openssl x509 -in /etc/sing-box/cert/cert.pem -text -noout

# 检查私钥匹配
openssl rsa -in /etc/sing-box/cert/private.key -check
```

#### 4. Reality 协议连接失败
- 确保目标域名可正常访问
- 检查时间同步 (`ntpdate -s time.nist.gov`)
- 验证 Reality 密钥对正确性

### 日志查看
```bash
# sing-box 服务日志
journalctl -u sing-box -f

# 文件日志
tail -f /etc/sing-box/logs/box.log
```

## 更新与维护

### 程序更新
- 脚本菜单选择 `5 - 更新程序`
- 自动下载最新版本
- 保留现有配置不变

### 配置备份
```bash
# 备份整个配置目录
tar -czf sing-box-backup.tar.gz /etc/sing-box/

# 恢复配置
tar -xzf sing-box-backup.tar.gz -C /
```

### 性能优化
```bash
# 调整系统参数
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -p
```

## 安全建议

1. **定期更新**: 保持 sing-box 和系统最新版本
2. **端口安全**: 使用非标准端口，配置防火墙规则
3. **密钥管理**: 定期更换密码和 UUID
4. **监控日志**: 关注异常连接和错误日志
5. **证书续期**: 自动续期 SSL 证书

## 技术支持

- **项目地址**: https://github.com/dayao888/diy
- **问题反馈**: GitHub Issues
- **sing-box 官方文档**: https://sing-box.sagernet.org/

## 许可证

本项目基于 MIT 许可证开源。

-1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111--
## 项目检查报告：整体质量良好，已完成核心功能优化
经过全面检查，您的sing-box一键安装脚本项目整体运行逻辑正确，关联调用关系清晰，配置文件结构合理。以下是详细分析：

### ✅ 项目架构设计正确
核心脚本分工明确：

- `install.sh` ：主控脚本，包含系统检查、安装流程、菜单管理
- `protocols.sh` ：11种协议配置实现
- `security.sh` ：安全加固与BBR配置
- `merge_config.sh` ：配置合并引擎
- `templates_conf.sh` ：基础配置模板生成
- `subscribe.sh` ：订阅链接与二维码生成
- `sb.sh` ：快捷管理命令
### ✅ 配置文件结构合理
模块化配置设计：

- 基础配置： 00_log.json 到 06_ntp.json
- 协议配置： 11_*_inbounds.json 到 21_*_inbounds.json
- 最终合并：通过 `merge_json_configs` 生成完整的 config.json
### ✅ 关键功能实现检查通过
1. 依赖管理

- 系统包自动安装： nginx , certbot , jq , qrencode , bc , dnsutils
- 二进制下载：sing-box程序、jq工具自动获取最新版本
2. 服务管理

- systemd服务正确创建： `create_systemd_service`
- 快捷命令集成： sb start/stop/restart/status/log
3. 协议配置完整性

- 11种协议全部实现：Reality(XTLS/H2/gRPC)、Hysteria2、TUIC、ShadowTLS、Shadowsocks、Trojan、VMess、VLESS、AnyTLS
- 智能配置逻辑： `smart_config_setup` 自动处理端口分配与证书生成
### 🔧 已完成的关键优化
1. 证书自动化处理

- 智能域名检查：自动验证DNS解析是否指向服务器IP
- 双重证书策略：域名证书(Let's Encrypt) + 自签名证书回退
- 自动续期计划：集成certbot定时任务
2. 端口智能分配

- 随机端口范围：20000-50000，自动检测冲突
- 端口占用检查： `is_port_in_use`
- 手动输入备选：支持用户自定义端口
3. 安全加固机制

- fail2ban防暴破：针对20000-50000端口段防扫描
- UFW防火墙：默认拒绝入站，仅开放必要端口
- 内核安全参数：启用BBR、syncookies、rp_filter等
- 服务隐身：可选修改SSH端口、禁用不必要服务
### ✅ 配置合并逻辑正确
分层配置架构：

- 模板生成： `templates_conf.sh` 创建基础JSON文件
- 协议添加：各 configure_* 函数写入对应的 *_inbounds.json
- 配置合并： `merge_json_configs` 按序合并并验证JSON格式
- 服务重启：每次配置更新后自动重启sing-box服务
### ✅ 订阅服务设计合理
多客户端支持：

- 目录结构： shadowrocket/ , clash/ , v2rayn/ , neko/ , sing-box-pc/ , sing-box-phone/
- Nginx订阅：可选部署，支持CORS，自动文件索引
- 二维码生成：集成qrencode，自动生成SVG格式二维码
### 🎯 总体评价：项目质量优秀
优点：

1. 1.
   架构清晰 ：模块化设计，职责分离明确
2. 2.
   功能完整 ：支持11种主流协议，覆盖各种使用场景
3. 3.
   用户友好 ：交互式菜单，智能配置，错误处理完善
4. 4.
   安全考量 ：内置防护机制，支持证书自动化
5. 5.
   维护性强 ：配置文件分离，便于管理和排错
建议使用流程：

1. 1.
   运行 sudo ./install.sh 选择"1"安装sing-box
2. 2.
   选择"2"配置所需协议（推荐Reality XTLS-Vision）
3. 3.
   选择"8"一键安全加固
4. 4.
   选择"9"检查BBR状态
5. 5.
   管理服务→查看节点链接信息获取分享链接

**免责声明**: 本脚本仅供学习和研究使用，请遵守当地法律法规。