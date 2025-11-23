import requests
import json

# API endpoint for getting categories
get_categories_url = "http://127.0.0.1:8080/get_categories"

try:
    # Make GET request to get_categories endpoint
    response = requests.get(get_categories_url)
    
    print("Status code:", response.status_code)
    
    if response.status_code == 200:
        categories_result = response.json()
        print("\n=== CATEGORIES API RESPONSE ===")
        print(json.dumps(categories_result, indent=2))
    else:
        print("Error:", response.status_code)
        print("Response text:", response.text)
        
except Exception as e:
    print(f"Exception occurred: {e}")