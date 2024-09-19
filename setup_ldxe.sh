#!/bin/bash

# setup_kiosk.sh
# This script sets up a Raspberry Pi to run in kiosk mode with Chromium.

LOG_FILE="/var/log/kiosk_setup.log"
exec > >(tee -i $LOG_FILE)
exec 2>&1

echo "Starting kiosk setup..."

# Update system packages
echo "Updating system packages..."
apt-get update -y && apt-get upgrade -y
if [ $? -ne 0 ]; then
    echo "Error updating system packages."
    exit 1
fi

# Install necessary packages
echo "Installing necessary packages..."
apt-get install -y xdotool unclutter sed chromium-browser
if [ $? -ne 0 ]; then
    echo "Error installing packages."
    exit 1
fi

# Configure display settings to force 1080p at 60Hz
echo "Configuring display settings..."
CONFIG_FILE="/boot/config.txt"

grep -q "^hdmi_force_hotplug=1" $CONFIG_FILE || echo "hdmi_force_hotplug=1" >> $CONFIG_FILE
grep -q "^hdmi_group=1" $CONFIG_FILE || echo "hdmi_group=1" >> $CONFIG_FILE
grep -q "^hdmi_mode=16" $CONFIG_FILE || echo "hdmi_mode=16" >> $CONFIG_FILE
grep -q "^disable_overscan=1" $CONFIG_FILE || echo "disable_overscan=1" >> $CONFIG_FILE

# Disable screen blanking and power management
echo "Disabling screen blanking and power management..."
LXSESSION_AUTOSTART="/etc/xdg/lxsession/LXDE-pi/autostart"
sed -i '/^@xset s/d' $LXSESSION_AUTOSTART
sed -i '/^@xset -dpms/d' $LXSESSION_AUTOSTART
sed -i '/^@xset s noblank/d' $LXSESSION_AUTOSTART
echo "@xset s noblank" >> $LXSESSION_AUTOSTART
echo "@xset s off" >> $LXSESSION_AUTOSTART
echo "@xset -dpms" >> $LXSESSION_AUTOSTART

# Disable screensaver
echo "Disabling screensaver..."
apt-get install -y xscreensaver
if [ $? -ne 0 ]; then
    echo "Error installing xscreensaver."
    exit 1
fi
xscreensaver-command -exit
sed -i 's/@xscreensaver -no-splash/#@xscreensaver -no-splash/g' $LXSESSION_AUTOSTART

# Install Chromium if not already installed
if ! command -v chromium-browser &> /dev/null; then
    echo "Installing Chromium browser..."
    apt-get install -y chromium-browser
    if [ $? -ne 0 ]; then
        echo "Error installing Chromium."
        exit 1
    fi
fi

# Create kiosk startup script
echo "Creating kiosk startup script..."
KIOSK_SCRIPT="/home/pi/kiosk.sh"
cat <<EOL > $KIOSK_SCRIPT
#!/bin/bash
# Wait for the desktop to load
while [ \$(pgrep lxsession | wc -l) -eq 0 ]; do
    sleep 1
done

# Hide the mouse cursor after 5 seconds of inactivity
unclutter -idle 5 &

# Launch Chromium in kiosk mode
chromium-browser --noerrdialogs --disable-infobars --kiosk --incognito 'http://your-url-here.com'
EOL

chmod +x $KIOSK_SCRIPT

# Ensure Chromium restarts if it crashes
echo "Setting up Chromium to restart if it crashes..."
SUPERVISOR_CONF="/etc/supervisor/conf.d/kiosk.conf"
apt-get install -y supervisor
if [ $? -ne 0 ]; then
    echo "Error installing Supervisor."
    exit 1
fi

cat <<EOL > $SUPERVISOR_CONF
[program:kiosk]
command=/home/pi/kiosk.sh
user=pi
autostart=true
autorestart=true
stderr_logfile=/var/log/kiosk.err.log
stdout_logfile=/var/log/kiosk.out.log
EOL

supervisorctl reread
supervisorctl update

# Add kiosk script to autostart
echo "Adding kiosk script to LXDE autostart..."
grep -q "^@/home/pi/kiosk.sh" $LXSESSION_AUTOSTART || echo "@/home/pi/kiosk.sh" >> $LXSESSION_AUTOSTART

# Disable splash screen (optional)
echo "Disabling splash screen..."
sed -i 's/^\#disable_splash=1/disable_splash=1/' $CONFIG_FILE
grep -q "^disable_splash=1" $CONFIG_FILE || echo "disable_splash=1" >> $CONFIG_FILE

# Hide boot messages (optional)
echo "Hiding boot messages..."
CMDLINE_FILE="/boot/cmdline.txt"
sed -i 's/console=tty1/console=tty3/' $CMDLINE_FILE
sed -i 's/$/ loglevel=3 quiet/' $CMDLINE_FILE

echo "Kiosk setup completed successfully."
echo "Please reboot the Raspberry Pi to apply all changes."
