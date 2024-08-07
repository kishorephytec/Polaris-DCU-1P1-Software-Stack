#!/bin/bash

# Paths to files
JSON_FILE="/etc/json_conf/gw_conf_local.json"
TEMP_FILE="/var/www/html/mqtt_transport1.tmp"
SETTINGS_FILE="/root/wirepas/polaris-settings.yml"

# Read settings from JSON
DCU_SERIAL_NO=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].dcu_serial_no' "$JSON_FILE")
PREFIX_ID=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].prefix_id' "$JSON_FILE")
CLUSTER_ID=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].cluster_id' "$JSON_FILE")
NETWORK_ID=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].network_id' "$JSON_FILE")
MQTT_HOSTNAME=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].mqtt_hostname' "$JSON_FILE")
MQTT_PORT=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].mqtt_port' "$JSON_FILE")
MQTT_USERNAME=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].mqtt_username' "$JSON_FILE")
MQTT_PASSWORD=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].mqtt_password' "$JSON_FILE")
MQTT_FORCE_UNSECURE=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].mqtt_force_unsecure' "$JSON_FILE")
MQTT_RATE_LIMIT_PPS=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].mqtt_rate_limit_pps' "$JSON_FILE")
BUFFERING_STOP_STACK=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].buffering_stop_stack' "$JSON_FILE")
BUFFERING_MAX_BUFFERED_PACKETS=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].buffering_max_buffered_packets' "$JSON_FILE")
BUFFERING_MAX_DELAY_WITHOUT_PUBLISH=$(jq -r '.[] | select(.channel_name == "polaris-transport-service") | .cfg_params[0].buffering_max_delay_without_publish' "$JSON_FILE")

# Check if temp file exists
if [ -f "$TEMP_FILE" ]; then
    # Read settings from temp file
    TEMP_DCU_SERIAL_NO=$(grep -oP '(?<=dcu_serial_no: ).*' "$TEMP_FILE")
    TEMP_PREFIX_ID=$(grep -oP '(?<=prefix_id: ).*' "$TEMP_FILE")
    TEMP_CLUSTER_ID=$(grep -oP '(?<=cluster_id: ).*' "$TEMP_FILE")
    TEMP_NETWORK_ID=$(grep -oP '(?<=network_id: ).*' "$TEMP_FILE")
    TEMP_MQTT_HOSTNAME=$(grep -oP '(?<=mqtt_hostname: ).*' "$TEMP_FILE")
    TEMP_MQTT_PORT=$(grep -oP '(?<=mqtt_port: ).*' "$TEMP_FILE")
    TEMP_MQTT_USERNAME=$(grep -oP '(?<=mqtt_username: ).*' "$TEMP_FILE")
    TEMP_MQTT_PASSWORD=$(grep -oP '(?<=mqtt_password: ).*' "$TEMP_FILE")
    TEMP_MQTT_FORCE_UNSECURE=$(grep -oP '(?<=mqtt_force_unsecure: ).*' "$TEMP_FILE")
    TEMP_MQTT_RATE_LIMIT_PPS=$(grep -oP '(?<=mqtt_rate_limit_pps: ).*' "$TEMP_FILE")
    TEMP_BUFFERING_STOP_STACK=$(grep -oP '(?<=buffering_stop_stack: ).*' "$TEMP_FILE")
    TEMP_BUFFERING_MAX_BUFFERED_PACKETS=$(grep -oP '(?<=buffering_max_buffered_packets: ).*' "$TEMP_FILE")
    TEMP_BUFFERING_MAX_DELAY_WITHOUT_PUBLISH=$(grep -oP '(?<=buffering_max_delay_without_publish: ).*' "$TEMP_FILE")

    # Compare settings between temp and JSON
    if [ "$DCU_SERIAL_NO" != "$TEMP_DCU_SERIAL_NO" ] || [ "$PREFIX_ID" != "$TEMP_PREFIX_ID" ] || [ "$CLUSTER_ID" != "$TEMP_CLUSTER_ID" ] || [ "$NETWORK_ID" != "$TEMP_NETWORK_ID" ] || [ "$MQTT_HOSTNAME" != "$TEMP_MQTT_HOSTNAME" ] || [ "$MQTT_PORT" != "$TEMP_MQTT_PORT" ] || [ "$MQTT_USERNAME" != "$TEMP_MQTT_USERNAME" ] || [ "$MQTT_PASSWORD" != "$TEMP_MQTT_PASSWORD" ] || [ "$MQTT_FORCE_UNSECURE" != "$TEMP_MQTT_FORCE_UNSECURE" ] || [ "$MQTT_RATE_LIMIT_PPS" != "$TEMP_MQTT_RATE_LIMIT_PPS" ] || [ "$BUFFERING_STOP_STACK" != "$TEMP_BUFFERING_STOP_STACK" ] || [ "$BUFFERING_MAX_BUFFERED_PACKETS" != "$TEMP_BUFFERING_MAX_BUFFERED_PACKETS" ] || [ "$BUFFERING_MAX_DELAY_WITHOUT_PUBLISH" != "$TEMP_BUFFERING_MAX_DELAY_WITHOUT_PUBLISH" ]; then
        # Update temp file
        echo "dcu_serial_no: $DCU_SERIAL_NO" > "$TEMP_FILE"
        echo "prefix_id: $PREFIX_ID" >> "$TEMP_FILE"
        echo "cluster_id: $CLUSTER_ID" >> "$TEMP_FILE"
        echo "network_id: $NETWORK_ID" >> "$TEMP_FILE"
        echo "mqtt_hostname: $MQTT_HOSTNAME" >> "$TEMP_FILE"
        echo "mqtt_port: $MQTT_PORT" >> "$TEMP_FILE"
        echo "mqtt_username: $MQTT_USERNAME" >> "$TEMP_FILE"
        echo "mqtt_password: $MQTT_PASSWORD" >> "$TEMP_FILE"
        echo "mqtt_force_unsecure: $MQTT_FORCE_UNSECURE" >> "$TEMP_FILE"
        echo "mqtt_rate_limit_pps: $MQTT_RATE_LIMIT_PPS" >> "$TEMP_FILE"
        echo "buffering_stop_stack: $BUFFERING_STOP_STACK" >> "$TEMP_FILE"
        echo "buffering_max_buffered_packets: $BUFFERING_MAX_BUFFERED_PACKETS" >> "$TEMP_FILE"
        echo "buffering_max_delay_without_publish: $BUFFERING_MAX_DELAY_WITHOUT_PUBLISH" >> "$TEMP_FILE"

        # Update settings file
        sed -i "s/dcu_serial_no: .*/dcu_serial_no: $DCU_SERIAL_NO/" "$SETTINGS_FILE"
        sed -i "s/prefix_id: .*/prefix_id: $PREFIX_ID/" "$SETTINGS_FILE"
        sed -i "s/cluster_id: .*/cluster_id: $CLUSTER_ID/" "$SETTINGS_FILE"
        sed -i "s/network_id: .*/network_id: $NETWORK_ID/" "$SETTINGS_FILE"
        sed -i "s/mqtt_hostname: .*/mqtt_hostname: $MQTT_HOSTNAME/" "$SETTINGS_FILE"
        sed -i "s/mqtt_port: .*/mqtt_port: $MQTT_PORT/" "$SETTINGS_FILE"
        sed -i "s/mqtt_username: .*/mqtt_username: $MQTT_USERNAME/" "$SETTINGS_FILE"
        sed -i "s/mqtt_password: .*/mqtt_password: $MQTT_PASSWORD/" "$SETTINGS_FILE"
        sed -i "s/mqtt_force_unsecure: .*/mqtt_force_unsecure: $MQTT_FORCE_UNSECURE/" "$SETTINGS_FILE"
        sed -i "s/mqtt_rate_limit_pps: .*/mqtt_rate_limit_pps: $MQTT_RATE_LIMIT_PPS/" "$SETTINGS_FILE"
        sed -i "s/buffering_stop_stack: .*/buffering_stop_stack: $BUFFERING_STOP_STACK/" "$SETTINGS_FILE"
        sed -i "s/buffering_max_buffered_packets: .*/buffering_max_buffered_packets: $BUFFERING_MAX_BUFFERED_PACKETS/" "$SETTINGS_FILE"
        sed -i "s/buffering_max_delay_without_publish: .*/buffering_max_delay_without_publish: $BUFFERING_MAX_DELAY_WITHOUT_PUBLISH/" "$SETTINGS_FILE"

        sleep 10s
        
        systemctl daemon-reload
        systemctl restart polarisTransport.service

        echo "Settings updated successfully"
        systemctl status polarisTransport.service >> /var/log/Transport1.log
    else
        echo "Settings are the same. No changes required."
        exit 0
    fi
else
    # Update temp file
    echo "dcu_serial_no: $DCU_SERIAL_NO" > "$TEMP_FILE"
    echo "prefix_id: $PREFIX_ID" >> "$TEMP_FILE"
    echo "cluster_id: $CLUSTER_ID" >> "$TEMP_FILE"
    echo "network_id: $NETWORK_ID" >> "$TEMP_FILE"
    echo "mqtt_hostname: $MQTT_HOSTNAME" >> "$TEMP_FILE"
    echo "mqtt_port: $MQTT_PORT" >> "$TEMP_FILE"
    echo "mqtt_username: $MQTT_USERNAME" >> "$TEMP_FILE"
    echo "mqtt_password: $MQTT_PASSWORD" >> "$TEMP_FILE"
    echo "mqtt_force_unsecure: $MQTT_FORCE_UNSECURE" >> "$TEMP_FILE"
    echo "mqtt_rate_limit_pps: $MQTT_RATE_LIMIT_PPS" >> "$TEMP_FILE"
    echo "buffering_stop_stack: $BUFFERING_STOP_STACK" >> "$TEMP_FILE"
    echo "buffering_max_buffered_packets: $BUFFERING_MAX_BUFFERED_PACKETS" >> "$TEMP_FILE"
    echo "buffering_max_delay_without_publish: $BUFFERING_MAX_DELAY_WITHOUT_PUBLISH" >> "$TEMP_FILE"

    # Update settings file
    sed -i "s/dcu_serial_no: .*/dcu_serial_no: $DCU_SERIAL_NO/" "$SETTINGS_FILE"
    sed -i "s/prefix_id: .*/prefix_id: $PREFIX_ID/" "$SETTINGS_FILE"
    sed -i "s/cluster_id: .*/cluster_id: $CLUSTER_ID/" "$SETTINGS_FILE"
    sed -i "s/network_id: .*/network_id: $NETWORK_ID/" "$SETTINGS_FILE"
    sed -i "s/mqtt_hostname: .*/mqtt_hostname: $MQTT_HOSTNAME/" "$SETTINGS_FILE"
    sed -i "s/mqtt_port: .*/mqtt_port: $MQTT_PORT/" "$SETTINGS_FILE"
    sed -i "s/mqtt_username: .*/mqtt_username: $MQTT_USERNAME/" "$SETTINGS_FILE"
    sed -i "s/mqtt_password: .*/mqtt_password: $MQTT_PASSWORD/" "$SETTINGS_FILE"
    sed -i "s/mqtt_force_unsecure: .*/mqtt_force_unsecure: $MQTT_FORCE_UNSECURE/" "$SETTINGS_FILE"
    sed -i "s/mqtt_rate_limit_pps: .*/mqtt_rate_limit_pps: $MQTT_RATE_LIMIT_PPS/" "$SETTINGS_FILE"
    sed -i "s/buffering_stop_stack: .*/buffering_stop_stack: $BUFFERING_STOP_STACK/" "$SETTINGS_FILE"
    sed -i "s/buffering_max_buffered_packets: .*/buffering_max_buffered_packets: $BUFFERING_MAX_BUFFERED_PACKETS/" "$SETTINGS_FILE"
    sed -i "s/buffering_max_delay_without_publish: .*/buffering_max_delay_without_publish: $BUFFERING_MAX_DELAY_WITHOUT_PUBLISH/" "$SETTINGS_FILE"

    sleep 10s
    
    systemctl daemon-reload
    systemctl restart polarisTransport.service

    echo "Settings updated successfully"
    systemctl status polarisTransport.service >> /var/log/Transport1.log
fi
