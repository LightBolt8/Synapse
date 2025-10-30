# CAC AI Project - Deployment Guide

Complete guide for deploying the backend locally and frontend on Android emulator.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Backend Setup](#backend-setup)
3. [Frontend Setup](#frontend-setup)
4. [Starting the Emulator](#starting-the-emulator)
5. [Running the Application](#running-the-application)
6. [Troubleshooting](#troubleshooting)
7. [Testing Checklist](#testing-checklist)

---

## Prerequisites

### Required Software

#### 1. Flutter SDK (Version 3.10.0 or higher)
```bash
flutter --version
```
**Expected output:** Flutter 3.10.0 or higher with Dart 3.0.0 or higher

**Installation:**
- Download from: https://docs.flutter.dev/get-started/install
- Follow platform-specific instructions for your OS

#### 2. Python 3.x (Version 3.8 or higher)
```bash
python --version
# or
python3 --version
```

**Installation:**
- macOS: `brew install python3`
- Windows: Download from https://www.python.org/downloads/
- Linux: `sudo apt install python3 python3-pip`

#### 3. Android SDK & Tools

**Required Components:**
- Android SDK Platform 34 (Android 14) - **minimum required**
- Android SDK Build-Tools 30.0.0 or higher
- Android SDK Platform-Tools
- Android Emulator

**Check Installation:**
```bash
# Check if Android SDK is installed
echo $ANDROID_HOME  # Should show path like /Users/yourname/Android/sdk

# List installed platforms
ls $ANDROID_HOME/platforms/
# Should see: android-34 (or android-35)
```

**Installation via Android Studio:**
1. Open Android Studio → SDK Manager
2. SDK Platforms tab → Check "Android 14.0 (API 34)"
3. SDK Tools tab → Check:
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - Android Emulator

---

## Backend Setup

### Step 1: Configure Firebase Credentials

You need three Firebase configuration files:

#### 1.1 Backend Service Account Key
**File:** `backend/serviceAccountKey.json`

**How to get it:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `wonderhoy-pro-max-ai-project`
3. Navigate to: **Project Settings** → **Service Accounts**
4. Click **"Generate New Private Key"**
5. Save the downloaded file as `serviceAccountKey.json` in the `backend/` folder

**File structure should look like:**
```json
{
  "type": "service_account",
  "project_id": "wonderhoy-pro-max-ai-project",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",
  "client_email": "firebase-adminsdk-xxxxx@...",
  ...
}
```

#### 1.2 Frontend Android Configuration
**File:** `backend/google-services.json`

**How to get it:**
1. Firebase Console → Project Settings → Your Apps
2. Select your Android app (or create one if it doesn't exist)
3. Download `google-services.json`
4. Place in `backend/` folder (will be copied to frontend during build)

### Step 2: Configure Environment Variables

**File:** `backend/.env`

Create or verify the `.env` file contains:

```env
FIREBASE_PROJECT_ID=wonderhoy-pro-max-ai-project
ENVIRONMENT=development
API_PORT=8000
OPENAI_API_KEY=your-openai-api-key-here
DEV_MODE=true
FIREBASE_API_KEY=your-firebase-api-key-here
```

**Important:**
- The backend runs on **port 8080** by default (not 8000)
- If `PORT` env variable is not set, it defaults to 8080
- The `API_PORT=8000` is unused; actual port is 8080

**Get your OpenAI API Key:**
1. Go to https://platform.openai.com/api-keys
2. Create a new secret key
3. Copy and paste into `.env`

### Step 3: Install Backend Dependencies

```bash
cd backend
pip install -r requirements.txt
```

**If you encounter permission errors:**
```bash
pip install --user -r requirements.txt
```

**Dependencies installed:**
- fastapi==0.104.1
- uvicorn==0.24.0
- firebase-admin==6.2.0
- python-dotenv==1.0.0
- PyPDF2==3.0.1
- Pillow>=11.0.0
- python-multipart==0.0.6
- requests==2.31.0

### Step 4: Start the Backend Server

```bash
# From the backend directory
python main.py
```

**Expected output:**
```
INFO:     Started server process [xxxxx]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
```

✅ **Backend is now running on http://0.0.0.0:8080**

**Keep this terminal open!** The backend must stay running.

---

## Frontend Setup

### Step 1: Copy Firebase Configuration

Copy the `google-services.json` to the Android app folder:

```bash
# From project root
cp backend/google-services.json frontend/android/app/google-services.json
```

**Verify the file exists:**
```bash
ls -la frontend/android/app/google-services.json
```

### Step 2: Configure API URL

**File:** `frontend/lib/services/api_service.dart`

Verify the baseUrl points to the emulator-accessible backend:

```dart
static const String baseUrl = 'http://10.0.2.2:8080/api/v1';
```

**Important:** `10.0.2.2` is a special IP that Android emulators use to access the host machine's localhost.

### Step 3: Install Flutter Dependencies

```bash
cd frontend
flutter pub get
```

**Expected output:**
```
Resolving dependencies...
Got dependencies!
```

### Step 4: Fix file_picker Plugin (Important!)

The `file_picker` plugin may have a build issue. Apply this fix:

```bash
# Find your Flutter cache directory
cd ~/.pub-cache/hosted/pub.dev/file_picker-*/android/

# Edit build.gradle
# Change line: compileSdk flutter.compileSdkVersion
# To: compileSdk 34
```

**Automated fix (Linux/macOS):**
```bash
find ~/.pub-cache/hosted/pub.dev/file_picker-*/android/ -name "build.gradle" -exec sed -i.bak 's/compileSdk flutter.compileSdkVersion/compileSdk 34/g' {} \;
```

**Windows PowerShell:**
```powershell
$file = Get-ChildItem -Path "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\" -Filter "build.gradle" -Recurse | Where-Object { $_.FullName -like "*file_picker*" } | Select-Object -First 1
(Get-Content $file.FullName) -replace 'compileSdk flutter.compileSdkVersion', 'compileSdk 34' | Set-Content $file.FullName
```

---

## Starting the Emulator

### Option 1: Check for Existing Emulators

```bash
emulator -list-avds
```

If you see an emulator name (e.g., `Pixel_7_API_34`, `My_Android_Emulator`), skip to **Step 2**.

### Option 2: Create a New Emulator (if needed)

#### Check Your System Architecture

```bash
uname -m
```

- Output `arm64` → You have **Apple Silicon (M1/M2/M3)**
- Output `x86_64` → You have **Intel processor**

#### Install System Image

**For Apple Silicon (M1/M2/M3):**
```bash
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-34;google_apis_playstore;arm64-v8a"
```

**For Intel Macs/Windows/Linux:**
```bash
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-34;google_apis_playstore;x86_64"
```

#### Create Emulator

**Via Android Studio (Recommended):**
1. Open Android Studio
2. Tools → Device Manager
3. Click **"Create Device"**
4. Select: **Pixel 7** (or similar)
5. Select System Image:
   - API Level 34 (Android 14)
   - ABI: `arm64-v8a` (Apple Silicon) or `x86_64` (Intel)
   - Target: **Google Play**
6. Name: Choose any name (e.g., `My_Emulator`, `Android_Test`)
7. RAM: 2048 MB
8. Click **"Finish"**

**Via Command Line:**
```bash
# For Apple Silicon
# Replace "My_Emulator" with your preferred name
avdmanager create avd -n My_Emulator -k "system-images;android-34;google_apis_playstore;arm64-v8a" -d "pixel_7"

# For Intel
# Replace "My_Emulator" with your preferred name
avdmanager create avd -n My_Emulator -k "system-images;android-34;google_apis_playstore;x86_64" -d "pixel_7"
```

### Step 2: Start the Emulator

**From Android Studio:**
- Device Manager → Click **Play** button next to your emulator

**From Command Line:**
```bash
# Replace "My_Emulator" with your actual emulator name
emulator -avd My_Emulator -no-snapshot-load -no-audio &
```

### Step 3: Verify Emulator is Running

```bash
adb devices
```

**Expected output:**
```
List of devices attached
emulator-5554    device
```

⚠️ **Wait 1-2 minutes for the emulator to fully boot before proceeding.**

---

## Running the Application

### Step 1: Verify Flutter Detects the Emulator

```bash
cd frontend
flutter devices
```

**Expected output:**
```
2 connected devices:

sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64 • Android 14 (API 34)
```

### Step 2: Clean Build (First Time)

```bash
flutter clean
flutter pub get
```

### Step 3: Run the App

```bash
flutter run -d emulator-5554
```

**Build Time:**
- First build: 2-5 minutes (Gradle downloads dependencies)
- Subsequent builds: 30-60 seconds

**Expected output:**
```
Launching lib/main.dart on sdk gphone64 arm64 in debug mode...
Running Gradle task 'assembleDebug'...
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...
Syncing files to device sdk gphone64 arm64...

Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h List all available interactive commands.
q Quit (terminate the application on the device).
```

✅ **The app should now appear on your emulator!**

---

## Troubleshooting

### Issue 1: `compileSdk` Version Mismatch

**Note:** This project is already configured with `compileSdk = 35` by default. You should not encounter this issue unless the configuration was modified.

**Error (if you see it):**
```
Your project is configured to compile against Android SDK 34, but the following plugin(s) require to be compiled against a higher Android SDK version:
- flutter_plugin_android_lifecycle compiles against Android SDK 35
```

**Solution:**

Verify or update `frontend/android/app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.example.frontend"
    // Required by flutter_plugin_android_lifecycle (35 is backward compatible with 34)
    compileSdk = 35  // Should already be set to 35
    ndkVersion = "27.0.12077973"
    ...
}
```

Then run:
```bash
flutter clean
flutter pub get
flutter run
```

### Issue 2: `withValues` Method Not Found

**Error:**
```
Error: The method 'withValues' isn't defined for the class 'Color'.
```

**Solution:**

This occurs with older Dart versions. Replace `withValues` with `withOpacity`:

```dart
// Old (Dart 3.5+):
Colors.black.withValues(alpha: 0.06)

// New (Dart 3.0+):
Colors.black.withOpacity(0.06)
```

**Files to check:**
- `frontend/lib/main.dart:248`
- `frontend/lib/instructor_my_classes_page.dart:123`

### Issue 3: Backend Connection Timeout

**Error:**
```
Exception: Login failed: Connection timeout
```

**Checklist:**

1. **Verify backend is running:**
   ```bash
   curl http://localhost:8080/api/v1/health
   ```

2. **Check frontend API URL:**
   - File: `frontend/lib/services/api_service.dart`
   - Should be: `http://10.0.2.2:8080/api/v1`
   - NOT: `http://localhost:8080/api/v1`

3. **Check firewall settings** (allow port 8080)

4. **Restart both backend and emulator**

### Issue 4: file_picker Build Failure

**Error:**
```
A problem occurred evaluating project ':file_picker'.
> Could not get unknown property 'flutter' for extension 'android'
```

**Solution:**

Apply the file_picker fix from **[Frontend Setup - Step 4](#step-4-fix-file_picker-plugin-important)**.

### Issue 5: Gradle Build Fails with "SDK not found"

**Error:**
```
SDK location not found. Define location with sdk.dir in local.properties
```

**Solution:**

Edit `frontend/android/local.properties`:

```properties
sdk.dir=/path/to/your/Android/sdk
flutter.sdk=/path/to/your/flutter
```

**Find your SDK paths:**
```bash
# Android SDK
echo $ANDROID_HOME

# Flutter SDK
which flutter | sed 's|/bin/flutter||'
```

### Issue 6: "Execution failed for task ':app:compileDebugKotlin'"

**Solution:**

Update Gradle and Kotlin versions in `frontend/android/settings.gradle.kts`:

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.1.0" apply false  // Update version
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false  // Update version
}
```

### Issue 7: Emulator Won't Start

**Solution:**

```bash
# Kill existing emulator processes
pkill -9 qemu-system

# Restart ADB
adb kill-server
adb start-server

# Try starting emulator again (replace with your emulator name)
emulator -avd My_Emulator -no-snapshot-load
```

### Issue 8: "Dart SDK version ^3.8.1 not found"

**Solution:**

The `pubspec.yaml` has been updated to support Dart 3.0+. Run:

```bash
cd frontend
flutter pub get
```

If you still have issues, check your Flutter version:
```bash
flutter --version
# You need Flutter 3.10.0+ (includes Dart 3.0.0+)
```

**Upgrade Flutter if needed:**
```bash
flutter upgrade
```

---

## Testing Checklist

Use this checklist to verify your deployment:

### Backend

- [ ] Backend starts without errors
- [ ] Health endpoint responds: `curl http://localhost:8080/api/v1/health`
- [ ] Firebase credentials loaded (check terminal for "✅ Firebase Admin SDK initialized")
- [ ] OpenAI API key configured (no errors about missing API key)

### Frontend

- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] `google-services.json` exists in `frontend/android/app/`
- [ ] API URL set to `http://10.0.2.2:8080/api/v1`
- [ ] No compilation errors

### Emulator

- [ ] Emulator listed in `emulator -list-avds`
- [ ] Emulator shows in `adb devices` as "device" (not "offline")
- [ ] Emulator fully booted (home screen visible)

### App Running

- [ ] App builds successfully (Gradle completes)
- [ ] App installs on emulator
- [ ] App launches and shows start screen
- [ ] Sign up works (create new account)
- [ ] Login works (authenticate existing user)
- [ ] Can create a class (instructor)
- [ ] Can join a class (student)
- [ ] AI chat responds

### Hot Reload Test

- [ ] Make a small change to `frontend/lib/main.dart`
- [ ] Press `r` in Flutter terminal
- [ ] Changes appear instantly in emulator

---

## Common Configuration Values

### Port Numbers

| Service | Port | Access URL (from host) | Access URL (from emulator) |
|---------|------|------------------------|----------------------------|
| Backend | 8080 | http://localhost:8080 | http://10.0.2.2:8080 |

### File Locations

| File | Purpose | Required |
|------|---------|----------|
| `backend/serviceAccountKey.json` | Firebase Admin SDK credentials | ✅ Yes |
| `backend/google-services.json` | Firebase Android app config | ✅ Yes |
| `backend/.env` | Environment variables (API keys) | ✅ Yes |
| `frontend/android/app/google-services.json` | Copy of backend google-services.json | ✅ Yes |
| `frontend/lib/services/api_service.dart` | API endpoint configuration | ✅ Yes |
| `frontend/android/app/build.gradle.kts` | Android build configuration | ✅ Yes |

---

## Development Tips

### Hot Reload vs Hot Restart

**Hot Reload (Press `r`):**
- Fast (< 1 second)
- Preserves app state
- Use for UI changes, widget updates

**Hot Restart (Press `R`):**
- Slower (2-5 seconds)
- Resets app state
- Use for logic changes, new dependencies

### Viewing Logs

**Flutter logs:**
```bash
# Already visible in flutter run terminal
```

**Backend logs:**
```bash
# Check the terminal where you ran `python main.py`
```

**Android logcat:**
```bash
adb logcat | grep flutter
```

### Clearing Cache

**Flutter cache:**
```bash
cd frontend
flutter clean
rm -rf build/
flutter pub get
```

**Gradle cache:**
```bash
cd frontend/android
./gradlew clean
```

---

## Support & Resources

### Documentation Links

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com/)
- [Android Emulator Guide](https://developer.android.com/studio/run/emulator)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

### Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Search error messages in:
   - Stack Overflow
   - Flutter GitHub Issues
   - Firebase Support
3. Check backend terminal for error logs
4. Check Flutter terminal for build errors

### Clean Reinstall (Last Resort)

If nothing works, perform a clean reinstall:

```bash
# 1. Stop all running processes
pkill -9 qemu-system
pkill -9 python

# 2. Clean Flutter
cd frontend
flutter clean
rm -rf build/
rm -rf .dart_tool/
rm -rf android/.gradle/

# 3. Reinstall dependencies
flutter pub get

# 4. Clean backend
cd ../backend
rm -rf __pycache__/
pip install -r requirements.txt --force-reinstall

# 5. Restart everything
python main.py  # Terminal 1
flutter run     # Terminal 2
```

---

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         Android Emulator                │
│  (CAC AI Flutter App)                   │
│                                          │
│  API URL: http://10.0.2.2:8080/api/v1  │
└─────────────────┬───────────────────────┘
                  │ HTTP Requests
                  ↓
┌─────────────────────────────────────────┐
│         Host Machine (Your Laptop)      │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │  Backend (Port 8080)            │   │
│  │  - FastAPI                      │   │
│  │  - Firebase Admin SDK           │   │
│  │  - OpenAI Integration           │   │
│  └─────────────────────────────────┘   │
│                                          │
│  Connects to:                           │
│  - Firebase Firestore (Cloud)           │
│  - Firebase Authentication (Cloud)      │
│  - OpenAI API (Cloud)                   │
└─────────────────────────────────────────┘
```

---

## Version Compatibility Matrix

| Flutter Version | Dart Version | Supported |
|----------------|--------------|-----------|
| 3.24.x | 3.5.x | ✅ Tested |
| 3.22.x | 3.4.x | ✅ Should work |
| 3.19.x | 3.3.x | ✅ Should work |
| 3.16.x | 3.2.x | ⚠️ May work (test first) |
| 3.13.x | 3.1.x | ⚠️ May work (test first) |
| 3.10.x | 3.0.x | ✅ Minimum supported |
| < 3.10 | < 3.0 | ❌ Not supported |

| Android SDK | Status |
|-------------|--------|
| API 35 (Android 15) | ✅ Recommended |
| API 34 (Android 14) | ✅ Minimum required |
| API 33 (Android 13) | ⚠️ May work |
| < API 33 | ❌ Not supported |

---

**Last Updated:** 2025-10-27

**Project Version:** 1.0.0

Good luck with your deployment! 🚀