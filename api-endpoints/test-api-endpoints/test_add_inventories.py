import requests
import json

# API endpoint for adding inventories
add_inventories_url = "http://127.0.0.1:8080/add_inventories"

try:
    # Make POST request to add_inventories endpoint with user_id
    data = {"user_id": "testuser123"}
    response = requests.post(add_inventories_url, data=data)
    
    print("Status code:", response.status_code)
    
    if response.status_code == 200:
        inventory_result = response.json()
        print("\n=== ADD INVENTORIES API RESPONSE ===")
        print(json.dumps(inventory_result, indent=2))
    else:
        print("Error:", response.status_code)
        print("Response text:", response.text)
        
except Exception as e:
    print(f"Exception occurred: {e}") 