#!/bin/bash

# Paths to files
JSON_FILE="/etc/json_conf/gw_conf_local.json"
TEMP_FILE="/var/www/html/network_cellular_conf.tmp"
N58_SCRIPT="/var/www/html/cellular.sh"
SERVICE_FILE="/etc/systemd/system/cellular.service"

# Read APN from JSON
APN=$(jq -r '.[] | select(.channel_name == "4G_Channel") | .cfg_params[] | select(.name == "APN") | .value' "$JSON_FILE")

# Check if APN is empty
if [ -z "$APN" ]; then
    echo "Error: APN is empty in the JSON file."
    exit 1
fi

# Check if temp file exists
if [ -f "$TEMP_FILE" ]; then
    # Read APN from temp file
    TEMP_APN=$(< "$TEMP_FILE")

    # Compare APN between temp and JSON
    if [ "$APN" != "$TEMP_APN" ]; then
        # Update temp file
        echo "$APN" > "$TEMP_FILE"

        # Update APN in n58.sh script
        sed -i "s/^echo \"AT+CGDCONT=.*$/echo \"AT+CGDCONT=1,\"IP\",\"$APN\"\" > \/dev\/ttyUSB2/" "$N58_SCRIPT"
        sed -i "s/^echo \"AT+CGDCONT=.*$/echo \"AT+CGDCONT=2,\"IP\",\"$APN\"\" > \/dev\/ttyUSB2/" "$N58_SCRIPT"

        # Restart the service
        systemctl restart cellular.service

        echo "APN updated successfully"
    else
        echo "APN is the same. No changes required."

        # Update APN in n58.sh script
        sed -i "s/^echo \"AT+CGDCONT=.*$/echo \"AT+CGDCONT=1,\"IP\",\"$APN\"\" > \/dev\/ttyUSB2/" "$N58_SCRIPT"
        sed -i "s/^echo \"AT+CGDCONT=.*$/echo \"AT+CGDCONT=2,\"IP\",\"$APN\"\" > \/dev\/ttyUSB2/" "$N58_SCRIPT"

    fi
else
    # Create temp file and store APN
    echo "$APN" > "$TEMP_FILE"

    # Update APN in n58.sh script
    sed -i "s/^echo \"AT+CGDCONT=.*$/echo \"AT+CGDCONT=1,\"IP\",\"$APN\"\" > \/dev\/ttyUSB2/" "$N58_SCRIPT"
    sed -i "s/^echo \"AT+CGDCONT=.*$/echo \"AT+CGDCONT=2,\"IP\",\"$APN\"\" > \/dev\/ttyUSB2/" "$N58_SCRIPT"

    # Restart the service
    systemctl restart cellular.service

    echo "Temp file created and APN updated successfully"
fi

