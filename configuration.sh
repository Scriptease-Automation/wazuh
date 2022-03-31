#!/bin/bash

#Neccessary package installation
echo "/////////////////////////////////////////////////////"
echo "Installing All neccessary packages for Wazuh !!!"
echo "/////////////////////////////////////////////////////"
##installing NetTools
sudo apt-get install net-tools -y
#Nginx Installation 
sudo apt-get install nginx curl -y
#Certbot Install
sudo snap install core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot


while getopts d: name
do
    case "${name}" in
        d) domain=${OPTARG};;
        *) echo "Invalid option: -$name" ;;
    esac
done

#Variables
echo "/////////////////////////////////////////////////////"
echo "Please Insert an Information to configure Wazuh !!!"
echo "/////////////////////////////////////////////////////"


echo $domain

ipaddress="$(dig @ns1-1.akamaitech.net ANY whoami.akamai.net +short)" 
echo $ipaddress

echo "/////////////////////////////////////////////////////"
password=$(< /dev/urandom tr -dc '1234567890qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM' | head -c24; echo "")

# Configuring DNS for the Wazuh System'    
if [[ -z "$domain" ]]; then
   printf '%s\n' "Please Feel all options that required"
   exit 1
else
   # If userInput is not empty show what the user typed in and run ls -l
   printf "Configuration: %s "  "Please go to your DNS management system and set for $domain A record $ipaddress Value" and then press Enter:
   echo ""
   read -rsn1 -p"If you have done changes Press any key to continue" variable;echo
fi

#Checking The DNS Changes
checkip="$(dig +short $domain)"
echo $checkip
if [[ "$ipaddress" == "$checkip" ]]
    then 
        echo "//////////////////////////////////////////"
        echo "SUCCESS:: DNS Records Changed Successfully"
        echo "//////////////////////////////////////////"
    else
        echo "The $domain A record is not set to $ipaddress, Please Do changes And Run Again"
        exit 0
fi
#NGINX Configuration
webservice="nginx"
webconfig=/etc/nginx/sites-enabled/default
kibanawebconf=/etc/nginx/sites-enabled/kibana.conf

rm $webconfig
curl https://mirror.istc.am/scripts/wazuh/nginx/nginx_default -o $webconfig
if [ -f "/etc/init.d/$webservice" ]; 
    then
        sed -i "s/_;/$domain;/g" $webconfig
        echo "$domain was set on NGINX successfuly."
else   
    echo "$nginx does not exists"
    echo "Sorry We cant Create an SSL Certificate for $domain at this moment"
fi
sudo systemctl restart nginx


#Creating SLL with Certbot
if pgrep -x "$webservice" >/dev/null
    then
        certbot certonly -d $domain --agree-tos --manual-public-ip-logging-ok --webroot -w /var/www/html --server https://acme-v02.api.letsencrypt.org/directory --register-unsafely-without-email --rsa-key-size 4096
    else
        echo "$webservice not running"
        exit 0
fi

sslfull=/etc/letsencrypt/live/$domain/fullchain.pem 
sslprivate=/etc/letsencrypt/live/$domain/privkey.pem
if [ -f "$sslfill"]; 
    then
        echo "SSL Files are located in"
        echo "$sslfull"
        echo "$sslprivate"
    else
        echo "Sorry, We couldnt find any SSL Certificates, Please rerun the script and set correct parameters"
fi

#Kibana Nginx Configuration
rm $webconfig
curl https://mirror.istc.am/scripts/wazuh/kibana/kibana.conf -o $kibanawebconf

if test -f "$kibanawebconf"; 
    then
        sed -i "s/example.com/$domain/g" $kibanawebconf
        echo "$domain was set successfully."
    else   
        echo "$kibanawebconf does not exists"
fi

if test -f "$kibanawebconf"; 
    then
        sed -i "s/exampleip/$ipaddress/g" $kibanawebconf
        echo "$ipaddress was set successfully."
    else   
        echo "$kibanawebconf does not exists"
fi


#Changing Kibana Configuration
kibana=/etc/kibana/kibana.yml
filebeat=/etc/filebeat/filebeat.yml

if test -f "$kibana"; then
sed -i "s/0.0.0.0/$domain/g" $kibana
sed -i "s/443/8443/g" $kibana
    echo "$domain was set successfully."
else   
    echo "Cant Find server.host on $kibana, or the changes have already done"
fi

optssl=/etc/letsencrypt/options-ssl-nginx.conf
ssldhparams=/etc/letsencrypt/ssl-dhparams.pem
curl https://mirror.istc.am/scripts/wazuh/nginx/options-ssl-nginx.conf -o $optssl
curl https://mirror.istc.am/scripts/wazuh/nginx/ssl-dhparams.pem -o $ssldhparams

sudo systemctl restart nginx
sudo systemctl restart kibana


#Chnaging password for Wazuh
backup=/home/backup
passwordmanager=/home/backup/wazuh-passwords-tool.sh
filebeat=/etc/filebeat/filebeat.yml
elasticip=127.0.0.1
str='"'
mkdir $backup

curl https://packages.wazuh.com/resources/4.1/open-distro/tools/wazuh-passwords-tool.sh -o $passwordmanager
cd $backup
bash wazuh-passwords-tool.sh -u admin -p $password

if test -f "$filebeat"; then
sed -i "s/password.*/password: $str$password$str/g" $filebeat
    echo "Password was changed successfully."
else
    echo "Cant Find $kibana, or cant do the changes"
fi
echo "Your Wazuh Password is:  $password"
systemctl restart kibana elasticsearch filebeat wazuh-manager
systemctl start nginx