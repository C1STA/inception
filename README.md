*This project has been created as part of the 42 curriculum by wacista.*

# Inception

## Description

Inception is a 42 system administration project. It builds a small Docker infrastructure inside a Debian virtual machine.

The mandatory stack contains:

- **NGINX**: HTTPS entrypoint on port `443`.
- **WordPress + php-fpm**: application service.
- **MariaDB**: database service.

The website is available at:

```text
https://wacista.42.fr
```

HTTP on port `80` is not exposed.

## Project description

Architecture:

```text
Browser -> HTTPS 443 -> NGINX -> wordpress:9000 -> WordPress/php-fpm -> mariadb:3306 -> MariaDB
```

Each service has its own Dockerfile and local image:

```text
nginx:inception
wordpress:inception
mariadb:inception
```

Persistent data is stored in Docker named volumes:

```text
mariadb_data   -> /home/wacista/data/mariadb
wordpress_data -> /home/wacista/data/wordpress
```

The services communicate through the Docker network `inception`. Only NGINX publishes a port to the host.

## Docker concepts

### Virtual Machines vs Docker

A virtual machine runs a complete guest operating system with its own kernel. It provides strong isolation, but it is heavier in terms of disk usage, memory usage, and startup time.

Docker containers share the host kernel and isolate processes using Linux features. They are lighter, faster to start, and easier to reproduce, which makes them suitable for packaging services such as NGINX, WordPress, and MariaDB.

In this project, the whole infrastructure runs inside a virtual machine, while each service runs inside its own Docker container.

### Secrets vs Environment Variables

Environment variables define how the services are configured; Docker secrets store sensitive values such as passwords outside of the Git repository.

### Docker Network vs Host Network

A Docker network gives containers their own isolated network and lets them communicate by service name.

Host networking would make a container use the host network directly, reducing isolation and making port exposure less explicit.

This project uses a Docker network, so only NGINX publishes port `443` to the host.

### Docker Volumes vs Bind Mounts

Containers are temporary, so persistent data must be stored outside the container writable layer.

Docker volumes are managed by Docker and are designed to persist data beyond a container’s lifetime.

Bind mounts directly map a specific host directory into a container.

In this project, named volumes are used for MariaDB and WordPress data, and they are configured to store their files under `/home/wacista/data`.

## Instructions

From the project root:

```bash
make
```

This creates the data directories, generates missing password secrets, builds the images and starts the containers.

Useful commands:

```bash
make down      # stop containers
make ps        # show services
make logs      # show logs
make fclean    # full cleanup, including /home/wacista/data
make re        # full rebuild
```

## Useful checks

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

Check TLS:

```bash
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_2
openssl s_client -connect wacista.42.fr:443 -servername wacista.42.fr -tls1_3
```

Check exposed ports:

```bash
docker ps
```

Only NGINX should publish a host port:

```text
0.0.0.0:443->443/tcp
```

## Resources

During the project, official documentation and community resources were consulted when needed, mainly for Docker, Docker Compose, NGINX, MariaDB, WordPress, WP-CLI and PHP-FPM.

The Grademe Inception guide was also used as a complementary learning resource.

## AI usage

AI tools were used as a support resource to clarify concepts, troubleshoot issues, and review documentation.  
The final implementation and validation tests were manually checked.
