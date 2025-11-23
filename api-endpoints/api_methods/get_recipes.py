from firebase_admin import firestore
import google.generativeai as genai
import json

def get_recipes(user_id: str = None):
    try:
        db = firestore.client()
        
        # Filter inventories by user_id if provided
        if user_id:
            inventories_ref = db.collection("inventories").where("userId", "==", user_id)
        else:
            inventories_ref = db.collection("inventories")
            
        docs = inventories_ref.stream()
        inventory_items = [doc.to_dict().get('item_name', '') for doc in docs]
        inventory_items = [item for item in inventory_items if item]
        
        if not inventory_items:
            return {"recipes": [], "message": "No inventory items found."}
        
        # Use Gemini to suggest recipes
        prompt = (
            "Given the following list of available inventory items, suggest up to 10 recipes that can be prepared using these items. "
            "For each recipe, return the recipe name and a short list of main ingredients (from the inventory). "
            "Return the result as a JSON array of objects with 'recipe' and 'ingredients' fields. "
            "If no recipes can be made, return an empty array.\n"
            f"Inventory items: {json.dumps(inventory_items)}"
        )
        model = genai.GenerativeModel("gemini-2.0-flash")
        result = model.generate_content(prompt)
        answer = result.text.strip()
        import re
        json_match = re.search(r'\[.*\]', answer, re.DOTALL)
        if json_match:
            recipes_json = json_match.group()
            recipes = json.loads(recipes_json)
            return {"recipes": recipes, "user_id": user_id}
        return {"recipes": [], "raw": answer, "user_id": user_id}
    except Exception as e:
        return {"error": str(e)} 