#!/bin/bash
set -e

# Check if TastyIgniter is already installed
if [ ! -f /var/www/html/composer.json ] || [ ! -d /var/www/html/vendor ]; then
    echo "Installing TastyIgniter..."
    # Create new TastyIgniter project with fallback for handling extension requirements
    composer create-project tastyigniter/tastyigniter:^v4.0 /tmp/tastyigniter --prefer-dist --no-interaction --no-progress || \
    composer create-project tastyigniter/tastyigniter:^v4.0 /tmp/tastyigniter --prefer-dist --no-interaction --no-progress --ignore-platform-req=ext-intl

    # Move files to web root
    cp -a /tmp/tastyigniter/. /var/www/html/
    rm -rf /tmp/tastyigniter

    echo "TastyIgniter files installed"
fi

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
    echo "Running TastyIgniter installer..."
    php artisan igniter:install --no-interaction

    # Mark as installed in .env
    echo "IGNITER_INSTALLED=true" >> .env

    echo "TastyIgniter installed successfully"
else
    echo "TastyIgniter already installed"
fi

# Check for TastyIgniter's .nginx.conf file and copy it if needed
if [ -f /var/www/html/.nginx.conf ]; then
    echo "TastyIgniter .nginx.conf found"
else
    echo "TastyIgniter .nginx.conf not found, creating a default one"
    cat > /var/www/html/.nginx.conf <<EOF
# Default TastyIgniter nginx config
location / {
    root /var/www/html/public;
    try_files \$uri \$uri/ /index.php?\$query_string;
    index index.php;
}

location ~ \.php$ {
    root /var/www/html/public;
    try_files \$uri \$uri/ /index.php?\$query_string;
    fastcgi_pass app:9000;
    fastcgi_index index.php;
    fastcgi_buffers 16 16k;
    fastcgi_buffer_size 32k;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
}

location ~ /\.ht {
    deny all;
}
EOF
fi

# Set permissions again to ensure proper access
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html/storage

exec "$@"
