# Inception Developer Documentation

## Purpose

This document summarizes the technical structure of the project and the main commands used to inspect, maintain and modify the stack.

The project runs three mandatory services:

```text
NGINX      -> HTTPS entrypoint
WordPress  -> PHP application with PHP-FPM
MariaDB    -> WordPress database
```

## Architecture

```text
Browser
   |
   | HTTPS 443
   v
NGINX
   |
   | FastCGI wordpress:9000
   v
WordPress / PHP-FPM
   |
   | SQL mariadb:${MYSQL_PORT}
   v
MariaDB
```

Only NGINX publishes a port to the host. WordPress and MariaDB stay inside the Docker network.

## Project structure

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
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
        ├── nginx/
        └── wordpress/
```

The root directory contains the global project files.  
`srcs/docker-compose.yml` describes how the services run together.  
Each directory inside `srcs/requirements/` contains one service with its Dockerfile, configuration files and initialization script.

## Configuration files

`srcs/.env` contains global non-sensitive configuration:

```env
DOMAIN_NAME=wacista.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_PORT=3306
WP_TITLE=Inception
```

`srcs/local.env` contains local WordPress account values and is ignored by Git.

`secrets/*.txt` contains passwords and is ignored by Git. The containers read secrets from:

```text
/run/secrets/<secret_name>
```

## Main commands

Start or rebuild the project:

```bash
make
```

Stop the project:

```bash
make down
```

Restart the project:

```bash
make restart
```

Full cleanup:

```bash
make fclean
```

Equivalent Docker Compose command used by the Makefile:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
```

## Docker checks

List running containers:

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

List images:

```bash
docker images
```

Expected image names:

```text
nginx:inception
wordpress:inception
mariadb:inception
```

In Docker, the part before `:` is the image name and the part after `:` is the tag.

## HTTPS and TLS checks

Check HTTPS:

```bash
curl -k -I https://wacista.42.fr
```

Expected result:

```text
HTTP/1.1 200 OK
```

Check that HTTP is not exposed:

```bash
curl -I http://wacista.42.fr --max-time 5
```

Expected result: connection refused or timeout.

Check the TLS certificate:

```bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr
```

Check TLS 1.2 and TLS 1.3:

```bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_2
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_3
```

## MariaDB check

Enter the MariaDB container:

```bash
docker exec -it mariadb sh
```

Connect to MariaDB with the WordPress database user:

```bash
mysql -u wp_user -p
```

Enter the database password when prompted. The password is stored in:

```text
secrets/db_password.txt
```

Inside MariaDB:

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT COUNT(*) FROM wp_posts;
```

`SHOW TABLES;` shows that the WordPress tables exist.  
`SELECT COUNT(*) FROM wp_posts;` verifies that the database is not empty.

To inspect comments:

```sql
SELECT comment_ID, comment_author, comment_content FROM wp_comments LIMIT 5;
```

Exit MariaDB:

```sql
exit;
```

Exit the container:

```sh
exit
```

## Volumes and persistence

The project uses two named volumes:

```text
mariadb_data
wordpress_data
```

They store data on the host under:

```text
/home/wacista/data/mariadb
/home/wacista/data/wordpress
```

MariaDB writes inside the container to:

```text
/var/lib/mysql
```

but Docker stores the real files on the host in:

```text
/home/wacista/data/mariadb
```

WordPress writes inside the container to:

```text
/var/www/html
```

but Docker stores the real files on the host in:

```text
/home/wacista/data/wordpress
```

Inspect volumes:

```bash
docker volume inspect mariadb_data
docker volume inspect wordpress_data
```

Check host data:

```bash
ls -la /home/wacista/data
```

A simple persistence test is:

```text
1. Add or modify content on WordPress.
2. Restart or reboot.
3. Launch the project again.
4. Check that the content is still present.
```

## Reboot test

Reboot the VM:

```bash
sudo reboot
```

After the VM starts again:

```bash
cd ~/inception
make
```

Then check:

```bash
docker ps
curl -k -I https://wacista.42.fr
```

The WordPress content created before the reboot should still be present.

If the containers are already running after reboot, it is because they use a restart policy such as:

```yaml
restart: always
```

Running Docker Compose again is still useful because it ensures that the running stack matches the project configuration.

## Configuration changes

### Change the external HTTPS port

This is the safest change.

In `srcs/docker-compose.yml`, replace:

```yaml
ports:
  - "443:443"
```

with, for example:

```yaml
ports:
  - "8443:443"
```

Then rebuild and restart:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env down
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
```

Test:

```bash
curl -k -I https://wacista.42.fr:8443
docker ps
```

Expected port mapping:

```text
0.0.0.0:8443->443/tcp
```

### Change the WordPress / PHP-FPM port

If PHP-FPM changes from `9000` to `9001`, update:

```text
PHP-FPM listen port
NGINX fastcgi_pass
Dockerfile EXPOSE value, for consistency
```

Example NGINX change:

```nginx
fastcgi_pass wordpress:9001;
```

Then rebuild and restart:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env down
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
```

### Change the MariaDB port

If MariaDB changes from `3306` to `3307`, update the MariaDB configuration and the project environment.

In the MariaDB config:

```ini
port = 3307
```

In `srcs/.env`:

```env
MYSQL_PORT=3307
```

The WordPress initialization script uses `MYSQL_PORT` to wait for MariaDB and to update `DB_HOST` in `wp-config.php`.

After rebuild and restart, check:

```bash
docker exec wordpress grep DB_HOST /var/www/html/wp-config.php
curl -k -I https://wacista.42.fr
```

Expected DB host:

```php
define( 'DB_HOST', 'mariadb:3307' );
```

## Useful debug commands

Show service logs:

```bash
docker logs nginx --tail=100
docker logs wordpress --tail=100
docker logs mariadb --tail=100
```

Show all Compose logs:

```bash
make logs
```

Check where ports are configured:

```bash
grep -R "443\\|9000\\|3306\\|3307" srcs/
```

Check forbidden patterns:

```bash
grep -R "latest" .
grep -R "tail -f\\|sleep infinity\\|while true\\|--link\\|links:\\|network_mode: host" .
```

Check that local files and secrets are not tracked:

```bash
git ls-files | grep -E "local.env|secrets/.*\\.txt"
```

This command should return nothing.

## Short explanations

Dockerfile:

```text
The Dockerfile builds the image. It installs packages, copies configuration files and defines the entrypoint and default command.
```

Image:

```text
An image is not a running container. It is a built filesystem and configuration used as a template to create containers.
```

Container:

```text
A container is a running instance of an image.
```

Docker Compose:

```text
Docker Compose describes and runs the multi-container application. It defines services, networks, volumes, secrets, environment variables and exposed ports.
```

Docker network:

```text
The Docker network allows containers to communicate inside an isolated virtual network by using service names.
```

Docker volume:

```text
A Docker volume stores data outside the container writable layer so data persists when containers are recreated.
```

ENTRYPOINT and CMD:

```text
The entrypoint runs the initialization script. The CMD provides the default main command. At the end, exec "$@" replaces the script with the main process.
```
