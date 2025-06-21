#!/usr/bin/env bash

YOUR_DOMAIN="your.domain"
YOUR_EMAIL="your@email"
NGINX_HTTP_PORT="80"
NGINX_HTTPS_PORT="443"
STAGING_OPTION="--staging" # Set to "--staging" to use Let's Encrypt staging servers, or "" for production

mkdir -p ./nginx/config
mkdir -p ./nginx/html
mkdir -p ./nginx/logs
mkdir -p ./certbot/acme_challenge_files
mkdir -p ./certbot/config_etc_letsencrypt

cat > docker-compose.yaml <<EOF
services:
  nginx:
    image: nginx:stable-alpine
    container_name: ssl_nginx_server
    ports:
      - "${NGINX_HTTP_PORT}:80"
      - "${NGINX_HTTPS_PORT}:443"
    volumes:
      - ./nginx/config:/etc/nginx/conf.d:ro
      - ./nginx/html:/usr/share/nginx/html:ro
      - ./certbot/acme_challenge_files:/var/www/acme_challenge:ro
      - ./certbot/config_etc_letsencrypt:/etc/letsencrypt:ro
      - ./nginx/logs:/var/log/nginx:rw
    restart: unless-stopped

  certbot:
    image: certbot/certbot
    container_name: certbot_manager
    volumes:
      - ./certbot/acme_challenge_files:/var/www/acme_challenge:rw
      - ./certbot/config_etc_letsencrypt:/etc/letsencrypt:rw
EOF

cat > nginx/config/default.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${YOUR_DOMAIN};

    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/acme_challenge;
    }

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
        try_files $uri $uri/ /index.html; 
        # or change "/index.html" to "=404"
    }

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}
EOF

cat > nginx/html/index.html <<'EOF_HTML'
<!DOCTYPE html>
<html>
<head>
<title>Welcome to Nginx (HTTP)!</title>
</head>
<body>
<h1>Nginx is working via HTTP!</h1>
<p>SSL certificate will be obtained next.</p>
</body>
</html>
EOF_HTML

echo "Starting Nginx for HTTP challenge..."
docker-compose up -d nginx

echo "Waiting for Nginx to start (e.g., 10-20 seconds)..."
for i in {1..10}; do
  printf "Wait: %s \r" "$i"
  sleep 1
done
echo "Wait complete.                  "

echo "Obtaining SSL certificate with Certbot..."
docker-compose run --rm certbot certonly --webroot -w /var/www/acme_challenge \
    --email "${YOUR_EMAIL}" \
    -d "${YOUR_DOMAIN}" \
    ${STAGING_OPTION} \
    --agree-tos \
    --no-eff-email \
    --debug

echo "Certificate obtained. Waiting before reconfiguring Nginx (e.g., 5-10 seconds)..."
for i in {1..5}; do
  printf "Wait: %s \r" "$i"
  sleep 1
done
echo "Wait complete.                  "

cat > nginx/config/default.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${YOUR_DOMAIN};

    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/acme_challenge;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${YOUR_DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${YOUR_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${YOUR_DOMAIN}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    # add_header X-Frame-Options "SAMEORIGIN" always;
    # add_header X-XSS-Protection "1; mode=block" always;
    # add_header X-Content-Type-Options "nosniff" always;
    # add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/acme_challenge;
    }

    # --- Serve static content / Frontend for other paths ---
    location /static {
        alias /usr/share/nginx/html/;
        rewrite ^/static$ /static/ permanent;
    }

    # --- Reverse Proxy for Service at port 6681/ ---
    location / {
        proxy_pass http://host.docker.internal:6681;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;

        proxy_buffering off;
    }

}
EOF

echo "Restarting Nginx with SSL configuration..."
docker-compose restart nginx

echo "Setup complete. Nginx should now be serving HTTPS for ${YOUR_DOMAIN} on host port ${NGINX_HTTPS_PORT}."
echo "HTTP requests to host port ${NGINX_HTTP_PORT} should redirect to HTTPS."
echo "Requests to / will be proxied to the application at http://host.docker.internal:6681, and /static/ will serve static files."
echo "You might need to run 'docker-compose down && docker-compose up -d' if restart doesn't pick up all volume changes immediately."
