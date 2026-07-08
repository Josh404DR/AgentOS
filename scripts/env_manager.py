import os
import sys

def set_key(key, value):
    lines = []
    if os.path.exists('.env'):
        with open('.env', 'r') as f:
            lines = f.readlines()

    with open('.env', 'w') as f:
        key_found = False
        for line in lines:
            if line.strip().startswith(key + '='):
                f.write(f'{key}="{value}"\n')
                key_found = True
            else:
                f.write(line)
        if not key_found:
            f.write(f'{key}="{value}"\n')
    print(f"Set {key} in .env")

def get_key(key):
    if not os.path.exists('.env'):
        print(f"Error: .env file not found.")
        return
    with open('.env', 'r') as f:
        for line in f.readlines():
            if line.strip().startswith(key + '='):
                print(line.strip().split('=', 1)[1].strip('"'))
                return
    print(f"Error: {key} not found in .env")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python env_manager.py <get|set> <KEY> [VALUE]")
        sys.exit(1)
        
    action = sys.argv[1]
    key = sys.argv[2]

    if action == 'set':
        if len(sys.argv) < 4:
            print("Usage: python env_manager.py set <KEY> <VALUE>")
            sys.exit(1)
        value = sys.argv[3]
        set_key(key, value)
    elif action == 'get':
        get_key(key)
    else:
        print(f"Unknown action: {action}")
        sys.exit(1)
