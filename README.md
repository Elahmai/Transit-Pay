# Transit Pay Kenya 🚍
Smart QR Payment System for public transport (matatus/buses) in Kenya.

## Project Structure
```
transitpay/
├── lib/
│   ├── main.dart                          # App entry point & routes
│   ├── models/models.dart                 # Data models
│   ├── utils/theme.dart                   # Colors, theme, constants, routes
│   ├── services/
│   │   ├── auth_service.dart              # Firebase email/password auth
│   │   ├── wallet_service.dart            # Top-up & fare deduction
│   │   ├── trip_service.dart              # Trip lifecycle & GPS tracking
│   │   ├── vehicle_service.dart           # QR validation & vehicle registration
│   │   └── notification_service.dart      # FCM push notifications
│   ├── widgets/shared_widgets.dart        # Reusable UI components
│   └── screens/
│       ├── auth/
│       │   ├── splash_onboarding.dart     # Splash + 3-slide onboarding
│       │   └── login_screen.dart          # Login / Sign-up / Role select
│       ├── passenger/
│       │   ├── home_screen.dart           # Home + History + Profile tabs
│       │   ├── topup_screen.dart          # M-Pesa wallet top-up
│       │   ├── qr_scanner_screen.dart     # QR scan (start & end trip)
│       │   ├── active_trip_screen.dart    # Live map + distance counter
│       │   └── trip_summary_screen.dart   # Receipt after trip
│       └── driver/
│           └── driver_home_screen.dart    # Dashboard + Trips + QR + Profile
├── functions/
│   ├── src/index.js                       # Cloud Functions (M-Pesa, fare, FCM)
│   └── package.json
├── android/app/src/main/AndroidManifest.xml
├── firestore.rules                        # Security rules
├── firestore.indexes.json                 # Composite indexes
├── firebase.json
└── pubspec.yaml
```

---

## Setup Instructions

### 1. Firebase Project
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project: **transit-pay-kenya**
3. Enable **Authentication → Email/Password**
4. Enable **Firestore Database** (start in production mode)
5. Enable **Firebase Storage**
6. Enable **Firebase Cloud Messaging**
7. Download `google-services.json` → place in `android/app/`

### 2. Google Maps
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Enable **Maps SDK for Android** and **Maps SDK for iOS**
3. Create an API key
4. In `AndroidManifest.xml` replace `AIzaSyALtyMJUS41zsXFMTNVnO_V6PGJWwUcJME` with your actual key

### 3. Flutter Setup
```bash
flutter pub get
flutter run
```

### 4. Deploy Cloud Functions
```bash
cd functions
npm install

# Set environment variables
firebase functions:config:set \
  mpesa.consumer_key="YOUR_KEY" \
  mpesa.consumer_secret="YOUR_SECRET" \
  mpesa.shortcode="YOUR_SHORTCODE" \
  mpesa.passkey="YOUR_PASSKEY" \
  app.base_url="https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net"

# Deploy
firebase deploy --only functions
```

### 5. Deploy Firestore Rules & Indexes
```bash
firebase deploy --only firestore
```

---

## M-Pesa Integration

### MVP (Current)
The app uses **simulated top-up** — no real money moves. Great for testing.

### Production (Daraja API)
1. Register at [developer.safaricom.co.ke](https://developer.safaricom.co.ke)
2. Create an app and get Consumer Key + Secret
3. Subscribe to **Lipa Na M-Pesa Online (STK Push)**
4. Get your Business Shortcode and Passkey from Safaricom
5. Update the Cloud Functions environment variables above
6. Change sandbox URLs to production in `functions/src/index.js`

| Environment | Base URL |
|-------------|----------|
| Sandbox | `https://sandbox.safaricom.co.ke` |
| Production | `https://api.safaricom.co.ke` |

---

## Fare Formula
```
Base Fare:     KSh 20 (flat boarding fee)
Distance Rate: KSh 3 per km
Total Fare:    20 + (distance × 3)
Driver Earns:  95% of total fare (5% platform fee)

Example: 4.2 km trip → KSh 20 + (4.2 × 3) = KSh 32.60
```

---

## User Roles

| Feature | Passenger | Driver |
|---------|-----------|--------|
| Register / Login | ✅ | ✅ |
| Wallet top-up | ✅ | ❌ |
| Scan QR to board | ✅ | ❌ |
| Live trip tracking | ✅ | ❌ |
| Trip history | ✅ | ✅ |
| Generate QR code | ❌ | ✅ |
| Earnings dashboard | ❌ | ✅ |

---

## Android Permissions Required
- `ACCESS_FINE_LOCATION` — GPS during trip
- `ACCESS_BACKGROUND_LOCATION` — GPS when app is backgrounded
- `CAMERA` — QR code scanning
- `POST_NOTIFICATIONS` — Push notifications (Android 13+)

---

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x / Dart 3 |
| Auth | Firebase Email/Password |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| Functions | Firebase Cloud Functions (Node 18) |
| Maps | Google Maps Flutter |
| Location | Geolocator |
| QR Scan | mobile_scanner |
| QR Display | qr_flutter |
| Payments | Safaricom Daraja API (M-Pesa) |
| Push | Firebase Cloud Messaging |
