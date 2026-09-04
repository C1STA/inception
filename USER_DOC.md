# Inception user guide

## Start the stack

From a fresh clone, create the two local configuration files:

```bash
cp srcs/.env.example srcs/.env
cp srcs/local.env.example srcs/local.env
```

Review the domain, database name, WordPress title, usernames, and email
addresses. Passwords are not configured in these files; the Makefile generates
them under `secrets/` when they are missing.

Start all services:

```bash
make
```

The command prepares `$HOME/data`, builds the three images, and starts the stack
in the background.

## Access WordPress

The default domain is `inception.local`. Resolve it to the machine running
Docker by adding an entry to the client machine's hosts file:

```text
127.0.0.1 inception.local
```

Use the Docker host's IP instead of `127.0.0.1` when accessing the site from a
different machine.

- Website: <https://inception.local>
- Administration: <https://inception.local/wp-admin>

The certificate is self-signed, so a browser warning is expected in this local
environment.

WordPress usernames are defined in `srcs/local.env`. Their generated passwords
are stored in:

```text
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

## Operate the services

```bash
make ps       # show service status
make logs     # follow all service logs
make stop     # stop containers
make start    # start existing containers
make restart  # recreate the stack
make down     # stop and remove containers
```

Check the HTTPS endpoint:

```bash
curl -k -I https://inception.local
```

Inspect an individual service:

```bash
DATA_DIR="$HOME/data" docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs nginx
DATA_DIR="$HOME/data" docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs wordpress
DATA_DIR="$HOME/data" docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs mariadb
```

## Persistence

WordPress files and MariaDB data are stored outside the containers under:

```text
$HOME/data/wordpress
$HOME/data/mariadb
```

Running `make down` and then `make` recreates the containers without deleting
the website or database.

## Full cleanup

```bash
make fclean
```

This command removes the Inception containers, named volumes, and the two
project-owned data directories. It does not prune unrelated Docker images,
containers, or volumes.
