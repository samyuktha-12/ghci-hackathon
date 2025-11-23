import requests
import json

# API endpoint for generating chart data
generate_chart_url = "http://127.0.0.1:8080/generate_chart"

try:
    # Make GET request to generate_chart endpoint with user_id
    response = requests.get(generate_chart_url, params={"user_id": "testuser123"})
    
    print("Status code:", response.status_code)
    
    if response.status_code == 200:
        chart_result = response.json()
        print("\n=== CHART DATA API RESPONSE (for testuser123) ===")
        print(json.dumps(chart_result, indent=2))
    else:
        print("Error:", response.status_code)
        print("Response text:", response.text)
        
except Exception as e:
    print(f"Exception occurred: {e}") 