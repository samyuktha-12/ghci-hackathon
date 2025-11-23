# Environment Variables Setup

This document describes all the environment variables required for the PocketSage API endpoints.

## Required Environment Variables

### Firebase Configuration
- `FIREBASE_BUCKET`: Your Firebase storage bucket name (e.g., `pocketsage-466717.appspot.com`)
- `FIREBASE_SERVICE_ACCOUNT_JSON`: Path to your Firebase service account JSON file

### Gemini API Keys
- `GEMINI_API_KEY`: Your Google Gemini API key
- `GOOGLE_GENAI_API_KEY`: Alternative Google GenAI API key (used by Live AI service)

### News API Keys (Optional - for news service)
- `SERP_API_KEY`: SERP API key for news search
- `GOOGLE_NEWS_API_KEY`: Alternative Google News API key

### Email Service Configuration (Optional - for email features)
- `SENDER_EMAIL`: Email address to send emails from (e.g., `your-email@gmail.com`)
- `SENDER_PASSWORD`: App password for the email account (for Gmail, use App Password)

### Google Wallet Configuration (Optional - for wallet pass features)
- `GOOGLE_WALLET_ISSUER_ID`: Your Google Wallet issuer ID

## Setup Instructions

1. Create a `.env` file in the `api-endpoints` directory
2. Copy the template below and fill in your actual values:

```bash
# Firebase Configuration
FIREBASE_BUCKET=your-firebase-bucket-name
FIREBASE_SERVICE_ACCOUNT_JSON=/path/to/your/firebase-service-account.json

# Gemini API Keys
GEMINI_API_KEY=your-gemini-api-key-here
GOOGLE_GENAI_API_KEY=your-google-genai-api-key-here

# News API Keys (SERP API or Google News API)
SERP_API_KEY=your-serp-api-key-here
GOOGLE_NEWS_API_KEY=your-google-news-api-key-here

# Email Service Configuration
SENDER_EMAIL=your-email@gmail.com
SENDER_PASSWORD=your-app-password-here
```

3. Make sure your Firebase service account JSON file is stored securely and NOT committed to the repository
4. The `.env` file is already in `.gitignore` and will not be committed

## Firebase Service Account Setup

1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate a new private key
3. Save the JSON file to a secure location outside the repository
4. Set the `FIREBASE_SERVICE_ACCOUNT_JSON` environment variable to the full path of this file

## Security Notes

- **NEVER** commit your `.env` file or Firebase service account JSON files to the repository
- **NEVER** share your API keys or service account credentials
- Use environment variables or secure secret management in production
- Rotate your API keys regularly

