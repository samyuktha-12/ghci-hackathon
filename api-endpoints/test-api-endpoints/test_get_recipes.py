import requests
import json

# API endpoint for getting recipes
get_recipes_url = "http://127.0.0.1:8080/get_recipes"

try:
    # Make GET request to get_recipes endpoint with user_id
    response = requests.get(get_recipes_url, params={"user_id": "testuser123"})
    
    print("Status code:", response.status_code)
    
    if response.status_code == 200:
        recipes_result = response.json()
        print("\n=== GET RECIPES API RESPONSE (for testuser123) ===")
        print(json.dumps(recipes_result, indent=2))
    else:
        print("Error:", response.status_code)
        print("Response text:", response.text)
        
except Exception as e:
    print(f"Exception occurred: {e}") 