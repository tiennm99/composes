#!/bin/bash
set -e

# Check if TastyIgniter is already installed
if [ ! -f /var/www/html/composer.json ] || [ ! -d /var/www/html/vendor ]; then
    echo "Installing TastyIgniter..."
    # Create new TastyIgniter project
    composer create-project tastyigniter/tastyigniter:^v4.0 /tmp/tastyigniter --prefer-dist --no-interaction --no-progress

    # Move files to web root
    cp -a /tmp/tastyigniter/. /var/www/html/
    rm -rf /tmp/tastyigniter

    echo "TastyIgniter files installed"
fi

# Set proper permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/storage

# Generate app key if not set
if [ -z "$APP_KEY" ]; then
    php artisan key:generate
fi

# Wait for database to be ready
echo "Waiting for database to be ready..."
while ! mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    sleep 1
done
echo "Database connection established"

# Run TastyIgniter installer in non-interactive mode if not installed
if [ ! -f .env ] || ! grep -q "IGNITER_INSTALLED=true" .env; then
    echo "Running TastyIgniter installer..."
    php artisan igniter:install --no-interaction

    # Mark as installed in .env
    echo "IGNITER_INSTALLED=true" >> .env

    echo "TastyIgniter installed successfully"
else
    echo "TastyIgniter already installed"
fi

# Run database migrations if needed
php artisan migrate --force

exec "$@"
