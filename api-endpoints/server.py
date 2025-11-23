import os
import uuid
from fastapi import FastAPI, File, UploadFile, Form
from fastmcp import FastMCP
from google.cloud import firestore, storage
import google.generativeai as genai
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

app = FastAPI()
mcp = FastMCP(name="Receipt MCP")

# Firebase setup
FIREBASE_BUCKET = os.getenv("FIREBASE_BUCKET", "your-bucket-name")
SERVICE_ACCOUNT_JSON = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", None)
if not SERVICE_ACCOUNT_JSON:
    raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON environment variable must be set to the path of your Firebase service account JSON file")
db = firestore.Client.from_service_account_json(SERVICE_ACCOUNT_JSON)
storage_client = storage.Client.from_service_account_json(SERVICE_ACCOUNT_JSON)
bucket = storage_client.bucket(FIREBASE_BUCKET)

# Gemini setup
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "YOUR_GEMINI_API_KEY")
genai.configure(api_key=GEMINI_API_KEY)

@mcp.tool
def roll_dice(n_dice: int) -> list[int]:
    """Roll `n_dice` 6-sided dice and return the results."""
    return [random.randint(1, 6) for _ in range(n_dice)]

if __name__ == "__main__":
    mcp.run()