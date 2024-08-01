#!/bin/bash
ifconfig enxf04bb3b9ebe5 up
 
# Start microcom with specified settings
microcom -s 115200 -p /dev/ttyUSB2 &
 
sleep 2
 
echo "AT+CGDCONT=2,"IP","airtelgprs.com"" > /dev/ttyUSB2
 
#sleep 2
 
#echo "AT+CGDCONT=2,"IP","airtelgprs.com"" > /dev/ttyUSB2
 
sleep 1
echo "AT+NETSHAREACT=2,1,0" > /dev/ttyUSB2
 
sleep 1
echo -e "\x1c" > /dev/ttyUSB2
 
sleep 1
 
echo -e "\x03" > /dev/ttyUSB2
 
udhcpc -i enxf04bb3b9ebe5

tail -f /dev/null
