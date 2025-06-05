# SSL Server with Nginx and Certbot

This project sets up a secure web server using Nginx with automatic SSL certificate management through Certbot. It's designed to handle both static content and reverse proxy to your application.

## Features

- Automatic SSL certificate generation and renewal using Let's Encrypt
- Nginx configuration with modern SSL/TLS settings
- Support for both static content and reverse proxy
- HTTP to HTTPS automatic redirection
- Docker-based setup for easy deployment

## Prerequisites

- Docker and Docker Compose installed
- A registered domain name pointing to your server
- Ports 80 and 443 available on your server

## Configuration

Before running the setup, modify the following variables in `init.bash`:

```bash
YOUR_DOMAIN="your.domain"       # Your domain name
YOUR_EMAIL="your@email"         # Your email for Let's Encrypt notifications
NGINX_HTTP_PORT="80"            # HTTP port (default: 80)
NGINX_HTTPS_PORT="443"          # HTTPS port (default: 443)
STAGING_OPTION="--staging"      # Set to "" for production certificates
```

## Directory Structure

```
ssl_server/
├── nginx/
│   ├── config/         # Nginx configuration files
│   ├── html/          # Static content
│   └── logs/          # Nginx logs
├── certbot/
│   ├── acme_challenge_files/    # ACME challenge files
│   └── config_etc_letsencrypt/  # SSL certificates
├── docker-compose.yaml
└── init.bash
```

## Setup

1. Clone this repository
2. Configure the variables in `init.bash`
3. Make the script executable and run it:

```bash
chmod +x init.bash
./init.bash
```

## How It Works

1. The script creates necessary directories and configuration files
2. Starts Nginx container for HTTP challenge
3. Obtains SSL certificate using Certbot
4. Configures Nginx with SSL settings
5. Restarts Nginx with the new configuration

## Features

- **SSL Configuration**: Modern SSL/TLS settings with strong cipher suites
- **Static Content**: Serves static files from `/usr/share/nginx/html/`
- **Reverse Proxy**: Proxies requests to `host.docker.internal:6681`
- **Automatic Redirect**: Redirects HTTP to HTTPS
- **Logging**: Access and error logs in `nginx/logs/`

## Maintenance

### Certificate Renewal

Certbot certificates are valid for 90 days. To renew manually:

```bash
docker-compose run --rm certbot renew
```

### Viewing Logs

```bash
# Nginx logs
docker-compose logs nginx

# Certbot logs
docker-compose logs certbot
```

## Security Notes

- The configuration includes modern SSL/TLS settings
- HTTP/2 is enabled
- Strong cipher suites are configured
- Additional security headers are commented out but available

## Troubleshooting

If you encounter issues:

1. Check the logs in `nginx/logs/`
2. Ensure ports 80 and 443 are not blocked
3. Verify your domain's DNS settings
4. Try running `docker-compose down && docker-compose up -d` to restart all services

## License

This project is open source and available under the MIT License.
