# Inception Developer Documentation

## Purpose

This document explains how to build, inspect, maintain, and troubleshoot the Inception project.

The project runs a WordPress website using three Docker containers:

- NGINX
- WordPress with PHP-FPM
- MariaDB

Each service is built from its own Dockerfile and runs in its own container.

## Architecture Overview

```text
Browser
   |
   | HTTPS port 443
   v
NGINX
   |
   | FastCGI port 9000
   v
WordPress / PHP-FPM
   |
   | MariaDB port 3306
   v
MariaDB
```

Only NGINX is exposed to the host.

WordPress and MariaDB are only reachable inside the Docker network.

## Repository Structure

```text
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env
    ├── local.env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── conf/
        │   │   └── 50-server.cnf
        │   ├── Dockerfile
        │   └── tools/
        │       └── init.sh
        ├── nginx/
        │   ├── conf/
        │   │   └── nginx.conf
        │   ├── Dockerfile
        │   └── tools/
        │       └── init.sh
        └── wordpress/
            ├── conf/
            │   └── www.conf
            ├── Dockerfile
            └── tools/
                └── init.sh
```

## Configuration Files

### `srcs/.env`

This file contains non-sensitive project configuration.

Example:

```env
DOMAIN_NAME=wacista.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
WP_TITLE=Inception
```

This file can be tracked by Git because it does not contain passwords.

### `srcs/local.env`

This file contains local WordPress account information.

Example:

```env
WP_ADMIN_USER=wpmaster
WP_ADMIN_EMAIL=wpadmin@wacista.42.fr
WP_USER=wpeditor
WP_USER_EMAIL=wpeditor@wacista.42.fr
```

This file is ignored by Git because it is local to the machine.

### `secrets/`

Passwords are stored as local secret files.

```text
secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

The containers receive these values as Docker secrets and read them from:

```text
/run/secrets/<secret_name>
```

The secret files are ignored by Git.

## Project Lifecycle Commands

### Start the project

```bash
make
```

This builds the images if needed, creates the required local files, and starts the stack.

### Stop the project

```bash
make down
```

This stops and removes the containers, while keeping persistent data.

### Restart the project

```bash
make restart
```

This is a shortcut to stop and start the stack again.

### Show logs

```bash
make logs
```

### Validate the Compose configuration

```bash
make config
```

This prints the final Docker Compose configuration after variable interpolation.

### Full cleanup

```bash
make fclean
```

This removes containers, Docker volumes, unused Docker objects, and persistent project data.

Use it only when a full reset is needed.

### Rebuild from scratch

```bash
make re
```

This is equivalent to:

```bash
make fclean
make
```

## Source Checks

### Check Dockerfile base images

Purpose: check that each service is built from Debian.

```bash
grep -R "^FROM" srcs/requirements/*/Dockerfile
```

Expected idea:

```text
FROM debian:bookworm
```

### Check that no image uses the `latest` tag

```bash
grep -R "latest" .
```

Expected result: no relevant result.

### Check for forbidden shortcuts

```bash
grep -R "tail -f\|sleep infinity\|while true\|--link\|links:\|network_mode: host" .
```

Expected result: no relevant result.

### Check foreground processes

Purpose: make sure containers are kept alive by their real main service, not by a fake infinite command.

Useful expected processes:

```text
mariadbd --user=mysql --console
php-fpm8.2 -F
nginx -g "daemon off;"
```

## Git Hygiene Checks

### Check that secrets are not tracked

```bash
git ls-files | grep -E "(^|/)secrets/.*\.txt|srcs/local\.env"
```

Expected result: no output.

### Check that ignored files are ignored

```bash
git check-ignore -v secrets/*.txt srcs/local.env
```

Expected result: `.gitignore` should be shown as the ignore source.

### Check that `.env` is tracked

```bash
git ls-files srcs/.env
```

Expected result:

```text
srcs/.env
```

## Runtime Checks

### Check containers

```bash
docker ps
```

Expected idea:

```text
nginx       0.0.0.0:443->443/tcp
wordpress   9000/tcp
mariadb     3306/tcp
```

Only NGINX should publish a port to the host.

WordPress and MariaDB should remain internal.

### Check Compose services

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps
```

Expected services:

```text
mariadb
wordpress
nginx
```

All services should be running.

### Check images

```bash
docker images
```

Expected project images:

```text
mariadb     inception
wordpress   inception
nginx       inception
```

### Check container processes

```bash
docker top mariadb
docker top wordpress
docker top nginx
```

Expected main services:

```text
mariadbd
php-fpm
nginx
```

## Docker Network Checks

### Check that the custom network exists

```bash
docker network ls
```

Expected custom network:

```text
inception
```

### Inspect the network

```bash
docker network inspect inception
```

Expected containers connected to the network:

```text
mariadb
wordpress
nginx
```

### Check service-name resolution

Purpose: confirm that containers can resolve each other by service name.

```bash
docker exec nginx getent hosts wordpress
docker exec wordpress getent hosts mariadb
```

Expected result: each command returns an internal Docker network IP.

## HTTPS and TLS Checks

### Check HTTPS

```bash
curl -k -I https://wacista.42.fr
```

Expected result:

```text
HTTP/1.1 200 OK
```

The `-k` flag is used because the TLS certificate is self-signed.

### Check that HTTP is not exposed

```bash
curl -I http://wacista.42.fr --max-time 5
```

Expected result: connection refused or timeout.

### Check TLS 1.2

```bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_2
```

Expected result: the TLS handshake succeeds.

### Check TLS 1.3

```bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_3
```

Expected result: the TLS handshake succeeds.

### Inspect NGINX TLS configuration

```bash
docker exec nginx nginx -T | grep -E "listen|ssl_certificate|ssl_protocols"
```

Expected idea:

```text
listen 443 ssl;
ssl_certificate ...
ssl_certificate_key ...
ssl_protocols TLSv1.2 TLSv1.3;
```

### Inspect NGINX FastCGI configuration

```bash
docker exec nginx nginx -T | grep fastcgi_pass
```

Expected result:

```text
fastcgi_pass wordpress:9000;
```

NGINX forwards PHP requests to the WordPress PHP-FPM container.

## WordPress and PHP-FPM Checks

### Check WordPress container logs

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs wordpress
```

Expected idea: the logs should show that WordPress was installed or already exists, and that PHP-FPM started.

### Check WordPress files

```bash
docker exec wordpress ls -la /var/www/html
```

Expected files include:

```text
wp-config.php
wp-content
wp-admin
wp-includes
```

### Check WordPress installation with WP-CLI

```bash
docker exec wordpress wp core is-installed --path=/var/www/html --allow-root
```

Expected result: the command exits successfully.

### List WordPress users

```bash
docker exec wordpress wp user list --path=/var/www/html --allow-root
```

Expected idea: the administrator user and the regular user are listed.

### Check PHP-FPM configuration

```bash
docker exec wordpress grep -R "listen" /etc/php/*/fpm/pool.d/www.conf
```

Expected result:

```text
listen = 9000
```

## MariaDB Checks

### Check MariaDB container logs

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs mariadb
```

Expected idea: the logs should show that MariaDB is ready for connections.

### Connect to MariaDB interactively

```bash
docker exec -it mariadb sh
```

Then inside the container:

```bash
mariadb -u"$MYSQL_USER" -p"$(cat /run/secrets/db_password)" "$MYSQL_DATABASE"
```

Useful SQL commands:

```sql
SHOW DATABASES;
SHOW TABLES;
SELECT ID, post_title, post_type FROM wp_posts LIMIT 5;
```

Exit MariaDB:

```sql
exit;
```

Exit the container shell:

```bash
exit
```

### Check WordPress database tables directly

```bash
docker exec mariadb sh -c 'mariadb -u"$MYSQL_USER" -p"$(cat /run/secrets/db_password)" "$MYSQL_DATABASE" -e "SHOW TABLES;"'
```

Expected tables include:

```text
wp_options
wp_posts
wp_users
wp_comments
```

### Check MariaDB users

```bash
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SELECT User, Host FROM mysql.user;"'
```

Expected idea:

```text
root      localhost
wp_user   %
wp_user   localhost
```

### Check databases

```bash
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SHOW DATABASES;"'
```

Expected database:

```text
wordpress
```

## Docker Secret Checks

### Check mounted secrets in MariaDB

```bash
docker exec mariadb ls -la /run/secrets
```

Expected secrets:

```text
db_root_password
db_password
```

### Check mounted secrets in WordPress

```bash
docker exec wordpress ls -la /run/secrets
```

Expected secrets:

```text
db_password
wp_admin_password
wp_user_password
```

### Check that local secret files are not empty

```bash
for f in secrets/*.txt; do test -s "$f" && echo "$f: OK" || echo "$f: EMPTY"; done
```

Expected result: all secret files are `OK`.

## Volume and Persistence Checks

### Check Docker volumes

```bash
docker volume ls
```

Expected project volumes:

```text
mariadb_data
wordpress_data
```

### Inspect volume locations

```bash
docker volume inspect mariadb_data wordpress_data
```

Expected host paths:

```text
/home/wacista/data/mariadb
/home/wacista/data/wordpress
```

### Check host data folders

```bash
ls -la /home/wacista/data
ls -la /home/wacista/data/mariadb
ls -la /home/wacista/data/wordpress
```

Expected result: both data directories exist and contain files after the stack has started.

### Check persistence after restart

Create or modify a WordPress page from the browser, then run:

```bash
make down
make
```

After the stack is running again, the modification should still exist.

### Check persistence after removing containers

```bash
docker rm -f mariadb wordpress nginx
make
```

Expected result: the website and database data should still be present, because the Docker volumes were not removed.

## Browser Access Checks

### Open from the VM graphical session

```bash
startx
```

This opens a minimal graphical session with Firefox and `xterm`.

### Open through SSH X11 forwarding

```bash
ssh -X wacista@<vm_ip>
firefox-esr https://wacista.42.fr
```

Trusted X11 forwarding can also be used when needed:

```bash
ssh -Y wacista@<vm_ip>
firefox-esr https://wacista.42.fr
```

### Check domain resolution inside the VM

```bash
getent hosts wacista.42.fr
```

Expected result inside the VM:

```text
127.0.0.1 wacista.42.fr
```

## Configuration Changes

### Change the external HTTPS port

A common maintenance task is to change how the service is exposed on the host.

In `srcs/docker-compose.yml`, change:

```yaml
ports:
  - "443:443"
```

to:

```yaml
ports:
  - "8443:443"
```

Explanation:

```text
8443 = host port
443  = container port
```

Restart the stack:

```bash
make restart
```

Test the new host port:

```bash
curl -k -I https://wacista.42.fr:8443
```

Expected result:

```text
HTTP/1.1 200 OK
```

To restore the original configuration:

```yaml
ports:
  - "443:443"
```

Then restart again:

```bash
make restart
```

### Change a non-sensitive environment value

Example: change the WordPress website title.

Edit `srcs/.env`:

```env
WP_TITLE=New Title
```

Then perform a full reset if the value is only used during first installation:

```bash
make fclean
make
```

Some WordPress values are written into the database during installation, so changing the `.env` file alone may not update an already installed site.

## Full Rebuild Test

### Project-level rebuild

```bash
make fclean
make
```

Then check:

```bash
curl -k -I https://wacista.42.fr
docker ps
docker images
docker volume inspect mariadb_data wordpress_data
docker network ls
```

Expected result:

- HTTPS returns `HTTP/1.1 200 OK`
- only NGINX exposes port `443`
- project images are tagged `inception`
- project volumes exist
- project network exists

### Optional Docker-wide cleanup

This is destructive and removes Docker objects from the local environment.

```bash
docker stop $(docker ps -qa) 2>/dev/null || true
docker rm $(docker ps -qa) 2>/dev/null || true
docker rmi -f $(docker images -qa) 2>/dev/null || true
docker volume rm $(docker volume ls -q) 2>/dev/null || true
docker network rm $(docker network ls -q | grep -vE '^(bridge|host|none)$') 2>/dev/null || true
```

Then rebuild the project:

```bash
cd ~/inception
make
```

## Troubleshooting

### Container name already exists

```bash
docker rm -f mariadb wordpress nginx
make
```

This removes containers only. It does not remove persistent volume data.

### Old Compose project labels

If Docker reports that a volume or network was created by another Compose project:

```bash
make down
docker rm -f mariadb wordpress nginx 2>/dev/null || true
docker volume rm mariadb_data wordpress_data 2>/dev/null || true
docker network rm inception 2>/dev/null || true
make
```

This recreates project-specific Docker objects.

### WordPress cannot connect to MariaDB

Check MariaDB logs:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs mariadb
```

Check WordPress logs:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs wordpress
```

Check database user entries:

```bash
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SELECT User, Host FROM mysql.user;"'
```

Check that the database exists:

```bash
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SHOW DATABASES;"'
```

### HTTPS does not answer

Check that NGINX is running:

```bash
docker ps
```

Check NGINX logs:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs nginx
```

Check NGINX configuration:

```bash
docker exec nginx nginx -T
```

Check the domain resolution:

```bash
getent hosts wacista.42.fr
```

### Reset persistent data

```bash
make fclean
make
```

This deletes the database and WordPress files, then recreates the stack from scratch.

## Quick Maintenance Summary

```bash
# Build and start
make

# Stop containers
make down

# Restart
make restart

# Logs
make logs

# Compose config
make config

# HTTPS check
curl -k -I https://wacista.42.fr

# HTTP should not be exposed
curl -I http://wacista.42.fr --max-time 5

# Containers and exposed ports
docker ps

# Images
docker images

# Network
docker network inspect inception

# Volumes
docker volume inspect mariadb_data wordpress_data

# MariaDB tables
docker exec mariadb sh -c 'mariadb -u"$MYSQL_USER" -p"$(cat /run/secrets/db_password)" "$MYSQL_DATABASE" -e "SHOW TABLES;"'

# WordPress installed
docker exec wordpress wp core is-installed --path=/var/www/html --allow-root

# Full reset
make fclean
make
```
