#!/bin/bash

ver=$(wget -qO- "https://api.github.com/repos/txthinking/brook/releases/latest" | sed -n -r -e 's/.*"tag_name".+?"([vV0-9\.]+?)".*/\1/p')
[[ -z "${ver}" ]] && ver="v20210401"
brook_latest="https://github.com/txthinking/brook/releases/download/$ver/brook_linux_amd64"
wget --no-check-certificate $brook_latest
chmod +x brook_linux_amd64

./brook_linux_amd64 wsserver -l :12345 --path ${ws_path} -p $password &

[[ -z "${ws_path}" ]] && ws_path="/ws"

[[ -z "${url_redir}" ]] && url_redir="github.com/txthinking/brook"

if [[ "${app_name}" != "skip" ]]; then
    # generate a Brook link and a QR code
    mkdir /root/$password
    brook_link=$(./brook_linux_amd64 link -s wss://${app_name}.herokuapp.com:443${ws_path} -p $password | tr -d "\n")
    echo -n "${brook_link}" >/root/$password/link.txt
    echo -n "${brook_link}" | qrencode -s 6 -o /root/$password/qr.png
    echo -n "The Brook link is ${brook_link}"
else
    echo "skip generating"
fi

cat >/etc/nginx/conf.d/brook.conf <<EOF
server {
    listen       ${PORT};
    listen       [::]:${PORT};
    root /root;
    resolver 8.8.8.8:53;
    location / {
        proxy_pass https://${url_redir};
    }
    location = ${ws_path} {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:12345;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    location /$password {
        root /root;
    }
}
EOF

echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
echo Nginx config: /etc/nginx/conf.d/brook.conf
cat /etc/nginx/conf.d/brook.conf
echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
echo .
echo ////////////////////////////////////////////////////
echo "Brook wss client: remember replacing [app-name]!!!"
echo "Server:   wss://[app-name].herokuapp.com:443${ws_path}"
echo "Password: $password"
echo ////////////////////////////////////////////////////

rm -rf /etc/nginx/sites-enabled/default
nginx -g 'daemon off;'
