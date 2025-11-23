import os
import uuid
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Query, Body
from fastmcp import FastMCP
import firebase_admin
from firebase_admin import credentials, firestore, storage
import google.generativeai as genai
from datetime import datetime
from dotenv import load_dotenv
import re
import json
import io
from PIL import Image
from typing import List, Dict, Any
import numpy as np
from sentence_transformers import SentenceTransformer
import faiss
from email_service import EmailService
from api_methods.get_inventories_data import get_inventories_data
from api_methods.get_recipes import get_recipes
from api_methods.retrieve_expirations_data import retrieve_expirations_data
from fastapi.responses import StreamingResponse
import tempfile
import shutil
from live_ai_service import LiveAIService
from news_service import NewsService
from api_methods.budget_insights_data import budget_insights_data
from wallet import create_wallet_pass
import requests

# Load environment variables from .env
load_dotenv()

app = FastAPI()
mcp = FastMCP(name="Receipt MCP")

# Firebase setup
FIREBASE_BUCKET = os.getenv("FIREBASE_BUCKET", "pocketsage-466717.appspot.com")
SERVICE_ACCOUNT_JSON = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", None)
if not SERVICE_ACCOUNT_JSON:
    raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON environment variable must be set to the path of your Firebase service account JSON file")
if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_JSON)
    firebase_admin.initialize_app(cred, {"storageBucket": FIREBASE_BUCKET})
db = firestore.client()
bucket = storage.bucket()

# Gemini setup
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "YOUR_GEMINI_API_KEY")
genai.configure(api_key=GEMINI_API_KEY)

# Initialize sentence transformer for embeddings
embedding_model = SentenceTransformer('all-MiniLM-L6-v2')

# In-memory conversation storage (in production, use Redis or database)
conversations = {}

# In-memory cache for embeddings and FAISS index per user
user_rag_cache = {}  # user_id: { 'index': ..., 'embeddings': ..., 'receipts_data': ..., 'last_count': ... }

# Translation service configuration
TRANSLATION_API_URL = "https://api.mymemory.translated.net/get"

# Available languages for the chatbot (5 Indian languages + English)
AVAILABLE_LANGUAGES = {
    "en": "English",
    "hi": "Hindi",
    "ta": "Tamil",
    "te": "Telugu",
    "bn": "Bengali",
    "mr": "Marathi"
}

def translate_text(text: str, target_lang: str, source_lang: str = 'auto') -> str:
    """
    Translate text to target language using MyMemory Translation API
    
    Args:
        text: Text to translate
        target_lang: Target language code (e.g., 'en', 'es', 'fr')
        source_lang: Source language code (default: 'auto' for auto-detection)
    
    Returns:
        Translated text or original text if translation fails
    """
    try:
        # If target language is English or same as source, return original text
        if target_lang == 'en' or target_lang == source_lang:
            return text
        
        # Use MyMemory Translation API
        params = {
            'q': text,
            'langpair': f"{source_lang}|{target_lang}" if source_lang != 'auto' else f"auto|{target_lang}"
        }
        
        response = requests.get(TRANSLATION_API_URL, params=params, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        if data.get('responseStatus') == 200:
            translated_text = data['responseData']['translatedText']
            return translated_text
        else:
            print(f"Translation API error: {data.get('responseDetails', 'Unknown error')}")
            return text
            
    except Exception as e:
        print(f"Translation error: {e}")
        return text

def get_thinking_text(language: str) -> str:
    """
    Get thinking text in the specified language
    
    Args:
        language: Language code (e.g., 'en', 'hi', 'ta', 'te', 'bn', 'mr')
    
    Returns:
        Thinking text in the specified language
    """
    thinking_texts = {
        "en": "Thinking...",
        "hi": "सोच रहा हूँ...",
        "ta": "சிந்திக்கிறேன்...",
        "te": "ఆలోచిస్తున్నాను...",
        "bn": "ভাবছি...",
        "mr": "विचार करत आहे..."
    }
    return thinking_texts.get(language, "Thinking...")

def get_follow_up_chips(language: str) -> list:
    """
    Get follow-up suggestion chips in the specified language
    
    Args:
        language: Language code (e.g., 'en', 'hi', 'ta', 'te', 'bn', 'mr')
    
    Returns:
        List of follow-up suggestion chips in the specified language
    """
    chips = {
        "en": [
            "Show my recent expenses",
            "Analyze spending trends",
            "Find budget insights",
            "Generate shopping list",
            "Check expiring items"
        ],
        "hi": [
            "मेरे हाल के खर्च दिखाएं",
            "खर्च के रुझान का विश्लेषण करें",
            "बजट की अंतर्दृष्टि खोजें",
            "खरीदारी की सूची बनाएं",
            "समाप्त होने वाली वस्तुओं की जांच करें"
        ],
        "ta": [
            "எனது சமீபத்திய செலவுகளைக் காட்டு",
            "செலவு போக்குகளை பகுப்பாய்வு செய்",
            "பட்ஜெட் நுண்ணறிவுகளைக் கண்டறி",
            "கடைப்பிடிப்பு பட்டியலை உருவாக்கு",
            "காலாவதியாகும் பொருட்களை சரிபார்"
        ],
        "te": [
            "నా ఇటీవలి ఖర్చులను చూపించు",
            "ఖర్చు ధోరణులను విశ్లేషించు",
            "బడ్జెట్ అంతర్దృష్టులను కనుగొను",
            "షాపింగ్ జాబితాను సృష్టించు",
            "గడువు ముగియని వస్తువులను తనిఖీ చేయు"
        ],
        "bn": [
            "আমার সাম্প্রতিক খরচ দেখাও",
            "খরচের প্রবণতা বিশ্লেষণ করো",
            "বাজেটের অন্তর্দৃষ্টি খুঁজে বের করো",
            "কেনাকাটার তালিকা তৈরি করো",
            "মেয়াদোত্তীর্ণ আইটেমগুলি পরীক্ষা করো"
        ],
        "mr": [
            "माझे अलीकडील खर्च दाखवा",
            "खर्चाच्या प्रवृत्तींचे विश्लेषण करा",
            "बजेट अंतर्दृष्टी शोधा",
            "खरेदीची यादी तयार करा",
            "कालबाह्य होणाऱ्या वस्तू तपासा"
        ]
    }
    return chips.get(language, chips["en"])

def detect_language(text: str) -> str:
    """
    Detect the language of the input text using simple heuristics for Indian languages
    
    Args:
        text: Text to detect language for
    
    Returns:
        Language code (e.g., 'en', 'hi', 'ta', 'te', 'bn', 'mr') or 'en' as fallback
    """
    try:
        # Simple language detection using common patterns for Indian languages
        text_lower = text.lower()
        
        # Hindi patterns (Devanagari script)
        hindi_patterns = ['नमस्ते', 'कैसे', 'हैं', 'धन्यवाद', 'कृपया', 'अलविदा', 'सुप्रभात', 'शुभ रात्रि', 'हाँ', 'नहीं']
        if any(pattern in text_lower for pattern in hindi_patterns):
            return 'hi'
        
        # Tamil patterns (Tamil script)
        tamil_patterns = ['வணக்கம்', 'எப்படி', 'உள்ளீர்கள்', 'நன்றி', 'தயவுசெய்து', 'பிரியாவிடை', 'காலை வணக்கம்', 'இரவு வணக்கம்']
        if any(pattern in text_lower for pattern in tamil_patterns):
            return 'ta'
        
        # Telugu patterns (Telugu script)
        telugu_patterns = ['నమస్కారం', 'ఎలా', 'ఉన్నారు', 'ధన్యవాదాలు', 'దయచేసి', 'వీడ్కోలు', 'శుభోదయం', 'శుభ రాత్రి']
        if any(pattern in text_lower for pattern in telugu_patterns):
            return 'te'
        
        # Bengali patterns (Bengali script)
        bengali_patterns = ['নমস্কার', 'কেমন', 'আছেন', 'ধন্যবাদ', 'অনুগ্রহ করে', 'বিদায়', 'সুপ্রভাত', 'শুভ রাত্রি']
        if any(pattern in text_lower for pattern in bengali_patterns):
            return 'bn'
        
        # Marathi patterns (Devanagari script)
        marathi_patterns = ['नमस्कार', 'कसे', 'आहात', 'धन्यवाद', 'कृपया', 'निरोप', 'सुप्रभात', 'शुभ रात्री', 'होय', 'नाही']
        if any(pattern in text_lower for pattern in marathi_patterns):
            return 'mr'
        
        # Check for Devanagari script (Hindi/Marathi)
        devanagari_chars = sum(1 for char in text if '\u0900' <= char <= '\u097F')
        if devanagari_chars > len(text) * 0.3:
            # Try to distinguish between Hindi and Marathi
            if any(word in text_lower for word in ['हैं', 'कैसे', 'नमस्ते']):
                return 'hi'
            elif any(word in text_lower for word in ['आहात', 'कसे', 'नमस्कार']):
                return 'mr'
            else:
                return 'hi'  # Default to Hindi for Devanagari
        
        # Check for Tamil script
        tamil_chars = sum(1 for char in text if '\u0B80' <= char <= '\u0BFF')
        if tamil_chars > len(text) * 0.3:
            return 'ta'
        
        # Check for Telugu script
        telugu_chars = sum(1 for char in text if '\u0C00' <= char <= '\u0C7F')
        if telugu_chars > len(text) * 0.3:
            return 'te'
        
        # Check for Bengali script
        bengali_chars = sum(1 for char in text if '\u0980' <= char <= '\u09FF')
        if bengali_chars > len(text) * 0.3:
            return 'bn'
        
        # Default to English
        return 'en'
            
    except Exception as e:
        print(f"Language detection error: {e}")
        return 'en'

def upload_to_firebase(file: UploadFile, user_id: str, receipt_id: str):
    ext = file.filename.split('.')[-1]
    blob = bucket.blob(f"receipts_raw/{user_id}/{receipt_id}.{ext}")
    blob.upload_from_file(file.file, content_type=file.content_type)
    blob.make_public()
    return blob.public_url

def verify_and_parse_with_gemini(image_bytes):
    # Upload the image to Gemini first
    image = Image.open(io.BytesIO(image_bytes)) # or "image/png" as per your input

    model = genai.GenerativeModel("gemini-2.0-flash")
    prompt = (
        "If this image is a receipt, bill, invoice, or proof of purchase (including grocery bills, restaurant bills, online orders, utility bills, or pharmacy receipts), "
        "extract all possible fields, tags, and categories in JSON. If not, reply with 'not a receipt'."
    )

    # Pass the image object, not raw bytes
    result = model.generate_content([prompt, image])
    answer = result.text.strip()
    return {"raw": answer}

def get_user_receipts_embeddings(user_id: str) -> List[Dict[str, Any]]:
    """Get user's parsed receipts and create embeddings for RAG"""
    try:
        # Get all parsed receipts for the user
        receipts_ref = db.collection("receipts_parsed").where("userId", "==", user_id)
        receipts = receipts_ref.stream()
        
        receipts_data = []
        for receipt in receipts:
            receipt_data = receipt.to_dict()
            # Create a text representation for embedding
            text_content = f"""
            Receipt ID: {receipt_data.get('receiptId', '')}
            Vendor: {receipt_data.get('vendor', 'Unknown')}
            Categories: {', '.join(receipt_data.get('categories', []))}
            Parsed Data: {receipt_data.get('geminiRawOutput', '')}
            Extra Fields: {json.dumps(receipt_data.get('extraFields', {}))}
            Timestamp: {receipt_data.get('timestamp', '')}
            """
            receipt_data['text_content'] = text_content
            receipts_data.append(receipt_data)
        
        return receipts_data
    except Exception as e:
        print(f"Error getting user receipts: {e}")
        return []

def create_embeddings_and_index(receipts_data: List[Dict[str, Any]]):
    """Create embeddings and FAISS index for receipts"""
    if not receipts_data:
        return None, None
    
    # Create embeddings
    texts = [receipt['text_content'] for receipt in receipts_data]
    embeddings = embedding_model.encode(texts)
    
    # Create FAISS index
    dimension = embeddings.shape[1]
    index = faiss.IndexFlatIP(dimension)  # Inner product for cosine similarity
    index.add(embeddings.astype('float32'))
    
    return index, embeddings

def retrieve_relevant_receipts(query: str, index, embeddings, receipts_data: List[Dict[str, Any]], top_k: int = 3):
    """Retrieve most relevant receipts for a query"""
    if not index or not receipts_data:
        return []
    
    # Create query embedding
    query_embedding = embedding_model.encode([query])
    
    # Search index
    scores, indices = index.search(query_embedding.astype('float32'), top_k)
    
    # Return relevant receipts
    relevant_receipts = []
    for idx in indices[0]:
        if idx < len(receipts_data):
            relevant_receipts.append(receipts_data[idx])
    
    return relevant_receipts

def generate_chatbot_response(query: str, relevant_receipts: List[Dict[str, Any]], conversation_history: List[Dict[str, str]]):
    """Generate chatbot response using Gemini with RAG"""
    try:
        model = genai.GenerativeModel("gemini-2.0-flash")
        
        # Prepare context from relevant receipts
        context = ""
        if relevant_receipts:
            context = "Relevant receipt information:\n"
            for i, receipt in enumerate(relevant_receipts, 1):
                context += f"\nReceipt {i}:\n"
                context += f"- Vendor: {receipt.get('vendor', 'Unknown')}\n"
                context += f"- Categories: {', '.join(receipt.get('categories', []))}\n"
                context += f"- Parsed Data: {receipt.get('geminiRawOutput', '')}\n"
                context += f"- Extra Fields: {json.dumps(receipt.get('extraFields', {}))}\n"
                context += f"- Date: {receipt.get('timestamp', '')}\n"
        else:
            context = "No relevant receipts found for this query."
        
        # Prepare conversation history
        history_text = ""
        if conversation_history:
            history_text = "\nConversation History:\n"
            for msg in conversation_history[-5:]:  # Last 5 messages
                history_text += f"{msg['role']}: {msg['content']}\n"
        
        # Create the prompt
        prompt = f"""
        You are SageBot, a helpful AI assistant for PocketSage - a smart receipt and expense management app. 
        You help users understand their spending patterns, analyze receipts, and provide financial insights.
        
        {context}
        
        {history_text}
        
        User Query: {query}
        
        Please provide a helpful, conversational response based on the user's receipt data and conversation history. 
        If the user asks about spending patterns, categories, vendors, or specific receipts, use the provided context.
        If no relevant data is available, politely inform the user and suggest what they could do to get better insights.
        
        Keep your response conversational, helpful, and focused on financial insights and receipt analysis.
        """
        
        result = model.generate_content(prompt)
        return result.text.strip()
        
    except Exception as e:
        print(f"Error generating chatbot response: {e}")
        return "I'm sorry, I'm having trouble processing your request right now. Please try again later."

# Owner: Mohamed Fazil
def classify_with_gemini(parsed_data):
    """
    Use Gemini API to classify the receipt as one of the allowed categories.
    Returns: one of the allowed categories or None
    """
    allowed_categories = [
        "groceries", "utilities", "transportation", "dining", "travel", "reimbursement", "home"
    ]
    # Prepare the data string for Gemini
    if isinstance(parsed_data, dict) and 'raw' in parsed_data:
        data_str = parsed_data['raw']
        if isinstance(data_str, dict):
            data_str = json.dumps(data_str)
    else:
        data_str = json.dumps(parsed_data)

    prompt = (
        "Classify the following receipt data as one of these categories: "
        "Groceries, Utilities, Transportation, Dining, Travel, Reimbursement, or Home. "
        "Return only the category name (one of: Groceries, Utilities, Transportation, Dining, Travel, Reimbursement, Home).\n"
        "Receipt data:\n" + data_str
    )
    try:
        model = genai.GenerativeModel("gemini-2.0-flash")
        result = model.generate_content(prompt)
        answer = result.text.strip().lower()
        # Normalize and validate
        answer = answer.replace("category:", "").replace(":", "").strip()
        answer = answer.split("\n")[0].strip()  # Only first line
        for cat in allowed_categories:
            if cat in answer:
                return cat
        # Try exact match if Gemini returns just the category
        if answer in allowed_categories:
            return answer
        return None
    except Exception as e:
        print(f"Gemini API error: {e}")
        return None

# Update endpoints to include reimbursement and home
@app.get("/get_languages")
def get_languages():
    """Get list of available languages for the chatbot"""
    return {
        "languages": AVAILABLE_LANGUAGES,
        "default_language": "en"
    }

@app.get("/get_thinking_text/{language}")
def get_thinking_text_endpoint(language: str):
    """Get thinking text in the specified language"""
    return {
        "thinking_text": get_thinking_text(language),
        "language": language
    }

@app.get("/get_follow_up_chips/{language}")
def get_follow_up_chips_endpoint(language: str):
    """Get follow-up suggestion chips in the specified language"""
    return {
        "chips": get_follow_up_chips(language),
        "language": language
    }

@app.post("/translate")
async def translate_endpoint(
    text: str = Form(...),
    target_language: str = Form(...),
    source_language: str = Form("auto")
):
    """Translate text to target language"""
    try:
        translated_text = translate_text(text, target_language, source_language)
        detected_lang = detect_language(text)
        
        return {
            "original_text": text,
            "translated_text": translated_text,
            "source_language": detected_lang,
            "target_language": target_language
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Translation error: {str(e)}")

@app.get("/get_categories")
def get_categories():
    try:
        receipts_ref = db.collection("receipts_parsed")
        docs = receipts_ref.stream()
        groceries = []
        utilities = []
        transportation = []
        dining = []
        travel = []
        reimbursement = []
        home = []
        for doc in docs:
            receipt = doc.to_dict()
            doc_id = doc.id
            parsed_data = receipt.get('parsedData', {})
            raw_data = parsed_data.get('raw', {})
            category_from_firestore = receipt.get('categories', 'N/A')
            gemini_category = classify_with_gemini(raw_data)
            entry = {"document_id": doc_id, "categories": category_from_firestore}
            if gemini_category == 'groceries':
                groceries.append(entry)
            elif gemini_category == 'utilities':
                utilities.append(entry)
            elif gemini_category == 'transportation':
                transportation.append(entry)
            elif gemini_category == 'dining':
                dining.append(entry)
            elif gemini_category == 'travel':
                travel.append(entry)
            elif gemini_category == 'reimbursement':
                reimbursement.append(entry)
            elif gemini_category == 'home':
                home.append(entry)
        result = {
            "groceries": groceries,
            "utilities": utilities,
            "transportation": transportation,
            "dining": dining,
            "travel": travel,
            "reimbursement": reimbursement,
            "home": home
        }
        return result
    except Exception as e:
        return {"error": str(e)}

@app.post("/chatbot")
async def chatbot_endpoint(
    user_id: str = Form(...),
    message: str = Form(...),
    conversation_id: str = Form(None),
    language: str = Form("en")
):
    """Multi-turn chatbot endpoint with RAG from user's receipts"""
    try:
        # Generate conversation ID if not provided
        if not conversation_id:
            conversation_id = str(uuid.uuid4())
        # Initialize conversation if new
        if conversation_id not in conversations:
            conversations[conversation_id] = {
                'user_id': user_id,
                'messages': [],
                'created_at': datetime.utcnow().isoformat()
            }
        # --- Caching logic start ---
        # Get user's receipts
        receipts_data = get_user_receipts_embeddings(user_id)
        cache = user_rag_cache.get(user_id)
        needs_update = (
            cache is None or
            cache.get('last_count', 0) != len(receipts_data)
        )
        if needs_update:
            index, embeddings = create_embeddings_and_index(receipts_data)
            user_rag_cache[user_id] = {
                'index': index,
                'embeddings': embeddings,
                'receipts_data': receipts_data,
                'last_count': len(receipts_data)
            }
        else:
            index = cache['index']
            embeddings = cache['embeddings']
            receipts_data = cache['receipts_data']
        # --- Caching logic end ---
        # Handle multilingual support
        detected_lang = detect_language(message)
        original_message = message
        
        # Translate message to English for processing if not already in English
        if language != "en" and detected_lang != "en":
            message = translate_text(message, "en", detected_lang)
        
        # Retrieve relevant receipts for the query
        relevant_receipts = retrieve_relevant_receipts(message, index, embeddings, receipts_data)
        # Get conversation history
        conversation_history = conversations[conversation_id]['messages']
        # Generate response
        response = generate_chatbot_response(message, relevant_receipts, conversation_history)
        
        # Translate response back to user's language if needed
        if language != "en":
            response = translate_text(response, language, "en")
        # Update conversation history
        conversations[conversation_id]['messages'].append({
            'role': 'user',
            'content': original_message,
            'translated_content': message if language != "en" else None,
            'language': language,
            'timestamp': datetime.utcnow().isoformat()
        })
        conversations[conversation_id]['messages'].append({
            'role': 'assistant',
            'content': response,
            'original_language': 'en',
            'timestamp': datetime.utcnow().isoformat()
        })
        # Keep only last 20 messages to prevent memory issues
        if len(conversations[conversation_id]['messages']) > 20:
            conversations[conversation_id]['messages'] = conversations[conversation_id]['messages'][-20:]
        return {
            "conversation_id": conversation_id,
            "response": response,
            "language": language,
            "detected_language": detected_lang,
            "relevant_receipts_count": len(relevant_receipts),
            "total_receipts": len(receipts_data),
            "thinking_text": get_thinking_text(language),
            "follow_up_chips": get_follow_up_chips(language),
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        import traceback
        print(f"Chatbot error: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/chatbot/conversations/{user_id}")
async def get_user_conversations(user_id: str):
    """Get all conversations for a user"""
    try:
        user_conversations = []
        for conv_id, conv_data in conversations.items():
            if conv_data['user_id'] == user_id:
                user_conversations.append({
                    'conversation_id': conv_id,
                    'created_at': conv_data['created_at'],
                    'message_count': len(conv_data['messages'])
                })
        
        return {
            "user_id": user_id,
            "conversations": user_conversations
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/chatbot/conversations/{conversation_id}")
async def delete_conversation(conversation_id: str):
    """Delete a specific conversation"""
    try:
        if conversation_id in conversations:
            del conversations[conversation_id]
            return {"message": "Conversation deleted successfully"}
        else:
            raise HTTPException(status_code=404, detail="Conversation not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chatbot/send-email")
async def send_chatbot_email(
    user_id: str = Form(...),
    user_email: str = Form(...),
    user_name: str = Form(...),
    conversation_id: str = Form(...),
    include_summary: bool = Form(False)
):
    """Send the latest chatbot message via email to the user"""
    try:
        load_dotenv()
        try:
            email_service = EmailService()
        except ValueError as e:
            raise HTTPException(status_code=500, detail=f"Email service not configured: {str(e)}")
        if conversation_id not in conversations:
            raise HTTPException(status_code=404, detail="Conversation not found")
        conversation = conversations[conversation_id]
        if conversation['user_id'] != user_id:
            raise HTTPException(status_code=403, detail="Access denied to this conversation")
        messages = conversation['messages']
        latest_assistant_message = next((m['content'] for m in reversed(messages) if m['role'] == 'assistant'), None)
        if not latest_assistant_message:
            raise HTTPException(status_code=404, detail="No assistant messages found in conversation")
        # Clean markdown from the assistant message
        def clean_markdown(text):
            # Remove bold, italics, code, and other markdown
            text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)  # **bold**
            text = re.sub(r'__([^_]+)__', r'\1', text)         # __bold__
            text = re.sub(r'\*([^*]+)\*', r'\1', text)        # *italic*
            text = re.sub(r'_([^_]+)_', r'\1', text)           # _italic_
            text = re.sub(r'`([^`]+)`', r'\1', text)           # `code`
            text = re.sub(r'\n{3,}', '\n\n', text)            # Collapse >2 newlines
            return text.strip()
        cleaned_message = clean_markdown(latest_assistant_message)
        conversation_summary = None
        if include_summary and len(messages) > 2:
            try:
                model = genai.GenerativeModel("gemini-2.0-flash")
                summary_prompt = f"""
                Summarize this conversation in 1-2 sentences:
                {chr(10).join([f"{msg['role']}: {msg['content']}" for msg in messages[-6:]])}
                Summary:
                """
                result = model.generate_content([summary_prompt])
                conversation_summary = result.text.strip()
            except Exception as e:
                print(f"Error generating summary: {e}")
        email_sent = email_service.send_chatbot_message_email(
            user_email=user_email,
            user_name=user_name,
            conversation_id=conversation_id,
            latest_message=cleaned_message,
            conversation_summary=conversation_summary
        )
        if not email_sent:
            raise HTTPException(status_code=500, detail="Failed to send email")
        return {
            "success": True,
            "message": "Email sent successfully",
            "conversation_id": conversation_id,
            "email_sent_to": user_email,
            "timestamp": datetime.utcnow().isoformat()
        }
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        print(f"Email sending error: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/upload")
async def upload_receipt(
    file: UploadFile = File(...),
    user_id: str = Form(...),
    notes: str = Form(None)
):
    try:
        print("Step 1: Received upload request")
        # Step 2: Generate receipt_id
        receipt_id = str(uuid.uuid4())
        print("Step 2: Generated receipt_id:", receipt_id)
        ext = file.filename.split('.')[-1].lower()
        mime_type = file.content_type
        # Step 3: Read file bytes
        file.file.seek(0)
        image_bytes = file.file.read()
        print("Step 3: Read file bytes")
        # Step 4: Verify and parse with Gemini
        parsed = verify_and_parse_with_gemini(image_bytes)
        print("Step 4: Gemini verification and parse result:", parsed["raw"])
        if "not a receipt" in parsed["raw"].lower():
            print("Step 4b: Not a receipt, aborting upload")
            return {"error": "The uploaded document is not recognized as a receipt. Please upload a valid receipt."}
        # Step 5: Gemini call for categories/tags
        model = genai.GenerativeModel("gemini-2.5-flash-lite")
        prompt2 = (
            "Given the following parsed receipt data, assign one or more categories (e.g., 'grocery', 'electronics', 'restaurant', 'pharmacy', 'utility', etc.) "
            "based on the vendor, items, and any other relevant fields. "
            "Return ONLY a valid JSON object with a 'categories' field (list of strings) and any extra fields as 'extraFields' (dict of any additional key-value pairs). "
            "Do not include any explanation, markdown, or code block—just the JSON object.\n\n"
            "Parsed data:\n" + parsed["raw"]
        )
        result2 = model.generate_content([prompt2])
        answer2 = result2.text.strip()
        print("Step 5: Gemini categories/tags result:", answer2)
        categories = []
        extra_fields = {}
        try:
            cleaned = re.sub(r"^```(?:json)?\s*|```$", "", answer2.strip(), flags=re.MULTILINE).strip()
            parsed_json = json.loads(cleaned)
            categories = parsed_json.get("categories", [])
            extra_fields = parsed_json.get("extraFields", {})
        except Exception:
            print("Could not parse categories/extraFields as JSON.")
        # Step 6: Store parsed data in Firestore (receipts_parsed)
        parsed_id = str(uuid.uuid4())
        parsed_doc = {
            "parsedId": parsed_id,
            "receiptId": receipt_id,
            "userId": user_id,
            "timestamp": datetime.utcnow().isoformat(),
            "vendor": None,
            "mediaUrl": None,  # Will update after upload
            "parsedData": parsed,
            "walletPassGenerated": False,
            "geminiRawOutput": parsed["raw"],
            "categories": categories,
            "extraFields": extra_fields,
        }
        db.collection("receipts_parsed").document(parsed_id).set(parsed_doc)
        print("Step 6: Stored parsed data in Firestore (receipts_parsed)")
        # Invalidate RAG cache for this user
        if user_id in user_rag_cache:
            del user_rag_cache[user_id]
        # Step 7: Upload file to Firebase Storage
        # Rewind file for upload
        from io import BytesIO
        file_stream = BytesIO(image_bytes)
        file_for_upload = UploadFile(filename=file.filename, file=file_stream)
        media_url = upload_to_firebase(file_for_upload, user_id, receipt_id)
        print("Step 7: Uploaded to Firebase, media_url:", media_url)
        media_type = file.content_type.split('/')[0]
        timestamp = datetime.utcnow().isoformat()
        # Step 8: Store raw receipt in Firestore (receipts_raw)
        doc = {
            "receiptId": receipt_id,
            "userId": user_id,
            "mediaUrl": media_url,
            "mediaType": media_type,
            "timestamp": timestamp,
            "status": "parsed",
            "linkedParsedId": parsed_id,
            "fileName": file.filename,
            "notes": notes,
        }
        db.collection("receipts_raw").document(receipt_id).set(doc)
        # Step 9: Update receipts_parsed with mediaUrl
        db.collection("receipts_parsed").document(parsed_id).update({
            "mediaUrl": media_url
        })
        print("Step 8: Stored raw receipt in Firestore (receipts_raw) and updated parsed doc with mediaUrl")
        return {
            "receiptId": receipt_id,
            "mediaUrl": media_url,
            "status": "parsed",
            "parseResult": f"Parsed and stored as {parsed_id}",
            "parsedDoc": {**parsed_doc, "mediaUrl": media_url}
        }
    except Exception as e:
        import traceback
        print("Exception occurred:", e)
        traceback.print_exc()
        return {"error": str(e)}

@app.post("/upload-minimal")
async def upload_minimal(
    file: UploadFile = File(...),
    user_id: str = Form(...)
):
    try:
        print("[Minimal] Step 1: Received upload request")
        # Step 2: Generate receipt_id
        receipt_id = str(uuid.uuid4())
        print("[Minimal] Step 2: Generated receipt_id:", receipt_id)
        # Step 3: Read file bytes and verify/parse with Gemini
        file.file.seek(0)
        image_bytes = file.file.read()
        print("[Minimal] Step 3: Read file bytes, passing to Gemini")
        parsed = verify_and_parse_with_gemini(image_bytes)
        print("[Minimal] Step 3: Gemini verification and parse result:", parsed["raw"])
        return {
            "receiptId": receipt_id,
            "geminiResult": parsed["raw"]
        }
    except Exception as e:
        import traceback
        print("[Minimal] Exception occurred:", e)
        traceback.print_exc()
        return {"error": str(e)}

@app.post("/user-ecoscore")
async def user_ecoscore(user_id: str = Form(...)):
    try:
        # Step 1: Fetch all parsed receipts for the user
        parsed_receipts = db.collection("receipts_parsed").where("userId", "==", user_id).stream()
        receipts_data = []
        for doc in parsed_receipts:
            data = doc.to_dict()
            receipts_data.append(data)
        if not receipts_data:
            return {"error": "No parsed receipts found for this user."}
        # Step 2: Prepare data for Gemini
        # We'll send all parsedData fields to Gemini for eco analysis
        parsed_list = [r.get("parsedData", {}) for r in receipts_data]
        # Step 3: Ask Gemini to calculate EcoScore and trends
        model = genai.GenerativeModel("gemini-2.5-flash-lite")
        prompt = (
            "You are an eco-footprint analyst. Given a list of parsed receipt data, calculate an EcoScore for the user. "
            "Each purchase is evaluated for sustainability (local vs imported, organic tags, plastic-heavy items). "
            "Return a JSON object with: 'ecoScore' (0-100, higher is better), 'monthlyTrends' (dict of month: score), "
            "and 'recommendations' (list of strings for improvement). Do not include any explanation, markdown, or code block—just the JSON object.\n\n"
            f"Parsed receipts: {json.dumps(parsed_list)}"
        )
        result = model.generate_content([prompt])
        answer = result.text.strip()
        try:
            cleaned = re.sub(r"^```(?:json)?\\s*|```$", "", answer.strip(), flags=re.MULTILINE).strip()
            ecoscore_json = json.loads(cleaned)
        except Exception:
            ecoscore_json = {"raw": answer, "error": "Could not parse Gemini response as JSON."}
        return {
            "userId": user_id,
            "ecoScoreResult": ecoscore_json
        }
    except Exception as e:
        import traceback
        print("[EcoScore] Exception occurred:", e)
        traceback.print_exc()
        return {"error": str(e)}

def extract_total_amount_with_gemini(raw_data):
    """
    Use Gemini API to extract the total amount from receipt raw data.
    Returns: float amount or 0.0 if not found
    """
    if isinstance(raw_data, dict) and 'raw' in raw_data:
        data_str = raw_data['raw']
        if isinstance(data_str, dict):
            data_str = json.dumps(data_str)
    else:
        data_str = json.dumps(raw_data)

    prompt = (
        "Extract the total amount from the following receipt data. "
        "Look for fields like 'total', 'total_price', 'price', 'total_amount', 'amount', 'sum', etc. "
        "Return only the numeric value as a number (no currency symbols, no text). "
        "If no total amount is found, return 0.\n"
        "Receipt data:\n" + data_str
    )
    try:
        model = genai.GenerativeModel("gemini-2.0-flash")
        result = model.generate_content(prompt)
        answer = result.text.strip()
        # Try to extract numeric value
        import re
        numbers = re.findall(r'\d+\.?\d*', answer)
        if numbers:
            return float(numbers[0])
        return 0.0
    except Exception as e:
        print(f"Gemini API error for amount extraction: {e}")
        return 0.0

def extract_items_with_gemini(raw_data):
    """
    Use Gemini API to extract items from receipt raw data.
    Returns: list of item dictionaries with name, price, quantity
    """
    if isinstance(raw_data, dict) and 'raw' in raw_data:
        data_str = raw_data['raw']
        if isinstance(data_str, dict):
            data_str = json.dumps(data_str)
    else:
        data_str = json.dumps(raw_data)

    prompt = (
        "Extract all items from the following receipt data. "
        "For each item, provide: name, price, and quantity. "
        "Return as a JSON array of objects with keys: 'name', 'price', 'quantity'. "
        "If no items found, return empty array [].\n"
        "Receipt data:\n" + data_str
    )
    try:
        model = genai.GenerativeModel("gemini-2.0-flash")
        result = model.generate_content(prompt)
        answer = result.text.strip()
        # Try to parse JSON response
        import re
        # Find JSON array in response
        json_match = re.search(r'\[.*\]', answer, re.DOTALL)
        if json_match:
            items_json = json_match.group()
            items = json.loads(items_json)
            return items
        return []
    except Exception as e:
        print(f"Gemini API error for items extraction: {e}")
        return []

def normalize_item_name_with_gemini(item_name: str, existing_items: list = None):
    """
    Use Gemini to normalize item names and identify similar items.
    Returns: normalized item name
    """
    try:
        model = genai.GenerativeModel("gemini-2.0-flash")
        
        # Create context with existing items if available
        context = ""
        if existing_items:
            context = f"Existing items: {', '.join(existing_items)}. "
        
        prompt = (
            f"{context}Normalize the following item name to a standard, full name. "
            "For example: 'ckn' should become 'chicken', 'milk 2%' should become 'milk', 'bread loaf' should become 'bread'. "
            "Return only the normalized name, no explanation. "
            f"Item to normalize: '{item_name}'"
        )
        
        result = model.generate_content(prompt)
        normalized_name = result.text.strip().lower()
        
        # Clean up the response
        normalized_name = normalized_name.replace('"', '').replace("'", "").strip()
        
        return normalized_name if normalized_name else item_name
    except Exception as e:
        print(f"Gemini normalization error: {e}")
        return item_name

def extract_expiry_date_with_gemini(item_name: str, raw_data: dict):
    """
    Use Gemini to extract expiry date for a specific item from receipt data.
    If no expiry date is found, automatically assign one based on item type.
    Returns: expiry date string or None if not found
    """
    try:
        model = genai.GenerativeModel("gemini-2.0-flash")
        
        # Get current date
        from datetime import datetime
        current_date = datetime.now().strftime('%Y-%m-%d')

        # Prepare the data string for Gemini
        if isinstance(raw_data, dict) and 'raw' in raw_data:
            data_str = raw_data['raw']
            if isinstance(data_str, dict):
                data_str = json.dumps(data_str)
        else:
            data_str = json.dumps(raw_data)

        prompt = (
            f"Look for expiry date information for the item '{item_name}' in the following receipt data. "
            f"Today's date is {current_date}. "
            "Look for terms like 'expiry', 'expires', 'best before', 'use by', 'sell by', 'BB', 'EXP', etc. "
            f"Return only the expiry date in YYYY-MM-DD format if found, or 'None' if no expiry date is found. "
            "If the date is in a different format, convert it to YYYY-MM-DD. "
            f"IMPORTANT: If the extracted date is in the past relative to today ({current_date}), return 'None' instead. "
            f"Receipt data:\n{data_str}"
        )

        result = model.generate_content(prompt)
        answer = result.text.strip().lower()

        # Try to extract date from response
        import re
        # Look for date patterns
        date_patterns = [
            r'(\d{4}-\d{2}-\d{2})',  # YYYY-MM-DD
            r'(\d{2}/\d{2}/\d{4})',  # MM/DD/YYYY
            r'(\d{2}-\d{2}-\d{4})',  # MM-DD-YYYY
            r'(\d{1,2}/\d{1,2}/\d{2,4})',  # M/D/YY or M/D/YYYY
        ]

        for pattern in date_patterns:
            match = re.search(pattern, answer)
            if match:
                date_str = match.group(1)
                # Convert to YYYY-MM-DD format if needed
                if '/' in date_str:
                    parts = date_str.split('/')
                    if len(parts) == 3:
                        if len(parts[2]) == 2:  # YY format
                            parts[2] = '20' + parts[2]
                        if len(parts[0]) == 1:  # Single digit month
                            parts[0] = '0' + parts[0]
                        if len(parts[1]) == 1:  # Single digit day
                            parts[1] = '0' + parts[1]
                        date_str = f"{parts[2]}-{parts[0]}-{parts[1]}"
                elif '-' in date_str and len(date_str.split('-')[0]) == 2:
                    # MM-DD-YYYY format
                    parts = date_str.split('-')
                    if len(parts[2]) == 2:  # YY format
                        parts[2] = '20' + parts[2]
                    date_str = f"{parts[2]}-{parts[0]}-{parts[1]}"

                # Validate that the date is in the future
                try:
                    expiry_date = datetime.strptime(date_str, '%Y-%m-%d')
                    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                    if expiry_date > today:
                        return date_str
                    else:
                        print(f"Warning: Extracted past date {date_str} for {item_name}, using fallback")
                        break
                except ValueError:
                    print(f"Warning: Invalid date format {date_str} for {item_name}, using fallback")
                    break

        # Check if Gemini explicitly said "None" or "not found"
        if 'none' in answer or 'not found' in answer or 'no expiry' in answer:
            # No expiry date found in receipt, use Gemini to assign one based on item type
            return assign_expiry_date_by_item_type(item_name)

        # If we get here, no valid future date was found, use fallback
        return assign_expiry_date_by_item_type(item_name)
        
    except Exception as e:
        print(f"Gemini expiry extraction error: {e}")
        # Fallback to assigning expiry date by item type
        return assign_expiry_date_by_item_type(item_name)

def assign_expiry_date_by_item_type(item_name: str):
    """
    Use Gemini to assign an appropriate expiry date based on the item type.
    Returns: expiry date string in YYYY-MM-DD format
    """
    try:
        model = genai.GenerativeModel("gemini-2.0-flash")
        
        # Get current date
        from datetime import datetime
        current_date = datetime.now().strftime('%Y-%m-%d')

        prompt = (
            f"Given the item '{item_name}' and today's date is {current_date}, assign an appropriate expiry date based on typical shelf life. "
            "Consider factors like: "
            "- Dairy products (milk, cheese, yogurt): 7-14 days from today "
            "- Bread and baked goods: 5-7 days from today "
            "- Fresh produce (fruits, vegetables): 3-7 days from today "
            "- Meat and fish: 3-5 days from today "
            "- Canned goods: 1-2 years from today "
            "- Dry goods (rice, pasta): 1-2 years from today "
            "- Snacks and packaged foods: 3-6 months from today "
            "- Beverages: 1-2 weeks from today "
            "- Frozen foods: 6-12 months from today "
            f"Return only the expiry date in YYYY-MM-DD format, calculated from today's date ({current_date}). "
            "Be conservative with perishable items and generous with non-perishable items. "
            "IMPORTANT: The expiry date must be in the future relative to today's date."
        )

        result = model.generate_content(prompt)
        answer = result.text.strip()

        # Extract date from response
        import re
        date_patterns = [
            r'(\d{4}-\d{2}-\d{2})',  # YYYY-MM-DD
            r'(\d{2}/\d{2}/\d{4})',  # MM/DD/YYYY
            r'(\d{2}-\d{2}-\d{4})',  # MM-DD-YYYY
            r'(\d{1,2}/\d{1,2}/\d{2,4})',  # M/D/YY or M/D/YYYY
        ]

        for pattern in date_patterns:
            match = re.search(pattern, answer)
            if match:
                date_str = match.group(1)
                # Convert to YYYY-MM-DD format if needed
                if '/' in date_str:
                    parts = date_str.split('/')
                    if len(parts) == 3:
                        if len(parts[2]) == 2:  # YY format
                            parts[2] = '20' + parts[2]
                        if len(parts[0]) == 1:  # Single digit month
                            parts[0] = '0' + parts[0]
                        if len(parts[1]) == 1:  # Single digit day
                            parts[1] = '0' + parts[1]
                        date_str = f"{parts[2]}-{parts[0]}-{parts[1]}"
                elif '-' in date_str and len(date_str.split('-')[0]) == 2:
                    # MM-DD-YYYY format
                    parts = date_str.split('-')
                    if len(parts[2]) == 2:  # YY format
                        parts[2] = '20' + parts[2]
                    date_str = f"{parts[2]}-{parts[0]}-{parts[1]}"

                # Validate that the date is in the future
                try:
                    expiry_date = datetime.strptime(date_str, '%Y-%m-%d')
                    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                    if expiry_date > today:
                        return date_str
                    else:
                        print(f"Warning: Gemini returned past date {date_str} for {item_name}, using fallback")
                except ValueError:
                    print(f"Warning: Invalid date format {date_str} for {item_name}, using fallback")

        # Fallback: return a default expiry date (7 days from now)
        from datetime import timedelta
        default_expiry = datetime.now() + timedelta(days=7)
        return default_expiry.strftime('%Y-%m-%d')

    except Exception as e:
        print(f"Gemini expiry assignment error: {e}")
        # Fallback: return a default expiry date (7 days from now)
        from datetime import datetime, timedelta
        default_expiry = datetime.now() + timedelta(days=7)
        return default_expiry.strftime('%Y-%m-%d')

# Owner: Mohamed Fazil
@app.post("/add_inventories")
def add_inventories(user_id: str = Form(None), process_all: bool = Form(False)):
    try:
        # Filter receipts by user_id if provided
        if user_id:
            receipts_ref = db.collection("receipts_parsed").where("userId", "==", user_id)
        else:
            receipts_ref = db.collection("receipts_parsed")
            
        docs = receipts_ref.stream()
        
        # Convert to list and sort by timestamp to get the latest receipt
        receipts_list = []
        for doc in docs:
            receipt_data = doc.to_dict()
            receipt_data['doc_id'] = doc.id
            receipts_list.append(receipt_data)
        
        # Sort by timestamp (newest first)
        receipts_list.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
        
        # If process_all is False, only process the latest receipt
        if not process_all and receipts_list:
            receipts_list = [receipts_list[0]]  # Only the latest receipt
        
        # Dictionary to store item counts and last bought dates
        inventory_items = {}
        existing_items = []
        
        for receipt in receipts_list:
            parsed_data = receipt.get('parsedData', {})
            raw_data = parsed_data.get('raw', {})
            timestamp = receipt.get('timestamp', '')
            
            # Extract items using Gemini
            items = extract_items_with_gemini(raw_data)
            
            for item in items:
                original_item_name = item.get('name', '').lower().strip()
                if original_item_name:
                    # Normalize the item name using Gemini
                    normalized_name = normalize_item_name_with_gemini(original_item_name, existing_items)
                    
                    # Extract expiry date for this item
                    expiry_date = extract_expiry_date_with_gemini(original_item_name, raw_data)
                    
                    if normalized_name not in inventory_items:
                        inventory_items[normalized_name] = {
                            'count': 0,
                            'last_bought_date': timestamp,
                            'first_bought_date': timestamp,
                            'userId': user_id if user_id else None,
                            'original_names': [original_item_name],
                            'expiryDate': expiry_date
                        }
                        existing_items.append(normalized_name)
                    
                    inventory_items[normalized_name]['count'] += 1
                    # Update last bought date if this receipt is more recent
                    if timestamp > inventory_items[normalized_name]['last_bought_date']:
                        inventory_items[normalized_name]['last_bought_date'] = timestamp
                    
                    # Add original name to the list if not already present
                    if original_item_name not in inventory_items[normalized_name]['original_names']:
                        inventory_items[normalized_name]['original_names'].append(original_item_name)
                    
                    # Update expiry date to the earliest one if a new expiry date is found
                    if expiry_date:
                        current_expiry = inventory_items[normalized_name]['expiryDate']
                        if current_expiry is None or expiry_date < current_expiry:
                            inventory_items[normalized_name]['expiryDate'] = expiry_date
        
        # Store in inventories collection
        inventories_ref = db.collection("inventories")
        for item_name, item_data in inventory_items.items():
            doc_id = item_name.replace(' ', '_').replace('-', '_')  # Create safe document ID
            inventory_doc = {
                'item_name': item_name,
                'count': item_data['count'],
                'last_bought_date': item_data['last_bought_date'],
                'first_bought_date': item_data['first_bought_date'],
                'userId': item_data['userId'],
                'original_names': item_data['original_names'],
                'expiryDate': item_data['expiryDate'],
                'created_at': datetime.utcnow().isoformat()
            }
            inventories_ref.document(doc_id).set(inventory_doc)
        
        return {
            "message": f"Successfully added {len(inventory_items)} items to inventory",
            "items_count": len(inventory_items),
            "items": list(inventory_items.keys()),
            "user_id": user_id,
            "process_all": process_all,
            "receipts_processed": len(receipts_list),
            "normalization_applied": True,
            "expiry_tracking_enabled": True
        }
        
    except Exception as e:
        return {"error": str(e)}

# Owner: Mohamed Fazil
@app.get("/generate_chart")
def generate_chart(user_id: str = Query(None)):
    try:
        # Filter receipts by user_id if provided
        if user_id:
            receipts_ref = db.collection("receipts_parsed").where("userId", "==", user_id)
        else:
            receipts_ref = db.collection("receipts_parsed")
            
        docs = receipts_ref.stream()
        stats = {
            "groceries": [0, 0.0],
            "utilities": [0, 0.0],
            "transportation": [0, 0.0],
            "dining": [0, 0.0],
            "travel": [0, 0.0],
            "reimbursement": [0, 0.0],
            "home": [0, 0.0]
        }
        for doc in docs:
            receipt = doc.to_dict()
            parsed_data = receipt.get('parsedData', {})
            raw_data = parsed_data.get('raw', {})
            gemini_category = classify_with_gemini(raw_data)
            amount_val = extract_total_amount_with_gemini(raw_data)
            if gemini_category in stats:
                stats[gemini_category][0] += 1
                stats[gemini_category][1] += amount_val
        return stats
    except Exception as e:
        return {"error": str(e)}

@app.post("/tip-of-the-day")
async def tip_of_the_day(user_id: str = Form(...)):
    try:
        # Step 1: Fetch all parsed receipts for the user
        parsed_receipts = db.collection("receipts_parsed").where("userId", "==", user_id).stream()
        receipts_data = []
        for doc in parsed_receipts:
            data = doc.to_dict()
            receipts_data.append(data)
        if not receipts_data:
            return {"error": "No parsed receipts found for this user."}
        # Step 2: Prepare data for Gemini
        parsed_list = [r.get("parsedData", {}) for r in receipts_data]
        # Step 3: Ask Gemini for a personalized tip of the day
        model = genai.GenerativeModel("gemini-2.5-flash-lite")
        prompt = (
            "You are PocketSage, an agentic financial assistant. Given a user's parsed receipts, analyze their recent spending trends and deliver a single, actionable, personalized financial tip of the day. "
            "The tip should be based on their actual purchases and habits, and should be specific, goal-based, and encouraging. "
            "For example: 'Reduce your grocery bill by ₹600/month by switching to X.' or 'Consider buying in bulk to save on household essentials.' "
            "Return ONLY a JSON object with a 'tip' field (string). Do not include any explanation, markdown, or code block—just the JSON object.\n\n"
            f"Parsed receipts: {json.dumps(parsed_list)}"
        )
        result = model.generate_content([prompt])
        answer = result.text.strip()
        try:
            cleaned = re.sub(r"^```(?:json)?\\s*|```$", "", answer.strip(), flags=re.MULTILINE).strip()
            tip_json = json.loads(cleaned)
            if isinstance(tip_json, dict) and set(tip_json.keys()) == {"tip"}:
                tip_json = tip_json["tip"]
        except Exception:
            # If parsing fails, sanitize using another Gemini call
            sanitize_prompt = (
                "The following is a response that should be a JSON object with 'tip', but may contain markdown, code blocks, or extra text. "
                "Return ONLY a valid JSON object with 'tip' field, with no markdown, code block, or explanation.\n\n"
                f"Response to sanitize:\n{answer}"
            )
            sanitize_result = model.generate_content([sanitize_prompt])
            sanitized_answer = sanitize_result.text.strip()
            try:
                sanitized_cleaned = re.sub(r"^```(?:json)?\\s*|```$", "", sanitized_answer.strip(), flags=re.MULTILINE).strip()
                tip_json = json.loads(sanitized_cleaned)
                if isinstance(tip_json, dict) and set(tip_json.keys()) == {"tip"}:
                    tip_json = tip_json["tip"]
            except Exception:
                tip_json = {"raw": sanitized_answer, "error": "Could not parse sanitized Gemini response as JSON."}
        return {
            "userId": user_id,
            "tipOfTheDay": tip_json
        }
    except Exception as e:
        import traceback
        print("[TipOfTheDay] Exception occurred:", e)
        traceback.print_exc()
        return {"error": str(e)}

# Owner: Mohamed Fazil
@app.get("/get_inventories")
def get_inventories(order: str = Query('desc', enum=['asc', 'desc']), user_id: str = Query(None)):
    return get_inventories_data(order, user_id)

@app.get("/get_recipes")
def get_recipes_endpoint(user_id: str = Query(None)):
    return get_recipes(user_id)

@app.get("/retrieve_expirations")
def retrieve_expirations(user_id: str = "testuser123"):
    """
    Retrieve top 5 products that are going to expire soon from user's inventory.
    """
    return retrieve_expirations_data(user_id)

@app.get("/budget_insights")
def budget_insights(user_id: str = "testuser123", period: str = "monthly"):
    """
    Generate budget insights and spending analysis for the user.
    """
    return budget_insights_data(user_id, period)

# --- Preset monthly budget and categories ---
PRESET_BUDGET = {
    "groceries": 200,
    "entertainment": 100,
    "transport": 150,
    "utilities": 200,
    "shopping": 100,
    "health": 50,
}
AVAILABLE_CATEGORIES = list(PRESET_BUDGET.keys())


# --- Robust Normalization ---
def normalize_receipt(receipt: dict) -> dict:
    """
    Normalize various receipt formats to a standard structure:
    {
        'items': [{'description': str, 'price': float}],
        'total': float,
        'merchant': str (optional),
        'date': str (optional)
    }
    """
    # Step 1: If 'parsedData' and 'raw' exist, parse the JSON string
    if 'parsedData' in receipt and 'raw' in receipt['parsedData']:
        raw = receipt['parsedData']['raw']
        # Remove code block markers if present
        if raw.startswith('```json'):
            raw = raw[7:]
        if raw.endswith('```'):
            raw = raw[:-3]
        try:
            parsed = json.loads(raw)
            receipt = parsed
        except Exception as e:
            print("Error parsing raw JSON:", e)
            # fallback to original
            pass

    normalized = {
        'items': [],
        'total': 0.0,
        'merchant': None,
        'date': None
    }

    # Try all known item fields
    if 'items' in receipt and isinstance(receipt['items'], list):
        normalized['items'] = [
            {'description': item.get('name', item.get('item_name', '')), 'price': float(item.get('price', item.get('unit_price', item.get('total_price', 0))))}
            for item in receipt['items']
        ]
    elif 'receipt_items' in receipt and isinstance(receipt['receipt_items'], list):
        normalized['items'] = [
            {'description': item.get('item_name', ''), 'price': float(item.get('price', item.get('unit_price', item.get('total_price', 0))))}
            for item in receipt['receipt_items']
        ]
    elif 'fields' in receipt and isinstance(receipt['fields'], dict):
        # Some receipts have 'fields' with 'line_items'
        if 'line_items' in receipt['fields']:
            normalized['items'] = [
                {'description': item.get('item_name', item.get('item_description', '')), 'price': float(item.get('price', item.get('unit_price', item.get('total_price', 0))))}
                for item in receipt['fields']['line_items']
            ]
        elif 'items' in receipt['fields']:
            normalized['items'] = [
                {'description': item.get('name', item.get('item_name', '')), 'price': float(item.get('price', item.get('unit_price', item.get('total_price', 0))))}
                for item in receipt['fields']['items']
            ]

    # Try all known total fields
    for total_field in ['total', 'total_amount', 'total_price', 'total_purchase', 'payment_amount', 'bill_total', 'amount_paid']:
        if total_field in receipt:
            try:
                normalized['total'] = float(receipt[total_field])
                break
            except Exception:
                continue
    # Sometimes in fields
    if normalized['total'] == 0.0 and 'fields' in receipt and isinstance(receipt['fields'], dict):
        for total_field in ['total', 'total_amount', 'total_price', 'total_purchase', 'payment_amount', 'bill_total', 'amount_paid']:
            if total_field in receipt['fields']:
                try:
                    normalized['total'] = float(receipt['fields'][total_field])
                    break
                except Exception:
                    continue

    # Try all known merchant/store fields
    for merchant_field in ['merchant_name', 'store_name', 'vendor_name']:
        if merchant_field in receipt:
            normalized['merchant'] = receipt[merchant_field]
            break
    if not normalized['merchant'] and 'fields' in receipt and isinstance(receipt['fields'], dict):
        for merchant_field in ['merchant_name', 'store_name', 'vendor_name']:
            if merchant_field in receipt['fields']:
                normalized['merchant'] = receipt['fields'][merchant_field]
                break

    # Try all known date fields
    for date_field in ['date', 'receipt_date']:
        if date_field in receipt:
            normalized['date'] = receipt[date_field]
            break
    if not normalized['date'] and 'fields' in receipt and isinstance(receipt['fields'], dict):
        for date_field in ['date', 'receipt_date']:
            if date_field in receipt['fields']:
                normalized['date'] = receipt['fields'][date_field]
                break

    return normalized

# --- Manual Categorization ---
def manual_categorize_receipt(normalized: dict) -> str:
    """
    Categorize based on item/merchant keywords for your 6 categories.
    """
    items = normalized['items']
    merchant = (normalized.get('merchant') or '').lower()
    # Keywords for each category
    category_keywords = {
        'groceries': [
            'grocery', 'supermarket', 'market', 'walmart', 'food', 'bread', 'milk', 'butter', 'cheese', 'eggs', 'vegetable', 'fruit', 'banana', 'tomato', 'onion', 'potato', 'paneer', 'chicken', 'rice', 'flour', 'sugar', 'spices', 'tea', 'coffee', 'biscuit', 'biscuits', 'yogurt', 'cheese', 'jam', 'honey', 'ketchup', 'pickle', 'noodles', 'juice', 'water', 'chips', 'chocolate', 'ice cream'
        ],
        'entertainment': [
            'movie', 'game', 'cinema', 'theater', 'concert', 'ticket', 'entertainment'
        ],
        'transport': [
            'uber', 'lyft', 'taxi', 'bus', 'train', 'metro', 'parking', 'car', 'transport', 'fuel', 'gas'
        ],
        'utilities': [
            'electricity', 'water', 'internet', 'phone', 'utility', 'power', 'bill'
        ],
        'shopping': [
            'shirt', 't-shirt', 'pants', 'dress', 'shoes', 'electronics', 'phone', 'laptop', 'towel', 'hand towel', 'push pins', 'notebook', 'book', 'fan', 'lighter', 'batteries', 'matchbox', 'nail cutter', 'bucket', 'watering can', 'garden gloves', 'plastic bag', 'shopping bag', 'bag', 'bags', 'dustbin', 'mat', 'carrier bag', 'pouch', 'pack', 'carton', 'box', 'jar', 'bottle', 'tube', 'pen', 'pencil'
        ],
        'health': [
            'medicine', 'pharmacy', 'doctor', 'hospital', 'medical', 'fitness', 'gym', 'vitamin', 'shampoo', 'soap', 'toothpaste', 'toothbrush', 'cream', 'oil', 'lotion', 'capsules', 'tablets', 'syrup'
        ]
    }
    # Check merchant name first
    for category, keywords in category_keywords.items():
        for keyword in keywords:
            if keyword in merchant:
                return category
    # Check item descriptions
    for item in items:
        description = item.get('description', '').lower()
        for category, keywords in category_keywords.items():
            for keyword in keywords:
                if keyword in description:
                    return category
    # Default to groceries if no clear match
    return 'groceries'

# --- Use in analysis loop ---
def analyze_spending(user_id: str):
    try:
        receipts_ref = db.collection("receipts_parsed").where("userId", "==", user_id)
        docs = receipts_ref.stream()
        spending = {category: 0 for category in AVAILABLE_CATEGORIES}
        categorized_receipts = []
        for doc in docs:
            data = doc.to_dict()
            receipt_data = data.get("data", data)
            normalized = normalize_receipt(receipt_data)
            category = manual_categorize_receipt(normalized)
            total = normalized['total']
            date = normalized.get('date') or 'unknown'
            spending[category] += total
            categorized_receipts.append({
                "receiptId": doc.id,
                "category": category,
                "amount": total,
                "date": date
            })
        overspent = {}
        for category, spent_amount in spending.items():
            budget = PRESET_BUDGET.get(category, 0)
            if spent_amount > budget:
                overspent[category] = {
                    "spent": spent_amount,
                    "budget": budget,
                    "overspent_by": spent_amount - budget
                }
        return {
            "spending_by_category": spending,
            "overspent_categories": overspent,
            "categorized_receipts": categorized_receipts,
            "budget_limits": PRESET_BUDGET
        }
    except Exception as e:
        print(f"Error analyzing spending: {e}")
        return {"error": str(e)}

@app.get("/analyze/{user_id}")
def analyze(user_id: str):
    """
    Analyze spending for a specific user
    """
    result = analyze_spending(user_id)
    return result

@app.get("/categories")
def get_categories_budget():
    """
    Get available categories and their budget limits
    """
    return {
        "categories": AVAILABLE_CATEGORIES,
        "budget_limits": PRESET_BUDGET
    }


@app.post("/read_message")
def read_message(message: str = Form(...), user_id: str = Form("testuser123")):
    """
    Process a text message to extract expense information and store it in expenses_from_messages collection.
    """
    try:
        # Get current date
        from datetime import datetime
        current_date = datetime.now().strftime('%Y-%m-%d')
        
        # Use Gemini to extract expense information from the message
        model = genai.GenerativeModel("gemini-2.0-flash")
        
        prompt = (
            f"Extract expense information from this message: '{message}'\n\n"
            "Return a JSON object with the following fields:\n"
            "- 'expense_name': A descriptive name for the expense (e.g., 'Food', 'Transport', 'Shopping')\n"
            "- 'amount': The expense amount as a number (extract only the numeric value)\n"
            "- 'category': One of these 7 categories: groceries, utilities, transportation, dining, travel, reimbursement, home\n\n"
            "Example response format:\n"
            "{\n"
            '  "expense_name": "Food Delivery",\n'
            '  "amount": 500,\n'
            '  "category": "dining"\n'
            "}\n\n"
            "If no expense information can be extracted, return:\n"
            "{\n"
            '  "expense_name": null,\n'
            '  "amount": null,\n'
            '  "category": null\n'
            "}"
        )
        
        result = model.generate_content(prompt)
        answer = result.text.strip()
        
        # Extract JSON from Gemini response
        import re
        json_match = re.search(r'\{.*\}', answer, re.DOTALL)
        
        if json_match:
            try:
                expense_data = json.loads(json_match.group())
                
                # Validate extracted data
                expense_name = expense_data.get('expense_name')
                amount = expense_data.get('amount')
                category = expense_data.get('category')
                
                # Check if valid expense data was extracted
                if expense_name and amount is not None and category:
                    # Validate category
                    allowed_categories = [
                        "groceries", "utilities", "transportation", "dining", 
                        "travel", "reimbursement", "home"
                    ]
                    
                    if category.lower() not in allowed_categories:
                        # Use Gemini to classify the category
                        category = classify_with_gemini({"raw": message})
                        if not category:
                            category = "home"  # Default category
                    
                    # Store in expenses_from_messages collection
                    expenses_ref = db.collection("expenses_from_messages")
                    
                    expense_doc = {
                        'expense_name': expense_name,
                        'amount': float(amount),
                        'type': 'message_extraction',
                        'category': category.lower(),
                        'userId': user_id,
                        'date': current_date,
                        'original_message': message,
                        'created_at': datetime.utcnow().isoformat()
                    }
                    
                    # Create a unique document ID
                    doc_id = f"{user_id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"
                    expenses_ref.document(doc_id).set(expense_doc)
                    
                    return {
                        "success": True,
                        "message": "Expense information extracted and stored successfully",
                        "extracted_data": {
                            "expense_name": expense_name,
                            "amount": float(amount),
                            "category": category.lower(),
                            "type": "message_extraction"
                        },
                        "user_id": user_id,
                        "date": current_date,
                        "document_id": doc_id
                    }
                else:
                    return {
                        "success": False,
                        "message": "No valid expense information found in the message",
                        "extracted_data": expense_data,
                        "user_id": user_id,
                        "original_message": message
                    }
                    
            except json.JSONDecodeError as e:
                return {
                    "success": False,
                    "message": f"Failed to parse Gemini response: {str(e)}",
                    "raw_response": answer,
                    "user_id": user_id,
                    "original_message": message
                }
        else:
            return {
                "success": False,
                "message": "No JSON response found from Gemini",
                "raw_response": answer,
                "user_id": user_id,
                "original_message": message
            }
            
    except Exception as e:
        return {
            "success": False,
            "message": f"Error processing message: {str(e)}",
            "user_id": user_id,
            "original_message": message
        }
# --- Live AI Endpoints ---

@app.post("/live-ai/process-audio")
async def process_audio_conversation(
    audio_file: UploadFile = File(...),
    user_id: str = Form(...),
    conversation_id: str = Form(None)
):
    """Process audio conversation using Google's Live API"""
    try:
        # Generate conversation ID if not provided
        if not conversation_id:
            conversation_id = str(uuid.uuid4())
        
        # Save uploaded audio file temporarily
        temp_input = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
        shutil.copyfileobj(audio_file.file, temp_input)
        temp_input.close()
        
        # Create output file path
        output_filename = f"response_{conversation_id}.wav"
        output_path = os.path.join(tempfile.gettempdir(), output_filename)
        
        # Process audio with Live AI
        live_ai_service = LiveAIService()
        result = await live_ai_service.process_audio_conversation(
            audio_file_path=temp_input.name,
            output_path=output_path
        )
        
        # Clean up input file
        os.unlink(temp_input.name)
        
        if not result["success"]:
            raise HTTPException(status_code=500, detail=result["error"])
        
        # Upload response audio to Firebase Storage
        response_audio_url = None
        try:
            with open(output_path, 'rb') as f:
                response_file = UploadFile(filename=output_filename, file=f)
                response_audio_url = upload_to_firebase(response_file, user_id, conversation_id)
        except Exception as e:
            print(f"Failed to upload response audio: {e}")
        
        # Store conversation info in memory (similar to text chatbot)
        if conversation_id not in conversations:
            conversations[conversation_id] = {
                'user_id': user_id,
                'messages': [],
                'created_at': datetime.utcnow().isoformat(),
                'type': 'audio'
            }
        
        # Add audio conversation entry
        conversations[conversation_id]['messages'].append({
            'role': 'user',
            'content': f"Audio input: {audio_file.filename}",
            'timestamp': datetime.utcnow().isoformat(),
            'audio_url': None  # Could store input audio URL if needed
        })
        
        conversations[conversation_id]['messages'].append({
            'role': 'assistant',
            'content': f"Audio response: {output_filename}",
            'timestamp': datetime.utcnow().isoformat(),
            'audio_url': response_audio_url
        })
        
        return {
            "success": True,
            "conversation_id": conversation_id,
            "user_id": user_id,
            "input_audio": audio_file.filename,
            "response_audio_url": response_audio_url,
            "response_count": result.get("response_count", 0),
            "message": "Audio conversation processed successfully"
        }
        
    except Exception as e:
        import traceback
        print(f"Live AI processing error: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/live-ai/conversations/{user_id}")
async def get_audio_conversations(user_id: str):
    """Get all audio conversations for a user"""
    try:
        audio_conversations = []
        for conv_id, conv_data in conversations.items():
            if conv_data['user_id'] == user_id and conv_data.get('type') == 'audio':
                audio_conversations.append({
                    'conversation_id': conv_id,
                    'created_at': conv_data['created_at'],
                    'message_count': len(conv_data['messages']),
                    'last_audio_response': next(
                        (msg['audio_url'] for msg in reversed(conv_data['messages']) 
                         if msg['role'] == 'assistant' and msg.get('audio_url')), 
                        None
                    )
                })
        
        return {
            "user_id": user_id,
            "audio_conversations": audio_conversations
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/live-ai/convert-audio")
async def convert_audio_format(
    audio_file: UploadFile = File(...),
    target_sr: int = Form(16000)
):
    """Convert audio file to required format for Live API"""
    try:
        # Save uploaded file temporarily
        temp_input = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
        shutil.copyfileobj(audio_file.file, temp_input)
        temp_input.close()
        
        # Create output file
        output_filename = f"converted_{audio_file.filename}"
        output_path = os.path.join(tempfile.gettempdir(), output_filename)
        
        # Convert audio
        live_ai_service = LiveAIService()
        success = live_ai_service.convert_audio_format(
            input_path=temp_input.name,
            output_path=output_path,
            target_sr=target_sr
        )
        
        # Clean up input file
        os.unlink(temp_input.name)
        
        if not success:
            raise HTTPException(status_code=500, detail="Audio conversion failed")
        
        # Read the converted file and return as response
        with open(output_path, 'rb') as f:
            file_content = f.read()
        
        # Clean up output file
        os.unlink(output_path)
        
        return StreamingResponse(
            io.BytesIO(file_content),
            media_type="audio/wav",
            headers={"Content-Disposition": f"attachment; filename={output_filename}"}
        )
            
    except Exception as e:
        import traceback
        print(f"Audio conversion error: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

# --- News MCP Integration Endpoints ---

@app.get("/news/insight/bangalore")
async def get_bangalore_insight(
    category: str = Query("all", description="Category: all, tech, real_estate, startup, economy, jobs"),
    gl: str = Query("in", description="Country code (default: in for India)"),
    hl: str = Query("en", description="Language code"),
    num: int = Query(5, description="Number of news articles to analyze")
):
    """Get Bangalore-specific financial insights using Gemini"""
    try:
        # Map category to Bangalore-specific search queries
        bangalore_queries = {
            "all": "bangalore financial news economy market",
            "tech": "bangalore tech sector IT companies startup funding",
            "real_estate": "bangalore real estate property prices housing market",
            "startup": "bangalore startup ecosystem funding unicorn",
            "economy": "bangalore economy GDP growth inflation",
            "jobs": "bangalore job market salary IT sector employment",
            "investment": "bangalore investment opportunities stock market",
            "cost_of_living": "bangalore cost of living expenses rent food",
            "transportation": "bangalore transportation fuel prices metro",
            "education": "bangalore education sector colleges universities"
        }
        
        query = bangalore_queries.get(category, "bangalore financial news")
        
        # Get news articles
        news_service = NewsService()
        news_result = news_service.search_news(query, gl, hl, num)
        
        if not news_result["success"]:
            raise HTTPException(status_code=500, detail=news_result.get("error", "Failed to fetch news"))
        
        articles = news_result.get("articles", [])
        if not articles:
            return {
                "success": False,
                "message": f"No news articles found for Bangalore category: {category}",
                "category": category,
                "location": "Bangalore"
            }
        
        # Prepare articles for Gemini analysis
        articles_text = ""
        for i, article in enumerate(articles, 1):
            articles_text += f"{i}. {article.get('title', '')}\n"
            articles_text += f"   Source: {article.get('source', '')}\n"
            articles_text += f"   Summary: {article.get('snippet', '')}\n\n"
        
        # Use Gemini to generate Bangalore-specific insight
        model = genai.GenerativeModel("gemini-2.0-flash")
        
        prompt = f"""
        Based on the following Bangalore financial news articles, provide ONE concise financial insight in exactly one line (max 100 characters).
        
        The insight should be:
        - Specific to Bangalore, India
        - Relevant to {category} category
        - Actionable and practical for Bangalore residents
        - Based on the news content
        - Clear and easy to understand
        - No more than 100 characters
        - Focus on local impact and opportunities
        
        News Articles:
        {articles_text}
        
        Generate ONE Bangalore {category} financial insight:
        """
        
        result = model.generate_content(prompt)
        insight = result.text.strip()
        
        # Clean up the insight
        insight = insight.replace('"', '').replace("'", "").strip()
        if insight.startswith("Insight:"):
            insight = insight[8:].strip()
        if insight.startswith("Financial insight:"):
            insight = insight[18:].strip()
        if insight.startswith("Bangalore insight:"):
            insight = insight[17:].strip()
        
        # Limit to 100 characters
        if len(insight) > 100:
            insight = insight[:97] + "..."
        
        return {
            "success": True,
            "location": "Bangalore",
            "category": category,
            "insight": insight,
            "articles_analyzed": len(articles),
            "timestamp": datetime.utcnow().isoformat(),
            "search_metadata": news_result.get("search_metadata", {}),
            "local_context": {
                "city": "Bangalore",
                "state": "Karnataka",
                "country": "India",
                "timezone": "IST",
                "currency": "INR"
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/news/insight/bangalore/tech")
async def get_bangalore_tech_insight(
    gl: str = Query("in", description="Country code"),
    hl: str = Query("en", description="Language code"),
    num: int = Query(5, description="Number of news articles to analyze")
):
    """Get Bangalore tech sector specific financial insights"""
    return await get_bangalore_insight(category="tech", gl=gl, hl=hl, num=num)

@app.get("/news/insight/bangalore/real-estate")
async def get_bangalore_real_estate_insight(
    gl: str = Query("in", description="Country code"),
    hl: str = Query("en", description="Language code"),
    num: int = Query(5, description="Number of news articles to analyze")
):
    """Get Bangalore real estate specific financial insights"""
    return await get_bangalore_insight(category="real_estate", gl=gl, hl=hl, num=num)

@app.get("/news/insight/bangalore/startup")
async def get_bangalore_startup_insight(
    gl: str = Query("in", description="Country code"),
    hl: str = Query("en", description="Language code"),
    num: int = Query(5, description="Number of news articles to analyze")
):
    """Get Bangalore startup ecosystem specific financial insights"""
    return await get_bangalore_insight(category="startup", gl=gl, hl=hl, num=num)

@app.get("/news/insight/bangalore/cost-of-living")
async def get_bangalore_cost_of_living_insight(
    gl: str = Query("in", description="Country code"),
    hl: str = Query("en", description="Language code"),
    num: int = Query(5, description="Number of news articles to analyze")
):
    """Get Bangalore cost of living specific financial insights"""
    return await get_bangalore_insight(category="cost_of_living", gl=gl, hl=hl, num=num)
@app.post("/create_pass")
def create_pass(
    event_name: str = Body(...),
    barcode_value: str = Body(...),
    class_id: str = Body("shoppingListClass"),
    object_id: str = Body("shoppingListObject"),
    issuer_name: str = Body("PocketSage")
):
    """
    Create a Google Wallet pass for a shopping list, recipe, or event.
    - event_name: The title (e.g., 'Shopping List', 'Banana Bread Recipe')
    - barcode_value: The value to encode (could be a URL, list, or unique string)
    - class_id/object_id: Unique IDs for the pass
    - issuer_name: (optional) Brand name
    """
    try:
        wallet_url = create_wallet_pass(
            class_id=class_id,
            object_id=object_id,
            event_name=event_name,
            barcode_value=barcode_value,
            issuer_name=issuer_name
        )
        return {"wallet_url": wallet_url}
    except Exception as e:
        return {"error": str(e)}

@app.post("/generate-shopping-list")
async def generate_shopping_list(user_id: str = Body(...)):
    """
    Generate a smart shopping list using Gemini based on user's spending patterns.
    """
    try:
        # Get user's recent receipts to analyze spending patterns
        receipts_ref = db.collection("receipts_parsed").where("userId", "==", user_id)
        receipts = receipts_ref.stream()
        
        receipts_data = []
        for receipt in receipts:
            receipt_data = receipt.to_dict()
            receipts_data.append(receipt_data)
        
        if not receipts_data:
            # Return a default shopping list if no receipts found
            default_list = "Milk, Bread, Eggs, Bananas, Chicken, Rice, Vegetables, Yogurt, Cheese, Tomatoes"
            return {"shopping_list": default_list}
        
        # Prepare data for Gemini
        parsed_list = [r.get("parsedData", {}) for r in receipts_data]
        
        # Use Gemini to generate a smart shopping list
        model = genai.GenerativeModel("gemini-2.0-flash")
        prompt = f"""
        Based on the user's recent spending patterns from their receipts, generate a smart shopping list.
        
        Receipt data: {json.dumps(parsed_list[:10])}  # Limit to last 10 receipts
        
        Generate a shopping list that:
        1. Includes common household essentials
        2. Suggests items the user might need based on their spending patterns
        3. Is practical and realistic for a typical shopping trip
        4. Includes 8-12 items maximum
        
        Return ONLY a comma-separated list of items, no explanations or formatting.
        Example: "Milk, Bread, Eggs, Bananas, Chicken, Rice, Vegetables"
        """
        
        result = model.generate_content(prompt)
        shopping_list = result.text.strip()
        
        # Clean up the response
        shopping_list = re.sub(r'^["\']|["\']$', '', shopping_list)  # Remove quotes
        shopping_list = re.sub(r'\n+', ', ', shopping_list)  # Replace newlines with commas
        shopping_list = re.sub(r'\s*,\s*', ', ', shopping_list)  # Clean up spacing
        
        return {"shopping_list": shopping_list}
        
    except Exception as e:
        print(f"Error generating shopping list: {e}")
        # Return a default list on error
        default_list = "Milk, Bread, Eggs, Bananas, Chicken, Rice, Vegetables, Yogurt, Cheese, Tomatoes"
        return {"shopping_list": default_list}

@app.get("/receipt_stats")
def get_receipt_stats(user_id: str = Query(...)):
    """
    Get total number of receipts for a user and breakdown by category.
    Returns: {
        "user_id": str,
        "total_receipts": int,
        "category_breakdown": {
            "groceries": int,
            "utilities": int,
            "transportation": int,
            "dining": int,
            "travel": int,
            "reimbursement": int,
            "home": int
        }
    }
    """
    try:
        # Get all parsed receipts for the user
        receipts_ref = db.collection("receipts_parsed").where("userId", "==", user_id)
        receipts = receipts_ref.stream()
        
        # Initialize category counters
        category_breakdown = {
            "groceries": 0,
            "utilities": 0,
            "transportation": 0,
            "dining": 0,
            "travel": 0,
            "reimbursement": 0,
            "home": 0
        }
        
        total_receipts = 0
        
        # Process each receipt
        for receipt in receipts:
            receipt_data = receipt.to_dict()
            total_receipts += 1
            
            # Get the parsed data
            parsed_data = receipt_data.get('parsedData', {})
            raw_data = parsed_data.get('raw', {})
            
            # Classify the receipt using the existing function
            category = classify_with_gemini(raw_data)
            
            # Increment the appropriate category counter
            if category and category in category_breakdown:
                category_breakdown[category] += 1
            else:
                # If classification fails or returns unknown category, count as "home"
                category_breakdown["home"] += 1
        
        return {
            "user_id": user_id,
            "total_receipts": total_receipts,
            "category_breakdown": category_breakdown
        }
        
    except Exception as e:
        print(f"Error getting receipt stats: {e}")
        return {"error": str(e)}

@app.get("/list_receipts")
def list_receipts(
    user_id: str = Query(...),
    limit: int = Query(50, description="Number of receipts to return (max 100)"),
    offset: int = Query(0, description="Number of receipts to skip"),
    category: str = Query(None, description="Filter by category"),
    sort_by: str = Query("timestamp", description="Sort by field (timestamp, vendor, amount)"),
    sort_order: str = Query("desc", description="Sort order (asc, desc)")
):
    """
    List receipts for a user from both receipts_raw and receipts_parsed collections.
    Returns: {
        "user_id": str,
        "total_count": int,
        "receipts": [
            {
                "receipt_id": str,
                "parsed_id": str,
                "user_id": str,
                "timestamp": str,
                "vendor": str,
                "media_url": str,
                "categories": list,
                "amount": float,
                "status": str,
                "notes": str,
                "parsed_data": dict
            }
        ]
    }
    """
    try:
        # Validate parameters
        limit = min(limit, 100)  # Cap at 100
        if sort_by not in ["timestamp", "vendor", "amount"]:
            sort_by = "timestamp"
        if sort_order not in ["asc", "desc"]:
            sort_order = "desc"
        
        # Get receipts from receipts_raw collection
        raw_receipts_ref = db.collection("receipts_raw").where("userId", "==", user_id)
        raw_receipts = raw_receipts_ref.stream()
        
        # Get receipts from receipts_parsed collection
        parsed_receipts_ref = db.collection("receipts_parsed").where("userId", "==", user_id)
        parsed_receipts = parsed_receipts_ref.stream()
        
        # Create a mapping of parsed receipts by receipt_id for easy lookup
        parsed_receipts_map = {}
        for parsed_doc in parsed_receipts:
            parsed_data = parsed_doc.to_dict()
            receipt_id = parsed_data.get('receiptId')
            if receipt_id:
                parsed_receipts_map[receipt_id] = {
                    'parsed_id': parsed_doc.id,
                    'parsed_data': parsed_data,
                    'categories': parsed_data.get('categories', []),
                    'gemini_raw_output': parsed_data.get('geminiRawOutput', ''),
                    'extra_fields': parsed_data.get('extraFields', {})
                }
        
        # Combine and process receipts
        combined_receipts = []
        
        for raw_doc in raw_receipts:
            raw_data = raw_doc.to_dict()
            receipt_id = raw_data.get('receiptId')
            
            # Get parsed data if available
            parsed_info = parsed_receipts_map.get(receipt_id, {})
            
            # Extract amount from parsed data
            amount = 0.0
            if parsed_info and parsed_info.get('parsed_data'):
                parsed_data = parsed_info['parsed_data'].get('parsedData', {})
                raw_parsed = parsed_data.get('raw', {})
                amount = extract_total_amount_with_gemini(raw_parsed)
            
            # Get vendor information
            vendor = raw_data.get('vendor') or parsed_info.get('parsed_data', {}).get('vendor') or 'Unknown'
            
            # Get categories
            categories = parsed_info.get('categories', [])
            
            # Apply category filter if specified
            if category and category.lower() not in [cat.lower() for cat in categories]:
                continue
            
            # Create receipt object
            receipt_obj = {
                "receipt_id": receipt_id,
                "parsed_id": parsed_info.get('parsed_id'),
                "user_id": user_id,
                "timestamp": raw_data.get('timestamp', ''),
                "vendor": vendor,
                "media_url": raw_data.get('mediaUrl'),
                "categories": categories,
                "amount": amount,
                "status": raw_data.get('status', 'unknown'),
                "notes": raw_data.get('notes', ''),
                "parsed_data": parsed_info.get('parsed_data', {}),
                "gemini_raw_output": parsed_info.get('gemini_raw_output', ''),
                "extra_fields": parsed_info.get('extra_fields', {}),
                "file_name": raw_data.get('fileName', ''),
                "media_type": raw_data.get('mediaType', ''),
                "linked_parsed_id": raw_data.get('linkedParsedId')
            }
            
            combined_receipts.append(receipt_obj)
        
        # Sort receipts
        reverse_sort = sort_order == "desc"
        if sort_by == "timestamp":
            combined_receipts.sort(key=lambda x: x.get('timestamp', ''), reverse=reverse_sort)
        elif sort_by == "vendor":
            combined_receipts.sort(key=lambda x: x.get('vendor', '').lower(), reverse=reverse_sort)
        elif sort_by == "amount":
            combined_receipts.sort(key=lambda x: x.get('amount', 0.0), reverse=reverse_sort)
        
        # Apply pagination
        total_count = len(combined_receipts)
        paginated_receipts = combined_receipts[offset:offset + limit]
        
        return {
            "user_id": user_id,
            "total_count": total_count,
            "receipts": paginated_receipts,
            "pagination": {
                "limit": limit,
                "offset": offset,
                "has_more": offset + limit < total_count
            },
            "filters": {
                "category": category,
                "sort_by": sort_by,
                "sort_order": sort_order
            }
        }
        
    except Exception as e:
        print(f"Error listing receipts: {e}")
        return {"error": str(e)}

if __name__ == "__main__":
    import sys
    if "--transport" in sys.argv:
        mcp.run()
    else:
        import uvicorn
        uvicorn.run(app, host="0.0.0.0", port=8080)
