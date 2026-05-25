FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx \
	openssl \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh \
	&& mkdir -p /etc/nginx/ssl /run/nginx

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["nginx", "-g", "daemon off;"]
