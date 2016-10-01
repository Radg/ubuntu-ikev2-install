#!/bin/bash

# Config file
source config

# Established or related connections accept
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp -m tcp --dport $SSH_PORT -j ACCEPT

# Port for VPN
iptables -A INPUT -p udp -m udp --dport 4500 -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 500 -j ACCEPT

# Loopback interface accept
iptables -A INPUT -i lo -j ACCEPT

# Drop other connections
iptables -P INPUT DROP

# Masquerading for VPN
iptables -t nat -A POSTROUTING -s $VPN_NET -o eth0 -j MASQUERADE

# Save iptables rules
iptables-save > $IPT_RULES

apt-get install -y iptables-persistent