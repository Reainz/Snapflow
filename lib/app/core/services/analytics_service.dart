import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'error_service.dart';

/// Service for tracking analytics events including geographic data collection.
/// Handles user analytics, video watch time, and geographic distribution.
class AnalyticsService extends GetxService {
  // Dependencies - injected via Get.find()
  late final AuthService _authService;
  late final ErrorService _errorService;
  
  // Lazy getter for Firestore to avoid initialization errors
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    _authService = Get.find<AuthService>();
    _errorService = Get.find<ErrorService>();
  }

  /// Collect geographic data (country code and region) using IP geolocation API.
  /// Uses ipapi.co free tier (no API key required for basic usage).
  /// Returns Map with 'countryCode' and 'region' fields, or null on failure.
  Future<Map<String, String>?> collectGeographicData() async {
    try {
      // Use ipapi.co free tier API (1000 requests/day, no API key required)
      final response = await http.get(
        Uri.parse('https://ipapi.co/json/'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Extract country code (ISO 3166-1 alpha-2) and region
        final countryCode = data['country_code'] as String?;
        final region = data['continent_code'] as String?;
        
        if (countryCode != null && region != null) {
          return {
            'countryCode': countryCode,
            'region': _mapContinentCodeToRegion(region),
          };
        }
      }
      
      Get.log('Failed to fetch geographic data: HTTP ${response.statusCode}');
      return null;
    } catch (e, stackTrace) {
      _errorService.handleError(
        e,
        context: 'collectGeographicData',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Map continent code to human-readable region name.
  String _mapContinentCodeToRegion(String continentCode) {
    switch (continentCode.toUpperCase()) {
      case 'NA':
        return 'North America';
      case 'SA':
        return 'South America';
      case 'EU':
        return 'Europe';
      case 'AS':
        return 'Asia';
      case 'AF':
        return 'Africa';
      case 'OC':
        return 'Oceania';
      case 'AN':
        return 'Antarctica';
      default:
        return 'Unknown';
    }
  }

  /// Log video watch event to Firestore for analytics aggregation.
  /// Called when user leaves a video or video completes.
  Future<void> logVideoWatchEvent({
    required String videoId,
    required int watchDurationSeconds,
    required bool completed,
  }) async {
    try {
      final userId = _authService.currentUser.value?.uid;
      if (userId == null) return;

      await _firestore.collection('video_watch_events').add({
        'videoId': videoId,
        'userId': userId,
        'watchDurationSeconds': watchDurationSeconds,
        'completed': completed,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      // Silent failure - don't disrupt user experience for analytics
      Get.log('Failed to log watch event: $e', isError: true);
      Get.log('Stack trace: $stackTrace', isError: true);
      // Intentionally avoid surfacing a snackbar; analytics failures should stay invisible to users.
    }
  }
}
