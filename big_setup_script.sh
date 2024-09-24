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

update_system() {
    # Update the system
    echo "Updating the system..."
    #sudo apt update && sudo apt upgrade -y
}

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
    REPO_URL="https://github.com/Tesseract-Technologies-IT/ScriptNumeroRaspiBilance.git"  # Replace with your Git repo URL

    # Define target directories and their respective subdirectories for cloning
    TARGET_DIRS=(
      "/var/www/html"  # Clone into /var/www/html/myrepo
      "/services"      # Clone into /services/myrepo
    )
    TARGET_DIR="/myrepo"

    # Confirm with the user
    echo "WARNING: This might delete files in the specified directories' subdirectories."
    read -p "Are you sure you want to proceed? (y/N): " confirmation
    if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
      echo "Aborting."
      exit 1
    fi

    # Delete existing contents in the subdirectories if they exist
    for dir in "${TARGET_DIRS[@]}"; do
      if [ -d "$dir" ]; then
        echo "Deleting existing contents in $dir..."
        sudo rm -rf "$dir"/*
        # Optionally, remove hidden files as well
        sudo rm -rf "$dir"/.[!.]* "$dir"/..?*
      else
        echo "Creating directory $dir..."
        sudo mkdir -p "$dir"
        sudo chown $USER:$USER "$dir"
      fi
    done

    if [ -d "${TARGET_DIR}" ]; then
        echo "Deleting existing contents in ${TARGET_DIR}..."
        sudo rm -rf "${TARGET_DIR}"/*
        # Optionally, remove hidden files as well
        sudo rm -rf "${TARGET_DIR}"/.[!.]* "${TARGET_DIR}"/..?*
      else
        echo "Creating directory ${TARGET_DIR}..."
        sudo mkdir -p "${TARGET_DIR}"
        sudo chown $USER:$USER "${TARGET_DIR}"
      fi

    # Clone the repository into each target subdirectory
    
    echo "Cloning repository $REPO_URL into ${TARGET_DIR}..."
    sudo git clone "$REPO_URL" "${TARGET_DIR}"

    # Check if the clone was successful
    if [ $? -eq 0 ]; then
        echo "Repository successfully cloned into ${TARGET_DIR}"
        # Move the contents of /myrepo/services/ to /services/
        echo "Moving contents of /myrepo/services/ to /services/..."
        sudo mv /myrepo/services/* /services/

        # Move the contents of /myrepo/var/www/html/ to /var/www/html/
        echo "Moving contents of /myrepo/var/www/html/ to /var/www/html/..."
        sudo mv /myrepo/var/www/html/* /var/www/html/
        #set all .txt and .php files in /var/www/html/ to be executable
        sudo chmod 666 /var/www/html/*.txt
        sudo chmod 777 /var/www/html/*.php

        # Move all files in / that end with .sh to /
        echo "Moving all files in / that end with .sh to /..."
        # Set all files that end with .sh to be executable
        sudo chmod 777 /myrepo/*.sh
        sudo mv /myrepo/*.sh /
    else
        echo "Failed to clone repository into ${TARGET_DIR}. Please check the repo URL and permissions."
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
echo "--==|Updating the system|==--" 
update_system

# Clone Git repository
echo "--==|Cloning Repo...|==--" 
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
for service_file in /services/*.service; do
  # Check if the file is a regular file
  if [ -f "$service_file" ]; then
    # Get the filename without the path
    service_name=$(basename "$service_file")
    target_file="/etc/systemd/system/$service_name"
    
    # Check if the target service file already exists
    if [ -f "$target_file" ]; then
      # Compare the contents of the existing file and the new file
      if ! cmp -s "$service_file" "$target_file"; then
        echo "Updating $service_name as the files are different..."
        sudo mv "$service_file" "$target_file"
      else
        echo "Skipping $service_name as the files are identical."
        sudo rm "$service_file"
        continue
      fi
    else
      echo "Moving $service_name to $target_file..."
      sudo mv "$service_file" "$target_file"
    fi
    
    # Enable and start the service
    echo "Enabling and starting $service_name..."
    sudo chmod 644 "$target_file"
    sudo systemctl enable "$service_name"
    #sudo systemctl start "$service_name"
    
    # Check the status of the service
    #echo "Checking status of $service_name..."
    #sudo systemctl status "$service_name"
    
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