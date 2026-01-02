# Snapflow Admin Dashboard - Deployment Guide

**Last Updated:** October 21, 2025  
**Status:** Production Ready

---

## 📍 Production URL

**Vercel Deployment:** https://snapflow-admin.vercel.app  
*(or custom domain: https://admin.snapflow.com)*

---

## 🚀 Quick Deploy

### One-Command Deploy to Vercel

```bash
cd snapflow-admin
vercel --prod
```

---

## 📋 Deployment Information

### Platform Details
- **Platform:** Vercel
- **Region:** Global CDN (automatically distributed)
- **Build Command:** `npm run build`
- **Output Directory:** `.next`
- **Framework:** Next.js 15.5.6
- **Node Version:** 18.x+
- **Install Command:** `npm install`

### Build Configuration
```json
{
  "framework": "nextjs",
  "buildCommand": "npm run build",
  "devCommand": "npm run dev",
  "installCommand": "npm install",
  "outputDirectory": ".next"
}
```

---

## 🔐 Environment Variables

All environment variables must be configured in Vercel dashboard before deployment.

### Required Variables

| Variable Name | Description | Example Value |
|---------------|-------------|---------------|
| `NEXT_PUBLIC_FIREBASE_API_KEY` | Firebase API Key | `AIzaSyDN6Tlko1InF...` |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | Firebase Auth Domain | `snapflow-4577d.firebaseapp.com` |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Firebase Project ID | `snapflow-4577d` |
| `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET` | Firebase Storage Bucket | `snapflow-4577d.firebasestorage.app` |
| `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID` | Firebase Messaging Sender ID | `104537550413` |
| `NEXT_PUBLIC_FIREBASE_APP_ID` | Firebase App ID | `1:104537550413:android:...` |
| `FIREBASE_SERVICE_ACCOUNT_KEY` | **Required for admin middleware**. JSON stringified service account (Base64 not required). | `{"type":"service_account",...}` |

### Setting Environment Variables in Vercel

1. Open Vercel Dashboard: https://vercel.com/dashboard
2. Select **snapflow-admin** project
3. Navigate to **Settings** → **Environment Variables**
4. Add each variable above
5. **Important:** Check all three environment checkboxes:
   - ✅ Production
   - ✅ Preview
   - ✅ Development

### Local Development

Copy `.env.local.example` to `.env.local` and fill in values:

```bash
cp .env.local.example .env.local
```

**Never commit `.env.local` to version control!**

---

## 🌐 Initial Deployment Steps

### Step 1: Install Vercel CLI

```bash
npm install -g vercel
```

### Step 2: Login to Vercel

```bash
vercel login
```

Follow the email verification or GitHub authorization flow.

### Step 3: Link Project

```bash
cd snapflow-admin
vercel
```

Interactive prompts:
- Set up and deploy? **Y**
- Which scope? **Select your account**
- Link to existing project? **N** (first time) or **Y** (if already exists)
- What's your project's name? **snapflow-admin**
- In which directory is your code located? **./**
- Want to modify settings? **N**

### Step 4: Configure Environment Variables

See [Environment Variables](#environment-variables) section above.

### Step 5: Deploy to Production

```bash
vercel --prod
```

**Result:** Production deployment URL (e.g., `snapflow-admin.vercel.app`)

---

## 🔄 Redeployment

### Manual Redeploy (via CLI)

```bash
cd snapflow-admin
vercel --prod
```

### Automatic Deployment (GitHub Integration)

1. Connect Vercel to your GitHub repository
2. **Automatic triggers:**
   - Push to `main` branch → Automatic production deployment
   - Pull request → Preview deployment
   - Merge PR → Automatic production deployment

### Rollback to Previous Version

1. Open Vercel Dashboard
2. Navigate to **Deployments**
3. Find previous successful deployment
4. Click **"..."** menu → **Promote to Production**

---

## 🌍 Custom Domain Configuration (Optional)

### Add Custom Domain

**Example:** `admin.snapflow.com`

1. In Vercel Dashboard → **snapflow-admin** project
2. Navigate to **Settings** → **Domains**
3. Click **Add Domain**
4. Enter your domain: `admin.snapflow.com`
5. Follow DNS configuration instructions

### Update DNS Records

**Option A: Using CNAME Record** (Recommended)

Add at your domain registrar:

```
Type: CNAME
Name: admin
Value: cname.vercel-dns.com
TTL: 3600
```

**Option B: Using A Record**

```
Type: A
Name: admin (or @ for root domain)
Value: 76.76.21.21
TTL: 3600
```

### Verify Domain

```bash
nslookup admin.snapflow.com
```

Wait 5-60 minutes for DNS propagation.

**HTTPS is automatic** via Vercel (Let's Encrypt SSL certificates).

---

## 📊 Monitoring & Analytics

### Vercel Analytics

- **Dashboard:** Vercel Dashboard → Analytics
- **Metrics:** Page views, unique visitors, top pages
- **Real-time:** Live visitor tracking

### Firebase Console Monitoring

- **Firestore Usage:** https://console.firebase.google.com/project/snapflow-4577d/firestore
- **Auth Users:** Firebase Console → Authentication
- **Cloud Functions Logs:** Firebase Console → Functions

### Application Logs

- **Vercel Functions Logs:** Vercel Dashboard → Logs
- **Runtime Logs:** Real-time function execution logs
- **Build Logs:** Full build output history

### Performance Monitoring

**Run Lighthouse Audit:**
1. Open production URL in Chrome
2. Open DevTools (F12)
3. Navigate to **Lighthouse** tab
4. Select **Desktop** mode
5. Click **Generate report**

**Target Scores:**
- Performance: > 90
- Accessibility: > 95
- Best Practices: > 90
- SEO: > 80

---

## 👤 Admin User Setup

To grant admin access to a user:

### Option 1: Cloud Function (Recommended)

```bash
firebase functions:call assignAdminRole --data '{"email":"user@example.com"}'
```

### Option 2: Update Allowlist

1. Edit `functions/src/auth/allowlist.ts`
2. Add email or domain to allowlist:

```typescript
export const allowedAdmins = [
  'admin@snapflow.com',
  'user@example.com'
];

export const allowedDomains = [
  '@student.tdtu.edu.vn',
  '@tdtu.edu.vn'
];
```

3. Deploy functions:

```bash
cd functions
npm run deploy
```

### Option 3: Existing User

For users who already have accounts:

```bash
firebase functions:call ensureAdminRole --data '{"email":"user@example.com"}'
```

---

## 🧪 Production Testing Checklist

### Critical Path Testing

- [ ] **Authentication**
  - [ ] Login with admin credentials
  - [ ] Login with non-admin (should fail)
  - [ ] Logout and re-login
  - [ ] Session persistence

- [ ] **Dashboard Home**
  - [ ] Stats cards display correctly
  - [ ] Trend indicators show
  - [ ] Real-time updates work (wait 30s)

- [ ] **User Management**
  - [ ] User list loads
  - [ ] Search works
  - [ ] Sort works
  - [ ] Pagination works
  - [ ] Ban/delete actions work

- [ ] **Content Moderation**
  - [ ] Flagged videos display
  - [ ] Approve/remove actions work
  - [ ] Video preview works

- [ ] **Analytics**
  - [ ] Charts render
  - [ ] Date range selection works
  - [ ] Real-time updates work

- [ ] **Alerts**
  - [ ] Alerts display
  - [ ] Acknowledge works
  - [ ] Filters work

- [ ] **Settings**
  - [ ] Profile displays
  - [ ] System info correct
  - [ ] Sign out works

### Cross-Device Testing

- [ ] Desktop browsers (Chrome, Firefox, Edge, Safari)
- [ ] Tablet (iPad or Android tablet)
- [ ] Mobile (iPhone or Android phone)

### Performance Testing

- [ ] Lighthouse score > 90
- [ ] Page load time < 3s
- [ ] No console errors
- [ ] Responsive on all devices

---

## 🛠️ Maintenance

### Regular Updates

**Weekly:**
- Monitor Vercel analytics
- Check Firebase Console for unusual activity
- Review error logs

**Monthly:**
- Update dependencies: `npm update`
- Run security audit: `npm audit fix`
- Run Lighthouse performance audit
- Backup Firestore data

### Security Updates

```bash
npm audit
npm audit fix
```

### Dependency Updates

```bash
npm outdated
npm update
```

---

## 🔧 Troubleshooting

### Build Failures

**Issue:** TypeScript errors during build

**Solution:**
```bash
npm run build
# Fix TypeScript errors shown in output
```

### Environment Variables Not Working

**Issue:** Firebase connection errors

**Solution:**
1. Verify all environment variables in Vercel dashboard
2. Ensure variables are set for Production environment
3. Redeploy: `vercel --prod`

### CORS Errors

**Issue:** Firebase requests blocked by CORS

**Solution:**
- Verify `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` is correct
- Check Firebase Console → Authentication → Settings → Authorized domains
- Add Vercel domain to authorized domains list

### Slow Performance

**Issue:** Slow page loads

**Solution:**
1. Run Lighthouse audit
2. Check Vercel Analytics for bottlenecks
3. Optimize images and assets
4. Enable Vercel Edge caching

---

## 📚 Additional Resources

### Documentation
- [Vercel Documentation](https://vercel.com/docs)
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)

### Support
- Vercel Support: https://vercel.com/support
- Firebase Support: https://firebase.google.com/support
- Project Issues: https://github.com/yourusername/snapflow/issues

---

## 📝 Deployment History

| Date | Version | Changes | Deployed By |
|------|---------|---------|-------------|
| 2025-10-21 | 1.0.0 | Initial deployment | - |

---

## ✅ Success Criteria

- [ ] Web admin dashboard accessible via production URL
- [ ] All environment variables configured correctly
- [ ] Authentication working (admin login/logout)
- [ ] All features functional in production
- [ ] Performance metrics meet targets (Lighthouse > 90)
- [ ] Real-time updates working
- [ ] Cross-device compatibility verified
- [ ] Custom domain configured (if applicable)
- [ ] Admin users can be assigned successfully
- [ ] Monitoring and analytics enabled

---

**Note:** Keep this document updated with each deployment. Record any issues encountered and their solutions for future reference.
