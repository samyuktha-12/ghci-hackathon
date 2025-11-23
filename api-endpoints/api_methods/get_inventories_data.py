from firebase_admin import firestore

def get_inventories_data(order: str = 'desc', user_id: str = None):
    try:
        db = firestore.client()
        
        # If user_id is provided, filter by userId
        if user_id:
            inventories_ref = db.collection("inventories").where("userId", "==", user_id)
        else:
            inventories_ref = db.collection("inventories")
            
        docs = inventories_ref.stream()
        inventories = []
        for doc in docs:
            data = doc.to_dict()
            data['document_id'] = doc.id
            inventories.append(data)
        
        # Sort by count as integer
        reverse = (order == 'desc')
        inventories.sort(key=lambda x: int(x.get('count', 0)), reverse=reverse)
        return {"inventories": inventories}
    except Exception as e:
        return {"error": str(e)} 