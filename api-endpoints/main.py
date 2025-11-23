import os
import google.generativeai as genai
from fastmcp import FastMCP

# === 🔐 Set your Gemini API key here ===
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "YOUR_GEMINI_API_KEY")
genai.configure(api_key=GEMINI_API_KEY)

mcp = FastMCP(name="Gemini QnA MCP")

@mcp.tool
def ask_gemini(question: str) -> str:
    """Ask Gemini a question and get the answer as a string."""
    try:
        model = genai.GenerativeModel("gemini-pro")
        response = model.generate_content([question])
        return response.text.strip()
    except Exception as e:
        return f"Error: {e}"

if __name__ == "__main__":
    mcp.run() 