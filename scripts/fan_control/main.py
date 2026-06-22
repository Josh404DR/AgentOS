import os
import time
import subprocess
import configparser
import logging
import sys

try:
    import psutil
    import pyautogui
except ImportError:
    # This will be logged, and the script will exit.
    logging.error("Dependencies not installed. Please run 'pip install -r requirements.txt'")
    sys.exit(1)

# --- Logging Setup ---
log_file = os.path.join(os.path.dirname(__file__), 'fan_control.log')
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)

# --- Configuration Loading ---
config = configparser.ConfigParser()
config_path = os.path.join(os.path.dirname(__file__), 'config.ini')
if not os.path.exists(config_path):
    logging.error(f"config.ini not found at {config_path}")
    sys.exit(1)
config.read(config_path)

settings = config['Settings']
TEMPERATURE_THRESHOLD = settings.getint('TEMPERATURE_THRESHOLD', 80)
PREDATOR_APP_ID = settings.get('PREDATOR_APP_ID', '')
COORDS_RAW = settings.get('MAX_FAN_BUTTON_COORDS', '0,0')
MAX_FAN_BUTTON_COORDS = tuple(map(int, COORDS_RAW.split(',')))
WAIT_FOR_APP_START = settings.getint('WAIT_FOR_APP_START', 12)

def get_cpu_temperature():
    # ... (same as v2 draft)
    try:
        temps = psutil.sensors_temperatures()
        for name, entries in temps.items():
            if "coretemp" in name.lower() or "cpu" in name.lower():
                return entries[0].current
        logging.warning("Could not find a recognized CPU temperature sensor.")
    except Exception as e:
        logging.error(f"Error reading temperature: {e}")
    return None

def open_predator_uwp_app():
    # ... (same as v2 draft)
    logging.info(f"Launching UWP App: {PREDATOR_APP_ID}...")
    try:
        command = f'explorer.exe shell:AppsFolder\\{PREDATOR_APP_ID}'
        subprocess.Popen(command, shell=True)
        logging.info(f"Waiting {WAIT_FOR_APP_START} seconds for the app to load...")
        time.sleep(WAIT_FOR_APP_START)
        return True
    except Exception as e:
        logging.error(f"FATAL: Failed to launch UWP app: {e}")
        return False

def activate_max_fans():
    # ... (same as v2 draft)
    logging.info(f"Moving mouse to fan button at {MAX_FAN_BUTTON_COORDS} and clicking.")
    try:
        pyautogui.moveTo(MAX_FAN_BUTTON_COORDS[0], MAX_FAN_BUTTON_COORDS[1], duration=0.7)
        pyautogui.click()
        logging.info("Fan button clicked.")
        time.sleep(1)
        pyautogui.moveTo(1, 1, duration=0.5)
    except Exception as e:
        logging.error(f"Error during GUI automation: {e}")

def main():
    logging.info("--- Predator Fan Control ---")
    current_temp = get_cpu_temperature()

    if current_temp is None:
        logging.error("Could not determine CPU temperature. Aborting.")
        return

    logging.info(f"Current CPU Temperature: {current_temp}°C")

    if current_temp > TEMPERATURE_THRESHOLD:
        logging.warning(f"Alert: Temperature ({current_temp}°C) exceeds threshold ({TEMPERATURE_THRESHOLD}°C).")
        if open_predator_uwp_app():
            activate_max_fans()
    else:
        logging.info("Status: Temperature is within the normal range.")

if __name__ == "__main__":
    main()
