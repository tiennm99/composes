# TastyIgniter Docker Setup

This repository contains Docker configuration files to quickly set up a TastyIgniter v4.0+ environment. The setup includes:

- PHP 8.3 with all required extensions
- MySQL 8 database
- Nginx web server
- Automated installation process
- Properly configured scheduler and queue workers

## Prerequisites

- Docker and Docker Compose installed on your system
- Basic understanding of Docker concepts

## Directory Structure

```
tastyigniter-docker/
├── docker/
│   ├── entrypoint.sh
│   └── nginx/
│       └── default.conf
├── docker-compose.yml
├── Dockerfile
└── README.md
```

## Setup Instructions

1. Create the directory structure as shown above:

```bash
mkdir -p tastyigniter-docker/docker/nginx
```

2. Copy all the configuration files into their respective directories.

3. Start the Docker environment:

```bash
cd tastyigniter-docker
docker-compose up -d
```

4. The setup will:
   - Create a new TastyIgniter project
   - Set up the database connection
   - Run the non-interactive installation
   - Configure the proper permissions
   - Set up scheduled tasks and queue processing

5. Access TastyIgniter:
   - Frontend: http://localhost
   - Admin panel: http://localhost/admin
   - Default admin credentials:
     - Username: admin
     - Email: admin@example.com
     - Password: admin123

## Configuration Options

You can customize the installation by modifying the environment variables in the `docker-compose.yml` file:

- `APP_URL`: Your application URL
- `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`: Database connection details
- `ADMIN_USER`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`: Administrator account details

## Persistent Storage

The setup uses Docker volumes for:
- MySQL data: Stored in the `dbdata` volume
- TastyIgniter storage: Mapped to the `./storage` directory on your host

## Production Deployment

Before deploying to production, make sure to:

1. Change all default passwords
2. Set `APP_DEBUG=false`
3. Generate a unique `APP_KEY`
4. Configure proper SSL/TLS in the Nginx configuration for HTTPS

## Troubleshooting

If you encounter issues:

1. Check the logs: `docker-compose logs -f app`
2. Verify database connectivity: `docker-compose exec app php artisan db:monitor`
3. Check container status: `docker-compose ps`
4. Ensure proper permissions on the storage directory
