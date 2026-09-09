# 📱 Mobile CI/CD & Automated Android APK Distribution

VPS-Infra includes a built-in mobile build runner capable of compiling **Flutter**, **React Native**, and **Native Android (Gradle)** applications directly on your VPS, generating downloadable release APKs with zero third-party build costs.

---

## 🏗️ Supported Frameworks

| Framework | Auto-Detection Indicator | Build Tool |
|---|---|---|
| **Flutter** | `pubspec.yaml` in root | `flutter build apk --flavor <env>` |
| **React Native** | `package.json` + `android/` directory | `./gradlew assemble<Env>Release` |
| **Native Android** | `build.gradle` or `build.gradle.kts` + `gradlew` | `./gradlew assembleRelease` |

---

## ⚙️ 1. Environment & Flavor Mapping

The build engine automatically maps your project environment to Gradle flavors:

| Deployment Environment | Gradle Build Flavor | Generated APK Suffix |
|---|---|---|
| **Dev** | `dev` | `app-dev.apk` |
| **UAT / QA** | `uat` / `qa` | `app-uat.apk` |
| **Production** | `prod` / `release` | `app-prod.apk` |

---

## 📋 2. Onboarding a Mobile Repository

1. Open `https://devops.yourdomain.com`.
2. Click **"New Project"** -> enter your mobile project name.
3. Select **Application Type: Mobile Application**.
4. Set your **Git Repository URL** and branch (e.g. `main` or `release/uat`).
5. Under **Environment Variables**, provide any required build secrets (e.g. `API_BASE_URL`).

---

## 🚀 3. Triggering a Build & Downloading Artifacts

1. Navigate to `https://ci.yourdomain.com`.
2. Find your mobile service and click **"Run Build"**.
3. Watch live build output streaming in the CI console:
   - Dependency fetching (`flutter pub get` / `npm install`)
   - Asset compilation & AAPT2 packaging
   - APK code signing & alignment
4. Once completed, the build status turns green (`SUCCESS`).
5. A high-speed **Download APK** button appears directly in the UI:
   - Artifacts are saved to `/var/www/vps-infra/volumes/artifacts/builds/<build-id>/`
   - Download links support HTTP Range requests for instant mobile device installs.

---

## 🧪 4. Mobile Unit Testing & Code Coverage

VPS-Infra CI Server supports full automated test case ingestion and coverage tracking for Flutter mobile projects:

### 1. Flutter Machine-Readable Test Output:
To stream mobile test suites to the CI dashboard, execute unit tests in machine format during your build:
```bash
flutter test --machine > test-results/flutter-tests.json
```

### 2. Automated Test Case Ingestion (`ci_build_tests`):
The build runner parses `test-results/flutter-tests.json` events in real time:
- Maps `testStart`, `error`, and `testDone` events to individual test records.
- Ingests test name, suite path, execution duration (ms), error logs, and outcome (`PASSED`, `FAILED`, `SKIPPED`) with type `MOBILE_UNIT`.
- Displays individual mobile test case breakdowns directly in the CI Web Test Results tab.

### 3. LCOV Code Coverage Tracking:
When running Flutter test coverage:
```bash
flutter test --coverage
```
- Flutter writes coverage data to `coverage/lcov.info`.
- VPS-Infra's built-in LCOV parser extracts line-hit (`LH`) and line-found (`LF`) metrics across all Dart files.
- The overall line coverage percentage is recorded to the build record and evaluated against your project's configured coverage threshold.
