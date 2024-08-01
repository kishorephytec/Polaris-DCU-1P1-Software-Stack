#!/bin/bash
 
# Paths to files
JSON_FILE="/etc/json_conf/gw_conf_local.json"
TEMP_FILE="/var/www/html/network_wifi_conf.tmp"
CONF_FILE="/etc/wpa_supplicant.conf"
STATUS_FILE="/var/log/network_status.log"
 
# Read SSID and password from JSON
JSON_SSID=$(jq -r '.[] | select(.channel_name == "Wifi_Channel") | .cfg_params[] | select(.name == "ssid") | .value' "$JSON_FILE")
JSON_PASS=$(jq -r '.[] | select(.channel_name == "Wifi_Channel") | .cfg_params[] | select(.name == "password") | .value' "$JSON_FILE")
 
# Check if SSID and password are empty
if [ -z "$JSON_SSID" ] || [ -z "$JSON_PASS" ]; then
    echo "Error: SSID or password is empty in the JSON file."
    exit 1
fi
 
# Debugging output
echo "JSON_SSID: $JSON_SSID"
echo "JSON_PASS: $JSON_PASS"
 
# Ensure the temp file exists
if [ ! -f "$TEMP_FILE" ]; then
    echo "Temp file not found. Creating temp file."
    echo "ssid=\"$JSON_SSID\"" > "$TEMP_FILE"
    echo "psk=\"$JSON_PASS\"" >> "$TEMP_FILE"
    NEED_UPDATE=true
else
    # Read SSID and password from temp file
    TEMP_SSID=$(grep -oP '(?<=ssid=").*(?=")' "$TEMP_FILE")
    TEMP_PASS=$(grep -oP '(?<=psk=").*(?=")' "$TEMP_FILE")
 
    # Compare SSID and password between temp and JSON
    if [ "$JSON_SSID" != "$TEMP_SSID" ] || [ "$JSON_PASS" != "$TEMP_PASS" ]; then
        NEED_UPDATE=true
    else
        NEED_UPDATE=false
    fi
fi
 
if [ "$NEED_UPDATE" = true ]; then
    # Update temp file
    echo "Updating temp file and wpa_supplicant.conf."
    echo "ssid=\"$JSON_SSID\"" > "$TEMP_FILE"
    echo "psk=\"$JSON_PASS\"" >> "$TEMP_FILE"
 
    # Update wpa_supplicant.conf with proper indentation
    sed -i -E "/^(\s*ssid\s*=).*/ { s//\1\"$JSON_SSID\"/ }" "$CONF_FILE"
    sed -i -E "/^(\s*psk\s*=).*/ { s//\1\"$JSON_PASS\"/ }" "$CONF_FILE"
 
    # Restart WiFi connection
    sudo rm /var/run/wpa_supplicant/wlx5026efb0f288
 
    wpa_supplicant -B -Dnl80211 -i wlx5026efb0f288 -c "$CONF_FILE"
 
    udhcpc -i wlx5026efb0f288
 
    # Get the IP address
    WIFI_IP=$(ip addr show wlx5026efb0f288 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
 
    # Log the connection status
    echo "$(date -u) WiFi: IP address $WIFI_IP is connected" >> "$STATUS_FILE"
else
    echo "SSID and password are the same. No changes required."
fi
 
exit 0
