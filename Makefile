NAME		= inception
LOGIN		= wacista

SRC_DIR		= srcs
COMPOSE		= $(SRC_DIR)/docker-compose.yml
ENV_FILE	= $(SRC_DIR)/.env

DATA_DIR	= /home/$(LOGIN)/data
DB_DIR		= $(DATA_DIR)/mariadb
WP_DIR		= $(DATA_DIR)/wordpress

SECRETS_DIR	= secrets
DB_ROOT_PWD	= $(SECRETS_DIR)/db_root_password.txt
DB_PWD		= $(SECRETS_DIR)/db_password.txt
WP_ADMIN_PWD	= $(SECRETS_DIR)/wp_admin_password.txt
WP_USER_PWD	= $(SECRETS_DIR)/wp_user_password.txt

DC		= docker compose -f $(COMPOSE) --env-file $(ENV_FILE)

all: up

up: prepare
	$(DC) up -d --build

prepare: dirs secrets

dirs:
	mkdir -p $(DB_DIR)
	mkdir -p $(WP_DIR)

secrets:
	mkdir -p $(SECRETS_DIR)
	@if [ ! -s $(DB_ROOT_PWD) ]; then openssl rand -hex 24 > $(DB_ROOT_PWD); fi
	@if [ ! -s $(DB_PWD) ]; then openssl rand -hex 24 > $(DB_PWD); fi
	@if [ ! -s $(WP_ADMIN_PWD) ]; then openssl rand -hex 24 > $(WP_ADMIN_PWD); fi
	@if [ ! -s $(WP_USER_PWD) ]; then openssl rand -hex 24 > $(WP_USER_PWD); fi

down:
	$(DC) down

stop:
	$(DC) stop

start:
	$(DC) start

restart: down up

ps:
	$(DC) ps

logs:
	$(DC) logs -f

config: prepare
	$(DC) config

clean:
	$(DC) down
	docker system prune -af

fclean:
	$(DC) down -v
	docker volume rm mariadb_data wordpress_data 2>/dev/null || true
	sudo rm -rf $(DATA_DIR)
	docker system prune -af

re: fclean all

.PHONY: all up prepare dirs secrets down stop start restart ps logs config clean fclean re
