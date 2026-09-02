#!/usr/bin/env bash

set +e

CLIENT_NS="client"
SRV1_NS="srv1"
SRV2_NS="srv2"

LB_FRONT="lb-front"
LB_SRV1="lb-srv1"
LB_SRV2="lb-srv2"

echo "[+] Cleaning up XDP lab"


echo "[+] Removing namespaces"

ip netns del "$CLIENT_NS" 2>/dev/null
ip netns del "$SRV1_NS" 2>/dev/null
ip netns del "$SRV2_NS" 2>/dev/null


echo "[+] Removing remaining interfaces"

ip link del "$LB_FRONT" 2>/dev/null
ip link del "$LB_SRV1" 2>/dev/null
ip link del "$LB_SRV2" 2>/dev/null


echo "[+] Cleaning up firewalld"

if command -v firewall-cmd >/dev/null 2>&1; then

    firewall-cmd --zone=trusted \
        --remove-interface="$LB_FRONT" \
        >/dev/null 2>&1

    firewall-cmd --zone=trusted \
        --remove-interface="$LB_SRV1" \
        >/dev/null 2>&1

    firewall-cmd --zone=trusted \
        --remove-interface="$LB_SRV2" \
        >/dev/null 2>&1

fi


echo
echo "Lab removed."