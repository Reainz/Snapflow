@echo off
REM Script to get SHA-1 fingerprint for Google Sign-In setup (Windows)
REM This is needed to configure OAuth 2.0 client in Firebase Console

echo ==========================================
echo Getting SHA-1 Certificate Fingerprint
echo ==========================================
echo.
echo This SHA-1 fingerprint is required for:
echo - Google Sign-In configuration
echo - Firebase Dynamic Links
echo - Google Maps API (if used)
echo.
echo You'll need to add this to Firebase Console:
echo 1. Go to console.firebase.google.com
echo 2. Select your project
echo 3. Go to Project Settings
echo 4. Scroll to 'Your apps' section
echo 5. Click on your Android app
echo 6. Click 'Add fingerprint'
echo 7. Paste the SHA-1 below
echo.
echo ==========================================
echo Running Gradle signing report...
echo ==========================================
echo.

REM Run the signing report
gradlew.bat signingReport

echo.
echo ==========================================
echo Look for the SHA-1 under 'Variant: debug'
echo It looks like: SHA-1: XX:XX:XX:XX...
echo ==========================================
echo.
echo For RELEASE builds, also get the release SHA-1:
echo keytool -list -v -keystore ^<your-release-keystore^> -alias ^<your-alias^>
echo.

pause

