#!/bin/bash

# Paths to files
JSON_FILE="/etc/json_conf/gw_conf_local.json"
TEMP_FILE="/var/www/html/rauc-app-update-config.tmp"
SETTINGS_FILE="/root/rauc-hawkbit/rauc_hawkbit/config.cfg"

systemctl stop rauc-hawkbit-updater.service
sleep 2

# Read RAUC app update config settings from JSON
HAWKBIT_SERVER=$(jq -r '.[] | select(.channel_name == "Rauc-app-update-config") | .cfg_params[0].hawkbit_server' "$JSON_FILE")
TARGET_NAME=$(jq -r '.[] | select(.channel_name == "Rauc-app-update-config") | .cfg_params[0].target_name' "$JSON_FILE")
AUTH_TOKEN=$(jq -r '.[] | select(.channel_name == "Rauc-app-update-config") | .cfg_params[0].auth_token' "$JSON_FILE")

# Check if temp file exists
if [ -f "$TEMP_FILE" ]; then
    # Read RAUC app update config settings from temp file
    TEMP_HAWKBIT_SERVER=$(grep -oP '(?<=hawkbit_server: ).*' "$TEMP_FILE")
    TEMP_TARGET_NAME=$(grep -oP '(?<=target_name: ).*' "$TEMP_FILE")
    TEMP_AUTH_TOKEN=$(grep -oP '(?<=auth_token: ).*' "$TEMP_FILE")

    # Compare RAUC app update config settings between temp and JSON
    if [ "$HAWKBIT_SERVER" != "$TEMP_HAWKBIT_SERVER" ] || [ "$TARGET_NAME" != "$TEMP_TARGET_NAME" ] || [ "$AUTH_TOKEN" != "$TEMP_AUTH_TOKEN" ]; then
        # Update temp file
        echo "hawkbit_server: $HAWKBIT_SERVER" > "$TEMP_FILE"
        echo "target_name: $TARGET_NAME" >> "$TEMP_FILE"
        echo "auth_token: $AUTH_TOKEN" >> "$TEMP_FILE"

        # Update settings file
        sed -i "s/^hawkbit_server = .*/hawkbit_server = $HAWKBIT_SERVER/" "$SETTINGS_FILE"
        sed -i "s/^target_name = .*/target_name = $TARGET_NAME/" "$SETTINGS_FILE"
        sed -i "s/^auth_token = .*/auth_token = $AUTH_TOKEN/" "$SETTINGS_FILE"

        sleep 10s

        systemctl restart rauc-hawkbit.service

        echo "RAUC app update config settings updated successfully"
        systemctl status rauc-hawkbit.service >> /var/log/rauc-hawkbit-update.log
    else
        echo "RAUC app update config settings are the same. No changes required."
        exit 0
    fi
else
    # Update temp file
    echo "hawkbit_server: $HAWKBIT_SERVER" > "$TEMP_FILE"
    echo "target_name: $TARGET_NAME" >> "$TEMP_FILE"
    echo "auth_token: $AUTH_TOKEN" >> "$TEMP_FILE"

    # Update settings file
    sed -i "s/^hawkbit_server = .*/hawkbit_server = $HAWKBIT_SERVER/" "$SETTINGS_FILE"
    sed -i "s/^target_name = .*/target_name = $TARGET_NAME/" "$SETTINGS_FILE"
    sed -i "s/^auth_token = .*/auth_token = $AUTH_TOKEN/" "$SETTINGS_FILE"

    sleep 10s

    systemctl restart rauc-hawkbit.service

    echo "RAUC app update config settings updated successfully"
    systemctl status rauc-hawkbit.service >> /var/log/rauc-hawkbit-update.log
fi
