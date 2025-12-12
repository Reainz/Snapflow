import 'package:flutter/material.dart';

/// Shadow tier system for consistent elevation
class AppShadows {
  // Tier 1: Subtle (general UI elements)
  static const light = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.08),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  
  // Tier 2: Standard (cards, elevated surfaces)
  static const medium = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.15),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  
  // Tier 3: Strong (modals, overlays)
  static const strong = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.25),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  
  // Tier 4: Premium (glassmorphism, hero elements)
  static const premium = BoxShadow(
    color: Color.fromRGBO(103, 80, 164, 0.3), // Purple accent
    blurRadius: 32,
    offset: Offset(0, 12),
  );
  
  // Tier 5: Recording state (red glow)
  static const recording = BoxShadow(
    color: Color.fromRGBO(244, 67, 54, 0.4), // Colors.red with alpha
    blurRadius: 20,
    spreadRadius: 2,
    offset: Offset(0, 0),
  );

  // Tier 6: Active filter state (purple glow)
  static const activeFilter = BoxShadow(
    color: Color.fromRGBO(156, 39, 176, 0.4), // Colors.purple with alpha
    blurRadius: 16,
    spreadRadius: 2,
    offset: Offset(0, 0),
  );

  // Tier 7: Large circular element shadow
  static const largeCircle = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.3),
    blurRadius: 24,
    spreadRadius: 4,
    offset: Offset(0, 6),
  );

  // Tier 8: Premium glow (for upload overlay)
  static const premiumGlow = BoxShadow(
    color: Color.fromRGBO(103, 80, 164, 0.3), // Purple accent
    blurRadius: 40,
    spreadRadius: -5,
    offset: Offset(0, 20),
  );

  // Tier 9: Subtle header shadow
  static const headerSubtle = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.05),
    blurRadius: 10,
    offset: Offset(0, 2),
  );
}
