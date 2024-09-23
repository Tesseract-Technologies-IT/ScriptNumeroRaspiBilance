#!/bin/bash

# Redirect all output to log file
exec >> /var/log/repo-sync.log 2>&1

echo "===== $(date) ====="

# Variables
REPO_DIR="/myrepo"        # Directory where the repo is cloned
WEB_DIR="/"                 # Web root directory
SERVICES_DIR="/services/"         # Directory for services
GIT_BRANCH="main"                       # Git branch to pull

# Navigate to repository directory
echo "Navigating to repository directory: $REPO_DIR"
cd "$REPO_DIR" || { echo "Failed to navigate to $REPO_DIR"; exit 1; }

# Pull latest changes
echo "Pulling latest changes from Git repository..."
git pull origin "$GIT_BRANCH"
if [ $? -eq 0 ]; then
    echo "Successfully pulled latest changes."
else
    echo "Failed to pull latest changes."
    exit 1
fi

# Move files to target directories
echo "Moving files to target directories..."

# Example: Copy PHP files to web directory
echo "Copying PHP files to $WEB_DIR..."
cp -r "$REPO_DIR/php_files/"* "$WEB_DIR/"
if [ $? -eq 0 ]; then
    echo "Successfully copied PHP files."
else
    echo "Failed to copy PHP files."
    exit 1
fi

# Example: Copy service scripts to services directory
echo "Copying service scripts to $SERVICES_DIR..."
cp -r "$REPO_DIR/service_scripts/"* "$SERVICES_DIR/"
if [ $? -eq 0 ]; then
    echo "Successfully copied service scripts."
else
    echo "Failed to copy service scripts."
    exit 1;
fi

# Restart Nginx to apply changes
echo "Restarting Nginx..."
systemctl restart nginx
if [ $? -eq 0 ]; then
    echo "Nginx restarted successfully."
else
    echo "Failed to restart Nginx."
    exit 1;
fi

echo "Update and deployment completed successfully."
echo "===== End of $(date) ====="