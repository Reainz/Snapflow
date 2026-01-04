# Firebase Development Security Rules

These permissive rules are intended for local development and emulator testing only. Do not deploy them to production.

## Firestore Rules (development)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write anywhere during development
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Storage Rules (development)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to read/write anywhere during development
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## How to use

1) Start the Firebase Emulator Suite for safe local testing:

```
firebase emulators:start
```

2) To deploy these rules to a development project (never production):

```
firebase deploy --only firestore:rules,storage
```

3) Replace with restrictive, production-grade rules before going live. Refer to Firebase documentation and tailor rules to your data model (videos, users, likes, comments) with proper validation and ownership checks.

