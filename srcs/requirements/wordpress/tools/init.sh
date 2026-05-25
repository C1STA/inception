#!/bin/sh

set -eu

if [ -z "${DOMAIN_NAME:-}" ] \
	|| [ -z "${MYSQL_DATABASE:-}" ] \
	|| [ -z "${MYSQL_USER:-}" ] \
	|| [ -z "${WP_TITLE:-}" ] \
	|| [ -z "${WP_ADMIN_USER:-}" ] \
	|| [ -z "${WP_ADMIN_EMAIL:-}" ] \
	|| [ -z "${WP_USER:-}" ] \
	|| [ -z "${WP_USER_EMAIL:-}" ]; then
	echo "Error: missing required environment variable"
	exit 1
fi

case "$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in
	*admin*)
		echo "Error: WP_ADMIN_USER must not contain 'admin'"
		exit 1
		;;
esac

if [ ! -f /run/secrets/db_password ] \
	|| [ ! -f /run/secrets/wp_admin_password ] \
	|| [ ! -f /run/secrets/wp_user_password ]; then
	echo "Error: missing WordPress secret files"
	exit 1
fi

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

mkdir -p /var/www/html /run/php

if [ ! -f /var/www/html/wp-load.php ]; then
	echo "Copying WordPress files..."
	cp -a /usr/src/wordpress/. /var/www/html/
fi

echo "Waiting for MariaDB..."
i=0
until mariadb -hmariadb -u"$MYSQL_USER" -p"$DB_PASSWORD" "$MYSQL_DATABASE" -e "SELECT 1;" >/dev/null 2>&1; do
	i=$((i + 1))
	if [ "$i" -ge 60 ]; then
		echo "Error: MariaDB is unavailable"
		exit 1
	fi
	sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then
	echo "Creating wp-config.php..."
	wp config create \
		--path=/var/www/html \
		--dbname="$MYSQL_DATABASE" \
		--dbuser="$MYSQL_USER" \
		--dbpass="$DB_PASSWORD" \
		--dbhost="mariadb:3306" \
		--allow-root
fi

if ! wp core is-installed --path=/var/www/html --allow-root >/dev/null 2>&1; then
	echo "Installing WordPress..."
	wp core install \
		--path=/var/www/html \
		--url="https://${DOMAIN_NAME}" \
		--title="$WP_TITLE" \
		--admin_user="$WP_ADMIN_USER" \
		--admin_password="$WP_ADMIN_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL" \
		--skip-email \
		--allow-root

	wp user create "$WP_USER" "$WP_USER_EMAIL" \
		--path=/var/www/html \
		--user_pass="$WP_USER_PASSWORD" \
		--role=author \
		--allow-root
fi

wp option update home "https://${DOMAIN_NAME}" --path=/var/www/html --allow-root
wp option update siteurl "https://${DOMAIN_NAME}" --path=/var/www/html --allow-root

chown -R www-data:www-data /var/www/html /run/php

exec "$@"
