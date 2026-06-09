*This project has been created as part of the 42 curriculum by wacista.*

# Inception

## Description

Inception is a system administration project based on Docker.

The goal of the project is to build a small containerized infrastructure inside a virtual machine using Docker Compose.

The mandatory stack contains three services:

- **NGINX**: the only public entrypoint, exposed on port 443 with TLSv1.2/TLSv1.3.
- **WordPress + php-fpm**: the application service, running without NGINX.
- **MariaDB**: the database service, running without NGINX.

The website is available at:

~~~text
https://wacista.42.fr
~~~

HTTP access on port 80 is intentionally not exposed.

## Project Description

The infrastructure is built with one Dockerfile per service.

Each image is built locally from Debian and is not pulled from ready-made service images.

The services communicate through a dedicated Docker network:

```text
NGINX -> WordPress/php-fpm -> MariaDB
```

Persistent data is stored using Docker named volumes:

~~text
mariadb_data   -> /home/wacista/data/mariadb
wordpress_data -> /home/wacista/data/wordpress
~~

Sensitive values such as database and WordPress passwords are stored in Docker secrets and are not committed to the Git repository.

## Design Choices

### Virtual Machines vs Docker

A virtual machine runs a complete guest operating system with its own kernel. It provides strong isolation, but it is heavier in terms of disk usage, memory usage, and startup time.

Docker containers share the host kernel and isolate processes using Linux features. They are lighter, faster to start, and easier to reproduce, which makes them suitable for packaging services such as NGINX, WordPress, and MariaDB.

In this project, the whole infrastructure runs inside a virtual machine, while each service runs inside its own Docker container.

### Secrets vs Environment Variables

Environment variables are useful for non-sensitive configuration, such as:

~~text
DOMAIN_NAME
MYSQL_DATABASE
MYSQL_USER
WP_TITLE
WP_ADMIN_USER
WP_USER
~~

Secrets are used for sensitive values, such as:

~~text
database root password
database user password
WordPress administrator password
WordPress regular user password
~~

This avoids storing passwords directly inside Dockerfiles, scripts, or the `.env` file.

### Docker Network vs Host Network

A Docker network isolates the containers from the host network while allowing containers to communicate with each other by service name.

For example:

~~text
wordpress can reach mariadb using the hostname "mariadb"
nginx can reach wordpress using the hostname "wordpress"
~~

Host network mode is not used because it removes this isolation and is forbidden in this project.

### Docker Volumes vs Bind Mounts

A Docker named volume is managed by Docker and can persist data even if containers are removed.

In this project, named volumes are used for:

~~text
MariaDB database files
WordPress website files
~~

The volumes are configured to store their data under `/home/wacista/data` on the host machine, as required by the project.

Bind mounts directly map a host path into a container. They are useful in some development workflows, but for this project the required persistent storages are Docker named volumes.

## Directory Structure

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

The secret files are generated locally and must not be committed to Git.

## Instructions

### Prerequisites

This project is designed to run inside a Debian virtual machine with Docker installed.

Required tools:

~~text
docker
docker compose
make
openssl
~~

### Configure the domain

The domain must point to the IP address of the machine running the project.

Inside the virtual machine, a local setup can use this line in `/etc/hosts`:

~~text
127.0.0.1 wacista.42.fr
~~

From another host machine, such as a Windows host running VirtualBox, `wacista.42.fr` must point to the virtual machine IP address.

Example:

~~text
192.168.x.x wacista.42.fr
~~

### Build and start

From the repository root:

~~bash
make
~~

This command:

1. creates the required data directories;
2. creates missing secret files;
3. builds the Docker images;
4. starts the containers with Docker Compose.

### Stop the stack

~~bash
make down
~~

### View containers

~~bash
make ps
~~

### View logs

~~bash
make logs
~~

### Clean Docker objects

~~bash
make clean
~~

### Full cleanup

~~bash
make fclean
~~

This removes containers, Docker volumes, unused Docker objects, and the persistent data directory:

~~text
/home/wacista/data
~~

### Rebuild from scratch

~~bash
make re
~~

## Useful Checks

Check that the website is reachable:

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

Expected result: connection refused or timeout.

Check TLSv1.2:

~~bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_2
~~

Check TLSv1.3:

~~bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_3
~~

Check volumes:

~~bash
docker volume inspect mariadb_data wordpress_data
~~

Check the Docker network:

~~bash
docker network ls
~~

Check running containers:

~~bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps
~~

## Services

### NGINX

NGINX is the only entrypoint into the infrastructure.

It listens on port 443 and uses a self-signed TLS certificate generated locally inside the container.

It forwards PHP requests to the WordPress container through FastCGI:

~~text
fastcgi_pass wordpress:9000
~~

### WordPress + php-fpm

WordPress is installed and configured automatically with WP-CLI.

It communicates with MariaDB through the Docker network using the hostname `mariadb`.

It runs with php-fpm and does not contain NGINX.

### MariaDB

MariaDB stores the WordPress database.

The database files are persisted through the `mariadb_data` named volume.

The WordPress database and SQL users are created automatically during container initialization.

## Security Notes

No password is written directly inside the Dockerfiles.

The `.env` file contains non-sensitive configuration only.

Sensitive values are stored in local secret files:

~~text
secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
~~

These files are ignored by Git.

## Resources

Classic references used for this project:

- Docker documentation
- Docker Compose documentation
- Dockerfile reference
- Docker secrets documentation
- NGINX documentation
- MariaDB documentation
- WordPress documentation
- WP-CLI documentation
- PHP-FPM documentation

## AI Usage

AI was used as a learning and debugging assistant during the project.

It helped with:

- understanding Docker and Docker Compose concepts;
- structuring the project according to the subject requirements;
- reviewing Dockerfiles and entrypoint scripts;
- debugging MariaDB and WordPress initialization issues;
- preparing validation commands;
- drafting documentation.

The final implementation choices, tests, and repository content were reviewed and validated manually.

