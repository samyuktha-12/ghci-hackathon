import requests
import json

# API endpoint for listing receipts
list_receipts_url = "http://127.0.0.1:8080/list_receipts"

# Test data
test_user_id = "testuser123"

def test_list_receipts_basic():
    """Test basic receipt listing without filters"""
    print(f"\n{'='*60}")
    print("TESTING BASIC RECEIPT LISTING")
    print(f"{'='*60}")
    
    params = {
        "user_id": test_user_id,
        "limit": 10,
        "offset": 0
    }
    
    try:
        response = requests.get(list_receipts_url, params=params)
        
        print("Status code:", response.status_code)
        
        if response.statusCode == 200:
            result = response.json()
            print("\n=== BASIC RECEIPT LISTING RESPONSE ===")
            print(json.dumps(result, indent=2))
            
            # Validate response structure
            if "user_id" in result and "total_count" in result and "receipts" in result:
                print("\n✅ Response structure is valid")
                print(f"📊 Total receipts: {result['total_count']}")
                print(f"📄 Receipts returned: {len(result['receipts'])}")
                
                # Show first receipt details if available
                if result['receipts']:
                    first_receipt = result['receipts'][0]
                    print(f"\n📋 First receipt details:")
                    print(f"   Receipt ID: {first_receipt.get('receipt_id', 'N/A')}")
                    print(f"   Vendor: {first_receipt.get('vendor', 'N/A')}")
                    print(f"   Amount: ${first_receipt.get('amount', 0.0):.2f}")
                    print(f"   Categories: {', '.join(first_receipt.get('categories', []))}")
                    print(f"   Timestamp: {first_receipt.get('timestamp', 'N/A')}")
            else:
                print("\n❌ Response structure is invalid")
                
        else:
            print("Error:", response.status_code)
            print("Response text:", response.text)
            
    except Exception as e:
        print(f"Exception occurred: {e}")

def test_list_receipts_with_category_filter():
    """Test receipt listing with category filter"""
    print(f"\n{'='*60}")
    print("TESTING RECEIPT LISTING WITH CATEGORY FILTER")
    print(f"{'='*60}")
    
    test_categories = ["groceries", "dining", "utilities"]
    
    for category in test_categories:
        print(f"\n--- Testing category: {category} ---")
        
        params = {
            "user_id": test_user_id,
            "limit": 20,
            "offset": 0,
            "category": category
        }
        
        try:
            response = requests.get(list_receipts_url, params=params)
            
            print("Status code:", response.status_code)
            
            if response.statusCode == 200:
                result = response.json()
                print(f"📊 Total receipts for {category}: {result.get('total_count', 0)}")
                print(f"📄 Receipts returned: {len(result.get('receipts', []))}")
                
                # Verify all receipts have the specified category
                receipts = result.get('receipts', [])
                all_have_category = all(
                    category.lower() in [cat.lower() for cat in receipt.get('categories', [])]
                    for receipt in receipts
                )
                
                if all_have_category:
                    print(f"✅ All receipts have category '{category}'")
                else:
                    print(f"❌ Some receipts don't have category '{category}'")
                    
            else:
                print("Error:", response.status_code)
                print("Response text:", response.text)
                
        except Exception as e:
            print(f"Exception occurred: {e}")

def test_list_receipts_with_sorting():
    """Test receipt listing with different sorting options"""
    print(f"\n{'='*60}")
    print("TESTING RECEIPT LISTING WITH SORTING")
    print(f"{'='*60}")
    
    sort_options = [
        {"sort_by": "timestamp", "sort_order": "desc"},
        {"sort_by": "timestamp", "sort_order": "asc"},
        {"sort_by": "vendor", "sort_order": "asc"},
        {"sort_by": "amount", "sort_order": "desc"},
    ]
    
    for sort_option in sort_options:
        print(f"\n--- Testing sort: {sort_option['sort_by']} {sort_option['sort_order']} ---")
        
        params = {
            "user_id": test_user_id,
            "limit": 5,
            "offset": 0,
            "sort_by": sort_option["sort_by"],
            "sort_order": sort_option["sort_order"]
        }
        
        try:
            response = requests.get(list_receipts_url, params=params)
            
            print("Status code:", response.status_code)
            
            if response.statusCode == 200:
                result = response.json()
                receipts = result.get('receipts', [])
                print(f"📄 Receipts returned: {len(receipts)}")
                
                # Show first few receipts to verify sorting
                for i, receipt in enumerate(receipts[:3]):
                    if sort_option["sort_by"] == "timestamp":
                        print(f"   {i+1}. Timestamp: {receipt.get('timestamp', 'N/A')}")
                    elif sort_option["sort_by"] == "vendor":
                        print(f"   {i+1}. Vendor: {receipt.get('vendor', 'N/A')}")
                    elif sort_option["sort_by"] == "amount":
                        print(f"   {i+1}. Amount: ${receipt.get('amount', 0.0):.2f}")
                        
            else:
                print("Error:", response.status_code)
                print("Response text:", response.text)
                
        except Exception as e:
            print(f"Exception occurred: {e}")

def test_list_receipts_pagination():
    """Test receipt listing with pagination"""
    print(f"\n{'='*60}")
    print("TESTING RECEIPT LISTING WITH PAGINATION")
    print(f"{'='*60}")
    
    # Test first page
    params_page1 = {
        "user_id": test_user_id,
        "limit": 3,
        "offset": 0
    }
    
    try:
        response = requests.get(list_receipts_url, params=params_page1)
        
        if response.statusCode == 200:
            result_page1 = response.json()
            print(f"📄 Page 1: {len(result_page1.get('receipts', []))} receipts")
            print(f"📊 Total count: {result_page1.get('total_count', 0)}")
            print(f"🔄 Has more: {result_page1.get('pagination', {}).get('has_more', False)}")
            
            # Test second page if there are more receipts
            if result_page1.get('pagination', {}).get('has_more', False):
                params_page2 = {
                    "user_id": test_user_id,
                    "limit": 3,
                    "offset": 3
                }
                
                response_page2 = requests.get(list_receipts_url, params=params_page2)
                
                if response_page2.statusCode == 200:
                    result_page2 = response_page2.json()
                    print(f"📄 Page 2: {len(result_page2.get('receipts', []))} receipts")
                    
                    # Verify no overlap between pages
                    page1_ids = {receipt.get('receipt_id') for receipt in result_page1.get('receipts', [])}
                    page2_ids = {receipt.get('receipt_id') for receipt in result_page2.get('receipts', [])}
                    
                    overlap = page1_ids.intersection(page2_ids)
                    if not overlap:
                        print("✅ No overlap between pages")
                    else:
                        print(f"❌ Overlap found: {overlap}")
                else:
                    print("Error on page 2:", response_page2.status_code)
            else:
                print("ℹ️  No second page available")
                
        else:
            print("Error:", response.status_code)
            print("Response text:", response.text)
            
    except Exception as e:
        print(f"Exception occurred: {e}")

def test_list_receipts_error_cases():
    """Test error cases for receipt listing"""
    print(f"\n{'='*60}")
    print("TESTING ERROR CASES")
    print(f"{'='*60}")
    
    # Test without user_id (should fail)
    print("\n--- Testing without user_id ---")
    try:
        response = requests.get(list_receipts_url)
        print("Status code:", response.status_code)
        
        if response.statusCode == 422:  # Validation error
            print("✅ Correctly returned validation error (422)")
        else:
            print("❌ Expected validation error but got:", response.status_code)
            
    except Exception as e:
        print(f"Exception occurred: {e}")
    
    # Test with invalid user_id
    print("\n--- Testing with invalid user_id ---")
    params = {
        "user_id": "nonexistent_user",
        "limit": 10
    }
    
    try:
        response = requests.get(list_receipts_url, params=params)
        print("Status code:", response.status_code)
        
        if response.statusCode == 200:
            result = response.json()
            print(f"📊 Total receipts: {result.get('total_count', 0)}")
            if result.get('total_count', 0) == 0:
                print("✅ Correctly returned 0 receipts for invalid user")
            else:
                print("❌ Unexpected receipts for invalid user")
        else:
            print("Error:", response.status_code)
            print("Response text:", response.text)
            
    except Exception as e:
        print(f"Exception occurred: {e}")

# Run all tests
if __name__ == "__main__":
    print("🧪 TESTING LIST RECEIPTS ENDPOINT")
    print("Make sure the server is running on http://127.0.0.1:8080")
    
    # Run all test functions
    test_list_receipts_basic()
    test_list_receipts_with_category_filter()
    test_list_receipts_with_sorting()
    test_list_receipts_pagination()
    test_list_receipts_error_cases()
    
    print(f"\n{'='*60}")
    print("🎉 ALL TESTS COMPLETED")
    print(f"{'='*60}") 