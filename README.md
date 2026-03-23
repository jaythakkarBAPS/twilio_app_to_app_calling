# Twilio Calling: App-to-App & App-to-PSTN

A comprehensive Flutter application demonstrating Twilio Voice integration for seamless communication.

## Features

- **App-to-App Calling**: Call other users within the app using unique identities.
- **App-to-Phone (PSTN)**: Dial normal mobile or landline numbers directly from the app.
- **Phone-to-App**: Receive calls from any normal phone number directly in your Flutter app.
- **Native Call UI**: Full integration with **iOS CallKit** and **Android Notifications** for a native calling experience.
- **Background Support**: Receive calls even when the app is in the background or killed.

## Project Structure

- `lib/`: Flutter code including the `TwilioVoiceService`.
- `ios/`: Native Swift implementation using Twilio Voice SDK, PushKit, and CallKit.
- `android/`: Native Kotlin implementation using Twilio Voice SDK and Firebase Cloud Messaging (FCM).
- `twilio_server/`: Node.js server to handle token generation and TwiML routing.

## Setup Instructions

For a detailed, step-by-step guide on configuring Twilio, Firebase, and the backend, please refer to:

👉 **[SETUP_GUIDE.md](./SETUP_GUIDE.md)**

## Quick Start

1. **Clone the repo.**
2. **Setup the Backend**:
   - Go to `twilio_server`, run `npm install`.
   - Configure `.env` with your Twilio credentials.
   - Start the server.
3. **Configure Flutter**:
   - Update your `google-services.json` (Android) and certificates (iOS).
   - Run `flutter pub get`.
4. **Run the app!**

## Technologies Used

- **Flutter**: Cross-platform UI.
- **Twilio Voice SDK**: Real-time communication.
- **Node.js**: Token and TwiML backend.
- **Firebase/FCM**: Android push notifications.
- **PushKit/CallKit**: iOS native call experience.
