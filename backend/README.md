# Azure OpenAI Realtime Token Service

A FastAPI backend that generates ephemeral tokens for the Azure OpenAI Realtime API. This service enables secure authentication without exposing API keys in the iOS app.

## Purpose

The iOS app needs to authenticate with Azure OpenAI's Realtime API via WebRTC. Rather than embedding API keys in the app (security risk), this backend:

1. Receives token requests from the iOS app
2. Authenticates with Azure OpenAI using server-side API keys
3. Returns short-lived ephemeral tokens for WebRTC connections

## Setup

### Prerequisites

- Python 3.11+
- Azure OpenAI resource with Realtime API access

### Installation

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -e .

# Configure environment
cp .env.example .env
# Edit .env with your Azure credentials
```

### Configuration

Edit `.env` with your Azure OpenAI credentials:

```
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_API_KEY=your-api-key-here
AZURE_OPENAI_DEPLOYMENT=gpt-realtime-mini
AZURE_OPENAI_TRANSCRIPTION_MODEL=gpt-4o-mini-transcribe
```

### Running

```bash
# Development
uvicorn main:app --reload

# Production (bind to all interfaces)
uvicorn main:app --host 0.0.0.0 --port 8000
```

## API Endpoints

### Health Check

```
GET /health
```

Response:
```json
{
  "status": "healthy",
  "message": "Azure OpenAI Realtime Token Service is running"
}
```

### Generate Token

```
POST /api/v1/token
```

Response:
```json
{
  "token": "ephemeral-token-string",
  "endpoint": "wss://your-resource.openai.azure.com/openai/v1/realtime/calls?webrtcfilter=on"
}
```

## Security Notes

- **Never commit `.env`** - it contains your API key
- In production, restrict CORS origins to your app's domain
- Consider adding rate limiting for the token endpoint
- Ephemeral tokens are short-lived by design

## Architecture

```
iOS App                    Token Service              Azure OpenAI
   │                            │                          │
   │  POST /api/v1/token        │                          │
   │──────────────────────────► │                          │
   │                            │  POST /client_secrets    │
   │                            │────────────────────────► │
   │                            │                          │
   │                            │  { client_secret }       │
   │                            │◄──────────────────────── │
   │  { token, endpoint }       │                          │
   │◄────────────────────────── │                          │
   │                            │                          │
   │  WebRTC connection with ephemeral token               │
   │──────────────────────────────────────────────────────►│
```
