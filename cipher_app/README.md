# 🔐 Cipher — Corporate Chat App

A full-featured Flutter corporate chat application with real-time messaging, AI integration, and voice calling.

---

## ✅ Features

- 🔐 **Auth** — Email OTP login via Firebase Auth
- 🏢 **Workspaces** — Create & join via invite code
- 📢 **Channels** — Announcement channels (admin-only posting)
- 💬 **DMs** — 1-on-1 direct messages
- 👥 **Groups** — Group chats with multiple members
- 🧵 **Threads** — Reply to any message in a thread
- 📁 **File Sharing** — All file types (images, video, audio, docs)
- ✏️ **Message Actions** — Edit, delete, copy, share
- 🤖 **AI Assistant** — Powered by Groq API (Llama 3)
- 📞 **Voice Calls** — Powered by Stream Video SDK
- ⚙️ **Settings** — Profile, account, workspace management

---

## 🚀 Setup Guide

### 1. Flutter Setup
```bash
flutter pub get
```

### 2. Firebase Setup
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (creates firebase_options.dart automatically)
flutterfire configure
```
- Go to [Firebase Console](https://console.firebase.google.com)
- Create a new project
- Enable **Authentication** → Email/Password + Email Link
- Enable **Firestore Database**
- Enable **Firebase Storage**
- Enable **Cloud Messaging**

### 3. Groq API Key
- Go to [console.groq.com](https://console.groq.com)
- Create a free account
- Generate an API key
- Replace `YOUR_GROQ_API_KEY` in `lib/core/constants/app_constants.dart`

### 4. Stream SDK Key
- Go to [getstream.io](https://getstream.io)
- Create a free account
- Get your API key
- Replace `YOUR_STREAM_API_KEY` in `lib/core/constants/app_constants.dart`

### 5. Run the App
```bash
flutter run
```

---

## 📁 Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   ├── constants/app_constants.dart
│   ├── theme/app_theme.dart
│   └── router/app_router.dart
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── models/user_model.dart
    │   │   └── repositories/auth_repository.dart
    │   └── presentation/
    │       ├── providers/auth_provider.dart
    │       └── screens/
    │           ├── splash_screen.dart
    │           ├── login_screen.dart
    │           └── otp_screen.dart
    ├── workspace/
    │   ├── data/
    │   │   ├── models/workspace_model.dart
    │   │   └── repositories/workspace_repository.dart
    │   └── presentation/
    │       ├── providers/workspace_provider.dart
    │       └── screens/
    │           ├── workspace_screen.dart
    │           ├── create_workspace_screen.dart
    │           └── join_workspace_screen.dart
    ├── chat/
    │   ├── data/
    │   │   ├── models/
    │   │   │   ├── message_model.dart
    │   │   │   ├── channel_model.dart
    │   │   │   ├── group_model.dart
    │   │   │   └── dm_model.dart
    │   │   └── repositories/chat_repository.dart
    │   └── presentation/
    │       ├── providers/chat_provider.dart
    │       ├── screens/
    │       │   ├── home_screen.dart
    │       │   ├── channel_screen.dart
    │       │   ├── dm_screen.dart
    │       │   ├── group_screen.dart
    │       │   └── thread_screen.dart
    │       └── widgets/
    │           ├── message_bubble.dart
    │           └── message_input_bar.dart
    ├── ai/
    │   ├── data/groq_service.dart
    │   └── presentation/
    │       ├── providers/ai_provider.dart
    │       └── screens/ai_screen.dart
    ├── settings/
    │   └── presentation/
    │       └── screens/
    │           ├── settings_screen.dart
    │           ├── profile_screen.dart
    │           ├── account_screen.dart
    │           └── workspace_settings_screen.dart
    └── calls/
        └── presentation/
            ├── providers/call_provider.dart
            └── screens/voice_call_screen.dart
```

---

## 🔑 Keys to Replace

Open `lib/core/constants/app_constants.dart` and replace:
- `YOUR_GROQ_API_KEY` → Your Groq API key
- `YOUR_STREAM_API_KEY` → Your Stream API key

Run `flutterfire configure` to auto-generate `firebase_options.dart`.

---

## 📦 Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `firebase_auth` | OTP Authentication |
| `cloud_firestore` | Real-time database |
| `firebase_storage` | File storage |
| `stream_video_flutter` | Voice calls |
| `dio` | HTTP client for Groq API |
| `file_picker` | File selection |
| `image_picker` | Image selection |
| `cached_network_image` | Image caching |
| `share_plus` | Share messages |

---

## 💡 Notes

- This app uses **Firebase Auth Email Link** for OTP (passwordless login)
- Firestore security rules should be configured before production use
- Stream SDK free tier supports up to 25 MAU
- Groq free tier supports ~14,400 requests/day

---

Built with ❤️ using Flutter + Firebase + Groq + Stream
