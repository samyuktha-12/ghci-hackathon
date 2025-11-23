from fastapi import FastAPI, Query
import google.generativeai as genai
import os
import uvicorn
from flask_cors import CORS
from flask import Flask

app = Flask(__name__)
CORS(app, resources={r"/chat": {"origins": "*"}})

app = FastAPI()

# Set your Gemini API key
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
genai.configure(api_key=GEMINI_API_KEY)

@app.get("/ask")
def ask_gemini(question: str = Query(..., description="Your question for Gemini")):
    try:
        model = genai.GenerativeModel("gemini-2.0-flash")
        response = model.generate_content([question])
        return {"answer": response.text.strip()}
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)