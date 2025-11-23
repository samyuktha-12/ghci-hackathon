import requests
import json

# API endpoint for budget insights
budget_insights_url = "http://127.0.0.1:8080/budget_insights"

# Test data for monthly insights
test_params_monthly = {
    "user_id": "AmOpM7c76zOdaxwP22tkGa0jRvD2",
    "period": "monthly"
}

try:
    # Make GET request to budget_insights endpoint (monthly)
    response = requests.get(budget_insights_url, params=test_params_monthly)

    print("Status code:", response.status_code)

    if response.status_code == 200:
        result = response.json()
        print("\n=== BUDGET INSIGHTS API RESPONSE (MONTHLY) ===")
        print(json.dumps(result, indent=2))
    else:
        print("Error:", response.status_code)
        print("Response text:", response.text)

except Exception as e:
    print(f"Exception occurred: {e}")

# Test weekly insights
print("\n" + "="*60)
print("TESTING WEEKLY BUDGET INSIGHTS")
print("="*60)

test_params_weekly = {
    "user_id": "AmOpM7c76zOdaxwP22tkGa0jRvD2",
    "period": "weekly"
}

try:
    # Make GET request to budget_insights endpoint (weekly)
    response = requests.get(budget_insights_url, params=test_params_weekly)

    print("Status code:", response.status_code)

    if response.status_code == 200:
        result = response.json()
        print("\n=== BUDGET INSIGHTS API RESPONSE (WEEKLY) ===")
        print(json.dumps(result, indent=2))
    else:
        print("Error:", response.status_code)
        print("Response text:", response.text)

except Exception as e:
    print(f"Exception occurred: {e}") 