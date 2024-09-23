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

#update_system() {
    # Update the system
    #echo "Updating the system..."
    #sudo apt update && sudo apt upgrade -y
#}

# Function to install PHP 8.2.x
install_php() {
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
    echo "Installing PHP 8.2..."
    sudo apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mbstring php8.2-xml php8.2-mysql php8.2-curl php8.2-zip

    # Verify PHP installation
    echo "Verifying PHP version..."
    php -v

    # Restart PHP service (if applicable)
    echo "Restarting PHP-FPM service..."
    sudo systemctl restart php8.2-fpm

    echo "PHP 8.2 installation completed!"
}

# Function to install and configure Nginx
install_webserver() { 

    # Install Nginx
    echo "Installing Nginx..."
    sudo apt install -y nginx

    # Start and enable Nginx service
    echo "Starting and enabling Nginx service..."
    sudo systemctl start nginx
    sudo systemctl enable nginx

    # Set permissions for the web root directory
    WEB_ROOT="/"
    echo "Setting permissions for the web root directory..."
    sudo chown -R $USER:$USER "/var/www/html"
    sudo chown -R $USER:$USER "/services"
    sudo chmod -R 755 "/var/www/html"
    sudo chmod -R 755 "/services"

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

# clone the repo
git_clone_repo() {

    # Check if script is run as root
    if [[ $EUID -ne 0 ]]; then
      echo "This script must be run as root. Use sudo." 
      exit 1
    fi

    # Variables
    REPO_URL="https://github.com/username/repository.git"  # Replace with your Git repo URL
    TARGET_DIR="/"  # The directory to clone into (root)

    # Directories to exclude from deletion (critical system directories)
    EXCLUDE_DIRS=(
      "bin"
      "boot"
      "dev"
      "etc"
      "lib"
      "lib32"
      "lib64"
      "libx32"
      "media"
      "mnt"
      "proc"
      "root"
      "run"
      "sbin"
      "srv"
      "sys"
      "tmp"
      "usr"
    )

    # Confirm with the user
    echo "WARNING: This will delete files in the root directory, except for critical system directories."
    read -p "Are you sure you want to proceed? (y/N): " confirmation
    if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
      echo "Aborting."
      exit 1
    fi

    # Delete non-system directories in the root folder
    echo "Deleting files in $TARGET_DIR, excluding critical system directories..."
    for dir in "$TARGET_DIR"*; do
      # Extract the directory name
      base_dir=$(basename "$dir")

      # Check if the directory is in the exclusion list
      if [[ ! " ${EXCLUDE_DIRS[@]} " =~ " ${base_dir} " ]]; then
        echo "Deleting $dir..."
        rm -rf "$dir"
      else
        echo "Skipping $dir (protected)"
      fi
    done

    # Clone the repository into the root directory
    echo "Cloning repository $REPO_URL into $TARGET_DIR"
    git clone "$REPO_URL" "$TARGET_DIR"

    # Check if the clone was successful
    if [ $? -eq 0 ]; then
        echo "Repository successfully cloned into $TARGET_DIR"
    else
        echo "Failed to clone repository. Please check the repo URL and permissions."
        exit 1
    fi

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

# Update the system
update_system

# Perform Git sparse checkout
echo "--==|
|==--" 
git_clone_repo

# Check PHP version and install if necessary
echo "--==|Checking PHP version...|==--" 
check_php_version

# Run the web server installation script
echo "--==|Running web server installation...|==--" 
install_webserver

# Start the web server
echo "--==|Starting the web server...|==--" 
start

#create services to start the listener.php and pull the repo on startup
echo "Creating services to start the listener.php and pull the repo on startup..."

# Loop through all files in the /services/ directory
for service_file in /services/*; do
  # Check if the file is a regular file
  if [ -f "$service_file" ]; then
    # Get the filename without the path
    service_name=$(basename "$service_file")
    
    # Move the service file to the systemd directory
    echo "Moving $service_name to /etc/systemd/system/$service_name..."
    sudo mv "$service_file" "/etc/systemd/system/$service_name"
    
    # Enable and start the service
    echo "Enabling and starting $service_name..."
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"
    
    # Check the status of the service
    echo "Checking status of $service_name..."
    sudo systemctl status "$service_name"
    
    echo "Service $service_name created successfully."
  fi
done

echo "Services created successfully."


echo "Startup script completed."

# Ask if user wants to reboot
read -p "Do you want to reboot the system? (y/N): " reboot_confirmation
if [[ "$reboot_confirmation" == "y" || "$reboot_confirmation" == "Y" ]]; then
  echo "Rebooting the system..."
  sudo reboot
else
  echo "System reboot skipped."
fi