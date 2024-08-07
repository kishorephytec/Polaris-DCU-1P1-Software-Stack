import yaml
import subprocess
import time
import json
import paho.mqtt.client as mqtt
import uuid

# Constants
#CLIENTID = "mqtt_client_1"
PUB_TOPIC = "dcu_diagnostics"
SUB_TOPIC = "get_diagnostic_bundle"
QOS = 1
CONFIG_FILE = "/root/wirepas/polaris-settings.yml"
INTERVAL_FILE = "/etc/json_conf/gw_conf_local.json"
SYSTEM_LOG_PATH = "/var/log/system_performance.txt"
SIM_LOG_PATH = "/var/log/sim_status.txt"
BATTERY_LOG_PATH = "/var/log/battery-info.txt"
SINK_LOG_PATH = "/var/log/sink-service1.txt"
DCU_SERIAL_NO_PATH = "/root/wirepas/polaris-settings.yml"
CRASH_EVENT_LOG_PATH = "/var/www/html/crash_event_log.json"

# Function to read YAML configuration
def read_yaml_config(filename, key):
    with open(filename, 'r') as stream:
        config = yaml.safe_load(stream)
        return config[key]

# Function to read JSON interval and system config info
def read_json_config(filename):
    with open(filename, 'r') as f:
        config = json.load(f)
        for entry in config:
            if "System_config_info" in entry:
                dcu_mqtt_interval = entry["System_config_info"].get("dcu_mqtt_interval")
                modem_reset_interval = entry["System_config_info"].get("modem_reset_interval")
                
                # Consider empty strings as None
                if dcu_mqtt_interval == "":
                    dcu_mqtt_interval = None
                if modem_reset_interval == "":
                    modem_reset_interval = None
                
                return dcu_mqtt_interval, modem_reset_interval

    # If "System_config_info" is not found, return None for both values
    return None, None

# Function to parse application information
def parse_application_info(log_path):
    result = subprocess.run(['grep', 'Modem Version:', log_path], capture_output=True, text=True)
    line = result.stdout.strip()
    if line:
        modem_version = line.split('Modem Version: ')[1].strip()
        return {"MODEM_VERSION": modem_version}
    return {}

# Function to parse SIM status
def parse_sim_status(log_path):
    result = subprocess.run(['grep', '-E', 'Serial Number:|RSSI:|BER:|Network :|SIM status:', log_path], capture_output=True, text=True)
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

# Function to parse system information
def parse_system_info(log_path):
    result = subprocess.run(['grep', '-E', 'Average RAM Usage over 2 minutes|Maximum RAM Usage over 2 minutes|Average CPU Usage over 2 minutes|Maximum CPU Usage over 2 minutes|Average ROM Usage over 2 minutes|Maximum ROM Usage over 2 minutes', log_path], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    info = {line.split(': ')[0].replace(' ', '_'): line.split(': ')[1] for line in lines}
    for key in ['RAM_Usage', 'ROM_Usage']:
        if key in info:
            info[key] = f"{float(info[key]) * 1000}MB"
    return info

# Function to parse sink version
def parse_sink_version(log_path):
    result = subprocess.run(['grep', 'Config:Stack version is:', log_path], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    if lines:
        sink_version_line = lines[-1]
        sink_version = sink_version_line.split('Config:Stack version is: ')[1].strip()
        return {"SINK_VERSION": sink_version}
    return {}

# Function to parse DCU version
def parse_dcu_version(log_path):
    result = subprocess.run(['grep', 'gateway_version: ', log_path], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    if lines:
        dcu_version_line = lines[-1]
        dcu_version = dcu_version_line.split('gateway_version: ')[1].strip()
        return {"DCU_VERSION": dcu_version}
    return {}

# Function to parse dcu_serial_no ID
def parse_dcu_serial_no(log_path):
    result = subprocess.run(['grep', 'dcu_serial_no: ', log_path], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    if lines:
        dcu_serial_no_line = lines[-1]
        dcu_serial_no = dcu_serial_no_line.split('dcu_serial_no: ')[1].strip()
        return dcu_serial_no
    return {}

# Function to parse battery information
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

# Function to create JSON payload
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
    dcu_version_info = parse_dcu_version(DCU_SERIAL_NO_PATH)
    if 'DCU_VERSION' in dcu_version_info:
        app_info['DCU_VERSION'] = dcu_version_info['DCU_VERSION']
    dcu_serial_no = parse_dcu_serial_no(DCU_SERIAL_NO_PATH)
    
    # Read the system configuration info
    dcu_mqtt_interval, modem_reset_interval = read_json_config(INTERVAL_FILE)

    # Convert intervals from seconds to minutes, and format as "X min" strings
    dcu_diagnostics_interval_str = f"{int(dcu_mqtt_interval) // 60} min" if dcu_mqtt_interval else "0 min"
    modem_reset_interval_str = f"{int(modem_reset_interval) // 60} min" if modem_reset_interval else "0 min"

    # Create the system config info with formatted intervals
    system_config_info = {
        "dcu_diagnostics_interval": dcu_diagnostics_interval_str
    } 
    payload = [{
        "DCU_SERIAL_NO": dcu_serial_no,
        "SYSTEM_INFO": system_info,
        "SIM_INFO": sim_info,
        "Battery_info": battery_info,
        "Supply_info": supply_info,
        "Application_version_info": app_info,
        "System_config_info": system_config_info
    }]
    return payload

# Function to publish payload
def publish_payload(client):
    payload = create_json_payload()
    json_payload = json.dumps(payload)
    client.publish(PUB_TOPIC, json_payload, qos=QOS)
    print(f"Published payload to {PUB_TOPIC}")
    print(f"Waiting for {interval} sec for next publish")

# Function to publish crash event log
def publish_crash_event_log(client):
    try:
        with open(CRASH_EVENT_LOG_PATH, 'r') as f:
            crash_event_log = json.load(f)
        
        # Parse the gateway ID
        dcu_serial_no = parse_dcu_serial_no(DCU_SERIAL_NO_PATH)
        
        # Create a new payload with the dcu_serial_no  at the root level
        new_payload = {
            "DCU_SERIAL_NO": dcu_serial_no,
            "crash_event_log": crash_event_log
        }
        
        json_payload = json.dumps(new_payload)
        client.publish(PUB_TOPIC, json_payload, qos=QOS)
        print(f"Crash event log message published to {PUB_TOPIC}")
    except IOError as e:
        print(f"Error reading {CRASH_EVENT_LOG_PATH}: {e}")
    except Exception as e:
        print(f"Error processing crash event log: {e}")

# MQTT on_message callback
def on_message(client, userdata, msg):
    message = msg.payload.decode()
    print(f"Message received: {message}")
    if message == "get_dcu_diagnostic_bundle":
        publish_payload(client)
        print(f"Diagnostic bundle message published to {PUB_TOPIC} on demand")
    elif message == "get_dcu_events/1":
        publish_crash_event_log(client)
        print(f"Crash event log message published to {PUB_TOPIC} on demand")

def generate_client_id():
    return f"mqtt_client_{uuid.uuid4()}"


def setup_mqtt_client():
    client_id = generate_client_id()  # Use the unique CLIENTID
    client = mqtt.Client(client_id)

    mqtt_hostname = read_yaml_config(CONFIG_FILE, "mqtt_hostname")
    mqtt_port = int(read_yaml_config(CONFIG_FILE, "mqtt_port"))
    mqtt_username = read_yaml_config(CONFIG_FILE, "mqtt_username")
    mqtt_password = read_yaml_config(CONFIG_FILE, "mqtt_password")

    if mqtt_username:
        client.username_pw_set(mqtt_username, mqtt_password)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(mqtt_hostname, mqtt_port, 60)
    return client




# MQTT on_connect callback
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        if not hasattr(on_connect, 'connected'):
            on_connect.connected = True
            print("Connected with result code 0")
        client.subscribe(SUB_TOPIC)
        print(f"Subscribed to {SUB_TOPIC}")
    else:
        print(f"Failed to connect with result code {rc}")

# Main loop
def main():
    global interval
    client = setup_mqtt_client()
    client.loop_start()

    while True:
        # Re-read the interval from the configuration file
        dcu_mqtt_interval, _ = read_json_config(INTERVAL_FILE)
        interval = int(dcu_mqtt_interval) if dcu_mqtt_interval else 300

        publish_payload(client)
        time.sleep(interval)

if __name__ == "__main__":
    main()
