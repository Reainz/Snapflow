# Snapflow Scripts

This folder contains Node.js scripts for testing and seeding Firebase data.

## Scripts

### 1. storage_e2e_test.mjs

Validates Firebase Storage rules and filename conventions by:
- Creating a minimal Firestore `videos/{videoId}` document
- Uploading `thumbnails/{videoId}.jpg`
- Fetching a signed URL and printing `Cache-Control`

### 2. seed_demo_data.mjs

Seeds the Snapflow database with demo data for testing:
- Creates 6 demo user accounts (demo1@snapflow.test through demo6@snapflow.test)
- Creates 11 demo videos with complete metadata
- Establishes follower relationships between demo users
- Adds engagement data (likes, comments)
- Deletes existing E2E test videos

## General Requirements
- Node 18+
- A Firebase service account JSON with Storage Admin/Firestore access
- Env vars:
  - `GOOGLE_APPLICATION_CREDENTIALS` – absolute path to the service account JSON
  - `FIREBASE_PROJECT_ID` – defaults to `snapflow-4577d` if not provided
  - `FIREBASE_STORAGE_BUCKET` – optional; defaults to `<project>.firebasestorage.app`

Install deps

```powershell
cd "$PSScriptRoot"
npm init -y
npm i firebase-admin node-fetch@3
```

## Usage

### Running storage_e2e_test.mjs

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccount.json"
$env:FIREBASE_PROJECT_ID = "snapflow-4577d"  # optional if default
# Newer Firebase projects use firebasestorage.app, not appspot.com
$env:FIREBASE_STORAGE_BUCKET = "snapflow-4577d.firebasestorage.app"
node .\storage_e2e_test.mjs
```

### Running seed_demo_data.mjs

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccount.json"
$env:FIREBASE_PROJECT_ID = "snapflow-4577d"  # optional if default
node .\seed_demo_data.mjs
```

### Cleaning legacy HLS URLs (non-Cloudinary)

Detect and mark missing legacy Firebase Storage HLS assets. Dry run by default.

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "..\snapflow-e2e-key.json"
node .\cleanup_legacy_hls.mjs              # dry run
$env:APPLY = "true"; node .\cleanup_legacy_hls.mjs   # mark failed + clear hlsUrl
$env:APPLY = "true"; $env:DELETE_DOCS = "true"; node .\cleanup_legacy_hls.mjs  # delete broken docs
```

### Cleaning legacy profile pictures (old avatar path)

After migrating avatars to `profile-pictures/{userId}/avatar.<ext>`, you can remove
any leftover files that still live at the legacy path `profile-pictures/{userId}.<ext>`.
The script is a dry run by default.

```powershell
cd "$PSScriptRoot"
$env:GOOGLE_APPLICATION_CREDENTIALS = "..\snapflow-e2e-key.json"
node .\cleanup_legacy_avatars.mjs                  # dry run - lists legacy files
$env:APPLY = "true"; node .\cleanup_legacy_avatars.mjs   # actually delete legacy root avatars
```

## Demo User Accounts

After running seed_demo_data.mjs, you can sign in with these accounts:

| Username | Email | Password | Bio |
|----------|-------|----------|-----|
| @alexcreator | demo1@snapflow.test | Demo123! | Content creator \| Travel enthusiast |
| @samexplorer | demo2@snapflow.test | Demo123! | Exploring the world one video at a time 🌍 |
| @jordanartist | demo3@snapflow.test | Demo123! | Digital artist sharing my creative journey 🎨 |
| @taylorfitness | demo4@snapflow.test | Demo123! | Fitness coach \| Healthy lifestyle tips 💪 |
| @morgantech | demo5@snapflow.test | Demo123! | Tech enthusiast \| Coding tutorials |
| @rileyfoodie | demo6@snapflow.test | Demo123! | Food blogger \| Recipe creator 🍳 |

Notes
- The script keeps the created video document and thumbnail for manual inspection.
- Cache-Control is set during upload; adjust as needed for your CDN strategy.
- Storage rules derive IDs from filenames using `fileBaseName(name)`; see `doc/new-docs/STORAGE_CDN_CONFIG.md` (section: Filename Conventions).
