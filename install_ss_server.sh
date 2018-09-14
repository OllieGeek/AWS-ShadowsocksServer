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

sudo mv /etc/sysctl.conf /home/ec2-user/sysctl.conf.BAK
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

cd ~/

sudo mkdir /opt/shadowsocks

shadowsocks_port=$((1024 + RANDOM % 65535))
shadowsocks_pass="$(echo $(date +%s) $((1 + RANDOM % 1000000)) | sha256sum | base64 | head -c $((16 + RANDOM % 24)))"
shadowsocks_ciph='chacha20-ietf-poly1305'
udtmp="$shadowsocks_ciph:$shadowsocks_pass"
userdata=$(printf "%s" $udtmp|base64 -w 0)

external_ip=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
availability_zone=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)
region=$(echo $availability_zone | sed -n 's/\(.*\)[a-c]/\1/p')
security_group=$(curl http://169.254.169.254/latest/meta-data/security-groups)
security_group_id=$(aws ec2 describe-security-groups --region $region --group-names "$security_group" --query SecurityGroups[*].{Name:GroupId} | sed -n 's/.*\: "\(.*\)\".*/\1/p')

printf "{\"server\": \"0.0.0.0\",\"server_port\": \"$shadowsocks_port\",\"local_port\": \"1080\",\"method\": \"$shadowsocks_ciph\",\"fast_open\": true,\"password\": \"$shadowsocks_pass\",\"nameserver\": \"1.1.1.1\",\"nameserver\": \"1.0.0.1\",\"mode\": \"tcp_and_udp\",\"timeout\": 300}" | sudo tee /opt/shadowsocks/ss-server.conf 

SSURI="ss://$userdata@$external_ip:$shadowsocks_port#$instance_id%20($region)" 

echo "echo '$SSURI'" | sudo tee /opt/shadowsocks/client-url.sh
sudo chown ec2-user:root /opt/shadowsocks/client-url.sh
sudo chmod u=rx,g=,o= /opt/shadowsocks/client-url.sh

echo "ss-server -c /opt/shadowsocks/ss-server.conf -f /opt/shadowsocks/pid/ss-server.pid" | sudo tee /opt/shadowsocks/server-start.sh
sudo chown ec2-user:root /opt/shadowsocks/server-start.sh
sudo chmod u=rx,g=,o= /opt/shadowsocks/server-start.sh

sudo mkdir /opt/shadowsocks/pid/
sudo chown ec2-user:ec2-user /opt/shadowsocks/pid/

aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port $shadowsocks_port --cidr 0.0.0.0/0 --region $region
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol udp --port $shadowsocks_port --cidr 0.0.0.0/0 --region $region

su - ec2-user /opt/shadowsocks/server-start.sh