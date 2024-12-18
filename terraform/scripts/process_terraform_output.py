#!/usr/bin/env python3

import sys
import json

def process_terraform_output(input_str):
    data = json.loads(input_str)
    services = data["services_details"]["value"]
    
    for service_name, details in services.items():
        service_env_name = service_name.upper().replace('-', '_')
        
        if details.get('private_ip'):
            print(f"export PETCLINIC_{service_env_name}_IP='{details['private_ip']}'")
        
        if details.get('public_ip') and details['public_ip'] is not None:
            print(f"export PETCLINIC_{service_env_name}_PUBLIC_IP='{details['public_ip']}'")
        
        if details.get('port'):
            print(f"export PETCLINIC_{service_env_name}_PORT='{details['port']}'")

def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            input_str = f.read()
    else:
        input_str = sys.stdin.read()

    print("# Run these commands to set the environment variables:")
    process_terraform_output(input_str)
    print("\n# Or source this file directly")

if __name__ == "__main__":
    main()
