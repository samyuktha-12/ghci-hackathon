from firebase_admin import firestore
from datetime import datetime

def retrieve_expirations_data(user_id: str = "testuser123"):
    """
    Retrieve top 5 products that are going to expire soon from user's inventory.
    """
    try:
        # Get current date
        current_date = datetime.now()
        
        # Get user's inventory
        db = firestore.client()
        if user_id:
            inventories_ref = db.collection("inventories").where("userId", "==", user_id)
        else:
            inventories_ref = db.collection("inventories")
            
        inventory_docs = inventories_ref.stream()
        expiring_items = []
        
        for doc in inventory_docs:
            data = doc.to_dict()
            item_name = data.get('item_name', '')
            expiry_date = data.get('expiryDate', '')
            count = data.get('count', 0)
            
            if expiry_date:
                try:
                    # Parse expiry date
                    expiry_datetime = datetime.strptime(expiry_date, '%Y-%m-%d')
                    
                    # Calculate days until expiry
                    days_until_expiry = (expiry_datetime - current_date).days
                    
                    # Only include items that haven't expired yet
                    if days_until_expiry >= 0:
                        expiring_items.append({
                            'item_name': item_name,
                            'count': count,
                            'expiry_date': expiry_date,
                            'days_until_expiry': days_until_expiry,
                            'document_id': doc.id,
                            'last_bought_date': data.get('last_bought_date', ''),
                            'original_names': data.get('original_names', [])
                        })
                except ValueError:
                    # Skip items with invalid date format
                    continue
        
        # Sort by days until expiry (ascending - most urgent first)
        expiring_items.sort(key=lambda x: x['days_until_expiry'])
        
        # Get top 5 items
        top_5_expiring = expiring_items[:5]
        
        # Add urgency level to each item
        for item in top_5_expiring:
            days = item['days_until_expiry']
            if days <= 1:
                item['urgency'] = 'critical'
                item['urgency_message'] = 'Expires today or tomorrow!'
            elif days <= 3:
                item['urgency'] = 'high'
                item['urgency_message'] = 'Expires within 3 days'
            elif days <= 7:
                item['urgency'] = 'medium'
                item['urgency_message'] = 'Expires within a week'
            else:
                item['urgency'] = 'low'
                item['urgency_message'] = f'Expires in {days} days'
        
        return {
            "success": True,
            "message": f"Retrieved {len(top_5_expiring)} items expiring soon",
            "expiring_items": top_5_expiring,
            "user_id": user_id,
            "total_expiring_items": len(expiring_items),
            "current_date": current_date.strftime('%Y-%m-%d'),
            "summary": {
                "critical": len([item for item in top_5_expiring if item['urgency'] == 'critical']),
                "high": len([item for item in top_5_expiring if item['urgency'] == 'high']),
                "medium": len([item for item in top_5_expiring if item['urgency'] == 'medium']),
                "low": len([item for item in top_5_expiring if item['urgency'] == 'low'])
            }
        }
        
    except Exception as e:
        return {
            "success": False,
            "message": f"Error retrieving expiring items: {str(e)}",
            "user_id": user_id
        } 