import requests
import json

# API endpoint for reading messages
read_message_url = "http://127.0.0.1:8080/read_message"

# Test data
test_data = {
    "message": "You successfully paid 500 rs on Swiggy.",
    "user_id": "testuser123"
}

try:
    # Make POST request to read_message endpoint
    response = requests.post(read_message_url, data=test_data)

    print("Status code:", response.status_code)

    if response.status_code == 200:
        result = response.json()
        print("\n=== READ MESSAGE API RESPONSE ===")
        print(json.dumps(result, indent=2))
    else:
        print("Error:", response.status_code)
        print("Response text:", response.text)

except Exception as e:
    print(f"Exception occurred: {e}") 