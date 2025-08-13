#!/bin/sh
# Surfshark WireGuard Setup + Test Script
# Interface: wg0
# Firewall zone: vpn0
# Usage: sh install-wg0.sh <config_file>

WG_INTERFACE="wg0"
FW_ZONE="vpn0"
CONF_FILE="$1"

if [ -z "$CONF_FILE" ]; then
    echo "[ERROR] Please provide the WireGuard config file path."
    echo "Usage: sh $0 <config_file>"
    exit 1
fi

if [ ! -f "$CONF_FILE" ]; then
    echo "[ERROR] Config file '$CONF_FILE' not found."
    exit 1
fi

echo "[INFO] Deleting old WireGuard interface if exists..."
uci -q delete network.$WG_INTERFACE

echo "[INFO] Creating new WireGuard interface..."
uci set network.$WG_INTERFACE="interface"
uci set network.$WG_INTERFACE.proto="wireguard"

# 从配置文件读取值
WG_ADDR=$(grep '^Address' "$CONF_FILE" | awk '{print $3}')
WG_PRIVKEY=$(grep '^PrivateKey' "$CONF_FILE" | awk '{print $3}')
WG_DNS=$(grep '^DNS' "$CONF_FILE" | cut -d' ' -f3-)
WG_PUBKEY=$(grep '^PublicKey' "$CONF_FILE" | awk '{print $3}')
WG_ALLOWED=$(grep '^AllowedIPs' "$CONF_FILE" | awk '{print $3}')
WG_ENDPOINT=$(grep '^Endpoint' "$CONF_FILE" | awk '{print $3}')

uci set network.$WG_INTERFACE.addresses="$WG_ADDR"
uci set network.$WG_INTERFACE.private_key="$WG_PRIVKEY"
uci set network.$WG_INTERFACE.dns="$WG_DNS"

# 添加 peer
uci add network wireguard_$WG_INTERFACE
uci set network.@wireguard_$WG_INTERFACE[-1].public_key="$WG_PUBKEY"
uci set network.@wireguard_$WG_INTERFACE[-1].allowed_ips="$WG_ALLOWED"
uci set network.@wireguard_$WG_INTERFACE[-1].endpoint_host="${WG_ENDPOINT%:*}"
uci set network.@wireguard_$WG_INTERFACE[-1].endpoint_port="${WG_ENDPOINT##*:}"
uci set network.@wireguard_$WG_INTERFACE[-1].persistent_keepalive="25"

# ===== 防火墙配置 =====
echo "[INFO] Removing old firewall zone and forwardings if exist..."
ZONE_INDEX=$(uci show firewall | grep ".name='$FW_ZONE'" | cut -d'[' -f2 | cut -d']' -f1)
if [ -n "$ZONE_INDEX" ]; then
    uci delete firewall.@zone[$ZONE_INDEX]
fi
for idx in $(uci show firewall | grep ".dest='$FW_ZONE'" | cut -d'[' -f2 | cut -d']' -f1); do
    uci delete firewall.@forwarding[$idx]
done

echo "[INFO] Creating new firewall zone '$FW_ZONE'..."
uci add firewall zone
uci set firewall.@zone[-1].name="$FW_ZONE"
uci set firewall.@zone[-1].network="$WG_INTERFACE"
uci set firewall.@zone[-1].input="ACCEPT"
uci set firewall.@zone[-1].output="ACCEPT"
uci set firewall.@zone[-1].forward="REJECT"

echo "[INFO] Adding LAN -> $FW_ZONE forwarding..."
uci add firewall forwarding
uci set firewall.@forwarding[-1].src="lan"
uci set firewall.@forwarding[-1].dest="$FW_ZONE"

# 保存并应用
uci commit network
uci commit firewall
/etc/init.d/network restart
/etc/init.d/firewall restart

# ===== 测试部分 =====
echo "[INFO] Waiting 5s for interface to come up..."
sleep 5

echo "[TEST] WireGuard status:"
wg show $WG_INTERFACE

echo "[TEST] Routing table:"
ip route | head -n 5

# 检测公网IP
echo "[TEST] Checking public IP..."
VPN_IP=$(wget -qO- https://api.ipify.org)
echo "Public IP: $VPN_IP"

# 检查握手
if wg show $WG_INTERFACE | grep -q "latest handshake"; then
    echo "[RESULT] WireGuard interface '$WG_INTERFACE' handshake detected."
else
    echo "[WARNING] No handshake detected. Please check keys, endpoint, and firewall."
fi

echo "[DONE] Setup + Test finished."
