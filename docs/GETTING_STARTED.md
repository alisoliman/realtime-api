# Getting Started with Azure OpenAI Realtime iOS Sample

This guide walks you through setting up and running the Azure OpenAI Realtime iOS sample app from scratch.

## Prerequisites

Before you begin, ensure you have:

- **macOS 14.0+** (Sonoma or later)
- **Xcode 16.0+** with iOS 26 SDK
- **Python 3.11+** (check with `python3 --version`)
- **Azure Subscription** ([Create free account](https://azure.microsoft.com/free/))

## Step 1: Set Up Azure OpenAI

### Create Azure OpenAI Resource

1. Go to [Azure Portal](https://portal.azure.com)
2. Click **Create a resource** → Search for **Azure OpenAI**
3. Click **Create** and fill in:
   - **Subscription**: Your Azure subscription
   - **Resource group**: Create new or select existing
   - **Region**: Select a region that supports Realtime API (e.g., East US 2, Sweden Central)
   - **Name**: A unique name for your resource
   - **Pricing tier**: Standard S0
4. Click **Review + create** → **Create**
5. Wait for deployment to complete

### Deploy the Realtime Model

1. Go to your Azure OpenAI resource
2. Click **Model deployments** → **Manage Deployments**
3. Click **+ Create new deployment**
4. Select:
   - **Model**: `gpt-realtime-mini`
   - **Deployment name**: `gpt-realtime-mini` (or your choice)
   - **Deployment type**: Standard
5. Click **Create**

### Get Your Credentials

1. In your Azure OpenAI resource, go to **Keys and Endpoint**
2. Copy:
   - **Endpoint** (e.g., `https://your-resource.openai.azure.com`)
   - **Key 1** (your API key)
3. Note your deployment name from the previous step

## Step 2: Set Up the Backend

### Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/realtime-api.git
cd realtime-api
```

### Create Python Environment

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

### Install Dependencies

```bash
pip install -e .
```

### Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your Azure credentials:

```
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_API_KEY=your-api-key-here
AZURE_OPENAI_DEPLOYMENT=gpt-realtime-mini
AZURE_OPENAI_TRANSCRIPTION_MODEL=gpt-4o-mini-transcribe
```

### Start the Backend

```bash
uvicorn main:app --reload
```

You should see:
```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Started reloader process
```

### Verify Backend

```bash
curl http://localhost:8000/health
```

Expected response:
```json
{"status":"healthy","message":"Azure OpenAI Realtime Token Service is running"}
```

## Step 3: Run the iOS App

### Open in Xcode

1. Open `realtime-api.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies

### Configure Signing

1. Select the project in the navigator
2. Select the **realtime-api** target
3. Go to **Signing & Capabilities**
4. Select your **Team** (requires Apple Developer account)
5. Xcode will create a provisioning profile automatically

### Run on Simulator

1. Select an iOS 26+ Simulator (e.g., iPhone 16 Pro)
2. Press **⌘R** or click the Run button
3. The app will build and launch in Simulator

### First Launch

1. Tap the **+** button to start a new conversation
2. Grant microphone permission when prompted
3. Start speaking! The assistant will respond in real-time
4. Tap **End** to save the conversation

## Running on Physical Device

### Option A: Same Network (Development)

1. Find your Mac's IP address:
   ```bash
   ipconfig getifaddr en0
   ```

2. Start backend on all interfaces:
   ```bash
   uvicorn main:app --host 0.0.0.0
   ```

3. In Xcode:
   - Edit Scheme (⌘<)
   - Select **Run** → **Arguments**
   - Add Environment Variable:
     - Name: `BACKEND_URL`
     - Value: `http://YOUR_MAC_IP:8000`

4. Run on your device

### Option B: Deploy Backend (Production)

For production, deploy the backend to a cloud service:

- **Azure App Service**: [Quickstart](https://learn.microsoft.com/azure/app-service/quickstart-python)
- **Railway**: [Python deployment](https://docs.railway.app/guides/python)
- **Render**: [FastAPI guide](https://render.com/docs/deploy-fastapi)

Then update `BACKEND_URL` to your deployed service URL.

## Troubleshooting

### "Couldn't reach backend"

- Ensure backend is running (`uvicorn main:app`)
- Check the URL is correct (`http://127.0.0.1:8000` for Simulator)
- For device: ensure both are on same network and using Mac's IP

### "Microphone permission denied"

- Go to Settings → Privacy & Security → Microphone
- Enable permission for the app
- Restart the app

### "Azure API error"

- Verify `.env` credentials are correct
- Ensure deployment name matches exactly
- Check Azure OpenAI resource has Realtime API access
- Verify region supports Realtime API

### Build Errors

- Ensure Xcode 16.0+ is installed
- Clean build folder: **Product** → **Clean Build Folder** (⇧⌘K)
- Reset package caches: **File** → **Packages** → **Reset Package Caches**

### No Audio Response

- Check device volume is up
- Ensure Azure OpenAI model is deployed and active
- Check backend logs for errors

## Next Steps

- Explore the codebase to understand the architecture
- Customize the assistant's instructions in `backend/main.py`
- Try different voice options in the Settings screen
- Add your own features!

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review [Azure OpenAI documentation](https://learn.microsoft.com/azure/ai-services/openai/)
3. Open an issue on GitHub
