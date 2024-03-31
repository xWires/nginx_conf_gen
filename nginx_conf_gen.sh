set -e 
set -o pipefail

echo -e "\nxWires Nginx Configuration Generator\n"

function getDomain() {
    read -p "What domain is this for? (eg. subdomain.tangledwires.xyz) " DOMAIN_NAME
    if [[ $DOMAIN_NAME == http://* || $DOMAIN_NAME == https://* ]]; then
        echo -e "Do not include http:// or https:// in the domain name!\n"
        getDomain
    fi
}

function getDestination() {
    read -p "What should this domain point to? (Please include http:// or https://) " PROXY_DESTINATION
    if ! [[ $PROXY_DESTINATION == http://* || $PROXY_DESTINATION == https://* ]]; then
        echo -e "Destination should begin with either http:// or https://"
        getDestination
    fi
}

getDomain
getDestination
read -p "Generate a certificate with certbot? (y/n) " GEN_CERT && [[ $GEN_CERT == [yY] || $GEN_CERT == [yY][eE][sS] ]] && GEN_CERT=true
cat <<EOL > /etc/nginx/conf.d/$DOMAIN_NAME.conf
server {
    listen 80;

    server_name $DOMAIN_NAME;

    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;

    server_name $DOMAIN_NAME;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Host \$http_host;
    proxy_set_header X-NginX-Proxy true;

    location / {
        proxy_pass $PROXY_DESTINATION;
    }
}
EOL
if [ $GEN_CERT == true ]; then
    certbot --nginx -n -d $DOMAIN_NAME
fi
nginx -s reload