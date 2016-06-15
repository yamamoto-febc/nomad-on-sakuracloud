#!/usr/bin/env bash

# # # # # # # # # # # # # # # #
# install nginx
# # # # # # # # # # # # # # # #
yum install --assumeyes nginx


systemctl enable nginx
systemctl start nginx

# # # # # # # # # # # # # # # #
# install consul-template
# # # # # # # # # # # # # # # #
cd /tmp
curl -L https://releases.hashicorp.com/consul-template/0.15.0/consul-template_0.15.0_linux_amd64.zip -o consul-template.zip
unzip consul-template.zip
chmod +x consul-template
mv consul-template /usr/bin/consul-template

mkdir -p /etc/consul-template/
chmod a+w /etc/consul-template/

tee /etc/systemd/system/consul-template.service <<- EOF
[Unit]
Description=consul-template
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/consul-template -config=/etc/consul-template/generate-front-nginx.conf
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable consul-template
systemctl start consul-template
