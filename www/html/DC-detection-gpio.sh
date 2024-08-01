#!/bin/bash
 
GPIO_PIN=133
 
# Check if GPIO pin is already exported
if [ ! -d /sys/class/gpio/gpio${GPIO_PIN} ]; then
    echo ${GPIO_PIN} > /sys/class/gpio/export
fi
 
# Set direction
echo in > /sys/class/gpio/gpio${GPIO_PIN}/direction
 
# Keep the script running indefinitely
tail -f /dev/null
