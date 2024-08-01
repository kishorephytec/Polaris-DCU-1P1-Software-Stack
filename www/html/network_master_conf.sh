#!/bin/bash

# Directory and file name for the JSON file
JSON_DIR="/etc/json_conf/"
JSON_FILE="gw_conf_local.json"

# Function to process the JSON file

process_json_file() {
    echo "Started"
    jq -c '.[]' "$JSON_DIR$JSON_FILE" |
    while read OBJECT; do
        if echo "$OBJECT" | jq -e 'has("sink-service-1-name")' > /dev/null; then
            ./sink_service1.sh
            echo "Sink Service 1 Done!"
        fi
        if echo "$OBJECT" | jq -e 'has("sink-service-2-name")' > /dev/null; then
            ./sink_service2.sh
            echo "Sink Service 2 Done!"
        fi
    done
 
    # Read the JSON file and extract the channel_name for each object in the array
    jq -r '.[] | select(.channel_name != null) | .channel_name' "$JSON_DIR$JSON_FILE" |
    while read CHANNEL_NAME; do
        # Remove surrounding quotes from the channel_name
        CHANNEL_NAME=$(echo $CHANNEL_NAME | sed 's/"//g')
        echo "Channel name from JSON: $CHANNEL_NAME"
 
        # Trigger the respective service based on the channel_name
        case $CHANNEL_NAME in
            "Wifi_Channel")
                ./network_wifi_conf.sh | while IFS= read -r line; do printf '%s %s\n' "$(date)" "$line"; done >> /var/log/wifi.log
                echo "WIFI CONFGURATION APPLIED"
                sleep 15s
                ;;
            "4G_Channel")
                ./network_cellular_conf.sh | while IFS= read -r line; do printf '%s %s\n' "$(date)" "$line"; done >> /var/log/cellular.log
                echo "CELLULAR CONFIGURATION APPLIED"
                ;;
            "MQTT_Transport1")
                ./mqtt_transport1.sh | while IFS= read -r line; do printf '%s %s\n' "$(date)" "$line"; done >> /var/log/mqtt_transport1.log
                echo "MQTT TRANSPORT1 APPLIED"
                ;;
            "MQTT_Transport2")
                ./mqtt_transport2.sh | while IFS= read -r line; do printf '%s %s\n' "$(date)" "$line"; done >> /var/log/mqtt_transport2.log
                echo "MQTT TRANSPORT2 APPLIED"
                ;;
          
            *)
                echo "Unknown channel_name: $CHANNEL_NAME"
                exit 1
                ;;
        esac
    done
}



echo "Monitoring $JSON_DIR for file creation..."
# Process existing files
for FILENAME in "$JSON_DIR"/*; do
    if [ -f "$FILENAME" ]; then
        echo "Processing existing JSON file: $FILENAME"
        process_json_file
        echo "Network update is successful"
        # Optionally, you can remove the JSON file after processing
        # rm "$FILENAME"
    fi
done

