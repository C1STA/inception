# USER_DOC.md

# Inception User Documentation

## Purpose

This document explains how an end user or administrator can use the Inception stack.

The project provides a WordPress website running behind an NGINX HTTPS entrypoint, with MariaDB used as the database.

## Services Provided

The stack contains three mandatory services:

### NGINX

NGINX is the only public entrypoint into the infrastructure.

It listens on port `443` and serves the website through HTTPS using TLSv1.2/TLSv1.3.

HTTP on port `80` is intentionally not exposed.

### WordPress + php-fpm

WordPress is the website application.

It runs with php-fpm in its own container and does not contain NGINX.

### MariaDB

MariaDB stores the WordPress database.

It runs in its own container and is only reachable from the internal Docker network.

## Website Access

The website is available at:

~~text
https://wacista.42.fr
~~

Because the TLS certificate is self-signed, the browser may display a security warning. This is expected.

To access the website from another machine, make sure that `wacista.42.fr` points to the IP address of the virtual machine.

Example hosts entry:

~~text
192.168.x.x wacista.42.fr
~~

If the browser is opened directly inside the virtual machine, this entry can be used:

~~text
127.0.0.1 wacista.42.fr
~~

## Administration Panel

The WordPress administration panel is available at:

~~text
https://wacista.42.fr/wp-admin
~~

The administrator username is defined in:

~~text
srcs/.env
~~

Variable:

~~text
WP_ADMIN_USER
~~

The administrator password is stored in the local Docker secret file:

~~text
secrets/wp_admin_password.txt
~~

To display it locally:

~~bash
cat secrets/wp_admin_password.txt
~~

The regular WordPress user is also defined in:

~~text
srcs/.env
~~

Variable:

~~text
WP_USER
~~

Its password is stored in:

~~text
secrets/wp_user_password.txt
~~

## Starting the Project

From the root of the repository:

~~bash
make
~~

This command prepares the required folders and secrets, builds the Docker images, and starts the containers.

## Stopping the Project

To stop and remove the running containers while keeping the persistent data:

~~bash
make down
~~

The WordPress website files and MariaDB database remain stored in:

~~text
/home/wacista/data
~~

## Restarting the Project

To restart the stack:

~~bash
make restart
~~

Equivalent manual sequence:

~~bash
make down
make
~~

## Checking That Services Are Running

From the root of the repository:

~~bash
make ps
~~

Expected services:

~~text
mariadb
wordpress
nginx
~~

All three should be shown as running.

A more explicit command is:

~~bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps
~~

## Checking the Website

Check HTTPS:

~~bash
curl -k -I https://wacista.42.fr
~~

Expected result:

~~text
HTTP/1.1 200 OK
~~

Check that HTTP is not exposed:

~~bash
curl -I http://wacista.42.fr --max-time 5
~~

Expected result: connection refused, timeout, or another connection failure.

## Checking TLS

Check TLSv1.2:

~~bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_2
~~

Check TLSv1.3:

~~bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_3
~~

The connection should be established.

## Checking Logs

To view logs for all services:

~~bash
make logs
~~

To view logs for one service:

~~bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs nginx
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs wordpress
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs mariadb
~~

## Credentials Management

Sensitive credentials are stored in local secret files:

~~text
secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
~~

These files are ignored by Git and must not be committed.

The `.env` file contains non-sensitive configuration values such as:

~~text
DOMAIN_NAME
MYSQL_DATABASE
MYSQL_USER
WP_TITLE
WP_ADMIN_USER
WP_USER
~~

Passwords must not be stored in `.env`.

## Persistent Data

Persistent project data is stored in:

~~text
/home/wacista/data/mariadb
/home/wacista/data/wordpress
~~

MariaDB data is stored in:

~~text
/home/wacista/data/mariadb
~~

WordPress website files are stored in:

~~text
/home/wacista/data/wordpress
~~

These directories are connected to Docker named volumes:

~~text
mariadb_data
wordpress_data
~~

## Cleaning the Project

To stop containers and clean unused Docker objects:

~~bash
make clean
~~

To fully remove the stack, including volumes and persistent data:

~~bash
make fclean
~~

Warning: `make fclean` removes:

~~text
/home/wacista/data
~~

This deletes the persisted WordPress and MariaDB data.

## Rebuilding From Scratch

To fully clean and rebuild:

~~bash
make re
~~

This is equivalent to:

~~bash
make fclean
make
~~

## Common Issues

### The website works inside the VM but not from the host machine

Check that the host machine has a hosts entry pointing `wacista.42.fr` to the IP address of the VM.

Find the VM IP address:

~~bash
hostname -I
~~

Then add this line on the host machine:

~~text
VM_IP_ADDRESS wacista.42.fr
~~

### Browser shows a certificate warning

This is expected because the project uses a self-signed TLS certificate.

Continue to the website manually.

### A container name is already in use

Remove old containers:

~~bash
docker rm -f mariadb wordpress nginx
~~

Then restart the project:

~~bash
make
~~

### WordPress cannot connect to MariaDB

Check MariaDB logs:

~~bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs mariadb
~~

Check WordPress logs:

~~bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs wordpress
~~

Check that the MariaDB user and database exist:

~~bash
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SELECT User, Host FROM mysql.user;"'
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SHOW DATABASES;"'
~~

## Expected Running State

Only NGINX should expose a port to the host:

~~text
nginx       0.0.0.0:443->443/tcp
wordpress   9000/tcp
mariadb     3306/tcp
~~

The WordPress and MariaDB ports are internal only.

