#!/usr/bin/env bash

NODE_NAME="$1"
BIND_IP_ADDRESS="$2"
EXPECT_COUNT="$3"
NOMAD_IP_LIST="$4"
SERVER_MODE="$5"

# # # # # # # # # # # # # # # #
# Install nomad
# # # # # # # # # # # # # # # #

# install nomad
echo Fetching Nomad...
cd /tmp/
curl -sSL https://releases.hashicorp.com/nomad/0.3.2/nomad_0.3.2_linux_amd64.zip -o nomad.zip

echo Installing Nomad...
unzip nomad.zip
chmod +x nomad
mv nomad /usr/bin/nomad

mkdir -p /etc/nomad.d
chmod a+w /etc/nomad.d
mkdir -p /var/lib/nomad

if [ -z $SERVER_MODE ]; then
  CONF_BODY=$(cat <<-EOF
client {
    enabled = true
    servers = ["nomad.service.consul:4647"]
}
EOF
)
else
  CONF_BODY=$(cat <<-EOF
server {
    enabled = true
    bootstrap_expect = $EXPECT_COUNT
    retry_join = [$NOMAD_IP_LIST]
}
EOF
)
tee /etc/consul.d/nomad.json <<- EOF
{
  "service": {
    "name": "nomad",
    "address": "$BIND_IP_ADDRESS",
    "port": 4647,
    "checks": [
      {
        "tcp": "$BIND_IP_ADDRESS:4647",
        "interval": "10s"
      }
    ]
  }
}
EOF

consul reload
fi

tee /etc/nomad.d/server.hcl <<-EOF
name = "$NODE_NAME"
data_dir = "/var/lib/nomad"
bind_addr = "$BIND_IP_ADDRESS"
$CONF_BODY
EOF

tee /etc/sysconfig/nomad <<- EOF
EOF

tee /etc/systemd/system/nomad.service <<- EOF
[Unit]
Description=nomad agent
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/sysconfig/nomad
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/bin/nomad agent -config /etc/nomad.d
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable nomad
systemctl start nomad

tee /etc/profile.d/nomad.sh <<- EOF
export NOMAD_ADDR=http://$BIND_IP_ADDRESS:4646
EOF
