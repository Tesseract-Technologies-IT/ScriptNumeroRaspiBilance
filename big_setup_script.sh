#!/bin/bash

# Redirect all output to a log file
exec > >(tee -a /var/log/startup_script.log) 2>&1

# Function to check PHP version
check_php_version() {
    PHP_VERSION=$(php -v 2>/dev/null | grep -oP '^PHP \K8\.2\.\d+')
    if [ -z "$PHP_VERSION" ]; then
        echo "PHP 8.2.x is not installed. Installing PHP 8.2.x..."
        install_php
    else
        echo "PHP 8.2.x is already installed: $PHP_VERSION"
    fi
}

# Function to install PHP 8.2.x
install_php() {
    # Update the system
    echo "Updating the system..."
    sudo apt update && sudo apt upgrade -y

    # Install prerequisites
    echo "Installing prerequisites..."
    sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common wget

    # Add PHP repository
    echo "Adding PHP repository..."
    sudo wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list

    # Update package list after adding repository
    echo "Updating package list..."
    sudo apt update

    # Install PHP 8.2 and common PHP extensions
    echo "Installing PHP 8.2.18..."
    sudo apt install -y php8.2=8.2.18-1+$(lsb_release -sc)+1 php8.2-cli php8.2-fpm php8.2-mbstring php8.2-xml php8.2-mysql php8.2-curl php8.2-zip

    # Verify PHP installation
    echo "Verifying PHP version..."
    php -v

    # Restart PHP service (if applicable)
    echo "Restarting PHP-FPM service..."
    sudo systemctl restart php8.2-fpm

    echo "PHP 8.2.18 installation completed!"
}

# Function to install and configure Nginx
install_webserver() {
    # Update the system
    echo "Updating the system..."
    sudo apt update && sudo apt upgrade -y

    # Install Nginx
    echo "Installing Nginx..."
    sudo apt install -y nginx

    # Start and enable Nginx service
    echo "Starting and enabling Nginx service..."
    sudo systemctl start nginx
    sudo systemctl enable nginx

    # Set permissions for the web root directory
    WEB_ROOT="/var/www/html"
    echo "Setting permissions for the web root directory..."
    sudo chown -R $USER:$USER "$WEB_ROOT"
    sudo chmod -R 755 "$WEB_ROOT"

    # Configure Nginx to serve the numero.html file
    echo "Configuring Nginx to serve numero.html..."
    NGINX_CONF="/etc/nginx/sites-available/default"
    sudo sed -i 's|index index.html index.htm index.nginx-debian.html;|index numero.html;|' "$NGINX_CONF"

    # Ensure Nginx listens on all network interfaces
    sudo sed -i 's|listen 80 default_server;|listen 0.0.0.0:80 default_server;|' "$NGINX_CONF"
    sudo sed -i 's|listen \[::\]:80 default_server;|listen \[::\]:80 default_server;|' "$NGINX_CONF"

    # Test Nginx configuration
    echo "Testing Nginx configuration..."
    sudo nginx -t

    # Reload Nginx to apply the changes
    echo "Reloading Nginx..."
    sudo systemctl reload nginx

    # Allow HTTP traffic through the firewall (if UFW is used)
    if command -v ufw > /dev/null; then
        echo "Allowing HTTP traffic through the firewall..."
        sudo ufw allow 'Nginx Full'
    fi

    # Display the IP address of the machine
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo "Nginx setup completed. You can access numero.html at http://$IP_ADDRESS/numero.html from another device on the same network."
}

# Function to perform Git sparse checkout
git_clone_repo() {
    # Variables
    REPO_URL="https://github.com/Tesseract-Technologies-IT/ScriptNumeroRaspiBilance.git"
    TARGET_DIR="/"

    # Ensure git is installed
    if ! [ -x "$(command -v git)" ]; then
        echo "Git is not installed. Installing git..."
        sudo apt update
        sudo apt install git -y
    fi

    # Create a temporary directory for cloning
    echo "Creating a temporary directory for cloning..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit 1

    # Clone the repository
    echo "Cloning the repository..."
    git clone "$REPO_URL" || exit 1
    REPO_NAME=$(basename "$REPO_URL" .git)
    cd "$REPO_NAME" || exit 1

    # Backup the existing target directory
    if [ -d "$TARGET_DIR" ]; then
        echo "Backing up the existing target directory..."
        sudo mv "$TARGET_DIR" "${TARGET_DIR}_backup_$(date +%Y%m%d%H%M%S)"
    fi

    # Move the cloned files to the target directory
    echo "Moving files to the target directory: $TARGET_DIR"
    sudo mkdir -p "$TARGET_DIR"
    sudo mv ./* "$TARGET_DIR" || exit 1

    # Cleanup temporary directory
    echo "Cleaning up..."
    cd ..
    rm -rf "$TEMP_DIR"
}

# Main script
start(){
  # starting up the webserver
  echo "Starting up the webserver..."
  sudo service nginx start
  echo "Webserver started successfully."
  #run /var/www/html/listener.php
  echo "Running listener.php..."
  php /var/www/html/listener.php
  echo "listener.php completed."
}

# Check PHP version and install if necessary
check_php_version

# Run the web server installation script
echo "Running web server installation..."
install_webserver

# Perform Git sparse checkout
echo "Performing Git sparse checkout..."
git_clone_repo

# Start the web server
echo "Starting the web server..." 
start

#create a service to start the listener.php on startup and to pull the repo on startup
echo "Creating a service to start the listener.php on startup and to pull the repo on startup..."
sudo mv /services/listener.service /etc/systemd/system/listener.service
sudo systemctl enable listener.service
sudo systemctl start listener.service
echo "Service created successfully."
sudo mv /services/repo-sync.service /etc/systemd/system/repo-sync.service
sudo systemctl enable repo-sync.service
sudo systemctl start repo-sync.service
echo "Service created successfully."


echo "Startup script completed."

