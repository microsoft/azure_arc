#!/bin/bash
sudo ip route add 239.255.255.250/32 dev cni0  
sudo iptables -A INPUT -p udp --dport 3702 -j ACCEPT"
sudo sed -i '/-A OUTPUT -j ACCEPT/i-A INPUT -p udp -m udp --dport 3702 -j ACCEPT' /etc/systemd/scripts/ip4save"   
sudo iptables -A INPUT -p udp --sport 3702 -j ACCEPT"
sudo sed -i '/-A OUTPUT -j ACCEPT/i-A INPUT -p udp -m udp --sport 3702 -j ACCEPT' /etc/systemd/scripts/ip4save" 