import subprocess
import json
from datetime import datetime
import time

# Output JSON file
output_file = "crash_event_log.json"

# List of specific services to monitor
services = [
    "DC-detection-gpio.service",
    "RBSink1.service",
    "RBSink2.service",
    "battery-info.service",
    "cellular.service",
    "rauc.service",
    "sim_info.service",
    "gateway_network_config.service",
    "system_resource.service",
    "internet_connectivity.service",
    "dcu-diagnostics-publish.service",
    "wirepasTransport.service",
    "polarisTransport.service",
    "rauc-hawkbit-updater.service",
    "rauc-hawkbit.service",
    "rauc-mark-good.service",
    "wifi.service"
]

# Function to fetch service status for a specific service
def fetch_service_status(service):
    result = subprocess.run(
        ["systemctl", "status", service],
        stdout=subprocess.PIPE,
        text=True
    )
    return result.stdout

# Main loop to run every 5 minutes
while True:
    # Initialize an empty list to store crash event logs
    crash_event_logs = []

    # Iterate through each specified service
    for service in services:
        event_found = False
        try:
            status_output = fetch_service_status(service)
            if status_output:
                for line in status_output.splitlines():
                    if "failed" in line.lower():
                        event = {
                            "Service": service,
                            "event_TS": datetime.now().isoformat(),  # Using current time as we don't have exact log timestamp
                            "Reason_code": line.strip()
                        }
                        crash_event_logs.append(event)
                        event_found = True
                        print(f"Found failed event for {service}")
                        break
            else:
                print(f"No status output found for {service}")
        except subprocess.CalledProcessError as e:
            print(f"Error fetching status for {service}: {e}")

    # Write the collected crash event logs to the output file
    try:
        with open(output_file, "w") as f:
            json.dump(crash_event_logs, f, indent=4)
        print(f"Crash event log collected in {output_file}")
    except IOError as e:
        print(f"Error writing to {output_file}: {e}")

    # Wait for 3 minutes before the next iteration
    time.sleep(3)
