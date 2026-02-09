import os
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from pydantic import BaseModel

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(title="Azure OpenAI Realtime Token Service")

# Configure CORS for iOS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to your iOS app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TokenRequest(BaseModel):
    voice: str = "alloy"


# Response models


class TokenResponse(BaseModel):
    token: str
    endpoint: str


class HealthResponse(BaseModel):
    status: str
    message: str


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        message="Azure OpenAI Realtime Token Service is running"
    )


@app.post("/api/v1/token", response_model=TokenResponse)
async def generate_token(request: TokenRequest = TokenRequest()):
    """Generate ephemeral token for Azure OpenAI Realtime API"""
    try:
        deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT")
        azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        api_key = os.getenv("AZURE_OPENAI_API_KEY")

        transcription_model = os.getenv(
            "AZURE_OPENAI_TRANSCRIPTION_MODEL", "gpt-4o-mini-transcribe")

        # Construct the client_secrets endpoint URL
        client_secrets_url = f"{azure_endpoint}/openai/v1/realtime/client_secrets"

        # Session configuration with turn detection for proper VAD
        session_config = {
            "session": {
                "type": "realtime",
                "model": deployment_name,
                "instructions": "You are a helpful assistant. Maintain a calm, even tone throughout the conversation.",
                "audio": {
                    "input": {
                        "transcription": {
                            "model": transcription_model,
                            "language": "en",
                        },
                        "turn_detection": {
                            "type": "server_vad",
                            "threshold": 0.5,
                            "prefix_padding_ms": 300,
                            "silence_duration_ms": 500,
                            "create_response": True,
                        },
                    },
                    "output": {
                        "voice": request.voice,
                    },
                },
            },
        }

        # Make POST request to generate ephemeral token
        async with httpx.AsyncClient() as client:
            response = await client.post(
                client_secrets_url,
                headers={
                    "api-key": api_key,
                    "Content-Type": "application/json",
                },
                json=session_config
            )

        if response.status_code != 200:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Azure API error: {response.text}"
            )

        # Extract the ephemeral token from response
        response_data = response.json()

        # Try different response formats
        ephemeral_token = (
            response_data.get("client_secret", {}).get("value") or
            response_data.get("value") or
            response_data.get("token")
        )

        if not ephemeral_token:
            raise HTTPException(
                status_code=500,
                detail=f"No ephemeral token in response. Got: {response_data}"
            )

        # Construct the Azure WebRTC endpoint
        webrtc_endpoint = f"{azure_endpoint}/openai/v1/realtime/calls?webrtcfilter=on"

        return TokenResponse(
            token=ephemeral_token,
            endpoint=webrtc_endpoint
        )

    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=500,
            detail=f"HTTP error: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate token: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
