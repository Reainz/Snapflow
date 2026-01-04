import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'config_service.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';

class AuthService extends GetxService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;
  late final bool _isAndroid;
  DateTime? _lastActivityPingAt;

  final currentUser = Rxn<User>();
  final _isAdmin = false.obs;
  bool get isAdmin => _isAdmin.value;

  Future<void> _pingUserActivity(User user) async {
    // Throttle to avoid excessive writes on token refresh/userChanges events.
    final now = DateTime.now();
    final last = _lastActivityPingAt;
    if (last != null && now.difference(last) < const Duration(minutes: 10)) {
      return;
    }
    _lastActivityPingAt = now;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
        // Keep updatedAt moving for legacy metrics that still rely on it.
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Best-effort; do not block auth flows on analytics updates.
      debugPrint('AuthService: failed to update lastActiveAt: $e');
    }
  }

  Future<void> init() async {
    _isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    
    // CRITICAL FIX: google_sign_in v7.x requires serverClientId on Android
    // This is the Web OAuth client ID from google-services.json
    if (_isAndroid) {
      // Create GoogleSignIn with serverClientId for Android.
      // Prefer runtime-configured value from ConfigService via --dart-define.
      final config = Get.find<ConfigService>();
      final serverClientId = config.firebaseServerClientId;

      if (serverClientId.isNotEmpty) {
        _googleSignIn = GoogleSignIn(serverClientId: serverClientId);
      } else {
        // Fallback: default constructor (may fail if serverClientId is required)
        _googleSignIn = GoogleSignIn();
      }
    } else {
      // For web/iOS, use default GoogleSignIn
      _googleSignIn = GoogleSignIn();
    }
    
  // No need to initialize GoogleSignIn in v6.x or v7.x

    currentUser.value = _auth.currentUser;
    final initial = _auth.currentUser;
    if (initial != null) {
      await _pingUserActivity(initial);
    }
    _auth.userChanges().listen((u) async {
      currentUser.value = u;
      if (u != null) {
        await _pingUserActivity(u);
      }
      await _refreshAdminClaim();
    });
    // Initial claim fetch
    await _refreshAdminClaim();
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      _ensureInitialized();
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final u = cred.user;
      if (u != null) {
        await _pingUserActivity(u);
      }
      // Try to ensure admin role for existing accounts that match allow-list
      await ensureAdminRoleIfAllowed();
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      _ensureInitialized();
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final u = cred.user;
      if (u != null) {
        await _pingUserActivity(u);
      }
      // Best-effort: new users also attempt ensureAdminRole (not required, onCreate covers it)
      await ensureAdminRoleIfAllowed();
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      _ensureInitialized();

  // On Android, if serverClientId is missing, GoogleSignIn may throw configuration errors.

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google Sign-In was cancelled');
        }
      } catch (e) {
        // Check for configuration errors
        if (e.toString().contains('DEVELOPER_ERROR') || 
            e.toString().contains('10') ||
            e.toString().contains('ApiException')) {
          throw Exception(
            'Google Sign-In configuration error.\n\n'
            'The OAuth client IDs are not properly configured.\n'
            'Please check GOOGLE_SIGNIN_QUICK_FIX.md in the project root for setup instructions.\n\n'
            'Common causes:\n'
            '• Missing SHA-1 fingerprint in Firebase Console\n'
            '• Incorrect package name\n'
            '• OAuth client not enabled\n\n'
            'Tip: pass FIREBASE_SERVER_CLIENT_ID or FIREBASE_WEB_CLIENT_ID via --dart-define.\n'
            'Run "./gradlew signingReport" in android/ folder to get SHA-1.',
          );
        }
        
        // Check if user cancelled
        if (e.toString().contains('sign_in_canceled') || 
            e.toString().contains('cancelled')) {
          throw Exception('Google Sign-In was cancelled');
        }
        
        rethrow;
      }

  // Obtain the auth details (must await)
  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Verify we have an idToken
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw Exception('Failed to obtain Google ID token');
      }

      // Create a new credential (v7.x only supports idToken)
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
  final cred = await _auth.signInWithCredential(credential);
  final u = cred.user;
  if (u != null) {
    await _pingUserActivity(u);
  }
  // Ensure admin role after sign-in
  await ensureAdminRoleIfAllowed();
  return cred;
    } on FirebaseAuthException catch (e) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      throw _handleAuthException(e);
    } catch (e) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      
      // If it's already a detailed exception, rethrow it
      if (e.toString().contains('SETUP REQUIRED') || 
          e.toString().contains('configuration error')) {
        rethrow;
      }
      
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _ensureInitialized();
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    _ensureInitialized();
    await Future.wait([
      _auth.signOut(),
      // Guard in case GSI not initialized for some reason
      Future<void>.microtask(() async {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }),
    ]);
    _isAdmin.value = false;
  }

  Exception _handleAuthException(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found with this email address.';
        break;
      case 'wrong-password':
        message = 'Incorrect password. Please try again.';
        break;
      case 'invalid-email':
        message = 'Invalid email address format.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'too-many-requests':
        message = 'Too many failed attempts. Please try again later.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email address.';
        break;
      case 'weak-password':
        message = 'Password is too weak. Please use a stronger password.';
        break;
      case 'operation-not-allowed':
        message =
            'Email/password accounts are not enabled. Please contact support.';
        break;
      default:
        message = 'Authentication failed: ${e.message ?? 'Unknown error'}';
    }
    return Exception(message);
  }

  void _ensureInitialized() {
    if (Firebase.apps.isEmpty) {
      throw Exception(
        'Firebase is not initialized. Please configure Firebase options for this platform.',
      );
    }
  }

  Future<void> _refreshAdminClaim() async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        _isAdmin.value = false;
        return;
      }
      // Force refresh to ensure latest custom claims
      final tokenResult = await u.getIdTokenResult(true);
      final claims = tokenResult.claims ?? const <String, dynamic>{};
      _isAdmin.value = claims['admin'] == true;
    } catch (e) {
      debugPrint('AuthService: failed to refresh admin claim: $e');
      _isAdmin.value = false;
    }
  }

  // Expose a public method to refresh the admin claim on demand
  Future<void> refreshAdminClaim() => _refreshAdminClaim();

  // Call HTTPS callable to ensure admin role for existing accounts
  Future<void> ensureAdminRoleIfAllowed() async {
    try {
      final u = _auth.currentUser;
      if (u == null) return;
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('ensureAdminRole');
      await callable.call();
      // Refresh token to pick up claims if they changed
      await _refreshAdminClaim();
    } catch (e) {
      // Best-effort; ignore failures (may be not allowed / not deployed yet)
      debugPrint('ensureAdminRoleIfAllowed: $e');
    }
  }
}
