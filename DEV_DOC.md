# DEV_DOC.md

# Inception Developer Documentation

## Purpose

This document explains how a developer can set up, build, run, inspect, and maintain the Inception project.

The project is a small Docker Compose infrastructure composed of three mandatory services:

- NGINX
- WordPress + php-fpm
- MariaDB

Each service has its own Dockerfile and runs inside its own container.

## Global Architecture

The infrastructure follows this flow:

~~text
Client browser
    |
    | HTTPS 443
    v
NGINX container
    |
    | FastCGI: wordpress:9000
    v
WordPress + php-fpm container
    |
    | SQL: mariadb:3306
    v
MariaDB container
~~

NGINX is the only container exposed to the host machine.

WordPress and MariaDB are only reachable from inside the Docker network.

## Repository Structure

~~text
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
~~

## Prerequisites

The project is designed to run inside a Debian virtual machine.

Required packages:

~~text
docker
docker compose
make
openssl
~~

Install missing packages on Debian:

~~bash
sudo apt update
sudo apt install -y make openssl
~~

Docker must already be installed and running.

Check Docker:

~~bash
docker --version
docker compose version
~~

## Environment Configuration

The main environment file is:

~~text
srcs/.env
~~

It contains non-sensitive configuration:

~~text
DOMAIN_NAME=wacista.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
WP_TITLE=Inception
WP_ADMIN_USER=wacista_owner
WP_ADMIN_EMAIL=wacista@student.42.fr
WP_USER=wacista_user
WP_USER_EMAIL=user@student.42.fr
~~

Passwords must not be stored in `.env`.

## Secrets

Sensitive values are stored in local secret files:

~~text
secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
~~

These files are used by Docker Compose as Docker secrets.

Inside containers, they are mounted under:

~~text
/run/secrets/
~~

Examples:

~~text
/run/secrets/db_root_password
/run/secrets/db_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
~~

The Makefile creates these secret files automatically if they do not exist or if they are empty.

The secret files must stay ignored by Git.

Check that they are ignored:

~~bash
git check-ignore -v secrets/*.txt
~~

## Data Persistence

The project stores persistent data in:

~~text
/home/wacista/data
~~

MariaDB data:

~~text
/home/wacista/data/mariadb
~~

WordPress files:

~~text
/home/wacista/data/wordpress
~~

The Docker named volumes are:

~~text
mariadb_data
wordpress_data
~~

They are configured in `docker-compose.yml` with local driver options so their data is stored inside `/home/wacista/data`.

Check volume configuration:

~~bash
docker volume inspect mariadb_data wordpress_data
~~

Expected paths:

~~text
/home/wacista/data/mariadb
/home/wacista/data/wordpress
~~

## Docker Compose File

The main Compose file is:

~~text
srcs/docker-compose.yml
~~

It defines:

- the `mariadb` service;
- the `wordpress` service;
- the `nginx` service;
- the `mariadb_data` and `wordpress_data` named volumes;
- the `inception` Docker network;
- the Docker secrets.

The project name is set to:

~~text
inception
~~

The images are built locally with explicit tags:

~~text
mariadb:inception
wordpress:inception
nginx:inception
~~

## Services

## MariaDB

Path:

~~text
srcs/requirements/mariadb
~~

Files:

~~text
Dockerfile
conf/50-server.cnf
tools/init.sh
~~

The MariaDB Dockerfile starts from Debian and installs `mariadb-server`.

The configuration file makes MariaDB listen on the Docker network:

~~text
bind-address = 0.0.0.0
port = 3306
~~

The entrypoint script:

1. checks required environment variables;
2. reads database passwords from Docker secrets;
3. prepares `/run/mysqld` and `/var/lib/mysql`;
4. initializes the MariaDB system database if needed;
5. creates the WordPress database;
6. creates the SQL users;
7. starts `mariadbd` in the foreground.

The main process is:

~~text
mariadbd --user=mysql --console
~~

## WordPress + php-fpm

Path:

~~text
srcs/requirements/wordpress
~~

Files:

~~text
Dockerfile
conf/www.conf
tools/init.sh
~~

The WordPress Dockerfile starts from Debian and installs:

~~text
php8.2-fpm
php8.2-mysql
mariadb-client
curl
ca-certificates
~~

It also installs WP-CLI.

The php-fpm configuration listens on:

~~text
0.0.0.0:9000
~~

The entrypoint script:

1. checks required environment variables;
2. reads passwords from Docker secrets;
3. copies WordPress files into `/var/www/html` if needed;
4. waits for MariaDB to become available;
5. creates `wp-config.php`;
6. installs WordPress with WP-CLI;
7. creates a regular WordPress user;
8. updates `home` and `siteurl`;
9. starts php-fpm in the foreground.

The main process is:

~~text
php-fpm8.2 -F
~~

## NGINX

Path:

~~text
srcs/requirements/nginx
~~

Files:

~~text
Dockerfile
conf/nginx.conf
tools/init.sh
~~

The NGINX Dockerfile starts from Debian and installs:

~~text
nginx
openssl
~~

The entrypoint script generates a self-signed TLS certificate if it does not already exist.

The NGINX configuration:

- listens on port 443;
- enables TLSv1.2 and TLSv1.3;
- serves files from `/var/www/html`;
- forwards PHP requests to `wordpress:9000`.

The main process is:

~~text
nginx -g "daemon off;"
~~

## Makefile Usage

The Makefile is located at the root of the repository.

### Build and start

~~bash
make
~~

This executes the default target and starts the whole stack.

### Prepare folders and secrets

~~bash
make prepare
~~

This creates:

~~text
/home/wacista/data/mariadb
/home/wacista/data/wordpress
secrets/*.txt
~~

### Stop and remove containers

~~bash
make down
~~

This stops the Compose stack while keeping persistent data.

### Stop containers only

~~bash
make stop
~~

### Start stopped containers

~~bash
make start
~~

### Restart

~~bash
make restart
~~

### Show containers

~~bash
make ps
~~

### Show logs

~~bash
make logs
~~

### Validate Compose configuration

~~bash
make config
~~

### Clean Docker objects

~~bash
make clean
~~

### Full cleanup

~~bash
make fclean
~~

This removes:

- containers;
- Docker volumes;
- unused Docker objects;
- `/home/wacista/data`.

Warning: this deletes persisted WordPress and MariaDB data.

### Rebuild from scratch

~~bash
make re
~~

Equivalent to:

~~bash
make fclean
make
~~

## Build and Launch From Scratch

From the repository root:

~~bash
make
~~

Then check the status:

~~bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps
~~

Expected services:

~~text
mariadb
wordpress
nginx
~~

All services should be `Up`.

## Validation Commands

### Check HTTPS

~~bash
curl -k -I https://wacista.42.fr
~~

Expected result:

~~text
HTTP/1.1 200 OK
~~

### Check HTTP is not exposed

~~bash
curl -I http://wacista.42.fr --max-time 5
~~

Expected result: connection refused or timeout.

### Check TLSv1.2

~~bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_2
~~

### Check TLSv1.3

~~bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_3
~~

### Check images

~~bash
docker images
~~

Expected images:

~~text
mariadb     inception
wordpress   inception
nginx       inception
~~

### Check exposed ports

~~bash
docker ps
~~

Expected result:

~~text
nginx       0.0.0.0:443->443/tcp
wordpress   9000/tcp
mariadb     3306/tcp
~~

Only NGINX should expose a host port.

### Check network

~~bash
docker network ls
~~

Expected custom network:

~~text
inception
~~

### Check volumes

~~bash
docker volume inspect mariadb_data wordpress_data
~~

Expected volume devices:

~~text
/home/wacista/data/mariadb
/home/wacista/data/wordpress
~~

### Check WordPress database tables

~~bash
docker exec mariadb sh -c 'mariadb -u"$MYSQL_USER" -p"$(cat /run/secrets/db_password)" -hlocalhost "$MYSQL_DATABASE" -e "SHOW TABLES;"'
~~

Expected tables include:

~~text
wp_options
wp_posts
wp_users
wp_comments
~~

### Check WordPress installation

~~bash
docker exec wordpress wp core is-installed --path=/var/www/html --allow-root
~~

This command should exit successfully.

## Simulating the Evaluation Cleanup

The evaluation may start by removing Docker objects.

A local simulation can be done with:

~~bash
docker stop $(docker ps -qa) 2>/dev/null || true
docker rm $(docker ps -qa) 2>/dev/null || true
docker rmi -f $(docker images -qa) 2>/dev/null || true
docker volume rm $(docker volume ls -q) 2>/dev/null || true
docker network rm $(docker network ls -q) 2>/dev/null || true
~~

Then rebuild:

~~bash
cd ~/inception
make
~~

Validate again:

~~bash
curl -k -I https://wacista.42.fr
docker ps
docker images
docker volume inspect mariadb_data wordpress_data
docker network ls
~~

## Common Development Issues

### Container name already exists

If Docker reports that a container name is already in use:

~~bash
docker rm -f mariadb wordpress nginx
make
~~

This removes containers only, not persistent data.

### Old Compose project labels

If a warning says that a volume or network was created for another project, remove the Docker objects and recreate them:

~~bash
make down
docker rm -f mariadb wordpress nginx 2>/dev/null || true
docker volume rm mariadb_data wordpress_data 2>/dev/null || true
docker network rm inception 2>/dev/null || true
make
~~

### WordPress cannot connect to MariaDB

Inspect MariaDB users:

~~bash
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SELECT User, Host FROM mysql.user;"'
~~

Expected entries:

~~text
wp_user    %
wp_user    localhost
~~

Inspect databases:

~~bash
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SHOW DATABASES;"'
~~

Expected database:

~~text
wordpress
~~

### Reset persistent data

To fully reset MariaDB and WordPress data:

~~bash
make fclean
make
~~

## Configuration Change During Defense

A reviewer may ask for a small configuration change.

Example: expose NGINX on host port `8443` instead of `443`.

In `srcs/docker-compose.yml`, change:

~~yaml
ports:
  - "443:443"
~~

to:

~~yaml
ports:
  - "8443:443"
~~

Explanation:

~~text
8443 = host port
443  = container port
~~

Then rebuild/restart:

~~bash
make down
make
~~

Test:

~~bash
curl -k -I https://wacista.42.fr:8443
~~

After the test, restore:

~~yaml
ports:
  - "443:443"
~~

Then restart:

~~bash
make down
make
~~

## Git Hygiene

Secrets must not be tracked by Git.

Check tracked secret files:

~~bash
git ls-files | grep secrets
~~

Expected result: no `.txt` secret files should appear.

Check ignored secrets:

~~bash
git check-ignore -v secrets/*.txt
~~

The `.env` file may be tracked if it only contains non-sensitive configuration.

## Important Rules

The project must not use:

~~text
network_mode: host
links:
--link
latest
tail -f
sleep infinity
while true
~~

The main process of each container must run in the foreground:

~~text
mariadbd --user=mysql --console
php-fpm8.2 -F
nginx -g "daemon off;"
~~

