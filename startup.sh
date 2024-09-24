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

    # Clone the repository into target directory
    
    echo "Cloning repository $REPO_URL into ${TARGET_DIR}..."
    sudo git clone "$REPO_URL" "${TARGET_DIR}"

    # Check if the clone was successful
    if [ $? -eq 0 ]; then
        echo "Repository successfully cloned into ${TARGET_DIR}"
        # Move the contents of /myrepo/services/ to /services/
        sudo rm -rf /services/*
        echo "Moving contents of /myrepo/services/ to /services/..."
        sudo mv /myrepo/services/* /services/

        # Move all files in /myrepo/ that end with .sh to /
        echo "Moving all files in / that end with .sh to /..."
        # Set all files that end with .sh to be executable
        sudo chmod 777 /myrepo/*.sh
        sudo mv /myrepo/*.sh /

        # Move the contents of /myrepo/var/www/html/ to /var/www/html/ if they're different
        echo "Moving contents of /myrepo/var/www/html/ to /var/www/html/ if they're different..."
        rsync -r --ignore-existing /myrepo/var/www/html/ /var/www/html/
        # Set all .txt and .php files in /var/www/html/ to be executable
        sudo chmod 666 /var/www/html/*.txt
        sudo chmod 777 /var/www/html/*.php
    else
        echo "Failed to clone repository into ${TARGET_DIR}. Please check the repo URL and permissions."
        exit 1
    fi
}

enable_services() {
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
}

# Clone Git repository
echo "--==|Cloning Repo...|==--" 
git_clone_repo

#create services to start the listener.php, webserver and pull the repo on startup
echo "Creating services to start the listener.php and pull the repo on startup..."
enable_services

echo "Services created successfully."


echo "Startup script completed."
