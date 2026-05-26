#!/bin/bash
set -e

CONFIG_FILE="/var/lib/jenkins/config.xml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Jenkins config file not found at $CONFIG_FILE. Making sure Jenkins has run at least once."
    exit 1
fi

echo "============================================="
echo " Backing up config.xml"
echo "============================================="
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

echo "============================================="
echo " Disabling Jenkins Security"
echo "============================================="
# Change <useSecurity>true</useSecurity> to <useSecurity>false</useSecurity>
sed -i 's/<useSecurity>true<\/useSecurity>/<useSecurity>false<\/useSecurity>/g' "$CONFIG_FILE"

echo "============================================="
echo " Restarting Jenkins"
echo "============================================="
systemctl restart jenkins

echo "============================================="
echo " Security Disabled!"
echo "============================================="
echo "Please refresh http://localhost:8080 in your browser."
echo "You should now have direct admin access without a password."
echo ""
echo "Once logged in, you can configure a new user via: "
echo "Manage Jenkins -> Security -> Security Realm"
echo "============================================="
