import os
import requests
import json
from datetime import datetime
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class NewsService:
    def __init__(self):
        # Get API key from environment
        self.api_key = os.getenv("SERP_API_KEY") or os.getenv("GOOGLE_NEWS_API_KEY")
        if not self.api_key:
            raise ValueError("SERP_API_KEY or GOOGLE_NEWS_API_KEY environment variable must be set")
        
        self.base_url = "https://serpapi.com/search"
        
    def search_news(self, 
                    query: str, 
                    gl: str = "us", 
                    hl: str = "en", 
                    num: int = 10,
                    category: str = None) -> Dict:
        """
        Search for news articles using SerpAPI
        
        Args:
            query: Search query
            gl: Country code (e.g., 'us', 'uk', 'in')
            hl: Language code (e.g., 'en', 'es')
            num: Number of results to return
            category: News category (optional)
            
        Returns:
            Dict containing news results
        """
        try:
            params = {
                "engine": "google_news",
                "q": query,
                "gl": gl,
                "hl": hl,
                "num": num,
                "api_key": self.api_key
            }
            
            # Add category if specified
            if category:
                params["topic_token"] = category
            
            response = requests.get(self.base_url, params=params)
            response.raise_for_status()
            
            data = response.json()
            
            # Extract and format news results
            news_results = []
            if "news_results" in data:
                for article in data["news_results"]:
                    news_results.append({
                        "title": article.get("title", ""),
                        "link": article.get("link", ""),
                        "snippet": article.get("snippet", ""),
                        "source": article.get("source", ""),
                        "date": article.get("date", ""),
                        "thumbnail": article.get("thumbnail", "")
                    })
            
            return {
                "success": True,
                "query": query,
                "total_results": len(news_results),
                "articles": news_results,
                "search_metadata": {
                    "country": gl,
                    "language": hl,
                    "timestamp": datetime.utcnow().isoformat()
                }
            }
            
        except requests.exceptions.RequestException as e:
            return {
                "success": False,
                "error": f"API request failed: {str(e)}",
                "query": query
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Unexpected error: {str(e)}",
                "query": query
            }
    
    def get_financial_news(self, 
                          user_id: str = None, 
                          category: str = "finance",
                          gl: str = "us",
                          hl: str = "en",
                          num: int = 10) -> Dict:
        """
        Get financial news specifically for PocketSage users
        
        Args:
            user_id: User ID for personalization
            category: News category (finance, stocks, crypto, etc.)
            gl: Country code
            hl: Language code
            num: Number of results
            
        Returns:
            Dict containing financial news results
        """
        queries = {
            "finance": "financial news market updates",
            "stocks": "stock market news trading updates",
            "crypto": "cryptocurrency bitcoin ethereum news",
            "economy": "economic news inflation interest rates",
            "personal_finance": "personal finance tips budgeting saving",
            "investment": "investment news portfolio management",
            "banking": "banking news fintech digital payments"
        }
        
        query = queries.get(category, "financial news")
        
        # Add user context if available
        if user_id:
            query += f" personalized financial advice"
        
        return self.search_news(query, gl, hl, num, category)
    
    def get_market_updates(self, 
                          symbols: List[str] = None,
                          gl: str = "us",
                          hl: str = "en") -> Dict:
        """
        Get market updates for specific stocks/symbols
        
        Args:
            symbols: List of stock symbols (e.g., ['AAPL', 'GOOGL'])
            gl: Country code
            hl: Language code
            
        Returns:
            Dict containing market updates
        """
        if not symbols:
            symbols = ["AAPL", "GOOGL", "MSFT", "TSLA"]  # Default tech stocks
        
        query = f"stock news {' '.join(symbols)} market updates"
        
        return self.search_news(query, gl, hl, 15)
    
    def get_economic_indicators(self, 
                               gl: str = "us",
                               hl: str = "en") -> Dict:
        """
        Get news about economic indicators and trends
        
        Args:
            gl: Country code
            hl: Language code
            
        Returns:
            Dict containing economic news
        """
        query = "economic indicators inflation GDP unemployment interest rates"
        
        return self.search_news(query, gl, hl, 10)
    
    def get_personal_finance_tips(self, 
                                 user_id: str = None,
                                 gl: str = "us",
                                 hl: str = "en") -> Dict:
        """
        Get personal finance tips and advice
        
        Args:
            user_id: User ID for personalization
            gl: Country code
            hl: Language code
            
        Returns:
            Dict containing personal finance tips
        """
        query = "personal finance tips saving money budgeting investment advice"
        
        if user_id:
            query += " personalized financial planning"
        
        return self.search_news(query, gl, hl, 8)
    
    def search_trending_topics(self, 
                              gl: str = "us",
                              hl: str = "en") -> Dict:
        """
        Get trending financial topics and news
        
        Args:
            gl: Country code
            hl: Language code
            
        Returns:
            Dict containing trending topics
        """
        query = "trending financial news today market highlights"
        
        return self.search_news(query, gl, hl, 12) 