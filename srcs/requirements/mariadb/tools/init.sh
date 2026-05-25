#!/bin/sh

set -eu

if [ -z "${MYSQL_DATABASE:-}" ] || [ -z "${MYSQL_USER:-}" ]; then
	echo "Error: missing MYSQL_DATABASE or MYSQL_USER environment variable"
	exit 1
fi

if [ ! -f /run/secrets/db_root_password ] || [ ! -f /run/secrets/db_password ]; then
	echo "Error: missing database secret files"
	exit 1
fi

DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
	echo "Installing MariaDB system database..."

	mariadb-install-db \
		--user=mysql \
		--datadir=/var/lib/mysql \
		--skip-test-db \
		--auth-root-authentication-method=normal
fi

echo "Preparing Inception database initialization..."

cat > /tmp/init.sql <<EOF
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';

ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'localhost';

FLUSH PRIVILEGES;
EOF

chmod 600 /tmp/init.sql
chown mysql:mysql /tmp/init.sql

exec "$@" --init-file=/tmp/init.sql
