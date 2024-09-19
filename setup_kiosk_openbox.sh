#!/bin/bash

# Openbox Kiosk Setup Script for Raspberry Pi
# Author: OpenAI Assistant
# Date: $(date)

# Variables
URL="$1"
LOG_FILE="/home/pi/kiosk_setup_openbox.log"
USER="pi"
HOME_DIR="/home/$USER"

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (e.g., sudo $0 <URL>)"
  exit 1
fi

if [ -z "$URL" ]; then
  echo "Usage: sudo $0 <URL>" | tee -a $LOG_FILE
  exit 1
fi

echo "Openbox Kiosk setup started at $(date)" | tee -a $LOG_FILE

# Redirect stderr to log file
exec 2>>$LOG_FILE

# Function to check the exit status of commands
check_status() {
  if [ $? -ne 0 ]; then
    echo "Error: $1 failed to execute properly." | tee -a $LOG_FILE
    exit 1
  fi
}

# Update system packages
echo "Updating system packages..." | tee -a $LOG_FILE
sudo apt-get update -y && sudo apt-get upgrade -y
check_status "System update and upgrade"

# Install necessary packages
echo "Installing necessary packages..." | tee -a $LOG_FILE
sudo apt-get install -y --no-install-recommends \
  xserver-xorg \
  x11-xserver-utils \
  xinit \
  openbox \
  chromium-browser \
  unclutter \
  lightdm \
  htop \
  raspi-gpio \
  xcompmgr
check_status "Package installation"

# Force HDMI output to 1080p at 60Hz
echo "Configuring display settings..." | tee -a $LOG_FILE
if [ ! -f /boot/config.txt.bak ]; then
  sudo cp /boot/config.txt /boot/config.txt.bak
fi
sudo sed -i '/^hdmi_/d' /boot/config.txt
sudo tee -a /boot/config.txt > /dev/null <<EOT
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16
hdmi_drive=2
EOT
check_status "Display configuration"

# Disable screen blanking and power management
echo "Disabling screen blanking and power management..." | tee -a $LOG_FILE
if [ ! -f /etc/lightdm/lightdm.conf.bak ]; then
  sudo cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak
fi

# Clean existing configurations
sudo sed -i '/^\[Seat:\*\]/,/^\[/{/^xserver-command=/d}' /etc/lightdm/lightdm.conf
sudo sed -i '/^\[Seat:\*\]/,/^\[/{/^autologin-user=/d}' /etc/lightdm/lightdm.conf
sudo sed -i '/^\[Seat:\*\]/,/^\[/{/^autologin-session=/d}' /etc/lightdm/lightdm.conf
sudo sed -i '/^\[Seat:\*\]/d' /etc/lightdm/lightdm.conf

# Add new configuration
sudo tee -a /etc/lightdm/lightdm.conf > /dev/null <<EOT
[Seat:*]
xserver-command=X -s 0 -dpms
autologin-user=$USER
autologin-session=openbox
EOT
check_status "LightDM configuration"

# Create autostart directory if it doesn't exist
mkdir -p $HOME_DIR/.config/openbox
check_status "Creating Openbox config directory"

# Create autostart script for Openbox
echo "Creating autostart script..." | tee -a $LOG_FILE
cat <<EOL > $HOME_DIR/.config/openbox/autostart
# Disable any screen saver and power management
xset s off
xset s noblank
xset -dpms

# Hide the mouse cursor after 0.5 seconds of inactivity
unclutter -idle 0.5 -root &

# Start Chromium in kiosk mode with specified URL
while true; do
  chromium-browser \\
    --noerrdialogs \\
    --disable-infobars \\
    --kiosk \\
    --start-fullscreen \\
    --disable-translate \\
    --no-first-run \\
    --fast \\
    --fast-start \\
    --disable-features=TranslateUI \\
    --force-device-scale-factor=1 \\
    --password-store=basic \\
    "$URL"
  sleep 5
done &
EOL
check_status "Creating Openbox autostart script"

chmod +x $HOME_DIR/.config/openbox/autostart
check_status "Setting execute permission on autostart script"

# Remove screensaver packages to prevent screen blanking
echo "Removing screensaver packages..." | tee -a $LOG_FILE
sudo apt-get remove -y xscreensaver light-locker
check_status "Removing screensaver packages"

# Ensure proper permissions
echo "Setting permissions for $HOME_DIR/.config..." | tee -a $LOG_FILE
sudo chown -R $USER:$USER $HOME_DIR/.config
check_status "Setting ownership of $HOME_DIR/.config"

echo "Openbox Kiosk setup completed successfully at $(date)" | tee -a $LOG_FILE
echo "Please reboot the system to apply all changes." | tee -a $LOG_FILE

