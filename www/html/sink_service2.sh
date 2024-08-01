#!/bin/bash
# Paths to files
JSON_FILE="/etc/json_conf/gw_conf_local.json"
TEMP_FILE="/var/www/html/sink_service2.tmp"
SERVICE_FILE="/etc/systemd/system/RBSink2.service"
# Read the values from the JSON
SINK_NAME=$(jq -r '.[0]["sink-service-2-name"]["WM_GW_SINK_ID"]' "$JSON_FILE")
NODE_ADDRESS=$(jq -r '.[0]["sink-service-2-name"]["WM_CN_NODE_ADDRESS"]' "$JSON_FILE")
NODE_ROLE=$(jq -r '.[0]["sink-service-2-name"]["WM_CN_NODE_ROLE"]' "$JSON_FILE")
NETWORK_ADDRESS=$(jq -r '.[0]["sink-service-2-name"]["WM_CN_NETWORK_ADDRESS"]' "$JSON_FILE")
NETWORK_CHANNEL=$(jq -r '.[0]["sink-service-2-name"]["WM_CN_NETWORK_CHANNEL"]' "$JSON_FILE")
START=$(jq -r '.[0]["sink-service-2-name"]["WM_CN_START_SINK"]' "$JSON_FILE")
echo "done reading from the json file"
# Check if temp file exists
if [ -f "$TEMP_FILE" ]; then
    # Read values from temp file
    TEMP_SINK_NAME=$(grep -oP '(?<=SINK_NAME=).*' "$TEMP_FILE")
    TEMP_NODE_ADDRESS=$(grep -oP '(?<=NODE_ADDRESS=).*' "$TEMP_FILE")
    TEMP_NODE_ROLE=$(grep -oP '(?<=NODE_ROLE=).*' "$TEMP_FILE")
    TEMP_NETWORK_ADDRESS=$(grep -oP '(?<=NETWORK_ADDRESS=).*' "$TEMP_FILE")
    TEMP_NETWORK_CHANNEL=$(grep -oP '(?<=NETWORK_CHANNEL=).*' "$TEMP_FILE")
    TEMP_START=$(grep -oP '(?<=START=).*' "$TEMP_FILE")
    # Compare values
    if [ "$SINK_NAME" != "$TEMP_SINK_NAME" ] || [ "$NODE_ADDRESS" != "$TEMP_NODE_ADDRESS" ] || [ "$NODE_ROLE" != "$TEMP_NODE_ROLE" ] || [ "$NETWORK_ADDRESS" != "$TEMP_NETWORK_ADDRESS" ] || [ "$NETWORK_CH
ANNEL" != "$TEMP_NETWORK_CHANNEL" ] || [ "$START" != "$TEMP_START" ]; then
        # Update temp file
        echo "SINK_NAME=$SINK_NAME" > "$TEMP_FILE"
        echo "NODE_ADDRESS=$NODE_ADDRESS" >> "$TEMP_FILE"
        echo "NODE_ROLE=$NODE_ROLE" >> "$TEMP_FILE"
        echo "NETWORK_ADDRESS=$NETWORK_ADDRESS" >> "$TEMP_FILE"
        echo "NETWORK_CHANNEL=$NETWORK_CHANNEL" >> "$TEMP_FILE"
        echo "START=$START" >> "$TEMP_FILE"
        # Extract the number from the sink ID
        SINK_ID=$(echo "$SINK_NAME" | sed 's/sink//')
        # Update service file
        sed -i "s|ExecStart=/root/gateway/sink_service/build/sinkService -b 125000 -p /dev/ttymxc1 -i .*|ExecStart=/root/gateway/sink_service/build/sinkService -b 125000 -p /dev/ttymxc1 -i $SINK_ID|" "$SERVICE_FILE"
        # Restart service
        systemctl daemon-reload
        systemctl restart RBSink2.service
        echo "Done restarting the service"
        # Run wm-node-conf set command
        wm-node-conf set -n "$NODE_ADDRESS" -r "$NODE_ROLE" -N "$NETWORK_ADDRESS" -c "$NETWORK_CHANNEL" -s "$SINK_NAME" -S "$START"
        echo "Executed the command"
        echo $(date) >> /var/log/Sink2.log
        wm-node-conf list >> /var/log/Sink2.log
    else
        echo "Parameters are the same, no update needed"
        exit 0
    fi
else
    # Update temp file
    echo "SINK_NAME=$SINK_NAME" > "$TEMP_FILE"
    echo "NODE_ADDRESS=$NODE_ADDRESS" >> "$TEMP_FILE"
    echo "NODE_ROLE=$NODE_ROLE" >> "$TEMP_FILE"
    echo "NETWORK_ADDRESS=$NETWORK_ADDRESS" >> "$TEMP_FILE"
    echo "NETWORK_CHANNEL=$NETWORK_CHANNEL" >> "$TEMP_FILE"
    echo "START=$START" >> "$TEMP_FILE"
    # Extract the number from the sink ID
    SINK_ID=$(echo "$SINK_NAME" | sed 's/sink//')
    # Update service file
    sed -i "s|ExecStart=/root/gateway/sink_service/build/sinkService -b 125000 -p /dev/ttymxc1 -i .*|ExecStart=/root/gateway/sink_service/build/sinkService -b 125000 -p /dev/ttymxc1 -i $SINK_ID|" "$SERVICE_FILE"
 
    # Restart service
    systemctl daemon-reload
    systemctl restart RBSink2.service
    echo "Done restarting the service"
    # Run wm-node-conf set command
    wm-node-conf set -n "$NODE_ADDRESS" -r "$NODE_ROLE" -N "$NETWORK_ADDRESS" -c "$NETWORK_CHANNEL" -s "$SINK_NAME" -S "$START"
    echo "Executed the command"
    echo $(date) >> /var/log/Sink2.log
    wm-node-conf list >> /var/log/Sink2.log
fi
