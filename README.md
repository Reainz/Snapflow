# 📱 Snapflow

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Cloudinary](https://img.shields.io/badge/Cloudinary-3448C5?style=for-the-badge&logo=cloudinary&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)

**A modern short-video sharing platform built with Flutter and Firebase serverless architecture**

[Features](#-features) • [Architecture](#-architecture) • [Tech Stack](#-tech-stack) • [Getting Started](#-getting-started) • [Documentation](#-documentation)

</div>

---

## 📖 Overview

Snapflow is a TikTok/Instagram Reels-style short-video sharing platform developed as a **final-year thesis project**. It demonstrates modern mobile development practices, serverless backend architecture, and cloud-based video processing pipelines.

The platform enables users to create, share, and discover short-form video content (15-60 seconds) with social interactions, real-time features, and AI-powered capabilities like automatic captioning.

### 🎯 Project Objectives

- **Mobile Development**: Cross-platform app using Flutter with GetX reactive state management
- **Serverless Architecture**: Scalable backend using Firebase ecosystem
- **Video Processing Pipeline**: Cloud-based HLS transcoding via Cloudinary API
- **Real-time Features**: Live updates for social interactions using Firestore
- **Admin Dashboard**: Comprehensive analytics and content moderation interface

---

## ✨ Features

### Core Features
- 🎥 **Video Upload** - Record or upload short videos (15-60 seconds)
- 📺 **Video Feed** - TikTok-style vertical scrolling feed with HLS streaming
- ❤️ **Social Interactions** - Like, comment, follow, and share functionality
- 🔔 **Push Notifications** - Real-time notifications via Firebase Cloud Messaging
- 🔍 **Search & Discovery** - Find videos by title, hashtags, or users
- 👤 **User Profiles** - Customizable profiles with video galleries

### Advanced Features
- 🔐 **Privacy Controls** - Public, private, and followers-only video settings
- 📝 **Auto Captions** - AI-powered speech-to-text via Cloudinary
- 🎨 **Camera Filters** - Real-time filters during recording
- 💾 **Offline Support** - Queue actions when offline, sync when connected
- 🌙 **Dark Mode** - Full dark theme with system-based switching

### Admin Dashboard
- 📊 **Analytics** - User metrics, video statistics, engagement tracking
- 🛡️ **Content Moderation** - Review and manage flagged content
- 📈 **System Health** - Processing status, storage usage, CDN metrics

---

## 🏗️ Architecture

Snapflow implements **Flow B (Cloudinary HLS)** architecture for video processing:

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Flutter App   │────▶│  Firebase        │────▶│  Cloud Function │
│   (GetX)        │     │  Storage (raw)   │     │  Trigger        │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                                                          ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   HLS Playback  │◀────│  Cloudinary CDN  │◀────│  Cloudinary     │
│   in App        │     │  (processed)     │     │  Processing     │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

### Data Flow
1. **Upload**: User uploads raw video to Firebase Storage
2. **Trigger**: Cloud Function triggers on upload completion
3. **Process**: Cloudinary transcodes to HLS format with thumbnail generation
4. **Store**: Processed files stored in Cloudinary, metadata in Firestore
5. **Deliver**: HLS streams delivered via Cloudinary CDN
6. **Cleanup**: Raw video deleted after successful processing

---

## 🛠️ Tech Stack

### Mobile App
| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform UI framework |
| **GetX** | State management, navigation, dependency injection |
| **video_player** | HLS video playback |
| **camera** | Video recording |
| **firebase_* packages** | Firebase SDK integration |

### Backend (Serverless)
| Technology | Purpose |
|------------|---------|
| **Firebase Auth** | User authentication with social login |
| **Cloud Firestore** | Real-time NoSQL database |
| **Firebase Storage** | Raw video file storage |
| **Cloud Functions** | Serverless backend logic (Node.js/TypeScript) |
| **Firebase Cloud Messaging** | Push notifications |

### External Services
| Technology | Purpose |
|------------|---------|
| **Cloudinary** | Video processing, HLS transcoding, CDN delivery |
| **Cloudinary AI** | Auto-captioning (speech-to-text) |

### Admin Dashboard
| Technology | Purpose |
|------------|---------|
| **Next.js** | React framework for web dashboard |
| **TanStack Query** | Data fetching and caching |
| **Recharts** | Analytics visualizations |
| **shadcn/ui** | UI components |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.19+
- Node.js 18+
- Firebase CLI
- Android Studio / Xcode (for mobile development)

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/snapflow.git
cd snapflow
```

### 2. Flutter App Setup

```bash
cd snapflow

# Install dependencies
flutter pub get

# Configure Firebase (requires Firebase CLI)
flutterfire configure --project YOUR_PROJECT_ID --platforms=android,ios

# Run the app
flutter run
```

### 3. Cloud Functions Setup

```bash
cd snapflow/functions

# Install dependencies
npm ci

# Configure environment variables
firebase functions:config:set \
  cloudinary.cloud_name="YOUR_CLOUD_NAME" \
  cloudinary.api_key="YOUR_API_KEY" \
  cloudinary.api_secret="YOUR_API_SECRET"

# Build and deploy
npm run build
firebase deploy --only functions
```

### 4. Admin Dashboard Setup

```bash
cd snapflow-admin

# Install dependencies
npm install

# Configure environment variables
cp .env.example .env.local
# Edit .env.local with your Firebase config

# Run development server
npm run dev
```

---

## 📁 Project Structure

```
snapflow/
├── snapflow/                    # Flutter mobile app
│   ├── lib/
│   │   ├── app/
│   │   │   ├── core/            # Services, theme, utilities
│   │   │   ├── data/            # Models and repositories
│   │   │   ├── modules/         # Feature modules (GetX pattern)
│   │   │   │   ├── auth/
│   │   │   │   ├── video_feed/
│   │   │   │   ├── video_upload/
│   │   │   │   ├── profile/
│   │   │   │   ├── comments/
│   │   │   │   ├── search/
│   │   │   │   └── notifications/
│   │   │   ├── routes/          # App navigation
│   │   │   └── widgets/         # Shared widgets
│   │   └── main.dart
│   └── functions/               # Firebase Cloud Functions
│       └── src/
│           ├── video/           # Video processing
│           ├── storage/         # Signed URLs, CDN
│           ├── analytics/       # Metrics collection
│           ├── auth/            # Admin role management
│           └── utils/           # Cloudinary, Firestore helpers
│
├── snapflow-admin/              # Next.js admin dashboard
│   ├── app/                     # App router pages
│   ├── components/              # React components
│   └── lib/                     # Utilities and API clients
│
└── doc/                         # Documentation
    ├── main-docs/               # Core project documents
    └── new-docs/                # Implementation guides
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Project Requirements](doc/main-docs/project_requirements.md) | Full requirements specification |
| [System Architecture](doc/main-docs/system_architecture.md) | Technical architecture with GetX integration |
| [Development Plan](doc/main-docs/short_video_dev_plan.md) | Phase-by-phase implementation plan |
| [Cloudinary Flow B](doc/new-docs/CLOUDINARY_FLOW_B_ARCHITECTURE.md) | Video processing pipeline details |
| [Database Schema](doc/new-docs/DATABASE_SCHEMA.md) | Firestore collections structure |
| [Cloud Functions Spec](doc/new-docs/CLOUD_FUNCTIONS_SPEC.md) | Backend function specifications |
| [Theming Guide](snapflow/docs/THEMING_GUIDE.md) | Material Design 3 implementation |

---

## 🎨 Design System

Snapflow is **100% Material Design 3 compliant**:

- **Color System**: Dynamic color scheme with purple seed color
- **Typography**: Material3 text theme tokens
- **Components**: FilledButton, OutlinedButton, TextButton patterns
- **Dark Mode**: Full dark theme with system-based switching
- **Spacing**: 4dp grid system with consistent spacing constants

---

## 🔐 Security

- **Firebase Security Rules**: Comprehensive Firestore and Storage rules
- **Authenticated Delivery**: Signed URLs for private video content
- **Rate Limiting**: Protection against upload abuse
- **Admin Role Management**: Custom claims for admin access
- **Webhook Verification**: HMAC signature validation for Cloudinary callbacks

---

## 📊 Cloud Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `processVideoUpload` | Storage | Process uploaded videos via Cloudinary |
| `processCaptions` | HTTP | Handle Cloudinary transcription webhooks |
| `generateSignedUrl` | Callable | Generate signed URLs for private videos |
| `createVideoDraft` | Callable | Create video metadata with rate limiting |
| `flagVideo` | Callable | User content reporting |
| `aggregateUserAnalytics` | Scheduled | Daily user metrics aggregation |
| `aggregateVideoAnalytics` | Scheduled | Daily video metrics aggregation |
| `systemHealthCheck` | Scheduled | Hourly system health monitoring |

---

## 🧪 Testing

### Flutter App
```bash
cd snapflow
flutter test
```

### Cloud Functions
```bash
cd snapflow/functions
npm test
```

Test coverage includes:
- Unit tests for Cloud Functions (80%+ coverage)
- Widget tests for key UI components
- Integration tests for critical flows

---

## 🤝 Contributing

This is a thesis project, but suggestions and feedback are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is developed for educational purposes as part of a final-year thesis.

---

## 👨‍💻 Authors

**Thu Reain Htet Aung**
- GitHub: [@reainz](https://github.com/Reainz)

**Tran Dinh Nhat Dang**
- GitHub: [@monkeynerdcoding](https://github.com/MonkeyNerdCoding)
---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - UI framework
- [Firebase](https://firebase.google.com/) - Backend services
- [Cloudinary](https://cloudinary.com/) - Media processing
- [GetX](https://pub.dev/packages/get) - State management
- Academic supervisors and mentors

---

<div align="center">

**⭐ Star this repository if you find it helpful!**

</div>
