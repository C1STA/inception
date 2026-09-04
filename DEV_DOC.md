# Inception developer guide

## Architecture

The stack contains three custom services:

```text
Browser --HTTPS:443--> NGINX --FastCGI:9000--> WordPress --SQL:3306--> MariaDB
```

NGINX is the only service attached to a published host port. All internal
traffic uses service discovery on the `inception` bridge network.

## Configuration model

Copy the tracked templates before running the stack:

```bash
cp srcs/.env.example srcs/.env
cp srcs/local.env.example srcs/local.env
```

`srcs/.env` contains shared, non-sensitive values:

- `DOMAIN_NAME`
- `MYSQL_DATABASE`
- `MYSQL_PORT`
- `MYSQL_USER`
- `WP_TITLE`

`srcs/local.env` contains WordPress usernames and email addresses. Both local
files are ignored so each environment can use its own configuration.

Passwords are generated with OpenSSL under `secrets/` and mounted into the
relevant containers at `/run/secrets/*`. They are never stored in image layers
or committed to Git.

## Service initialization

### MariaDB

The entrypoint creates the MariaDB system database only when the volume is
empty. An initialization SQL file then removes anonymous and test accounts,
sets the root password, creates the WordPress database and user, and grants that
user access only to the application database.

### WordPress

The WordPress image downloads WP-CLI and the WordPress sources during the image
build. At runtime its entrypoint:

1. waits until MariaDB accepts an authenticated query;
2. copies WordPress into an empty persistent volume;
3. creates or updates `wp-config.php`;
4. installs the site and configured users only when WordPress is not installed;
5. starts PHP-FPM in the foreground.

### NGINX

The NGINX entrypoint generates a self-signed certificate for `DOMAIN_NAME` when
one does not already exist in the container. NGINX accepts TLS 1.2 and 1.3 and
forwards PHP requests to `wordpress:9000`.

Each entrypoint ends with `exec "$@"`, making the actual service process PID 1
so Docker can forward signals correctly.

## Persistence

Compose defines two named volumes backed by bind-mounted directories:

| Volume           | Container path    | Host path             |
| ---------------- | ----------------- | --------------------- |
| `mariadb_data`   | `/var/lib/mysql`  | `$HOME/data/mariadb`  |
| `wordpress_data` | `/var/www/html`   | `$HOME/data/wordpress`|

The Makefile exports `DATA_DIR` to Compose, which removes user-specific absolute
paths from the tracked configuration.

## Validation and debugging

Render the final Compose model:

```bash
make config
```

Inspect running services and their network:

```bash
make ps
docker network inspect inception
docker volume inspect mariadb_data wordpress_data
```

Check TLS and the application response:

```bash
openssl s_client -connect inception.local:443 -servername inception.local
curl -k -I https://inception.local
```

Query MariaDB from inside its container:

```bash
DATA_DIR="$HOME/data" docker compose -f srcs/docker-compose.yml --env-file srcs/.env exec mariadb \
  mariadb -u root -p
```

Follow logs with `make logs`, or target one service with `docker compose logs
<service>`.

## Making configuration changes

When changing an internal port, keep these locations aligned:

- the service configuration;
- its Dockerfile `EXPOSE` declaration;
- the dependent service address;
- the corresponding environment value, when present.

After a configuration change, rebuild with:

```bash
make down
make up
```

Use `make fclean` only when the persistent database and WordPress files should
also be deleted.
