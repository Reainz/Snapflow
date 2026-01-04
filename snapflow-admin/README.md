# Snapflow Web Admin Dashboard

Professional admin dashboard for Snapflow short-video sharing platform.

---

## 📋 Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Environment Variables](#environment-variables)
- [Development](#development)
- [Build & Production](#build--production)
- [Deployment](#deployment)
- [Admin Setup](#admin-setup)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [License](#license)

---

## ✨ Features

### Authentication & Security
- ✅ Admin authentication with Firebase Auth
- ✅ Admin access control with custom claims
- ✅ Protected routes with middleware
- ✅ Session persistence and management

### Dashboard & Analytics
- ✅ Real-time dashboard statistics (users, videos, active users)
- ✅ Trend indicators with percentage changes
- ✅ Interactive analytics charts (user growth, video uploads)
- ✅ Date range filtering for analytics
- ✅ System health monitoring
- ✅ Retention metrics visualization

### User Management
- ✅ Paginated user list with search and sort
- ✅ User profile details display
- ✅ Ban/unban user functionality
- ✅ Delete user with confirmation
- ✅ Real-time user data updates

### Content Moderation
- ✅ Flagged videos review queue
- ✅ Video preview with HLS playback
- ✅ Approve/remove video actions
- ✅ Video metadata display
- ✅ Moderation action confirmations

### System Alerts
- ✅ Active alerts monitoring
- ✅ Severity-based filtering (Critical, Warning, Info)
- ✅ Alert acknowledgment system
- ✅ Real-time alert updates

### Settings & Configuration
- ✅ Admin profile management
- ✅ System information display
- ✅ Sign out functionality

---

## 🛠️ Tech Stack

### Core Framework
- **Next.js 15** - React framework with App Router
- **TypeScript** - Type-safe development
- **React 19** - UI library

### UI & Styling
- **Tailwind CSS v4** - Utility-first CSS framework
- **Shadcn/ui** - Pre-built component library
- **Lucide React** - Icon library
- **Next Themes** - Dark/light theme support

### Backend & Data
- **Firebase v12** - Authentication and Firestore database
- **TanStack Query v5** - Data fetching and caching
- **Zustand** - Lightweight state management

### Visualization
- **Recharts** - Composable chart library

### Additional Libraries
- **date-fns** - Date manipulation
- **sonner** - Toast notifications
- **React Hook Form** - Form state management
- **Zod** - Schema validation

---

## 📦 Prerequisites

- **Node.js 18+** installed
- **npm** or **yarn** package manager
- **Firebase project** with Firestore and Auth enabled
- **Admin user** with custom claim: `admin: true`

---

## 🚀 Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd snapflow-admin
```

2. Install dependencies:
```bash
npm install
```

3. Create environment variables file:
```bash
cp .env.example .env.local
```

---

## 🔐 Environment Variables

Create a `.env.local` file in the root directory:

```env
NEXT_PUBLIC_FIREBASE_API_KEY=your_api_key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your_auth_domain
NEXT_PUBLIC_FIREBASE_PROJECT_ID=snapflow-4577d
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your_storage_bucket
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
NEXT_PUBLIC_FIREBASE_APP_ID=your_app_id
```

**⚠️ Important:** Never commit `.env.local` to version control.

---

## 💻 Development

Start the development server:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

The page auto-updates as you edit files. All changes are hot-reloaded.

---

## 🏗️ Build & Production

### Build for Production

```bash
npm run build
```

This creates an optimized production build in the `.next` folder.

### Start Production Server

```bash
npm run start
```

Runs the built application in production mode.

### Build Output

Expected build output:
- **Route sizes:** < 500KB total (gzipped)
- **Build time:** ~30-60 seconds
- **Zero TypeScript errors**
- **All routes pre-rendered**

---

## 🌐 Deployment

### Deploy to Vercel (Recommended)

1. Install Vercel CLI:
```bash
npm install -g vercel
```

2. Deploy to production:
```bash
vercel --prod
```

3. Add environment variables in Vercel dashboard:
   - Go to Project Settings → Environment Variables
   - Add all variables from `.env.local`
   - Redeploy after adding variables

### Deploy to Production

**Production URL:** https://snapflow-admin.vercel.app

For detailed deployment instructions, environment variable setup, custom domain configuration, and troubleshooting, see [DEPLOYMENT.md](DEPLOYMENT.md).

**Quick Deploy:**
```bash
cd snapflow-admin
vercel --prod
```

**Environment Variables:** Configure in Vercel dashboard before deployment (see DEPLOYMENT.md for full list)

### Deploy to Firebase Hosting (Alternative)

1. Build the application:
```bash
npm run build
```

2. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

3. Initialize Firebase:
```bash
firebase init hosting
```

4. Deploy:
```bash
firebase deploy --only hosting
```

---

## 👤 Admin Setup

### Create Admin User

To grant admin access to a user, run the Cloud Function:

```bash
firebase functions:call assignAdminRole --data '{"email":"admin@example.com"}'
```

This sets the custom claim: `{ admin: true }` on the user's Firebase Auth token.

### Verify Admin Access

1. Login with admin credentials
2. Check that dashboard displays correctly
3. Verify all features are accessible

### Revoke Admin Access

```bash
firebase functions:call revokeAdminRole --data '{"uid":"user_uid_here"}'
```

---

## 📂 Project Structure

```
snapflow-admin/
├── app/                        # Next.js App Router
│   ├── (auth)/                # Authentication routes
│   │   └── login/            # Login page
│   ├── (dashboard)/          # Dashboard routes
│   │   ├── alerts/          # Alerts management
│   │   ├── analytics/       # Analytics dashboard
│   │   ├── settings/        # Settings page
│   │   ├── users/           # User management
│   │   ├── videos/          # Content moderation
│   │   ├── layout.tsx       # Dashboard layout
│   │   └── page.tsx         # Dashboard home
│   ├── layout.tsx           # Root layout
│   └── page.tsx             # Landing page
├── components/              # React components
│   ├── ui/                 # Shadcn/ui components
│   ├── charts/            # Chart components
│   ├── stats/             # Stat card components
│   ├── tables/            # Data table components
│   └── layout/            # Layout components
├── lib/                    # Utility functions
│   ├── api/               # API client functions
│   ├── hooks/             # Custom React hooks
│   ├── firebase/          # Firebase configuration
│   └── utils.ts           # General utilities
├── types/                  # TypeScript type definitions
├── stores/                 # Zustand stores
├── public/                 # Static assets
├── .env.local             # Environment variables
├── next.config.ts         # Next.js configuration
├── tailwind.config.ts     # Tailwind configuration
└── tsconfig.json          # TypeScript configuration
```

---

## 🧪 Testing

### Run Manual Tests

Follow the comprehensive testing guide:

```bash
# Open testing guide
cat TESTING_GUIDE.md
```

### Testing Checklist

- ✅ Authentication flows
- ✅ Dashboard statistics
- ✅ User management actions
- ✅ Content moderation workflow
- ✅ Analytics charts and filters
- ✅ Alerts system
- ✅ Responsive design (mobile, tablet, desktop)
- ✅ Cross-browser compatibility (Chrome, Firefox, Safari, Edge)

### Performance Testing

Run Lighthouse audit in Chrome DevTools:
1. Open Chrome DevTools (F12)
2. Navigate to "Lighthouse" tab
3. Select "Desktop" mode
4. Click "Generate report"

**Target Metrics:**
- Performance: > 90
- Accessibility: > 95
- Best Practices: > 90
- SEO: > 80

---

## 📚 Documentation

- **[TESTING_GUIDE.md](./TESTING_GUIDE.md)** - Comprehensive testing procedures and test cases
- **[MVP_COMPLETION_SUMMARY.md](./MVP_COMPLETION_SUMMARY.md)** - Initial MVP implementation details
- **[PHASE5_COMPLETION_SUMMARY.md](./PHASE5_COMPLETION_SUMMARY.md)** - User Management implementation
- **[PHASE6_COMPLETION_SUMMARY.md](./PHASE6_COMPLETION_SUMMARY.md)** - Content Moderation implementation
- **[PHASE7_COMPLETION_SUMMARY.md](./PHASE7_COMPLETION_SUMMARY.md)** - Analytics Dashboard implementation
- **[PHASE8_COMPLETION_SUMMARY.md](./PHASE8_COMPLETION_SUMMARY.md)** - Alerts & Settings implementation

---

## 🤝 Contributing

This is a university project for Snapflow. For contributions:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📄 License

MIT License - See LICENSE file for details

---

## 📞 Support

For issues or questions:
- Create an issue in the repository
- Contact the development team
- Review the testing guide for troubleshooting

---

**Project Status:** ✅ Production Ready  
**Last Updated:** January 12, 2025  
**Version:** 1.0.0

---

## 🎯 Quick Start Guide

### For Developers

1. Clone repository
2. Install dependencies: `npm install`
3. Configure `.env.local` with Firebase credentials
4. Start dev server: `npm run dev`
5. Open http://localhost:3000

### For Testers

1. Review [TESTING_GUIDE.md](./TESTING_GUIDE.md)
2. Ensure admin user exists with custom claim
3. Run through all test cases
4. Report bugs using the bug template
5. Verify all features work correctly

### For Deployment

1. Build application: `npm run build`
2. Deploy to Vercel: `vercel --prod`
3. Configure environment variables in Vercel
4. Test production deployment
5. Monitor performance and errors

---

Built with ❤️ for Snapflow
