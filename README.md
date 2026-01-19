# Azure OpenAI Realtime iOS Sample

[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS 26+](https://img.shields.io/badge/iOS-26+-blue.svg)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A sample iOS app demonstrating real-time voice conversations with Azure OpenAI's GPT-4o Realtime API using WebRTC.

![App Screenshot](docs/screenshot.png)
<!-- TODO: Add actual screenshot before launch -->

## Features

- 🎤 **Real-time voice conversations** with GPT-4o
- 📝 **Live transcription** of both user and assistant speech
- 💾 **Conversation history** persisted with SwiftData
- 🔊 **Multiple voice options** (Alloy, Echo, Shimmer, etc.)
- 📤 **Share transcripts** via iOS share sheet

## Quick Start

### Prerequisites

- macOS 14.0+ with Xcode 16.0+
- Python 3.11+
- Azure subscription with [Azure OpenAI access](https://learn.microsoft.com/azure/ai-services/openai/overview)

### 1. Clone and Configure Backend

```bash
git clone https://github.com/YOUR_USERNAME/realtime-api.git
cd realtime-api/backend

# Setup Python environment
python3 -m venv .venv && source .venv/bin/activate
pip install -e .

# Configure Azure credentials
cp .env.example .env
# Edit .env with your Azure OpenAI credentials
```

### 2. Start the Token Service

```bash
uvicorn main:app --reload
```

Verify it's running: `curl http://localhost:8000/health`

### 3. Run the iOS App

1. Open `realtime-api.xcodeproj` in Xcode
2. Select your development team (Signing & Capabilities)
3. Run on Simulator (⌘R)

For detailed setup instructions, see [Getting Started Guide](docs/GETTING_STARTED.md).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   SwiftUI    │◄──►│  ViewModel   │◄──►│  SwiftData   │  │
│  │    Views     │    │              │    │  (SQLite)    │  │
│  └──────────────┘    └──────┬───────┘    └──────────────┘  │
│                             │                               │
│                    ┌────────▼────────┐                     │
│                    │  RealtimeAPI    │                     │
│                    │  (WebRTC)       │                     │
│                    └────────┬────────┘                     │
└─────────────────────────────┼───────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               │
     ┌────────────────┐  ┌────────────┐      │
     │ Token Backend  │  │ Azure      │      │
     │ (FastAPI)      │  │ OpenAI     │◄─────┘
     │ /api/v1/token  │  │ Realtime   │  WebRTC audio
     └───────┬────────┘  └────────────┘
             │
             ▼
     ┌────────────────┐
     │ Azure OpenAI   │
     │ /client_secrets│
     └────────────────┘
```

**Key Components:**

| Component | Technology | Purpose |
|-----------|------------|---------|
| iOS App | SwiftUI, SwiftData | Voice conversation UI |
| ViewModel | Swift, async/await | Business logic, API integration |
| RealtimeAPI | WebRTC | Real-time audio streaming |
| Token Backend | Python, FastAPI | Secure token generation |

## Project Structure

```
realtime-api/
├── realtime-api/              # iOS app source
│   ├── Models/                # SwiftData entities
│   ├── ViewModels/            # Business logic
│   ├── Views/                 # SwiftUI views
│   └── Services/              # API clients
├── backend/                   # Python token service
│   ├── main.py               # FastAPI app
│   └── .env.example          # Environment template
└── docs/                      # Documentation
    └── GETTING_STARTED.md    # Setup guide
```

## Configuration

### Backend Environment Variables

| Variable | Description |
|----------|-------------|
| `AZURE_OPENAI_ENDPOINT` | Your Azure OpenAI resource URL |
| `AZURE_OPENAI_API_KEY` | API key from Azure Portal |
| `AZURE_OPENAI_DEPLOYMENT` | Deployment name (e.g., `gpt-4o-realtime-preview`) |
| `AZURE_OPENAI_TRANSCRIPTION_MODEL` | Whisper model for transcription |

### iOS Configuration

The app automatically connects to `http://127.0.0.1:8000` on Simulator. For physical devices, set `BACKEND_URL` in the Xcode scheme environment variables.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Resources

- [Azure OpenAI Realtime API Documentation](https://learn.microsoft.com/azure/ai-services/openai/realtime-audio-quickstart)
- [swift-realtime-openai Package](backend/swift-realtime-openai/README.md)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
