# Follow/Unfollow Permission Error Fix

## Issue
User encounters "Failed to follow user: Exception: Failed to toggle follow: [cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation" when trying to follow/unfollow other users.

## Root Cause
Firestore security rules in `snapflow/firestore.rules` line 51-53 explicitly prevent client-side updates to `followersCount` and `followingCount` fields:

```dart
allow update: if isOwner(userId)
  && !(request.resource.data.keys().hasAny(['followersCount','followingCount','videosCount']))
  && request.resource.data.id == userId;
```

The `toggleFollow` method in `user_repository.dart` uses batch operations to:
1. Create/delete documents in following/followers subcollections
2. Increment/decrement followersCount and followingCount on user documents

Step 2 is blocked by the security rule.

## Solution
Modify Firestore security rules to allow updating counter fields when they are being incremented/decremented by FieldValue.increment(), which is the proper way to handle these operations.

## Files to Modify
- `snapflow/firestore.rules` - Update user update rule to allow counter field updates via increment operations
