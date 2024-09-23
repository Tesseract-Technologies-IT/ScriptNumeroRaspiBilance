#!/bin/bash

# Redirect all output to a log file
exec > >(tee -a /var/log/startup_script.log) 2>&1

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

        # Move big_setup_script.sh to /
        echo "Moving big_setup_script.sh to /..."
        sudo mv /myrepo/big_setup_script.sh /
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

# Perform Git sparse checkout
echo "--==|
|==--" 
git_clone_repo

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
    
    # Move the service file to the systemd directory
    echo "Moving $service_name to /etc/systemd/system/$service_name..."
    sudo mv "$service_file" "/etc/systemd/system/$service_name"
    
    # Enable and start the service
    echo "Enabling and starting $service_name..."
    sudo chmod 644 "/etc/systemd/system/$service_name"
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