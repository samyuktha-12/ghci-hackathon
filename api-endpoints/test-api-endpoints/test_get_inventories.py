import requests
import json

# API endpoint for getting inventories
get_inventories_url = "http://127.0.0.1:8080/get_inventories"

for order in ["desc", "asc"]:
    print(f"\n=== Testing /get_inventories?order={order}&user_id=testuser123 ===")
    try:
        response = requests.get(get_inventories_url, params={"order": order, "user_id": "testuser123"})
        print("Status code:", response.status_code)
        if response.status_code == 200:
            inventories_result = response.json()
            print(json.dumps(inventories_result, indent=2))
        else:
            print("Error:", response.status_code)
            print("Response text:", response.text)
    except Exception as e:
        print(f"Exception occurred: {e}") 