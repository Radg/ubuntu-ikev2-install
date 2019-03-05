#!/bin/bash

DOMAIN_NAME=server.example.com
ADMIN_EMAIL=admin@example.com

LEFT_ID="leftid="$DOMAIN_NAME
PWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
CREDENTIALS="user1 : EAP \""$PWD"\""

echo "Installing required packages..."
echo "------------------------------------"
apt-get update && apt-get -y upgrade
apt-get -y install mosh strongswan libcharon-extra-plugins letsencrypt
echo "...done!"

# Get certificates and copy them to destination
echo "Requesting certificates for $DOMAIN_NAME..."
echo "------------------------------------"
letsencrypt certonly --standalone -d $DOMAIN_NAME --non-interactive --agree-tos -m $ADMIN_EMAIL
echo "...done!"
echo "Copying certificates..."
echo "------------------------------------"
cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem /etc/ipsec.d/certs
cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem /etc/ipsec.d/private
echo "...done!"

# Tuning iptables ...
echo "Setting iptables up..."
echo "------------------------------------"
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 4500 -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 500 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 60000:60100 -j ACCEPT
iptables -P INPUT DROP
iptables -t nat -A POSTROUTING -s 10.11.12.0/24 -o eth0 -j MASQUERADE
iptables-save
echo "...done!"

# Tune kernel
echo "Tuning kernel parameters..."
echo "------------------------------------"
echo "net.ipv4.ip_forward = 1" | tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0" | tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" | tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter = 0" | tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_source_route = 0" | tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.send_redirects = 0" | tee -a /etc/sysctl.conf
echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" | tee -a /etc/sysctl.conf
for vpn in /proc/sys/net/ipv4/conf/*; do echo 0 > $vpn/accept_redirects; echo 0 > $vpn/send_redirects; done
sysctl -p
echo "...done!"

echo "Writing to rc.local..."
echo "------------------------------------"
sed -i '/^exit.*/i for vpn in /proc/sys/net/ipv4/conf/*; do echo 0 > $vpn/accept_redirects; echo 0 > $vpn/send_redirects; done' /etc/rc.local
echo "...done!"

#Setup ipsec
echo "Setting ipsec up..."
echo "------------------------------------"
sed -i 's,leftid=domain.*,'"$LEFT_ID"',g' ipsec.conf
echo "...done!"

#Save generated credentials
echo "Saving credentials to ipsec.secrets..."
echo $CREDENTIALS >> ipsec.secrets
echo "...done!"

echo "Copying ipsec files to etc..."
echo "------------------------------------"
cp ipsec.secrets /etc/
cp ipsec.conf /etc/
echo "...done!"

# Enable strongswan & restart ipsec
echo "Enabling strongswan..."
echo "------------------------------------"
systemctl enable strongswan
echo "...done!"

echo "Restarting ipsec..."
echo "------------------------------------"
ipsec restart
echo "...done!"

echo "Setting up crontab..."
echo "------------------------------------"
echo "$(echo "40 1 * * 1 iptables -I INPUT 1 -p tcp --dport 443 -j ACCEPT && letsencrypt renew && cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem /etc/ipsec.d/certs && cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem /etc/ipsec.d/private && ipsec restart && iptables -D INPUT -p tcp --dport 443 -j ACCEPT" ; crontab -l)" | crontab -
echo "...done!"

echo "Finished!"
