import requests
import json

# API endpoint for retrieving expiring items
retrieve_expirations_url = "http://127.0.0.1:8080/retrieve_expirations"

# Test data
test_params = {
    "user_id": "testuser123"
}

try:
    # Make GET request to retrieve_expirations endpoint
    response = requests.get(retrieve_expirations_url, params=test_params)

    print("Status code:", response.status_code)

    if response.status_code == 200:
        result = response.json()
        print("\n=== RETRIEVE EXPIRATIONS API RESPONSE ===")
        print(json.dumps(result, indent=2))
    else:
        print("Error:", response.status_code)
        print("Response text:", response.text)

except Exception as e:
    print(f"Exception occurred: {e}") 