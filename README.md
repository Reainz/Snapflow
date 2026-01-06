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

Snapflow is a TikTok/Instagram Reels-style short-video sharing platform developed as a **final-year thesis project** by Tran Dinh Nhat Dang (522k0013) and Thu Reain Htet Aung (522k0044). The platform demonstrates modern mobile development practices, serverless backend architecture, and cloud-based video processing pipelines.

The system enables users to create, share, and discover short-form video content (15-60 seconds) with social interactions, real-time features, and AI-powered capabilities including automatic captioning.

### 🎯 Project Objectives

- **Mobile Development**: Cross-platform app using Flutter with GetX state management
- **Serverless Architecture**: Scalable backend using Firebase ecosystem
- **Video Processing Pipeline**: Cloud-based HLS transcoding via Cloudinary API
- **Real-time Features**: Live updates for social interactions using Firestore
- **Admin Dashboard**: Analytics and content moderation interface

---

## ✨ Features

### Core Features
- Video upload and recording (15-60 seconds)
- TikTok-style vertical scrolling feed with HLS streaming
- Social interactions (like, comment, follow, share)
- Real-time push notifications via Firebase Cloud Messaging
- Search and discovery by title, hashtags, or users
- Customizable user profiles with video galleries

### Advanced Features
- Privacy controls (public, private, followers-only)
- AI-powered auto-captions via Cloudinary speech-to-text
- Real-time camera filters during recording
- Offline support with action queuing and sync
- Full dark mode with system-based switching

### Admin Dashboard
- Analytics dashboard with user metrics and engagement tracking
- Content moderation tools for flagged content review
- System health monitoring (processing status, storage, CDN metrics)

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

**Mobile App:** Flutter, GetX (state management), video_player (HLS playback), camera, Firebase SDK

**Backend (Serverless):** Firebase Auth, Cloud Firestore, Firebase Storage, Cloud Functions (Node.js/TypeScript), Firebase Cloud Messaging

**External Services:** Cloudinary (video processing, HLS transcoding, CDN delivery, AI captioning)

**Admin Dashboard:** Next.js, TanStack Query, Recharts, shadcn/ui

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.19+
- Node.js 18+
- Firebase CLI
- Android Studio / Xcode (for mobile development)

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/snapflow.git
   cd snapflow
   ```

2. **Flutter App:**
   ```bash
   flutter pub get
   flutterfire configure --project YOUR_PROJECT_ID --platforms=android,ios
   flutter run
   ```

3. **Cloud Functions:**
   ```bash
   cd functions
   npm ci
   firebase functions:config:set cloudinary.cloud_name="YOUR_CLOUD_NAME" \
     cloudinary.api_key="YOUR_API_KEY" cloudinary.api_secret="YOUR_API_SECRET"
   npm run build && firebase deploy --only functions
   ```

4. **Admin Dashboard:**
   ```bash
   cd snapflow-admin
   npm install
   cp .env.example .env.local  # Edit with your Firebase config
   npm run dev
   ```

For detailed setup instructions, see the documentation in `doc/` directory.

---

## 📁 Repository Structure

### `lib/`
Contains Flutter mobile app implementation with GetX state management.

→ Source code details: [lib/README.md](lib/README.md)

### `functions/`
Contains Firebase Cloud Functions implementation for video processing, analytics, and backend services.

→ Source code details: [functions/README.md](functions/README.md)

### `snapflow-admin/`
Contains Next.js admin dashboard for analytics and content moderation.

→ Source code details: [snapflow-admin/README.md](snapflow-admin/README.md)

### `load-tests/`
Contains k6 load/stress tests for admin dashboard API endpoints and auto-scaling benchmarks.

→ Testing details: [load-tests/README.md](load-tests/README.md)

### `doc/`
Contains project documentation including requirements, architecture, and implementation guides.

→ Documentation: [doc/](doc/)

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

## 🔐 Security

- Firebase Security Rules for Firestore and Storage
- Authenticated delivery via signed URLs for private video content
- Rate limiting protection against upload abuse
- Admin role management with custom claims
- Webhook verification with HMAC signature validation for Cloudinary callbacks

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
cd functions
npm test
```

### Load/Stress Tests (k6)

The `load-tests/` directory contains k6-based load and stress tests for the admin dashboard API endpoints, including auto-scaling benchmark tests that combine k6 load testing with Google Cloud Monitoring API metrics.

**Test Coverage:**
- Unit tests for Cloud Functions (80%+ coverage)
- Widget tests for key UI components
- Integration tests for critical flows
- Load/stress tests for admin dashboard API endpoints

→ Detailed testing documentation: [load-tests/README.md](load-tests/README.md)

---

## 📝 License

This project is developed for educational purposes as part of a final-year thesis.

---

## 👨‍💻 Authors

**Tran Dinh Nhat Dang (522k0013)**  
GitHub: [@monkeynerdcoding](https://github.com/MonkeyNerdCoding)

**Thu Reain Htet Aung (522k0044)**  
GitHub: [@reainz](https://github.com/Reainz)

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - UI framework
- [Firebase](https://firebase.google.com/) - Backend services
- [Cloudinary](https://cloudinary.com/) - Media processing
- [GetX](https://pub.dev/packages/get) - State management
- Academic supervisors and mentors

---

## 📝 Academic Note

This repository is intended for **research and educational purposes only.**

The original algorithm ideas and technologies belong to their respective authors and organizations.
