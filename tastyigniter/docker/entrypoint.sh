#!/bin/bash
set -e

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

# Run TastyIgniter installer in non-interactive mode
if [ ! -f .env ] || ! grep -q "IGNITER_INSTALLED=true" .env; then
    echo "Installing TastyIgniter..."
    php artisan igniter:install --no-interaction

    # Mark as installed in .env
    echo "IGNITER_INSTALLED=true" >> .env

    echo "TastyIgniter installed successfully"
else
    echo "TastyIgniter already installed"
fi

# Set permissions again to ensure proper access
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html/storage

exec "$@"
