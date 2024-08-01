import yaml
import subprocess
import time
import json
import paho.mqtt.client as mqtt
import threading
 
CLIENTID = "mqtt_client_4"
PUB_TOPIC = "dcu_diagnostics-4"
SUB_TOPIC = "get_dcu_diagnostic_bundle-4"
QOS = 1
CONFIG_FILE = "/root/wirepas/polaris-settings.yml"
INTERVAL_FILE = "/etc/json_conf/gw_conf_local.json"
 
SYSTEM_LOG_PATH = "/var/log/system_performance.txt"
SIM_LOG_PATH = "/var/log/sim_status.txt"
BATTERY_LOG_PATH = "/var/log/battery-info.txt"
SINK_LOG_PATH = "/var/log/sink-service1.txt"
 
def read_yaml_config(filename, key):
    with open(filename, 'r') as stream:
        config = yaml.safe_load(stream)
        return config[key]
 
def read_json_interval(filename):
    with open(filename, 'r') as f:
        config = json.load(f)
        for entry in config:
            if "dcu_mqtt_interval" in entry:
                return entry["dcu_mqtt_interval"]
    return 15  # Default value if not found
 
def parse_application_info(log_path):
    result = subprocess.run(['grep', 'Modem Version:', log_path], capture_output=True, text=True)
    line = result.stdout.strip()
    if line:
        modem_version = line.split('Modem Version: ')[1].strip()
        return {"MODEM_VERSION": modem_version}
    return {}
 
def parse_sim_status(log_path):
    result = subprocess.run(['grep', '-E', 'Timestamp:|Serial Number:|RSSI:|BER:|Network :|SIM status:', log_path], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    sim_info = {}
    for line in lines:
        if line.startswith('Timestamp:'):
            sim_info['timestamp'] = line.split(': ')[1]
        elif line.startswith('Serial Number:'):
            sim_info['Serial'] = line.split(': ')[1]
        elif line.startswith('RSSI:') and 'BER:' in line:
            rssi = line.split(', ')[0].split(': ')[1]
            ber = line.split(', ')[1].split(': ')[1]
            sim_info['RSSI'] = rssi
            sim_info['BER'] = ber
        elif line.startswith('Network :'):
            sim_info['APN/Make'] = line.split(': ')[1]
        elif line.startswith('SIM status:'):
            working = 'Y' if line.split(': ')[1] == 'Working' else 'N'
            sim_info['working'] = working
    return sim_info
 
def parse_system_info(log_path):
    result = subprocess.run(['grep', '-E', 'Timestamp|Average RAM Usage over 2 minutes|Maximum RAM Usage over 2 minutes|Average CPU Usage over 2 minutes|Maximum CPU Usage over 2 minutes|Average ROM Usage over 2 minutes|Maximum ROM Usage over 2 minutes', log_path], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    info = {line.split(': ')[0].replace(' ', '_'): line.split(': ')[1] for line in lines}
    for key in ['RAM_Usage', 'ROM_Usage']:
        if key in info:
            info[key] = f"{float(info[key]) * 1000}MB"
    return info
 
def parse_sink_version(log_path):
    result = subprocess.run(['grep', 'Config:Stack version is:', log_path], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    if lines:
        # Taking the last occurrence of the sink version in the log
        sink_version_line = lines[-1]
        sink_version = sink_version_line.split('Config:Stack version is: ')[1].strip()
        return {"SINK_VERSION": sink_version}
    return {}
 
def parse_battery_info(log_path):
    result = subprocess.run(['grep', '-E', 'Battery_voltage|Battery_charged_percentage|Last_battery_charged_TS|Last_on_Battery_TS|Supply_mode|Supply_switch_count|Power_on_duration_from_Last_supply_switch|Last_Power_on_Mains|Last_Power_on_Battery|Cum_Power_On_duration_Mains|Cum_Power_On_duration_Battery', log_path], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    info = {line.split(': ')[0].replace(' ', '_'): line.split(': ')[1] for line in lines}
    battery_info = {
        "Battery_voltage": info.get("Battery_voltage", ""),
        "Battery_charged_percentage": info.get("Battery_charged_percentage", ""),
        "Last_battery_charged_TS": info.get("Last_battery_charged_TS", ""),
        "Last_on_Battery_TS": info.get("Last_on_Battery_TS", "")
    }
    supply_info = {
        "Supply_mode": info.get("Supply_mode", ""),
        "Supply_switch_count": info.get("Supply_switch_count", ""),
        "Power_on_duration_from_Last_supply_switch": info.get("Power_on_duration_from_Last_supply_switch", ""),
        "Last_Power_on_Mains": info.get("Last_Power_on_Mains", ""),
        "Last_Power_on_Battery": info.get("Last_Power_on_Battery", ""),
        "Cum_Power_On_duration_Mains": info.get("Cum_Power_On_duration_Mains", ""),
        "Cum_Power_On_duration_Battery": info.get("Cum_Power_On_duration_Battery", "")
    }
    return battery_info, supply_info
 
def create_json_payload():
    system_info = parse_system_info(SYSTEM_LOG_PATH)
    sim_info = parse_sim_status(SIM_LOG_PATH)
    app_info = {}
    battery_info, supply_info = parse_battery_info(BATTERY_LOG_PATH)
    modem_version_info = parse_application_info(SIM_LOG_PATH)
    if 'MODEM_VERSION' in modem_version_info:
        app_info['MODEM_VERSION'] = modem_version_info['MODEM_VERSION']
    sink_version = parse_sink_version(SINK_LOG_PATH)
    if 'SINK_VERSION' in sink_version:
        app_info['SINK_VERSION'] = sink_version['SINK_VERSION']
    payload = [{
        "SYSTEM_INFO": system_info,
        "SIM_INFO": sim_info,
        "Battery_info": battery_info,
        "Supply_info": supply_info,
        "Application_version_info": app_info
    }]
    if app_info:
        payload[0]["Application_version_info"] = app_info
    return payload
 
def publish_payload(client):
    payload = create_json_payload()
    json_payload = json.dumps(payload)
    client.publish(PUB_TOPIC, json_payload, qos=QOS)
    print(f"Message published to {PUB_TOPIC}")
    print(f"Waiting for {interval} sec for next publish")
 
def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.subscribe(SUB_TOPIC)
 
def on_message(client, userdata, msg):
    message = msg.payload.decode()
    print(f"Message received: {message}")
    if message == "on-demand-pull-4":
        publish_payload(client)
        print(f"Message published to {PUB_TOPIC} on demand")
 
def periodic_publish(client):
    while True:
        publish_payload(client)
        time.sleep(interval)
 
mqtt_hostname = read_yaml_config(CONFIG_FILE, "mqtt_hostname")
mqtt_port = read_yaml_config(CONFIG_FILE, "mqtt_port")
mqtt_username = read_yaml_config(CONFIG_FILE, "mqtt_username")
mqtt_password = read_yaml_config(CONFIG_FILE, "mqtt_password")
interval = read_json_interval(INTERVAL_FILE)
 
client = mqtt.Client(CLIENTID)
client.on_connect = on_connect
client.on_message = on_message
 
if mqtt_username:
    client.username_pw_set(mqtt_username, mqtt_password)
 
client.connect(mqtt_hostname, mqtt_port, 60)
 
client.loop_start()
 
publish_thread = threading.Thread(target=periodic_publish, args=(client,))
publish_thread.daemon = True
publish_thread.start()
 
while True:
    time.sleep(1)
