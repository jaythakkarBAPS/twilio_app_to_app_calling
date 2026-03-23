# Twilio Voice Calling: Implementation & Setup Guide

This guide provides a comprehensive, step-by-step walkthrough for configuring Twilio, Backend Services, and Mobile Platforms (iOS & Android) for seamless app-to-app and PSTN calling.

---

## 1. Twilio Console Configuration

> [!IMPORTANT]
> Ensure you have a verified Twilio account. Trial accounts have limitations such as 10-minute call caps and verified caller ID requirements.

### A. Core Credentials
1. Log in to your [Twilio Console](https://console.twilio.com/).
2. Copy your **Account SID** and **Auth Token** from the Dashboard. These are your primary keys for API access.

### B. Configuring a Phone Number
1. Navigate to **Phone Numbers > Manage > Buy a Number**.
2. Select a number with **Voice** capabilities.
3. Once purchased, this number will be used as your `TWILIO_CALLER_NUMBER`.

### C. Creating a TwiML App
A TwiML App tells Twilio how to handle voice calls by pointing to your backend.
1. Go to **Voice > Manage > TwiML Apps**.
2. Click **Create new TwiML App**.
3. **Friendly Name**: `My Satsang Voice App`.
4. **Voice Configuration**:
   - **Request URL**: `https://<your-server-domain>/make-call`
   - **Method**: `HTTP POST`
5. Save and copy the **TwiML App SID** (`AP...`).

### D. Generating API Keys
1. Go to **Settings > API Keys**.
2. Create a new **Standard API Key**.
3. **Save the API Key SID and API Secret immediately** (the secret will not be shown again).

---

## 2. Push Notifications Setup

Twilio uses VoIP push notifications to wake up the app for incoming calls.

### A. Android (FCM)
1. In Twilio, go to **Voice > Settings > Push Credentials**.
2. Create a new credential of type **FCM**.
3. Enter your **Firebase Server Key** (Found in Firebase Console > Project Settings > Cloud Messaging).
4. Save the **FCM Push Credential SID** (`CR...`).

### B. iOS (APNS)
1. Go to **Voice > Settings > Push Credentials**.
2. Create a new credential of type **APP**.
3. Upload your **VoIP Services Certificate** (.p12) from the Apple Developer Portal.
4. Save the **APN Push Credential SID** (`CR...`).

---

## 3. Backend Implementation (`twilio_server`)

### Prerequisites
- **Node.js**: Installed (v14+)
- **Ngrok**: For local development (to expose local port 3000 to Twilio webhooks).

### Installation
```bash
cd twilio_server
npm install express twilio dotenv
```

### Environment Variables (`.env`)
Create a `.env` file in the `twilio_server` directory. This file stores your sensitive credentials.

| Variable | Description | Source |
| :--- | :--- | :--- |
| `PORT` | Local server port (default 3000) | User Defined |
| `TWILIO_ACCOUNT_SID` | Your primary Twilio Account SID | Twilio Dashboard |
| `TWILIO_API_KEY_SID` | SID of the API Key created in Step 1D | Twilio API Keys |
| `TWILIO_API_KEY_SECRET` | Secret of the API Key created in Step 1D | Twilio API Keys |
| `TWILIO_TWIML_APP_SID` | SID of the TwiML App created in Step 1C | Twilio TwiML Apps |
| `TWILIO_CALLER_NUMBER` | Your purchased Twilio phone number | Twilio Phone Numbers |
| `ANDROID_PUSH_CREDENTIAL_SID` | FCM Push Credential SID from Step 2A | Twilio Push Credentials |
| `IOS_PUSH_CREDENTIAL_SID` | APN Push Credential SID from Step 2B | Twilio Push Credentials |

### Running the Server
```bash
node server.js
```

---

## 4. Inbound Calling Setup (PSTN to App)

To allow users to call your Twilio number from any mobile or landline and have it ring directly in your Flutter app:

1. **Access Active Numbers**: 
   - From the Twilio Console side menu, navigate to **Phone Numbers > Manage > Active Numbers**.
2. **Select Your Number**:
   - Click on the phone number you purchased in Step 1B to open its configuration page.
3. **Configure Voice Webhook**:
   - Scroll down to the **Voice & Fax** section.
   - Look for the label **A CALL COMES IN**.
   - Set the first dropdown to **Webhook**.
   - In the text field, enter your backend's inbound endpoint: 
     `https://<your-server-domain>/inbound-call`
   - Set the method dropdown to **HTTP POST**.
4. **Save Configuration**:
   - Click the **Save** button at the bottom of the page.

> [!TIP]
> If you are testing locally, replace `<your-server-domain>` with your active **Ngrok URL**. Ensure the server is running so Twilio can reach the endpoint.

---

## 5. Platform-Specific Configuration

### Android
- Place `google-services.json` in `android/app/`.
- Ensure package name `org.baps.mysatsang.uat` matches Firebase.
- Permissions: `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, and `POST_NOTIFICATIONS` (for Android 13+).

### iOS
- Enable **Push Notifications** capability in Xcode.
- Enable **Background Modes**: Check `Voice over IP` and `Remote notifications`.
- Ensure the `AppDelegate` implements `PKPushRegistryDelegate` and `CXProviderDelegate` for CallKit.

---

## 6. App Usage Flow

1. **User Identity**: Every user registers with a unique ID (e.g., `user_001`).
2. **App-to-App**: Call `client:user_002` to dial another app user.
3. **App-to-Phone**: Call a phone number (e.g., `+1234567890`) for PSTN calls.
4. **Phone-to-App**: When someone calls your Twilio Number, the server routes it to the designated client identity.
