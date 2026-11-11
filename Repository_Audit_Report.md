# Raxxy Repository Audit Report

**Repository:** `mmyahya29/Raxxy`  
**Audited revision:** `902abf5e6351b263696f85fdf77c90ee93e8ed3e` (`main`)  
**Audit date:** 2026-11-11  
**Audit mode:** Read-only static and Git-history audit  
**Application execution:** Not performed  
**Permitted repository change:** This report only

## Executive Summary

Raxxy is a Flutter/Dart smart-vehicle-monitoring prototype integrating Firebase Authentication/Firestore, device sensors, GPS, crash detection, emergency SMS, maintenance reminders, driver profiling, goals, weather, notifications, text-to-speech, haptics, and a Groq-backed mechanic chat feature. The application has a substantial authored Dart implementation, but the repository also contains a large Flutter platform scaffold, generated configuration, a vendored `flutter_sms` package, binary assets, lockfiles, and template remnants.

The repository is **not ready for production release based on static evidence**. The highest-priority concerns are client-side transmission of an AI API key, `usesCleartextTraffic="true"`, broad sensitive Android permissions, an unverified/missing backend security-rules layer, missing iOS Firebase configuration, placeholder web Firebase configuration, a stale default counter test, an absent root license, and the inability to run the Flutter toolchain in this environment. These findings do not prove an exploitable vulnerability in a deployed system; they identify material risk and release blockers visible in the repository.

The codebase appears to be a collaborative academic/personal project with a mixed contributor history. Git metadata explicitly records commits by `copilot-swe-agent[bot]`, so AI-assisted development is verified for portions of the history. Git metadata cannot prove who authored individual source lines, whether code was copied from elsewhere, or whether the repository owner has rights to every asset and dependency.

## Scope and Method

The audit examined:

- Tracked files and physical line counts at the audited revision.
- `README.md`, `pubspec.yaml`, platform configuration, assets, tests, and source imports.
- Static references to authentication, Firestore, sensors, GPS, SMS, networking, credentials, placeholders, logging, and TODOs.
- Local Git history, author identities, commit signatures, branches, repository metadata, and object integrity.
- GitHub repository security-alert/workflow metadata where the account integration permitted read access.

The audit did **not** execute application code, install dependencies, run Flutter/Dart tests, build an APK/IPA/web bundle, inspect Firebase rules in the cloud, validate runtime behavior on a device, or perform penetration testing. Counts below are physical lines, including blank lines and comments unless stated otherwise.

## Project Purpose and Technology Stack

### Purpose

The README describes Raxxy as a real-time vehicle-safety and driver-coaching application (`README.md:1-14`). The source structure and imports support the following implemented feature areas:

| Area | Static evidence |
|---|---|
| Authentication and account data | `lib/authorization_screens/login_screen.dart`, `signup_screen.dart`, `resetpassword_screen.dart`; Firebase Auth/Firestore providers in `lib/providers/provider.dart:1-24` |
| Vehicle monitoring | `lib/services/monitoring_service/vehicle_monitor_service.dart:33-41`, GPS stream handling at `:489-563`, sensor/event processing throughout the file |
| Crash protocol | `lib/services/crash_detector.dart:12-205`; monitoring-triggered crash flow in `vehicle_monitor_service.dart:939-1057` |
| Emergency SMS/guardian flow | `lib/services/crash_detector.dart:145-175`, `lib/screens/guardian_alert_screen.dart:48`; local `flutter_sms` dependency |
| Driving score and session summaries | `lib/services/monitoring_service/driving_score_service.dart`, `session_summary_service.dart` |
| Maintenance | `lib/services/maintenance_service.dart`, `lib/screens/maintenance_subscreens/maintenance_widget.dart` |
| Driver profiling and goals | `lib/services/driver_profile_service.dart`, `goal_generation_service.dart` |
| Weather | `lib/providers/weather_api_provider.dart:25-40`, `lib/Models/weather_model.dart` |
| Voice/haptic/notifications | `lib/services/notifications_services.dart:1-222`, `crash_detector.dart:29-46` |
| Track mapping | `lib/screens/track_screens/track_mapping_screen.dart:33-81` |
| Mechanic chat | `lib/screens/maintenance_subscreens/chat_bot_screen.dart:11-42`, `:209-236` |
| Firebase | `firebase.json`, `lib/firebase_options.dart`, `android/app/google-services.json` |

### Stack

- Flutter application using Dart SDK constraint `^3.7.0` (`pubspec.yaml:19-22`).
- Riverpod, Firebase Auth/Firestore/Core, sensors, geolocation, maps, notifications, SMS, audio, vibration, TTS, dotenv, HTTP, charting, and local persistence dependencies (`pubspec.yaml:30-93`).
- Android Gradle Kotlin DSL with Android Gradle Plugin `8.11.1`, Kotlin `2.2.0`, Java 17 target, and Firebase services (`android/build.gradle.kts`, `android/app/build.gradle.kts:1-56`).
- iOS, macOS, Linux, Windows, and web Flutter scaffolding is present, but not all platform configuration is complete.
- A local copy of `flutter_sms` version 2.3.3 is vendored under `packages/flutter_sms-2.3.3`.

## Repository Metrics

### File and line totals

| Metric | Verified value | Definition |
|---|---:|---|
| Tracked files | **358** | `git ls-files` at the audited revision |
| Tracked text files | **237** | Files identified as text by Git content inspection |
| Tracked binary/non-text files | **121** | Mostly PNG/JPG/icon assets and other binary resources |
| Raw tracked text LOC | **25,660** | Physical lines across tracked text files, including dependencies, templates, generated files, comments, and configuration |
| Eligible authored application source files | **46** | Dart files under `lib/`, excluding generated `lib/firebase_options.dart` |
| Eligible authored application LOC | **13,873** | Physical lines in those 46 Dart files |
| Excluded LOC | **11,787** | Raw tracked text LOC minus eligible authored application LOC |
| Verified project-owned implementation LOC | **13,873** | Same conservative source set; ownership/provenance is verified by repository location/history, not legal originality |
| Local vendored package | **128 files / 9,409 LOC** | `packages/flutter_sms-2.3.3`; excluded as third-party code |
| Tracked assets | **6 files** | Five images and `assets/data/mechanic_data.json`; excluded from source LOC |
| Commits reachable from all refs | **146** | `git rev-list --count --all` |
| First-parent commits | **95** | `git rev-list --count --first-parent HEAD` |
| Git branches | **5** | `main` plus four `copilot/*` branches |

The raw-to-eligible arithmetic is intentionally conservative: `25,660 - 13,873 = 11,787` excluded lines. The excluded total includes platform scaffolding, generated files, vendored code, tests, documentation, lockfiles, configuration, and other non-eligible text. Binary file byte sizes are not converted into LOC.

### Eligible source LOC by language

| Language | Eligible files | Eligible LOC | Notes |
|---|---:|---:|---|
| Dart | 46 | **13,873** | Application implementation under `lib/`, excluding generated Firebase options |
| Kotlin | 0 | 0 | Present Kotlin is platform/plugin scaffold and excluded |
| Java | 0 | 0 | Java is confined to the vendored package example/plugin area |
| Swift | 0 | 0 | Present Swift is standard iOS/macOS scaffold |
| Objective-C | 0 | 0 | Platform scaffold only |
| C/C++ | 0 | 0 | Desktop Flutter runner/scaffold only |
| JavaScript/TypeScript | 0 | 0 | Web file is Flutter template/configuration, not eligible authored application source |
| Python/PHP | 0 | 0 | No eligible authored files |

The language table is an eligibility table, not a claim that the repository contains no files in those languages. Platform and vendored files were deliberately excluded.

## Implemented Features Versus Placeholder or Incomplete Areas

### Substantially implemented in source

The repository contains non-trivial source for authentication screens, vehicle CRUD/UI, monitoring state, accelerometer/gyroscope/GPS processing, crash dialogs and SMS fallback, Firestore persistence, driver-profile calculations, maintenance rules, session summaries, goals, weather retrieval, notifications, TTS, haptic feedback, track mapping, and a conversational maintenance screen. These are verified by source paths and symbols; runtime correctness was not tested.

### Placeholder, stale, or incomplete indicators

1. `pubspec.yaml:2` and `web/index.html:19` still say **“A new Flutter project.”**
2. `web/index.html:43-49` contains `YOUR_API_KEY`, `YOUR_PROJECT_ID`, and related placeholder Firebase values. The web target is therefore not configured for the repository’s Firebase project.
3. `test/widget_test.dart:14-28` is the default counter smoke test and expects `MyApp` to expose a counter and add button. It does not test Raxxy behavior and is likely stale relative to the application.
4. `README.md:80` links to `docs/SENSOR_CONFIGURATION.md`, but that file is absent at the audited revision.
5. `lib/screens/dashboard_subscreens/sos_screen.dart:45` logs “not real yet,” indicating at least one SOS path is explicitly unfinished even though other guardian/crash paths exist.
6. `lib/screens/maintenance_subscreens/chat_bot_screen.dart:40` falls back to the literal `default_value` when the API key is absent. This is a failure-prone placeholder, not a safe production configuration.
7. `raxxy.env` is absent, while `main.dart:19` unconditionally loads it and `pubspec.yaml:107-114` declares it as an asset. The documented setup requires a developer-created file; an unconfigured checkout is not directly runnable.
8. There are no localization resource directories or generated localization files identified in the tracked tree. Localization was therefore excluded from the LOC calculation as a category, but no material localization implementation was found.

## Security and Privacy Findings

### High priority

**Client-side AI credential exposure risk.** The mechanic chat reads `dotenv.env['API_KEY']` and sends it directly as an HTTP `Authorization: Bearer` header (`lib/screens/maintenance_subscreens/chat_bot_screen.dart:38-42`, `:211-218`). A dotenv value bundled into a client application is recoverable by users or through a distributed artifact. The fallback `default_value` can also produce misleading authentication behavior. Use a server-side proxy or short-lived, scoped credentials and fail explicitly when configuration is absent.

**Cleartext traffic is enabled.** `android/app/src/main/AndroidManifest.xml:25-26` sets `android:usesCleartextTraffic="true"`. This permits HTTP traffic at the Android application policy level and should be removed unless a documented, narrowly scoped legacy endpoint requires it. The inspected weather and Groq URLs are HTTPS, but the manifest setting broadens future exposure.

**Sensitive permission surface is broad.** The Android manifest requests background location, SMS read/receive/send, phone state, phone calls, storage, notifications, wake lock, and audio permissions (`android/app/src/main/AndroidManifest.xml:4-19`). The source demonstrates some location, SMS, notification, and wake-lock use, but the audit did not establish that every requested permission is necessary on every supported Android version. Apply least privilege, explain consent, and verify Play Store policy eligibility for SMS/background location.

### Medium priority

**Backend access control is not auditable from this repository.** The app writes to user, vehicle, track, goal, and session Firestore paths, but no Firestore rules file is present. Client-side path conventions are not a substitute for server-side authorization. Firebase rules, indexes, App Check, quotas, and production project settings must be reviewed separately.

**Firebase configuration is committed.** `lib/firebase_options.dart` is explicitly generated by FlutterFire (`:1`) and contains client configuration values; `android/app/google-services.json` is also tracked. Firebase API keys are generally client identifiers rather than server secrets, but repository owners must still enforce Firebase Auth, Firestore rules, API restrictions, quotas, and App Check. The report intentionally does not reproduce any credential-like values.

**Sensitive telemetry is persisted.** Monitoring and session services write driving, location, vehicle, and profile-related data to Firestore (`lib/services/monitoring_service/vehicle_monitor_service.dart:973-1088`, `session_summary_service.dart:347-359`, `driver_profile_service.dart:613-636`). Retention, consent, deletion, and access policies are not documented in the repository.

**Production logging is verbose.** Direct `print` calls remain in crash, SOS, score, goal, maintenance, and startup paths, including potentially sensitive contact/location context (`lib/services/crash_detector.dart:92-175`, `lib/main.dart:62`, `lib/screens/dashboard_subscreens/sos_screen.dart:42-45`). Replace with a controlled, redacted logging strategy before release.

### GitHub security metadata

- Dependabot alerts are disabled; no dependency-alert result was available.
- Code-scanning reported “no analysis found.”
- Secret-scanning results were not accessible through the current integration.
- Two dynamic Copilot workflow definitions are present, but no application CI workflow was identified.

These API results are availability/status observations, not evidence that the repository is free of vulnerabilities.

## Code Quality and Build Readiness

### Positive indicators

- Clear high-level separation into screens, providers, services, and reusable widgets.
- Firebase, sensor, GPS, notification, and telemetry concerns are separated into named services.
- `analysis_options.yaml` and `flutter_lints` are present.
- `.gitignore` excludes `raxxy.env`, build output, Dart tool state, and common IDE artifacts.
- Git object integrity check (`git fsck --full --no-reflogs --unreachable`) returned no errors, and `git diff --check` was clean.

### Quality concerns

- The only tracked test is a generic Flutter counter test (`test/widget_test.dart:1-30`) rather than feature tests for authentication, permissions, crash thresholds, SMS fallback, persistence, or scoring.
- The source contains 38 `catch` occurrences and 11 `dynamic` occurrences by simple static count. This is not itself a defect, but it indicates areas requiring typed error contracts and targeted tests.
- Direct `print` usage is widespread in operational code; several services use `debugPrint`, but logging is not consistently centralized.
- The dependency manifest includes a prerelease Riverpod constraint (`flutter_riverpod: ^3.0.0-dev.16`) and a broad, hardware-sensitive dependency set. Compatibility with the declared Flutter SDK and all platform targets was not verified.
- The README says Flutter “≥ 3.0” (`README.md:20`) while `pubspec.yaml` requires Dart `^3.7.0` (`:21-22`); the documentation is inconsistent.
- The app uses the default Android application ID/namespace `com.example.raxxy` (`android/app/build.gradle.kts:12-29`) and iOS bundle ID `com.example.raxxy` in generated options (`lib/firebase_options.dart:61-68`), which is unsuitable for a finalized release identity.

### Build readiness blockers

The Flutter and Dart executables were not available in the audit environment, so `flutter pub get`, `flutter analyze`, `flutter test`, and platform builds were not run. Static blockers and prerequisites include:

- `android/app/google-services.json` is present, but `ios/Runner/GoogleService-Info.plist` is absent.
- `raxxy.env` is intentionally absent from the checkout and is required by the documented setup and `main.dart:19`.
- Web Firebase configuration remains placeholder-only.
- `local.properties` is absent, which is normal for a developer checkout but required to locate a local Flutter SDK for Android Gradle setup.
- The README references a deleted/missing sensor-configuration document.

Build readiness is therefore **unverified and currently incomplete for web/iOS** based on repository contents.

## Git History, Contributors, and Authenticity

### Verified history facts

- Repository created: 2025-07-31; first commit `f6de499` is labeled “initial commit.”
- Audited HEAD: 2026-08-16; latest commit message is “Move weather API key to dotenv and document key usage.”
- 146 commits are reachable from all refs; 95 are on the first-parent history.
- Five branches are visible: `main` and four `copilot/*` branches.
- GitHub contributor metadata reports `mmyahya29` (77 contributions), `mehak-akhtar` (22), and `Copilot` (3). Local Git author strings contain additional aliases and duplicate email identities.
- Local history contains 12 commits authored as `copilot-swe-agent[bot]` in the checked-out object graph, including explicit “Initial plan” and feature-fix commits.
- Signature status across the inspected history was 139 `N` (no signature) and 7 `E` (signature error/unverified status); no valid `G` status was observed. HEAD itself is unsigned.
- `git fsck` reported no object-integrity errors.

### Interpretation and limitations

Commit metadata is self-asserted and can be rewritten or configured arbitrarily. The differing names/emails for the apparent primary contributor and the use of `ballsp156@gmail.com`, `mmyahyahyder@gmail.com`, and GitHub noreply identities are ownership/accountability concerns, but they do not prove misconduct. The presence of Copilot bot commits proves AI-assisted commits occurred; it does not identify which source lines were AI-generated or establish that human review was absent.

## Originality, Copied Templates, and Ownership

### Verified exclusions

- `lib/firebase_options.dart` identifies itself as generated by FlutterFire (`:1-2`) and is excluded.
- The platform directories contain conventional Flutter runner/project scaffolding, generated plugin registrants, Xcode/Gradle project metadata, default web bootstrap markup, and standard launch resources; these are excluded from original authored source LOC.
- `test/widget_test.dart` is the standard Flutter counter-test pattern and is excluded from eligible implementation LOC.
- `packages/flutter_sms-2.3.3` is a vendored upstream package with its own upstream README, homepage/repository references, and license file; all 128 files and 9,409 lines are excluded.

### AI-generated code indicators

AI assistance is directly evidenced by Git history: `copilot-swe-agent[bot]` authored commits such as “Refactor Guardian Safety SMS,” “Fix widespread theme inconsistency issues,” and “docs: update README, add sensor config docs, env example; remove orphaned files.” Repeated “Initial plan” commits paired with feature commits are also consistent with agent workflows. These are indicators of AI-assisted history, not proof that all or any particular implementation was generated by AI.

### Ownership and licensing concerns

- No root `LICENSE`, `COPYING`, or equivalent project license was found.
- `README.md:99-101` says the project is for “educational and personal use,” which is not a complete standard license grant and does not clearly address redistribution, modification, warranty, or commercial use.
- The vendored `flutter_sms` package includes its own license and attribution, but the project should preserve and review those terms.
- Third-party package licenses, image provenance, Firebase project ownership, Groq/OpenWeather terms, and any training-data/content provenance were not independently verified.
- Because source originality cannot be proven from Git history alone, “verified original LOC” in this report means code treated as project implementation after path/provenance exclusion; it is not a legal non-infringement opinion.

## Risk Register

| Risk | Severity | Evidence | Recommended action |
|---|---|---|---|
| AI API key distributed to clients | High | `chat_bot_screen.dart:40`, `:211-218` | Move calls behind an authenticated server proxy; rotate any exposed key; fail closed on missing configuration |
| Cleartext traffic enabled | High | `AndroidManifest.xml:25-26` | Remove the flag and enforce HTTPS/network security policy |
| Broad SMS/location/storage/phone permissions | High | `AndroidManifest.xml:4-19` | Minimize permissions, justify each one, and test modern Android policy behavior |
| Firestore rules not included/audited | High | No rules file; writes in monitoring/profile/goal services | Review deployed rules, App Check, data ownership, and least-privilege access |
| Missing iOS/web configuration | High | Missing iOS plist; web placeholders | Complete platform configuration and validate each target |
| Stale/no meaningful tests | High | `test/widget_test.dart:14-28` | Replace template test with unit, widget, integration, and permission/error-path coverage |
| No root license | Medium | No root license; `README.md:99-101` | Select and add an explicit license after confirming ownership and dependency obligations |
| Uncontrolled sensitive logging | Medium | `crash_detector.dart:92-175`, `sos_screen.dart:42-45` | Redact contact/location data and centralize release logging |
| Inconsistent identity/provenance | Medium | Mixed author emails/signatures; bot commits | Establish contributor attribution, signed commits, and documented AI-use/review policy |
| Documentation drift | Medium | Missing `docs/SENSOR_CONFIGURATION.md`, stale project description | Repair links and align setup/version requirements with actual builds |

## Final Recommendation

**Recommendation: Do not approve for production deployment.** Treat Raxxy as an active prototype or academic/personal project until the high-risk items are resolved and verified on real Android/iOS devices.

Minimum release gate:

1. Remove client-side secret use and rotate/restrict affected API credentials.
2. Disable cleartext traffic and minimize sensitive permissions.
3. Audit and deploy explicit Firebase Auth/Firestore/App Check rules.
4. Complete iOS, Android, and web configuration with non-placeholder identifiers.
5. Replace the stale counter test with feature and safety-critical-path tests.
6. Add a root license and review third-party/assets ownership.
7. Install the supported Flutter toolchain and pass `flutter analyze`, targeted tests, and reproducible platform builds.
8. Repair documentation, remove template remnants, and establish signed/reviewed contribution history.

