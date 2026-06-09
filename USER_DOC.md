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

## Start and stop

From the project root:

```bash
make
```

Stop the stack:

```bash
make down
```

Restart:

```bash
make restart
```

Show logs:

```bash
make logs
```

## Access the website

The website can be opened directly from the VM with:

```bash
startx
```

This launches a minimal graphical session with Firefox and `xterm`.
The goal is to be able to use Firefox and the terminal at the same time.

The website can also be opened through SSH with X11 forwarding if the host supports it:

```bash
ssh -X wacista@<vm_ip>
firefox-esr https://wacista.42.fr &
```

The website URL is:

```text
https://wacista.42.fr
```
The TLS certificate is self-signed, so the browser may display a security warning. This is expected.

To access the website from another machine, make sure that `wacista.42.fr` points to the IP address of the virtual machine.

Example hosts entry:

```text
192.168.x.x wacista.42.fr
```

If the browser is opened directly inside the virtual machine, this entry can be used:

```text
127.0.0.1 wacista.42.fr
```

## WordPress login

Admin URL:

```text
https://wacista.42.fr/wp-admin
```

WordPress usernames are stored locally in:

```text
srcs/local.env
```

Passwords are stored in:

```text
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

Display the admin password:

```bash
cat secrets/wp_admin_password.txt
```

## Checks

Check HTTPS:

```bash
curl -k -I https://wacista.42.fr
```

Check HTTP is not exposed:

```bash
curl -I http://wacista.42.fr --max-time 5
```

Check containers:

```bash
docker ps
```

Expected idea:

```text
nginx       0.0.0.0:443->443/tcp
wordpress   9000/tcp
mariadb     3306/tcp
```

Only NGINX should publish a host port.

## Persistence

WordPress files and MariaDB data are stored in:

```text
/home/wacista/data/wordpress
/home/wacista/data/mariadb
```

To test persistence:

1. Create or modify a WordPress page.
2. Run `make down`.
3. Run `make`.
4. Check that the modification is still present.

## Full cleanup

```bash
make fclean
```

This removes containers, volumes and persistent data.
