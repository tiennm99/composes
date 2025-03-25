#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate environment variables
validate_env() {
    local required_vars=("DB_HOST" "DB_DATABASE" "DB_USERNAME" "DB_PASSWORD")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log "ERROR: Missing required environment variables: ${missing_vars[*]}"
        exit 1
    fi
}

# Create log directory if it doesn't exist
mkdir -p /var/log/php
chown -R www-data:www-data /var/log/php

# Validate environment variables
validate_env

# Check if TastyIgniter is already installed
if [ ! -f /var/www/html/composer.json ] || [ ! -d /var/www/html/vendor ]; then
    log "Installing TastyIgniter..."
    # Create new TastyIgniter project
    composer create-project tastyigniter/tastyigniter:^v4.0 /tmp/tastyigniter --prefer-dist --no-interaction --no-progress

    # Move files to web root
    cp -a /tmp/tastyigniter/. /var/www/html/
    rm -rf /tmp/tastyigniter

    log "TastyIgniter files installed"
fi

# Set proper permissions
log "Setting proper permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache

# Generate app key if not set
if [ -z "$APP_KEY" ]; then
    log "Generating application key..."
    php artisan key:generate
fi

# Wait for database to be ready
log "Waiting for database to be ready..."
max_tries=30
counter=1
while ! mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    if [ $counter -ge $max_tries ]; then
        log "ERROR: Database connection failed after $max_tries attempts"
        exit 1
    fi
    log "Database connection attempt $counter/$max_tries failed, retrying in 2 seconds..."
    sleep 2
    counter=$((counter + 1))
done
log "Database connection established"

# Run TastyIgniter installer in non-interactive mode if not installed
if [ ! -f .env ] || ! grep -q "IGNITER_INSTALLED=true" .env; then
    log "Running TastyIgniter installer..."
    php artisan igniter:install --no-interaction

    # Mark as installed in .env
    echo "IGNITER_INSTALLED=true" >> .env

    log "TastyIgniter installed successfully"
else
    log "TastyIgniter already installed"
fi

# Run database migrations if needed
log "Running database migrations..."
php artisan migrate --force

# Clear and cache configuration
log "Clearing and caching configuration..."
php artisan config:clear
php artisan config:cache
php artisan route:clear
php artisan route:cache
php artisan view:clear
php artisan view:cache

# Set proper permissions again after all operations
log "Setting final permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache

log "Entrypoint script completed successfully"

# Execute the main command
exec "$@"
