#!/bin/bash

# Paths to files
JSON_FILE="/etc/json_conf/gw_conf_local.json"
TEMP_FILE="/var/www/html/mqtt_transport1.tmp"
SETTINGS_FILE="/root/wirepas/polaris-settings.yml"

# Read MQTT settings from JSON
MQTT_HOSTNAME=$(jq -r '.[] | select(.channel_name == "MQTT_Transport1") | .cfg_params[0].mqtt_hostname' "$JSON_FILE")
MQTT_PORT=$(jq -r '.[] | select(.channel_name == "MQTT_Transport1") | .cfg_params[0].mqtt_port' "$JSON_FILE")
MQTT_USERNAME=$(jq -r '.[] | select(.channel_name == "MQTT_Transport1") | .cfg_params[0].mqtt_username' "$JSON_FILE")
MQTT_PASSWORD=$(jq -r '.[] | select(.channel_name == "MQTT_Transport1") | .cfg_params[0].mqtt_password' "$JSON_FILE")
MQTT_FORCE_UNSECURE=$(jq -r '.[] | select(.channel_name == "MQTT_Transport1") | .cfg_params[0].mqtt_force_unsecure' "$JSON_FILE")
GATEWAY_ID=$(jq -r '.[] | select(.channel_name == "MQTT_Transport1") | .cfg_params[0].gateway_id' "$JSON_FILE")

# Check if temp file exists
if [ -f "$TEMP_FILE" ]; then
    # Read MQTT settings from temp file
    TEMP_MQTT_HOSTNAME=$(grep -oP '(?<=mqtt_hostname: ).*' "$TEMP_FILE")
    TEMP_MQTT_PORT=$(grep -oP '(?<=mqtt_port: ).*' "$TEMP_FILE")
    TEMP_MQTT_USERNAME=$(grep -oP '(?<=mqtt_username: ).*' "$TEMP_FILE")
    TEMP_MQTT_PASSWORD=$(grep -oP '(?<=mqtt_password: ).*' "$TEMP_FILE")
    TEMP_MQTT_FORCE_UNSECURE=$(grep -oP '(?<=mqtt_force_unsecure: ).*' "$TEMP_FILE")
    TEMP_GATEWAY_ID=$(grep -oP '(?<=gateway_id: ).*' "$TEMP_FILE")

    # Compare MQTT settings between temp and JSON
    if [ "$MQTT_HOSTNAME" != "$TEMP_MQTT_HOSTNAME" ] || [ "$MQTT_PORT" != "$TEMP_MQTT_PORT" ] || [ "$MQTT_USERNAME" != "$TEMP_MQTT_USERNAME" ] || [ "$MQTT_PASSWORD" != "$TEMP_MQTT_PASSWORD" ] || [ "$MQTT_FORCE_UNSECURE" != "$TEMP_MQTT_FORCE_UNSECURE" ] || [ "$GATEWAY_ID" != "$TEMP_GATEWAY_ID" ]; then
        # Update temp file
        echo "mqtt_hostname: $MQTT_HOSTNAME" > "$TEMP_FILE"
        echo "mqtt_port: $MQTT_PORT" >> "$TEMP_FILE"
        echo "mqtt_username: $MQTT_USERNAME" >> "$TEMP_FILE"
        echo "mqtt_password: $MQTT_PASSWORD" >> "$TEMP_FILE"
        echo "mqtt_force_unsecure: $MQTT_FORCE_UNSECURE" >> "$TEMP_FILE"
        echo "gateway_id: $GATEWAY_ID" >> "$TEMP_FILE"

        # Update settings file
        sed -i "s/mqtt_hostname: .*/mqtt_hostname: $MQTT_HOSTNAME/" "$SETTINGS_FILE"
        sed -i "s/mqtt_port: .*/mqtt_port: $MQTT_PORT/" "$SETTINGS_FILE"
        sed -i "s/mqtt_username: .*/mqtt_username: $MQTT_USERNAME/" "$SETTINGS_FILE"
        sed -i "s/mqtt_password: .*/mqtt_password: $MQTT_PASSWORD/" "$SETTINGS_FILE"
        sed -i "s/mqtt_force_unsecure: .*/mqtt_force_unsecure: $MQTT_FORCE_UNSECURE/" "$SETTINGS_FILE"
        sed -i "s/gateway_id: .*/gateway_id: $GATEWAY_ID/" "$SETTINGS_FILE"

        sleep 10s

        systemctl restart polarisTransport.service

        echo "MQTT settings updated successfully"
        systemctl status polarisTransport.service >> /var/log/Transport1.log
    else
        echo "MQTT settings are the same. No changes required."
        exit 0
    fi
else
    # Update temp file
    echo "mqtt_hostname: $MQTT_HOSTNAME" > "$TEMP_FILE"
    echo "mqtt_port: $MQTT_PORT" >> "$TEMP_FILE"
    echo "mqtt_username: $MQTT_USERNAME" >> "$TEMP_FILE"
    echo "mqtt_password: $MQTT_PASSWORD" >> "$TEMP_FILE"
    echo "mqtt_force_unsecure: $MQTT_FORCE_UNSECURE" >> "$TEMP_FILE"
    echo "gateway_id: $GATEWAY_ID" >> "$TEMP_FILE"

    # Update settings file
    sed -i "s/mqtt_hostname: .*/mqtt_hostname: $MQTT_HOSTNAME/" "$SETTINGS_FILE"
    sed -i "s/mqtt_port: .*/mqtt_port: $MQTT_PORT/" "$SETTINGS_FILE"
    sed -i "s/mqtt_username: .*/mqtt_username: $MQTT_USERNAME/" "$SETTINGS_FILE"
    sed -i "s/mqtt_password: .*/mqtt_password: $MQTT_PASSWORD/" "$SETTINGS_FILE"
    sed -i "s/mqtt_force_unsecure: .*/mqtt_force_unsecure: $MQTT_FORCE_UNSECURE/" "$SETTINGS_FILE"
    sed -i "s/gateway_id: .*/gateway_id: $GATEWAY_ID/" "$SETTINGS_FILE"

    sleep 10s

    systemctl restart polarisTransport.service

    echo "MQTT settings updated successfully"
    systemctl status polarisTransport.service >> /var/log/Transport1.log
fi
