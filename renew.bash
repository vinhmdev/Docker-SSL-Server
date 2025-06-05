#!/usr/bin/env bash

cd /home/mvinh/Desktop/docker/ssl_server/
docker-compose run --rm certbot renew --quiet
docker-compose exec nginx nginx -s reload


