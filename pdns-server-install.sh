#!/bin/bash

read -p "What backend are you using? (e.g. mysql): " backend

echo "deb [arch=amd64] http://repo.powerdns.com/ubuntu trusty-auth-40 main" >> /etc/apt/sources.list.d/pdns.list

cat > /etc/apt/preferences.d/pdns << EOF
Package: pdns-*
Pin: origin repo.powerdns.com
Pin-Priority: 600
EOF

curl https://repo.powerdns.com/FD380FBB-pub.asc | sudo apt-key add - && \
sudo apt-get update && \
sudo apt-get install -y pdns-server pdns-backend-$backend

THIS_IP="$(/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')"

CONF_FILE="/etc/powerdns/pdns.conf"

while true; do
	read -p "Do you wish to install the api? (Y/N): " yn
	case $yn in
		[Yy]* ) api="yes"; break;;
		[Nn]* ) api="no"; break;;
		* ) echo "Please answer y or n.";;
	esac
done

read -p "Webserver allowable range? (e.g. 10.0.0.0/8): " range
read -p "Webserver port? (e.g. 8081): " port

if [ "$api" == "yes" ]; then
	sed -i 's/# api=no/api=yes/g' "$CONF_FILE"
	read -p "What would you like the API key to be?" key
	sed -i "s/# api-key=/api-key=$key/g" "$CONF_FILE"
	sed -i 's/# api-readonly=no/api-readonly=no/g' "$CONF_FILE"
	sed -i 's/# webserver=no/webserver=yes/g' "$CONF_FILE"
	sed -i "s/# webserver-address=127.0.0.1/webserver-address=$THIS_IP/g"/ "$CONF_FILE"
	sed -i 's;# webserver-allow-from=0.0.0.0/0,::/0;webserver-allow-from='"$range"';g' "$CONF_FILE"
	sed -i "s/# webserver-port=8081/webserver-port=$port/g" $CONF_FILE
fi

read -p "Where is your database? (e.g. localhost, 10.30.20.52): " db_ip
read -p "What is your database name? (e.g. powerdns): " db_name
read -p "What is your database user? (e.g. pdns-admin): " db_user
read -s -p "What is your database password? " db_pass

cat >> /etc/powerdns/pdns.d/pdns.local.conf << EOF
launch=gmysql
gmysql-host=$db_ip
gmysql-dbname=$db_name
gmysql-user=$db_user
gmysql-password=$db_pass
EOF

service pdns stop
service pdns start
