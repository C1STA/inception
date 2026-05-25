#!/bin/sh

set -eu

if [ -z "${DOMAIN_NAME:-}" ]; then
	echo "Error: missing DOMAIN_NAME environment variable"
	exit 1
fi

mkdir -p /etc/nginx/ssl /run/nginx

if [ ! -f /etc/nginx/ssl/inception.crt ] || [ ! -f /etc/nginx/ssl/inception.key ]; then
	echo "Generating self-signed SSL certificate..."

	openssl req -x509 -nodes -days 365 \
		-newkey rsa:4096 \
		-keyout /etc/nginx/ssl/inception.key \
		-out /etc/nginx/ssl/inception.crt \
		-subj "/CN=${DOMAIN_NAME}"
fi

exec "$@"
