# TastyIgniter Docker Compose

This repository contains a Docker Compose setup for TastyIgniter, making it easy to deploy on Coolify or any other Docker-compatible platform.

## Features

- PHP 8.3 with FPM
- Nginx web server
- MySQL 8 database
- Queue worker for background jobs
- Cron job for scheduled tasks
- Persistent volumes for data storage
- Health checks for all services
- Environment variable configuration

## Prerequisites

- Docker
- Docker Compose
- Coolify (for deployment)

## Quick Start

1. Clone this repository:
```bash
git clone https://github.com/yourusername/tastyigniter-docker-compose.git
cd tastyigniter-docker-compose
```

2. Copy the example environment file:
```bash
cp .env.example .env
```

3. Edit the `.env` file with your configuration:
```bash
nano .env
```

4. Start the containers:
```bash
docker-compose up -d
```

## Deployment on Coolify

1. Push this repository to your Git provider (GitHub, GitLab, etc.)

2. In Coolify:
   - Create a new service
   - Select "Docker Compose" as the deployment method
   - Connect your Git repository
   - Set the following environment variables from the `.env.example` file
   - Deploy the service

### Required Environment Variables

Make sure to set these environment variables in Coolify:

- `APP_KEY`: Generate a random 32-character string
- `APP_URL`: Your domain name
- `DB_PASSWORD`: Secure database password
- `MYSQL_ROOT_PASSWORD`: Secure root password
- `IGNITER_CARTE_KEY`: Your TastyIgniter Carte key (if using)

### Volume Management

The following volumes are automatically managed by Coolify:
- `dbdata`: MySQL database data
- `tastyigniter`: Application files
- `tastyigniter-storage`: Application storage

### Health Checks

The deployment includes health checks for:
- Application container (PHP-FPM)
- Nginx web server
- MySQL database

## Development

To run in development mode:

1. Set `APP_ENV=local` in your `.env` file
2. Set `APP_DEBUG=true` in your `.env` file
3. Run `docker-compose up -d`

## Maintenance

### Database Backup

To backup the database:
```bash
docker-compose exec db mysqldump -u root -p tastyigniter > backup.sql
```

### Logs

View logs for all services:
```bash
docker-compose logs -f
```

View logs for a specific service:
```bash
docker-compose logs -f app
docker-compose logs -f nginx
docker-compose logs -f db
```

## Troubleshooting

1. If the application fails to start:
   - Check the logs: `docker-compose logs -f app`
   - Verify environment variables are set correctly
   - Ensure all required ports are available

2. If the database connection fails:
   - Check the database logs: `docker-compose logs -f db`
   - Verify database credentials in `.env`
   - Ensure the database container is running: `docker-compose ps`

3. If the web server is not accessible:
   - Check nginx logs: `docker-compose logs -f nginx`
   - Verify port configuration in `.env`
   - Check if the domain is properly configured

## License

This project is licensed under the MIT License - see the LICENSE file for details.
