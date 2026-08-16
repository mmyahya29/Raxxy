# Raxxy – Smart Vehicle Monitoring

Raxxy is a Flutter-based smart vehicle monitoring application that tracks driving behaviour in real time, detects crashes, and helps drivers improve safety through analytics and coaching.

## Features

- **Real-time vehicle monitoring** – Tracks speed and acceleration using the device accelerometer and GPS
- **Crash detection** – Automatically detects collisions and sends emergency SMS notifications
- **Driving score calculation** – Analyses each session and produces a score with detailed breakdowns
- **Maintenance tracking** – Reminds drivers of upcoming vehicle maintenance tasks
- **Driver profiling** – Identifies stress triggers and long-term driving patterns
- **Voice coaching & haptic feedback** – Provides in-trip guidance through audio and vibration
- **Turn quality analysis** – Classifies turns as Smooth, Normal, or Jerky based on lateral force
- **Goals & achievements** – Sets personalised driving goals and tracks progress over time

## Setup

### Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) SDK (≥ 3.0)
- A Firebase project with Android/iOS apps registered
- An Android or iOS device (sensors are required; emulators will not work correctly)

### 1. Clone the repository

```bash
git clone https://github.com/mmyahya29/Raxxy.git
cd Raxxy
flutter pub get
```

### 2. Configure Firebase

1. Create a Firebase project at <https://console.firebase.google.com>.
2. Register your Android and iOS apps in the project settings.
3. Run `flutterfire configure` to generate `lib/firebase_options.dart` and the platform-specific config files (`google-services.json`, `GoogleService-Info.plist`).

### 3. Configure environment variables

To use the AI Mechanic feature, you will need a Groq API key. Follow these steps:

1. Create a file named `raxxy.env` in the root directory of the project (at the same level as `pubspec.yaml`).
2. Add your keys to this file like so:
   ```env
   API_KEY=your_actual_groq_api_key_here
   WEATHER_API_KEY=your_actual_openweather_api_key_here
   ```
3. Alternatively, you can copy the example environment file:
   ```bash
   cp raxxy.env.example raxxy.env
   ```
   And then edit the `raxxy.env` file to include your keys.

**Never commit `raxxy.env`** – it contains sensitive keys and is already listed in `.gitignore`.

### 4. Required permissions

The following permissions must be granted on the device at runtime:

| Permission | Purpose |
|---|---|
| Location (fine & background) | GPS speed and position tracking |
| Notifications | Driving event and maintenance alerts |
| SMS | Emergency crash notifications |
| Phone | Emergency call feature |
| Vibration | Haptic feedback coaching |

Permissions are requested automatically when the app starts monitoring.

## Usage

1. Sign in or create an account on the login screen.
2. Add a vehicle in the **Vehicles** tab.
3. Tap **Start Monitoring** on the home screen before driving.
4. The app will track your trip in real time and save a session summary when you tap **Stop**.
5. Review your driving score, event history, and recommendations in the **Analytics** tab.

## Sensor Configuration

See [`docs/SENSOR_CONFIGURATION.md`](docs/SENSOR_CONFIGURATION.md) for a full description of all configurable sensor thresholds (acceleration limits, turn detection, crash detection, cooldown timers, and production vs testing guidance).

## Project Structure

```
lib/
├── Models/                  # Data models
├── authorization_screens/   # Login, sign-up, password reset
├── providers/               # Riverpod state providers
├── screens/                 # Main UI screens
├── services/
│   ├── monitoring_service/  # Core vehicle monitoring logic
│   ├── crash_detector.dart
│   ├── driver_profile_service.dart
│   ├── maintenance_service.dart
│   └── notifications_services.dart
└── widgets/                 # Reusable UI components
```

## License

This project is provided for educational and personal use.
