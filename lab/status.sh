#!/usr/bin/env bash

echo
echo "=== Namespaces ==="
ip netns list


echo
echo "=== LB Interfaces ==="
ip -br addr show lb-front 2>/dev/null
ip -br addr show lb-srv1 2>/dev/null
ip -br addr show lb-srv2 2>/dev/null


echo
echo "=== Client ==="
ip -n client -br addr 2>/dev/null


echo
echo "=== Backend 1 ==="
ip -n srv1 -br addr 2>/dev/null


echo
echo "=== Backend 2 ==="
ip -n srv2 -br addr 2>/dev/null


echo
echo "=== Client Routes ==="
ip -n client route 2>/dev/null


echo
echo "=== srv1 Routes ==="
ip -n srv1 route 2>/dev/null


echo
echo "=== srv2 Routes ==="
ip -n srv2 route 2>/dev/null


echo
echo "=== IPv4 Forwarding ==="
sysctl net.ipv4.ip_forward