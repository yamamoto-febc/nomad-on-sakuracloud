#!/usr/bin/env bash

NODE_NAME="$1"
BIND_IP_ADDRESS="$2"
EXPECT_COUNT="$3"
CONSUL_IP_LIST="$4"
SERVER_MODE="$5"

# # # # # # # # # # # # # # # #
# Install consul
# # # # # # # # # # # # # # # #

echo Fetching Consul...
cd /tmp/
curl -sSL https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_linux_amd64.zip -o consul.zip

echo Installing Consul...
unzip consul.zip
chmod +x consul
mv consul /usr/bin/consul

mkdir -p /etc/consul.d
chmod a+w /etc/consul.d
mkdir -p /var/lib/consul

if [ -z $SERVER_MODE ]; then
  OPTIONS="-data-dir /var/lib/consul -node=$NODE_NAME -bind=$BIND_IP_ADDRESS $CONSUL_IP_LIST"
else
  OPTIONS="-server -bootstrap-expect $EXPECT_COUNT -data-dir /var/lib/consul -node=$NODE_NAME -bind=$BIND_IP_ADDRESS $CONSUL_IP_LIST"
fi

# create defautl config
tee /etc/sysconfig/consul <<- EOF
GOMAXPROCS=2
OPTIONS=$OPTIONS
EOF

tee /etc/systemd/system/consul.service <<- EOF
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/sysconfig/consul
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/bin/consul agent \$OPTIONS  -config-dir /etc/consul.d
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable consul
systemctl start consul

# setup dnsmasq for consul
tee /etc/dnsmasq.d/consul.conf << EOF
server=/consul/127.0.0.1#8600
strict-order
EOF

sed -i '1i nameserver 127.0.0.1' /etc/resolv.conf
systemctl restart dnsmasq.service