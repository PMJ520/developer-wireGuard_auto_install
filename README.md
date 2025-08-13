# developer-wireGuard_auto_install
自动配置WireGuard工具

在执行脚本前，需要先更新软件源并安装以下必要功能包(优先考虑在后台更新)
opkg update || true
opkg install tcpdump uci [ wireguard-tools luci-proto-wireguard ]  || true


使用示例：
```Base
bash <(curl -L https://raw.githubusercontent.com/PMJ520/developer-wireGuard_auto_install/refs/heads/main/wireguard_auto.sh) *.conf
