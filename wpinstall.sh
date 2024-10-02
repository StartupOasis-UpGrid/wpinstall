#!/bin/bash

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") --domain '<domain>' --dbhost '<dbhost>:<port>' --dbuser '<database user>' --dbpass '<db password>' --wpadmin '<wp admin username>' --wppass '<wp admin password>'"
    exit 1
fi

opts=$(getopt \
  --longoptions domain:,dbhost:,db:,dbuser:,dbpass:,wpadmin:,wppass: \
  --name "$(basename "$0")" \
  --options "" \
  -- "$@"
)
eval set -- "$opts"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)
	  domain=$2
          siteuser="${domain//./}"
          shift 2
          ;;
        --dbhost)
          dbhost=$2
          shift 2
          ;;
	--db)
	  db=$2
	  shift 2
	  ;;
	--dbuser)
	  dbuser=$2
	  shift 2
	  ;;
	--dbpass)
	  dbpass=$2
	  shift 2
	  ;;
	--wpadmin)
	  wpadmin=$2
	  shift 2
	  ;;
	--wppass)
	  wppass=$2
	  shift 2
	  ;;
        *)
         break
         ;;
    esac
done


apt update && \
apt install -y apache2 php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php libapache2-mod-php php-mysql

curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x /usr/local/bin/wp

useradd -m -c "$domain" -s /bin/bash "$siteuser"
mkdir -p "/var/www/${domain}"
chown "$siteuser:$siteuser" "/var/www/${domain}"

cat <<EOF > "/etc/apache2/sites-available/${domain}.conf"
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/${domain}
    ErrorLog ${APACHE_LOG_DIR}/${domain}.error.log
    CustomLog ${APACHE_LOG_DIR}/${domain}_access.log combined
</VirtualHost>
<Directory /var/www/${domain}/>
    AllowOverride All
</Directory>
EOF

a2dissite 000-default
a2ensite $domain
systemctl reload apache2

su -c "cd /var/www/${domain} && \
/usr/local/bin/wp core download --path='/var/www/${domain}' && \
/usr/local/bin/wp config create --dbhost='$dbhost' --dbname='$db' --dbuser='$dbuser' --dbpass='$dbpass' && \
/usr/local/bin/wp core install --url='$domain' --title='$domain' --admin_user='$wpadmin' --admin_password='$wppass' --admin_email='admin@domain.tld'" -s /bin/bash $siteuser
