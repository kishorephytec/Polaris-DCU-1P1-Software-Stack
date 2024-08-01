#!/bin/bash

# Insert kernel modules
insmod /lib/modules/5.10.76/compat.ko
sleep 2

insmod /lib/modules/5.10.76/cfg80211.ko
sleep 2

insmod /lib/modules/5.10.76/brcmutil.ko
sleep 2

insmod /lib/modules/5.10.76/brcmfmac.ko
sleep 10

# Start wpa_supplicant
wpa_supplicant -B -Dnl80211 -i wlx5026efb0f288 -c /etc/wpa_supplicant.conf
sleep 2

# Obtain IP address
udhcpc -i wlx5026efb0f288

