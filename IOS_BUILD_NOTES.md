# iOS Build Notes — Chess Draughts Dominoes (CheckMate)

Context for building this Flutter app on macOS. Prepared on the Windows machine 2026-08-02.
NOTE: The Android upload-key/keystore issue is UNRELATED to iOS — ignore it here. iOS signing is separate.

## App facts
- Flutter app. Android package: `com.ludodo.checkmate`
- iOS bundle identifier: `com.chessapp.chessApp`  ← KEEP THIS. The Firebase iOS app is registered with it.
- Firebase project: `chess-ac4eb`; iOS appId `1:544347300592:ios:9cacaa8632a5e8919f1835`
- Dart Firebase config: `lib/firebase_options.dart` (has iOS values) — core Firebase initializes from this.

## Already configured on Windows (transfers with the project)
- `ios/Runner/Info.plist`: camera / photo-library / location usage descriptions; `UIBackgroundModes = remote-notification`;
  a `CFBundleURLTypes` entry for Google Sign-In with a PLACEHOLDER scheme `REPLACE_WITH_REVERSED_CLIENT_ID`.
- Minimum iOS raised to 13 (Firebase needs 13+): `project.pbxproj` IPHONEOS_DEPLOYMENT_TARGET, `ios/Flutter/AppFrameworkInfo.plist`.
- `ios/Podfile` created (`platform :ios, '13.0'`).

## MUST be done by the human (Claude CANNOT do these)
1. Install **Xcode** (App Store). Then run: `sudo xcodebuild -license accept` and `xcode-select --install`.
2. Apple signing:
   - iOS **Simulator** only: no Apple account needed.
   - Real device / TestFlight / App Store: **Apple Developer Program ($99/yr)**, signed in inside Xcode.
3. **GoogleService-Info.plist**: download from Firebase Console (project `chess-ac4eb`, iOS app `com.chessapp.chessApp`)
   and add it into `ios/Runner/` using Xcode (so it joins the Runner target).
4. In `ios/Runner/Info.plist`, replace `REPLACE_WITH_REVERSED_CLIENT_ID` with the `REVERSED_CLIENT_ID`
   from that GoogleService-Info.plist (required for Google Sign-In on iOS).
5. Any `sudo` / password step (e.g. installing CocoaPods) — run it yourself; Claude will not type your password.

## Steps Claude / terminal can do
- Confirm Flutter (macOS) is installed & on PATH: `flutter doctor -v`
- `flutter pub get`
- Install CocoaPods if missing (`sudo gem install cocoapods` OR `brew install cocoapods`), then `cd ios && pod install`
- Build options:
  - Simulator / quick check (NO Apple account, NO signing):  `flutter build ios --simulator`  or run on a booted simulator
  - Unsigned device build:  `flutter build ios --no-codesign`
  - App Store / TestFlight (needs Apple account + signing in Xcode):  `flutter build ipa --release`

## Realistic expectation
- Building + running on the iOS **Simulator** is straightforward once Xcode + CocoaPods are installed — Claude can drive this end to end.
- A **signed** build for the App Store needs YOUR Apple Developer account + signing set up in Xcode. Claude prepares the project but cannot log into your Apple ID.
