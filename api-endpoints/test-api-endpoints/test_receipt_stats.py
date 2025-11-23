import requests
import json

# API endpoint for receipt stats
receipt_stats_url = "http://127.0.0.1:8080/receipt_stats"

# Test data for different users
test_users = [
    "testuser123",
    "user456",
    "demo_user"
]

def test_receipt_stats(user_id):
    """Test the receipt_stats endpoint for a specific user"""
    print(f"\n{'='*60}")
    print(f"TESTING RECEIPT STATS FOR USER: {user_id}")
    print(f"{'='*60}")
    
    test_params = {
        "user_id": user_id
    }
    
    try:
        # Make GET request to receipt_stats endpoint
        response = requests.get(receipt_stats_url, params=test_params)
        
        print("Status code:", response.status_code)
        
        if response.status_code == 200:
            result = response.json()
            print("\n=== RECEIPT STATS API RESPONSE ===")
            print(json.dumps(result, indent=2))
            
            # Validate response structure
            if "user_id" in result and "total_receipts" in result and "category_breakdown" in result:
                print("\n✅ Response structure is valid")
                
                # Print summary
                total = result["total_receipts"]
                breakdown = result["category_breakdown"]
                print(f"\n📊 SUMMARY:")
                print(f"   Total receipts: {total}")
                print(f"   Categories with receipts:")
                for category, count in breakdown.items():
                    if count > 0:
                        print(f"     - {category}: {count}")
            else:
                print("\n❌ Response structure is invalid")
                
        else:
            print("Error:", response.status_code)
            print("Response text:", response.text)
            
    except Exception as e:
        print(f"Exception occurred: {e}")

def test_receipt_stats_without_user_id():
    """Test the receipt_stats endpoint without providing user_id (should fail)"""
    print(f"\n{'='*60}")
    print("TESTING RECEIPT STATS WITHOUT USER_ID (SHOULD FAIL)")
    print(f"{'='*60}")
    
    try:
        # Make GET request to receipt_stats endpoint without user_id
        response = requests.get(receipt_stats_url)
        
        print("Status code:", response.status_code)
        
        if response.status_code == 422:  # Validation error
            print("✅ Correctly returned validation error (422)")
            print("Response text:", response.text)
        else:
            print("❌ Expected validation error but got:", response.status_code)
            print("Response text:", response.text)
            
    except Exception as e:
        print(f"Exception occurred: {e}")

# Run tests
if __name__ == "__main__":
    print("🧪 TESTING RECEIPT STATS ENDPOINT")
    print("Make sure the server is running on http://127.0.0.1:8080")
    
    # Test with different users
    for user_id in test_users:
        test_receipt_stats(user_id)
    
    # Test error case (missing user_id)
    test_receipt_stats_without_user_id()
    
    print(f"\n{'='*60}")
    print("🎉 ALL TESTS COMPLETED")
    print(f"{'='*60}") 