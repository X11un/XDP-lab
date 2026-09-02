#!/usr/bin/env bash

set -e

CLIENT_NS="client"
SRV1_NS="srv1"
SRV2_NS="srv2"

LB_FRONT="lb-front"
LB_SRV1="lb-srv1"
LB_SRV2="lb-srv2"

CLIENT_IP="10.200.0.2/24"
LB_FRONT_IP="10.200.0.1/24"

SRV1_IP="10.201.0.2/24"
LB_SRV1_IP="10.201.0.1/24"

SRV2_IP="10.202.0.2/24"
LB_SRV2_IP="10.202.0.1/24"

VIP="10.200.0.100/32"

echo "[+] Creating namespaces"

ip netns add "$CLIENT_NS"
ip netns add "$SRV1_NS"
ip netns add "$SRV2_NS"


echo "[+] Bringing up loopback interfaces"

ip -n "$CLIENT_NS" link set lo up
ip -n "$SRV1_NS" link set lo up
ip -n "$SRV2_NS" link set lo up


echo "[+] Creating client <-> load balancer link"

ip link add cli0 type veth peer name "$LB_FRONT"

ip link set cli0 netns "$CLIENT_NS"

ip -n "$CLIENT_NS" link set cli0 name eth0

ip -n "$CLIENT_NS" addr add "$CLIENT_IP" dev eth0
ip addr add "$LB_FRONT_IP" dev "$LB_FRONT"

ip -n "$CLIENT_NS" link set eth0 up
ip link set "$LB_FRONT" up


echo "[+] Creating backend 1 <-> load balancer link"

ip link add srv1eth type veth peer name "$LB_SRV1"

ip link set srv1eth netns "$SRV1_NS"

ip -n "$SRV1_NS" link set srv1eth name eth0

ip -n "$SRV1_NS" addr add "$SRV1_IP" dev eth0
ip addr add "$LB_SRV1_IP" dev "$LB_SRV1"

ip -n "$SRV1_NS" link set eth0 up
ip link set "$LB_SRV1" up


echo "[+] Creating backend 2 <-> load balancer link"

ip link add srv2eth type veth peer name "$LB_SRV2"

ip link set srv2eth netns "$SRV2_NS"

ip -n "$SRV2_NS" link set srv2eth name eth0

ip -n "$SRV2_NS" addr add "$SRV2_IP" dev eth0
ip addr add "$LB_SRV2_IP" dev "$LB_SRV2"

ip -n "$SRV2_NS" link set eth0 up
ip link set "$LB_SRV2" up


echo "[+] Adding default routes"

ip -n "$CLIENT_NS" route add default via 10.200.0.1
ip -n "$SRV1_NS" route add default via 10.201.0.1
ip -n "$SRV2_NS" route add default via 10.202.0.1


echo "[+] Enabling IPv4 forwarding"

sysctl -w net.ipv4.ip_forward=1


echo "[+] Configuring firewalld"

if command -v firewall-cmd >/dev/null 2>&1; then

    if firewall-cmd --state >/dev/null 2>&1; then

        firewall-cmd --zone=trusted --change-interface="$LB_FRONT"
        firewall-cmd --zone=trusted --change-interface="$LB_SRV1"
        firewall-cmd --zone=trusted --change-interface="$LB_SRV2"

    fi
fi


echo "[+] Adding VIP"

ip addr add "$VIP" dev "$LB_FRONT"

ip -n "$SRV1_NS" addr add "$VIP" dev lo
ip -n "$SRV2_NS" addr add "$VIP" dev lo


echo
echo "===================================="
echo " XDP lab ready"
echo "===================================="
echo
echo "Client : 10.200.0.2"
echo "LB     : 10.200.0.1"
echo "VIP    : 10.200.0.100"
echo "srv1   : 10.201.0.2"
echo "srv2   : 10.202.0.2"
echo