#!/bin/bash

#############################################
# Raspberry Pi Kiosk Mode Setup Script
# Author: OpenAI ChatGPT
# Date: YYYY-MM-DD
#############################################

set -e  # Exit immediately if a command exits with a non-zero status

# -----------------------------
# Variables (Customize These)
# -----------------------------
VUE_APP_URL="https://your-vue-app-url.com"  # Replace with your Vue.js app URL
DISPLAY_OUTPUT="HDMI-1"                      # Adjust based on xrandr output
RESOLUTION_WIDTH=1920
RESOLUTION_HEIGHT=1080
REFRESH_RATE=60

# -----------------------------
# Function Definitions
# -----------------------------

# Function to update and upgrade the system
update_system() {
    echo "Updating and upgrading the system..."
    sudo apt update
    sudo apt full-upgrade -y
}

# Function to install necessary packages
install_packages() {
    echo "Installing necessary packages..."
    sudo apt install -y chromium-browser unclutter xdotool
}

# Function to configure /boot/config.txt for display settings
configure_display() {
    echo "Configuring /boot/config.txt for display settings..."
    sudo sed -i '/^# Force HDMI even if no monitor is detected/a \
hdmi_force_hotplug=1\n\
hdmi_group=1\n\
hdmi_mode=16\n\
disable_overscan=1\n\
hdmi_drive=2\n\
framebuffer_width=1920\n\
framebuffer_height=1080' /boot/config.txt
}

# Function to set display settings using xrandr
set_xrandr_settings() {
    echo "Setting display settings with xrandr..."
    mkdir -p ~/kiosk
    cat <<EOF > ~/kiosk/set_display.sh
#!/bin/bash
xrandr --output $DISPLAY_OUTPUT --primary --mode ${RESOLUTION_WIDTH}x${RESOLUTION_HEIGHT} --rate ${REFRESH_RATE}
EOF
    chmod +x ~/kiosk/set_display.sh
}

# Function to create the kiosk startup script
create_kiosk_script() {
    echo "Creating kiosk startup script..."
    cat <<EOF > ~/kiosk/start_kiosk.sh
#!/bin/bash
# Disable screen saver and power management
xset s off
xset -dpms
xset s noblank

# Hide the mouse cursor after a short period of inactivity
unclutter -idle 0.5 -root &

# Wait for the desktop environment to load
sleep 5

# Set display settings
~/kiosk/set_display.sh

# Launch Chromium in kiosk mode with additional flags
chromium-browser \\
  --noerrdialogs \\
  --disable-infobars \\
  --kiosk "$VUE_APP_URL" \\
  --incognito \\
  --disable-translate \\
  --disable-suggestions-service \\
  --start-fullscreen \\
  --window-position=0,0 \\
  --window-size=${RESOLUTION_WIDTH},${RESOLUTION_HEIGHT} \\
  --disable-features=TranslateUI

# Monitor Chromium and restart if it crashes
while true; do
    sleep 10
    if ! pgrep chromium-browser > /dev/null; then
        chromium-browser \\
          --noerrdialogs \\
          --disable-infobars \\
          --kiosk "$VUE_APP_URL" \\
          --incognito \\
          --disable-translate \\
          --disable-suggestions-service \\
          --start-fullscreen \\
          --window-position=0,0 \\
          --window-size=${RESOLUTION_WIDTH},${RESOLUTION_HEIGHT} \\
          --disable-features=TranslateUI
    fi
done
EOF

    chmod +x ~/kiosk/start_kiosk.sh
}

# Function to configure autostart
configure_autostart() {
    echo "Configuring autostart..."
    mkdir -p ~/.config/lxsession/LXDE-pi/
    cat <<EOF > ~/.config/lxsession/LXDE-pi/autostart
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xset s off
@xset -dpms
@xset s noblank
@/home/pi/kiosk/start_kiosk.sh
EOF
}

# Function to disable screen blanking and power management in LightDM
disable_lightdm_power_saving() {
    echo "Disabling screen blanking and power management in LightDM..."
    sudo sed -i '/^\[Seat:*\]/a \
xserver-command=X -s 0 dpms' /etc/lightdm/lightdm.conf
}

# Function to clean up existing autostart entries (optional)
cleanup_autostart() {
    echo "Cleaning up existing autostart entries..."
    # This removes Chromium or kiosk entries from system-wide autostart
    sudo grep -rl 'chromium-browser' /etc/xdg/autostart/ | xargs sudo rm -f
    sudo grep -rl 'start_kiosk.sh' ~/.config/autostart/ | xargs rm -f
}

# Function to reboot the system
reboot_system() {
    echo "Rebooting the system to apply changes..."
    sudo reboot
}

# -----------------------------
# Execution Steps
# -----------------------------

echo "Starting Raspberry Pi kiosk setup..."

cleanup_autostart
update_system
install_packages
configure_display
set_xrandr_settings
create_kiosk_script
configure_autostart
disable_lightdm_power_saving

echo "Kiosk setup completed successfully."

# Optionally, uncomment the next line to automatically reboot after setup
# reboot_system
