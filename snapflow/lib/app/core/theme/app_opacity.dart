import 'package:flutter/material.dart';

/// Opacity/Alpha tier system for consistent transparency
class AppOpacity {
  static const disabled = 0.38;        // Material Design standard
  static const subtleOverlay = 0.05;   // Very light backgrounds
  static const lightOverlay = 0.1;     // Gradient stops, hints
  static const overlayLight = 0.15;    // Light overlays
  static const overlayMedium = 0.18;   // Medium overlays
  static const mediumOverlay = 0.2;    // Standard overlays
  static const overlayStandard = 0.25; // Standard overlays
  static const overlayStrong = 0.3;    // Strong overlays
  static const overlayIntense = 0.4;   // Intense overlays
  static const overlayHeavy = 0.5;     // Heavy overlays
  static const darkOverlay = 0.6;      // Modal backgrounds
  static const overlayDark = 0.75;     // Dark overlays
  static const overlayVeryDark = 0.85; // Very dark overlays
  static const cardBackground = 0.95;  // White/light cards on dark
  static const textSecondary = 0.7;    // Secondary text
}

/// Animation duration tiers
class AppDurations {
  static const micro = Duration(milliseconds: 150);  // Micro-interactions
  static const quick = Duration(milliseconds: 200);  // Quick transitions
  static const standard = Duration(milliseconds: 300); // Standard transitions
  static const emphasis = Duration(milliseconds: 500); // Emphasis animations
  static const long = Duration(milliseconds: 800);    // Long animations
}

/// Border radius standards
class AppRadius {
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
}

/// Material3 spacing scale (4dp grid system)
class AppSpacing {
  // Base spacing unit (4dp)
  static const base = 4.0;
  
  // Micro spacing (0-8dp)
  static const none = 0.0;
  static const xs = 4.0;      // Extra small - tight spacing
  
  // Small spacing (8-16dp)
  static const sm = 8.0;      // Small - compact UI elements
  static const md = 12.0;     // Medium-small - between elements
  
  // Standard spacing (16-24dp)
  static const lg = 16.0;     // Large - default spacing
  static const xl = 20.0;     // Extra large - comfortable spacing
  static const xxl = 24.0;    // 2X large - generous spacing
  
  // Section spacing (28-40dp)
  static const section = 28.0;  // Section separators
  static const xxxl = 32.0;     // 3X large - major sections
  static const huge = 40.0;     // Huge - hero sections
  
  // Layout spacing (48-64dp)
  static const giant = 48.0;    // Giant - screen margins
  static const massive = 64.0;  // Massive - major layout blocks
  
  // Edge insets helpers
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);
  static const EdgeInsets allSection = EdgeInsets.all(section);
  static const EdgeInsets allXxxl = EdgeInsets.all(xxxl);
  static const EdgeInsets allHuge = EdgeInsets.all(huge);
  static const EdgeInsets allGiant = EdgeInsets.all(giant);
  static const EdgeInsets allMassive = EdgeInsets.all(massive);
  
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets horizontalXxl = EdgeInsets.symmetric(horizontal: xxl);
  static const EdgeInsets horizontalSection = EdgeInsets.symmetric(horizontal: section);
  static const EdgeInsets horizontalXxxl = EdgeInsets.symmetric(horizontal: xxxl);
  
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets verticalXxl = EdgeInsets.symmetric(vertical: xxl);
  static const EdgeInsets verticalSection = EdgeInsets.symmetric(vertical: section);
  static const EdgeInsets verticalXxxl = EdgeInsets.symmetric(vertical: xxxl);
}
