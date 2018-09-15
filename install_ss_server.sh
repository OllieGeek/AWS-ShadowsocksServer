#!/bin/bash

sudo yum install python-pip -y
sudo python -m pip install pip --upgrade

sudo amazon-linux-extras install epel -y

sudo yum install -y gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto udns-devel \
               libev-devel libsodium-devel mbedtls-devel git m2crypto c-ares-devel

sudo yum groupinstall "Development Tools" -y

cd /opt
sudo git clone https://github.com/shadowsocks/shadowsocks-libev.git
cd shadowsocks-libev
sudo git submodule update --init --recursive

sudo ./autogen.sh
sudo ./configure
sudo make
sudo make install

echo '''* soft nofile 51200
* hard nofile 51200''' | sudo tee /etc/security/limits.conf

ulimit -n 51200

sudo mv /etc/sysctl.conf /home/ec2-user/config-backup/sysctl.conf.BAK
sudo touch /etc/sysctl.conf

echo '''fs.file-max = 51200

net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096

net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = cubic''' | sudo tee /etc/sysctl.d/local.conf

sudo sysctl --system

sudo mkdir /opt/shadowsocks

echo '''#!/bin/sh
# TO BE GENERATED''' | sudo tee /opt/shadowsocks/server-start.sh

sudo chown ec2-user:root /opt/shadowsocks/server-start.sh
sudo chmod u=rx,g=,o= /opt/shadowsocks/server-start.sh

sudo mkdir /opt/shadowsocks/pid/
sudo chown ec2-user:ec2-user /opt/shadowsocks/pid/

for i in $(seq 1 $(cat /home/ec2-user/aws-ss-config/config_endpoints.tmp));
do
    /opt/aws-ss/create_ss_endpoint.sh
done

echo "[Unit]
Description=Shadowsocks via aws-ss
After=network.target

[Service]
Type=forking
User=ec2-user
WorkingDirectory=/opt/shadowsocks
ExecStart=/opt/shadowsocks/server-start.sh
Restart=on-failure" | sudo tee /lib/systemd/system/aws-ss.service

sudo systemctl daemon-reload
sudo systemctl enable aws-ss
sudo systemctl start aws-ss