import os
import time
import subprocess
import configparser
import logging
import sys
import argparse

# Standardize log file path
LOG_DIR = r"E:/AgentOS/scripts/fan_control"
LOG_FILE = os.path.join(LOG_DIR, 'fan_control.log')

# Ensure directory exists
if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR, exist_ok=True)

# --- Logging Setup ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
    ]
)

try:
    import psutil
    import pyautogui
except ImportError:
    # Standardize output for dependency failure
    print("STATUS=ERROR")
    print("MESSAGE=Dependencies not installed. Please run 'pip install -r requirements.txt'")
    logging.error("Dependencies not installed.")
    sys.exit(1)

# --- Configuration Loading ---
config = configparser.ConfigParser()
config_path = os.path.join(os.path.dirname(__file__), 'config.ini')
if not os.path.exists(config_path):
    logging.error(f"config.ini not found at {config_path}")
    print("STATUS=ERROR")
    print(f"MESSAGE=config.ini not found at {config_path}")
    sys.exit(1)
config.read(config_path)

settings = config['Settings']
TEMPERATURE_THRESHOLD = settings.getint('TEMPERATURE_THRESHOLD', 80)
PREDATOR_APP_ID = settings.get('PREDATOR_APP_ID', '')
COORDS_RAW = settings.get('MAX_FAN_BUTTON_COORDS', '0,0')
MAX_FAN_BUTTON_COORDS = tuple(map(int, COORDS_RAW.split(',')))
WAIT_FOR_APP_START = settings.getint('WAIT_FOR_APP_START', 12)

def get_cpu_temperature():
    try:
        # psutil might not support temperatures on all Windows systems without specific drivers
        # but we follow the existing logic.
        temps = psutil.sensors_temperatures()
        if not temps:
            return None
        for name, entries in temps.items():
            if "coretemp" in name.lower() or "cpu" in name.lower():
                return entries[0].current
        logging.warning("Could not find a recognized CPU temperature sensor.")
    except Exception as e:
        logging.error(f"Error reading temperature: {e}")
    return None

def open_predator_uwp_app():
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
    logging.info(f"Moving mouse to fan button at {MAX_FAN_BUTTON_COORDS} and clicking.")
    try:
        # Move mouse to button
        pyautogui.moveTo(MAX_FAN_BUTTON_COORDS[0], MAX_FAN_BUTTON_COORDS[1], duration=0.7)
        pyautogui.click()
        logging.info("Fan button clicked.")
        time.sleep(1)
        # Move back to a safe spot
        pyautogui.moveTo(1, 1, duration=0.5)
        return True
    except Exception as e:
        logging.error(f"Error during GUI automation: {e}")
        return False

def action_status():
    current_temp = get_cpu_temperature()
    if current_temp is None:
        print("STATUS=ERROR")
        print("MESSAGE=Could not determine CPU temperature.")
        logging.error("Could not determine CPU temperature.")
        return

    # Fix mojibake: Ensure we use 'C' instead of any special characters
    print(f"TEMPERATURE={current_temp}C")
    print(f"THRESHOLD={TEMPERATURE_THRESHOLD}C")
    
    if current_temp > TEMPERATURE_THRESHOLD:
        print("FAN_STATE=CRITICAL")
    else:
        print("FAN_STATE=NORMAL")
    
    print("STATUS=SUCCESS")
    logging.info(f"Status check: Temp={current_temp}C, State={'CRITICAL' if current_temp > TEMPERATURE_THRESHOLD else 'NORMAL'}")

def action_enable_max():
    logging.info("Action: enable_max requested.")
    
    # Requirement: skip clicks if temp UNKNOWN
    current_temp = get_cpu_temperature()
    if current_temp is None:
        print("STATUS=ERROR")
        print("MESSAGE=Action aborted: Could not determine CPU temperature.")
        logging.error("Action enable_max aborted: CPU temperature unknown.")
        return

    if open_predator_uwp_app():
        if activate_max_fans():
            print("STATUS=SUCCESS")
            print("MESSAGE=Max fans enabled via GUI.")
            logging.info("Max fans enabled.")
        else:
            print("STATUS=ERROR")
            print("MESSAGE=Failed to click max fan button.")
            logging.error("Failed to click max fan button.")
    else:
        print("STATUS=ERROR")
        print("MESSAGE=Failed to open PredatorSense app.")
        logging.error("Failed to open PredatorSense app.")

def main():
    parser = argparse.ArgumentParser(description="Predator Fan Control CLI")
    parser.add_argument("--action", choices=["status", "enable_max"], help="Action to perform")
    
    args = parser.parse_args()

    if not args.action:
        parser.print_help()
        sys.exit(0)

    if args.action == "status":
        action_status()
    elif args.action == "enable_max":
        action_enable_max()

if __name__ == "__main__":
    main()
