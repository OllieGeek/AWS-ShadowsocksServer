#!/bin/bash

shadowsocks_port=$((1024 + RANDOM % 65535))
while [ -f /opt/shadowsocks/ss-server_$shadowsocks_port.conf ]; do
    echo "$shadowsocks_port already used"
    shadowsocks_port=$((1024 + RANDOM % 65535))
done

shadowsocks_pass="$(printf "%s" $(echo $(date +%s) $(dd if=/dev/urandom bs=100 count=1) | sha256sum | head -c 32))"
shadowsocks_ciph='chacha20-ietf-poly1305'
udtmp="$shadowsocks_ciph:$shadowsocks_pass"
userdata=$(printf "%s" $udtmp|base64 -w 0)

external_ip=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
availability_zone=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)
region=$(echo $availability_zone | sed -n 's/\(.*\)[a-c]/\1/p')
security_group=$(curl http://169.254.169.254/latest/meta-data/security-groups)
security_group_id=$(aws ec2 describe-security-groups --region $region --group-names "$security_group" --query SecurityGroups[*].{Name:GroupId} | sed -n 's/.*\: "\(.*\)\".*/\1/p')

printf "{\"server\": \"0.0.0.0\",\"server_port\": \"$shadowsocks_port\",\"local_port\": \"1080\",\"method\": \"$shadowsocks_ciph\",\"fast_open\": true,\"password\": \"$shadowsocks_pass\",\"nameserver\": \"1.0.0.1\",\"nameserver\": \"1.1.1.1\",\"mode\": \"tcp_and_udp\",\"timeout\": 300}" | sudo tee /opt/shadowsocks/ss-server_$shadowsocks_port.conf 

SSURI="ss://$userdata@$external_ip:$shadowsocks_port#$instance_id%20(port:%20$shadowsocks_port%20/%20region:%20$region)" 

echo "$SSURI" | sudo tee /opt/shadowsocks/client-url_$shadowsocks_port.txt
sudo chown ec2-user:root /opt/shadowsocks/client-url_$shadowsocks_port.txt
sudo chmod u=r,g=,o= /opt/shadowsocks/client-url_$shadowsocks_port.txt

aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port $shadowsocks_port --cidr 0.0.0.0/0 --region $region
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol udp --port $shadowsocks_port --cidr 0.0.0.0/0 --region $region