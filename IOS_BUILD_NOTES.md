# iOS Build Notes — CheckMate (Chess Draughts Dominoes)

Operational runbook for getting `com.ludodo.checkmate` from this repo to TestFlight and then to
the App Store, **built on Codemagic's macOS machines from a Windows workstation**. No Mac required.

Read this together with `APP_STORE_METADATA.md` (listing copy, privacy answers, reviewer notes) and
`codemagic.yaml` (the build itself — its header comments are the authoritative list of Codemagic UI
prerequisites and are not duplicated here in full).

Lines marked **[VERIFY]** could not be settled from the repo alone, or describe work another agent
had in flight at the time of writing. Check each one before you start a build.

---

## 1. Current state

### 1.1 Done in the repo — nothing further to do

| Item | Where | Why it matters |
|---|---|---|
| Push entitlement | `ios/Runner/Runner.entitlements` → `aps-environment = production` | Without an entitlements file the archive has no APNs environment and push silently never works on TestFlight/App Store builds. |
| Entitlements wired to **all three** Runner configurations | `ios/Runner.xcodeproj/project.pbxproj` — `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` on Debug, Release **and** Profile | Flutter's `--release` archive uses the Release config, but a missing Profile entry bites later during profiling builds. All three are set. |
| iPhone-only | `TARGETED_DEVICE_FAMILY = "1"` on every config | Removes the entire iPad screenshot requirement and the iPad layout review surface. |
| Deployment target iOS 15.0, consistently in all three places | `project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 15.0`), `ios/Flutter/AppFrameworkInfo.plist` (`MinimumOSVersion 15.0`), `ios/Podfile` (`platform :ios, '15.0'`) | Firebase iOS SDK 12.x requires 15+. If these three disagree, `pod install` fails on CI, not locally — a wasted 20-minute build. |
| Export compliance declared | `ios/Runner/Info.plist` → `ITSAppUsesNonExemptEncryption = false` | Every upload without it parks in "Missing Compliance" in App Store Connect and cannot be submitted until answered by hand. The app uses only OS-standard HTTPS/TLS. |
| Permission usage strings | `Info.plist` → `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription` | Missing usage strings mean a hard crash the moment the permission is requested, which is a guaranteed 2.1 rejection. |
| Background mode | `Info.plist` → `UIBackgroundModes = [remote-notification]` only | Required for FCM background delivery. Note there is **no** background location mode — this is the factual basis for the privacy answer in `APP_STORE_METADATA.md` section 8. |
| CI pipeline | `codemagic.yaml` (workflow `ios-appstore`, `mac_mini_m2`) | Committed and complete: keychain init, signing-file fetch, `use-profiles`, `pub get`, `pod install`, signed IPA, publish to TestFlight. |
| Build-number collision fix | `codemagic.yaml` → `--build-number=$(($BUILD_NUMBER + 8))` | `pubspec.yaml` is pinned at `1.1.0+8`. Because webhooks do not fire on this repo, the same commit is built by hand repeatedly; without the CI counter every upload after the first is rejected for a duplicate `CFBundleVersion`. The `+8` offset keeps it from ever going below the value already used. |
| Stable-signing-key wiring | `codemagic.yaml` → `environment.groups: [ios_signing]` | This one line is what makes `$CERTIFICATE_PRIVATE_KEY` reach the build. `laptops.az` was missing it, so every build minted a throwaway certificate and eventually hit Apple's distribution-certificate limit (HTTP 409). |
| Launch-crash guard | `lib/main.dart` — `NotificationService().initialize()` wrapped in `try/catch` before `runApp()` | On iOS, `getToken()` throws while APNs has not yet returned a device token, which is exactly the first-cold-start case a reviewer sees. Unguarded, that throw happens before any UI is built and the app looks hung on a white screen. This is also the evidence for the 4.5.4 answer: push is degradable, never required. |
| `intl` version fix | `pubspec.yaml` → `intl: ^0.20.2` | `flutter_localizations` (pulled in by `easy_localization`) pins `intl 0.20.2` in the Flutter SDK. Leaving `^0.19.0` fails version solving on CI (`flutter: stable`) as well as locally. Only `DateFormat(...).format(...)` is used, and that API is unchanged between 0.19 and 0.20. |
| `app_theme` build fix | `lib/core/theme/app_theme.dart` — `import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;` | `CupertinoPageTransitionsBuilder` moved out of `material.dart` in newer Flutter. The narrow `show` import avoids a material/cupertino name clash. Codemagic runs `flutter: stable`, so it hits the newer SDK before your local one does. |
| 1024 marketing icon is opaque | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` is PNG colour type 2 (RGB, no alpha); `pubspec.yaml` sets `remove_alpha_ios: true` | An alpha channel on the marketing icon is an automatic upload rejection. Verified — nothing to do. |
| Sign in with Apple | `pubspec.yaml` (`sign_in_with_apple ^6.1.4`), `lib/core/services/auth_service.dart` (`signInWithApple`, `completeAppleSignUp`, `apple.com` re-auth in `deleteAccount`), `lib/features/auth/widgets/apple_sign_in_button.dart`, both auth screens, `Runner.entitlements` (`com.apple.developer.applesignin`) | Guideline 4.8 makes this mandatory because the app offers Google Sign-In; its absence is an automatic rejection. The nonce is SHA-256 on the Apple request and raw on the Firebase credential. Apple returns name/email only on the *first* authorization, so they are persisted immediately. The `deleteAccount` branch matters for 5.1.1(v): without it an Apple account hits `requires-recent-login` and cannot be deleted. |
| Report user / content + profanity filter | `firestore_service.dart` (`reportUser`), `lib/core/utils/content_filter.dart`, Report actions beside Block in `chat_screen.dart` and `profile_screen.dart`, `reports` rules in `firestore.rules` | Guideline 1.2 wants four things for user-generated content: a filter, reporting, blocking and published contact. Blocking already existed; the other three are now in place. Rules allow create-as-yourself only, with no client read/update/delete. |
| Hosted legal pages | `public/privacy.html`, `support.html`, `terms.html`, `index.html`; `hosting` block with clean URLs in `firebase.json` | App Store Connect requires a Privacy Policy URL **and** a Support URL that both return HTTP 200. Apple fetches them during review. Still needs deploying — see O5. |
| One canonical legal text | `lib/core/legal/legal_texts.dart`, used by both `about_screen.dart` and `privacy_screen.dart` | The app briefly carried two different privacy policies that disclosed different things — the About one complete, the Settings one missing location, FCM and third-party flows. App Review penalises exactly that. There is now a single source, matching the hosted page. |
| Third-party attribution is visible in-app | `about_screen.dart` registers asset licences with `LicenseRegistry` (shown by `showLicensePage`); `assets/licenses/NOTICE.md`; OpenStreetMap credit on the map | The bundled `cburnett` piece set is CC BY-SA 3.0 and *requires* visible attribution — a repo file alone does not satisfy it. Note `alpha` is still an open licence risk (O1). |
| No placeholder UI left | Six dead "coming soon" rows in `about_screen.dart` now open real Terms / Privacy / licence content; the fake **Groups** tab and its non-functional "Notify me when available" button were removed from `map_search_screen.dart` | Guideline 2.1 cites placeholder content and non-functional controls as an incomplete app. `grep -rn "coming soon" lib/` now returns nothing. The real Groups feature is untouched. |

| Bundle id `com.ludodo.checkmate` | `project.pbxproj` (3 Runner + 3 RunnerTests configs), `codemagic.yaml` `fetch-signing-files`, `firebase_options.dart`, the OSM `userAgentPackageName`, the hosted privacy/terms pages | `com.chessapp.chessApp` is held by another Apple account, so it could not be registered. The new id matches the Android `applicationId`, so both stores carry one identifier. The `codemagic.yaml` occurrence is load-bearing — CI mints the profile from that exact string. |
| Firebase iOS app re-registered | `ios/Runner/GoogleService-Info.plist` (`GOOGLE_APP_ID 1:544347300592:ios:61a92917b3d6402c9f1835`), mirrored into `lib/firebase_options.dart` | A Firebase iOS app is keyed by bundle id, so the original registration died with the old id. On iOS `Firebase.initializeApp()` reads `firebase_options.dart`, **not** the plist, so both had to be updated — a plist alone would still fail at runtime. |
| `GoogleService-Info.plist` wired into the Xcode project | `project.pbxproj` — `PBXBuildFile`, `PBXFileReference`, the Runner `PBXGroup` children, and the **Runner** `PBXResourcesBuildPhase` (not RunnerTests) | Flutter does **not** do this automatically. Dropping the file into `ios/Runner/` compiles and ships perfectly cleanly while the file never reaches `Runner.app`, so Google Sign-In fails on device with no build error. Verified by count: the file ref appears 3× and the build file 2×. |
| Real `REVERSED_CLIENT_ID` in `Info.plist` | `CFBundleURLSchemes` → `com.googleusercontent.apps.544347300592-65e0dtrk1pid6orjp73bsjaratspl2tl` | Without it Google Sign-In launches but cannot complete its callback — the reviewer sees a broken feature, Guideline 2.1. |

### 1.2 Outstanding — must be resolved before the build you submit

Everything Firebase- and identifier-related is now **done** and has moved to 1.1: the bundle id
move to `com.ludodo.checkmate`, the re-registered Firebase iOS app, `GoogleService-Info.plist`
committed and wired into the Xcode project, and the real `REVERSED_CLIENT_ID` in `Info.plist`.
Earlier drafts also listed the Sign in with Apple entitlement, the in-app report flow, the
`hosting` block in `firebase.json` and the in-app privacy text — all done.

What remains below is work only you can do, plus one item that waits for the first green build.

| # | Item | Owner | Impact if ignored |
|---|---|---|---|
| O1 | **`assets/pieces/alpha/` may not be licensed for commercial distribution.** Eric Bentzen's chess fonts were historically released "free for personal, non-commercial use". | You (decision) | App Store Connect makes you affirm content rights on every submission. Either obtain written permission or delete the set and its picker entry. **This is the one bundled asset with a genuine licence problem** — see `assets/licenses/NOTICE.md`. `merida` also needs its exact licence confirmed against Lichess's `public/piece/COPYING.md`. |
| O2 | **The map uses `tile.openstreetmap.org` directly.** The required "© OpenStreetMap contributors" credit is now displayed, but OSM's tile usage policy **prohibits** using their servers as an app backend. | You (needs an API key) | OSM can block the tile requests, which breaks the map for every user, not just reviewers. Migrate to MapTiler / Stadia / Thunderforest. The warning comment is at the `TileLayer` in `player_map_screen.dart`. |
| O3 | **No App Review demo account exists.** The app has no guest mode: a reviewer hits a login wall, email verification, and possibly the OTP/2FA screen. | You | Automatic "unable to review" rejection, costing a full 24–48h cycle each time. See `APP_STORE_METADATA.md` → App Review Information for exactly what to seed. |
| O4 | **`ios/Podfile.lock` does not exist.** It cannot be generated on Windows. | Me, after build 1 | Pod versions float between builds, so a build that was green yesterday can break today with no repo change. Fixed by section 5. |
| O5 | **The hosted legal pages are written but not deployed.** `public/` holds them; `firebase.json` serves them. | You | `firebase deploy --only hosting --project chess-ac4eb`, then confirm `/privacy`, `/support` and `/terms` return HTTP 200. Apple fetches the privacy URL during review; a 404 is an automatic 5.1.1 rejection. |
| O6 | **`firestore.rules` changed** (the new `reports` collection) and is not deployed. | You | Report submissions are rejected by the old rules, so the Guideline 1.2 reporting flow silently fails. `firebase deploy --only firestore:rules --project chess-ac4eb`. |
| O7 | Codemagic UI one-time setup (steps 6 and 7 below) has not been done. | You | No build can start at all. |

`DEVELOPMENT_TEAM` is deliberately **not** set in `project.pbxproj`. Codemagic's
`xcode-project use-profiles` writes the team and the profile into the project at build time from
the fetched signing files. Do not hand-edit it in — a stale team id there overrides CI and is
painful to debug.

---

## 2. The ordered human checklist

**The order is the point.** Each step depends on the one before it, and several of them do not fail
loudly when done out of sequence: they produce an artefact that looks fine and dies twenty minutes
later, or worse, pass the build and fail the review.

### Step 1 — Apple Developer, Certificates Identifiers & Profiles, Identifiers

Register the App ID `com.ludodo.checkmate` (Team `PLY98763D4`) and, **in the same visit, before
any provisioning profile exists**, tick:

- **Push Notifications**
- **Sign In with Apple**

**Why this is first.** A provisioning profile is a snapshot of the capabilities the App ID had at
the moment it was minted. A profile created before you switched Push on carries no
`aps-environment`, so the archive is signed without push and every notification silently vanishes —
with no build error anywhere. Codemagic then makes it worse by **reusing the stale profile** on the
next build, so flipping the capability afterwards does not fix it on its own; you must delete the
old profile so `fetch-signing-files --create` mints a new one. The same applies to Sign In with
Apple (O3): the entitlement in the app must be matched by the capability on the App ID, or the
archive fails to sign with a provisioning-profile-mismatch error.

### Step 2 — Apple Developer, Keys: create an APNs `.p8` and upload it to Firebase

1. Keys → **+** → name it (e.g. "CheckMate APNs") → enable **Apple Push Notifications service
   (APNs)** → Continue → Register.
2. **Download the `.p8` immediately.** Apple allows the download exactly once; if you lose it you
   must revoke the key and create a new one.
3. Note the **Key ID** shown on that page.
4. Firebase Console → project `chess-ac4eb` → Project settings → **Cloud Messaging** → iOS app
   `com.ludodo.checkmate` → **APNs Authentication Key** → Upload, supplying:
   - the `.p8` file,
   - the **Key ID** from step 3,
   - **Team ID `PLY98763D4`**.

**Why here.** The entitlement from step 1 lets the device *register* with APNs; this key is what
lets *Firebase* send through APNs. Both halves are required and they fail in different places —
without the key, the app gets an FCM token normally and pushes simply never arrive, which is nearly
impossible to diagnose from the device. One `.p8` covers every app on the team, so `laptops.az` and
this app can share it.

### Step 3 — Firebase Console: enable Apple sign-in, then `GoogleService-Info.plist`

1. Authentication → Sign-in method → enable the **Apple** provider (needed for O3 and Guideline
   4.8).
2. Project settings → Your apps → iOS app → **Download `GoogleService-Info.plist`**.
3. **Open the file in a text editor and confirm it contains a `REVERSED_CLIENT_ID` key, before you
   do anything else with it.**

That verification is not optional. If `REVERSED_CLIENT_ID` is absent, the Firebase iOS app has no
OAuth client provisioned and **nothing downstream can fix Google Sign-In** — not the Info.plist
edit, not the build, not a review response. You would have to go back to Firebase, add the iOS
OAuth client (Authentication → Sign-in method → Google → iOS configuration, or the credentials page
of Google Cloud project `chess-ac4eb`), and re-download. Discovering this after a green build costs
a whole cycle.

**This is all done** — the section is kept because it is the part people get wrong, and because it
has to be redone from scratch if the plist is ever regenerated.

- The file is committed at `ios/Runner/GoogleService-Info.plist`.
- It is **wired into `project.pbxproj` by hand**, in four places: `PBXBuildFile`,
  `PBXFileReference`, the Runner `PBXGroup` children, and the **Runner** `PBXResourcesBuildPhase`
  (not RunnerTests). Flutter does **not** do this for you, and this is the failure worth
  understanding: drop the file into `ios/Runner/` without the pbxproj entries and everything
  compiles, signs, uploads and passes validation while the file never reaches `Runner.app`. Google
  Sign-In then fails on device with no build error anywhere to explain it. Skipping the fourth
  entry — the resources phase — fails the same silent way.
  Verify by count, not by eye: the file reference id must appear **3×** and the build file id
  **2×**. `grep -c A1C2D3E41F0A00010000F001 ios/Runner.xcodeproj/project.pbxproj` → 3, and
  `...F002` → 2.
- `REVERSED_CLIENT_ID` is in `ios/Runner/Info.plist` → `CFBundleURLTypes` → `CFBundleURLSchemes`.
- `apiKey` and `appId` in `lib/firebase_options.dart` mirror the plist's `API_KEY` and
  `GOOGLE_APP_ID`. **On iOS, `Firebase.initializeApp()` reads `firebase_options.dart`, not the
  plist**, so a correct plist with stale Dart values still fails at runtime. Both must move together.

### Step 4 — App Store Connect, Business: accept the Free Applications agreement

Agreements, Tax, and Banking → **Free Applications** → accept. The app is free, so no banking or
tax forms are required.

**Why before the app record.** Until this agreement is active the account cannot distribute
anything. App Store Connect will happily let you create the app record and even upload a build,
then refuse to let you submit, with an error that points at the agreement from three screens away.

### Step 5 — App Store Connect: create the app record

My Apps → **+** → New App:

- Platform: **iOS**
- Name: see `APP_STORE_METADATA.md` section 1 (recommended: `Chess Draughts Dominoes`)
- Primary language: English
- **Bundle ID: `com.ludodo.checkmate`** — it only appears in the dropdown after step 1
- SKU: anything unique, e.g. `checkmate-ios-001`

**Read this twice.** `app-store-connect fetch-signing-files --create` in `codemagic.yaml` creates
the **App ID / bundle identifier**. It does **not** create the **app record**. They are different
objects in different systems. Without the app record the build runs green for roughly twenty
minutes — compile, archive, sign, all fine — and then dies at the publishing step with
`No suitable application records were found`. That message is buried inside the red post-processing
block, so it reads like a signing failure. Create the record first.

### Step 6 — Codemagic UI, one-time setup

The authoritative list is in the header comments of `codemagic.yaml`. Short form:

1. Connect the repository (GitHub: `MiryusifMajidov/FinalProjectUni`).
2. App settings → **Build configuration source = `codemagic.yaml`**. If this is left on "Workflow
   Editor", **none of the scripts in `codemagic.yaml` run** — the build uses a UI-defined pipeline
   instead and every fix encoded in that file is silently absent.
3. Teams → Integrations → an App Store Connect API key must exist, and **its name must match the
   value of `integrations.app_store_connect:` in `codemagic.yaml`** (currently `laptops_az_asc_key`).
   Same Apple team `PLY98763D4`, so the existing key works for both apps. A name mismatch fails the
   build at the very first script.
4. Environment variables → create the group **`ios_signing`** containing:
   - `CERTIFICATE_PRIVATE_KEY` = a PEM RSA private key, marked **Secure**.
     Generate it in Git Bash with `openssl genrsa -out cert_key.pem 2048`, then paste the **entire**
     file including the `-----BEGIN` and `-----END` lines.
   - Add the **same group name with the same value** to the `laptops.az` app in Codemagic, so both
     apps sign with one shared distribution certificate and the Apple 409 limit stops filling up.

The group name in the UI must equal the name under `environment.groups:` in `codemagic.yaml`.
Codemagic does not warn on a mismatch — the variable is simply empty, the build falls into the
throwaway-key branch, and you are back to burning certificates.

### Step 7 — Start the first build manually

Codemagic → the app → **Start new build** → branch `master` → workflow `ios-appstore`.

Webhooks do not fire on this repository, so the `triggering:` block in `codemagic.yaml` never
activates. The block is kept so it starts working by itself if a webhook is configured later, but
**for now every build is a manual start.** Do not wait for a push to trigger anything.

### Step 8 — Pricing and Availability, before you submit

App Store Connect → the app → **Pricing and Availability** → Price **Free**, Availability **All
Countries and Regions**.

**Why before submitting.** An incomplete Pricing and Availability section leaves the Submit button
disabled with no inline explanation on the version page. It is easy to lose an afternoon hunting
for a metadata error that does not exist.

---

## 3. How to tell whether a build really succeeded

Codemagic shows a green tick for the *build* stage and a separate red block at the end labelled
something like **"App Store distribution / post-processing failed"**. That red block is where
almost every real problem surfaces, including all of these:

- duplicate `CFBundleVersion` (`The build number ... has already been used`)
- missing app record (`No suitable application records were found`)
- missing export compliance
- every `ITMS-90xxx` validation error (entitlements, icons, missing usage strings, unsupported
  architectures)

A green compile with a red post-processing block means **nothing was delivered**. The IPA artefact
still exists and is downloadable, which is exactly what makes it look like a success. It is not.

### The check

1. Open the build's **publishing / post-processing log** and search it for, in order:
   - `ITMS-`
   - `already been used`
   - `No suitable application records`
   - `Missing Compliance`

   Any hit is the real error. Read the whole surrounding paragraph — the useful sentence is usually
   two or three lines below the first match.
2. **Then confirm independently, in App Store Connect → the app → TestFlight → iOS builds, that a
   NEW build row has appeared**, carrying the build number you expect (`$BUILD_NUMBER + 8`). Do not
   trust the Codemagic log alone for this, and do not accept a row that was already there from an
   earlier run — check both the build number and the upload timestamp.
3. A new row normally appears within a few minutes and sits in **Processing** for 5 to 30 minutes.
   Processing can *still* fail after that; Apple emails the account holder when it does. If the row
   disappears or flips to an error state, that email carries the reason.

Only when a new row exists **and** finishes processing has the build actually succeeded.

---

## 4. Certificate safety — read before running any `certificates` command

**`laptops.az` is on the same Apple team (`PLY98763D4`).**
`app-store-connect certificates list` and `app-store-connect certificates delete` operate on the
**team**, not on an app. There is no per-app scoping. Running
`app-store-connect certificates delete <id>` against the wrong certificate **revokes `laptops.az`'s
distribution certificate too**, and that app is live on the App Store. Recovery means reissuing the
certificate and reworking its signing setup.

### What `codemagic.yaml` already does about this

The signing script contains a deliberate guard. If `fetch-signing-files` fails **and**
`CERTIFICATE_PRIVATE_KEY` is set, the script **revokes nothing** and exits 1 with an explicit
message. The reasoning is worth keeping in mind:

- If a stable key is configured, the existing certificate is the *working, shared* certificate both
  apps depend on. Deleting it is the one thing you must not do.
- The cleanup branch — the loop that lists and revokes certificates — is reachable **only when
  `CERTIFICATE_PRIVATE_KEY` is empty**. In that state every existing certificate was minted with a
  throwaway key that no longer exists anywhere, so none of them can sign anything, they are pure
  dead weight against the Apple limit, and revoking them cannot affect any shipped release.

So: **if a build stops with "fetch-signing-files failed, stable key present, certificate NOT
deleted", that is the guard working.** Investigate by hand. Do not "fix" it by removing the guard or
by clearing `CERTIFICATE_PRIVATE_KEY` so the cleanup branch runs — that is precisely the path that
revokes `laptops.az`.

Inspect first:

```bash
app-store-connect certificates list --type IOS_DISTRIBUTION --json
```

Work out which certificate belongs to which app **before** deleting anything.

### Correct flag names

```bash
app-store-connect certificates list   --type IOS_DISTRIBUTION --json
app-store-connect certificates delete <CERTIFICATE_ID> --ignore-not-found
```

- The option is **`--type`**, not `--certificate-type`.
- The non-interactive behaviour comes from **`--ignore-not-found`**; there is **no `--yes` flag**.
- `--certificate-type` and `--yes` **do not exist.** Using them makes the command error out rather
  than do something unexpected — a safe failure mode, but it still costs you a build.

---

## 5. After the first green build

Do both of these before the second build, while you still know which versions produced the good one.

### 5.1 Commit `ios/Podfile.lock` (resolves O4)

`Podfile.lock` cannot be generated on Windows, which is why it is not in the repo. `codemagic.yaml`
already publishes it as an artefact:

```yaml
artifacts:
  - ios/Podfile.lock
```

Download it from the first successful build's artefacts, place it at `D:\chess\ios\Podfile.lock`,
and commit it. Until it is committed, CocoaPods re-resolves every pod on every build, and a
transitive Firebase pod update can break a build with no change on your side.

### 5.2 Pin the toolchain in `codemagic.yaml`

The workflow currently uses floating versions:

```yaml
flutter: stable
xcode: latest
```

Both `stable` and `latest` move. A build that is green today can fail tomorrow from a Flutter or
Xcode release alone. Find the exact versions in the first green build's log — Codemagic prints them
in the initial environment section — and replace the floating values with those literals, e.g.:

```yaml
flutter: 3.44.0
xcode: 16.4
```

**[VERIFY]** the exact strings from your own build log; do not copy the example numbers above.
Upgrade deliberately later, as its own build, so a toolchain change is never tangled up with an app
change.

---

## 6. Quick troubleshooting index

| Symptom | Cause | Fix |
|---|---|---|
| Build ends red at "post-processing" but the IPA exists | See section 3 — grep the publishing log | Depends on which `ITMS-`/text match hits |
| `No suitable application records were found` | App record never created | Step 5 |
| `The build number ... has already been used` | Two builds produced the same `CFBundleVersion` | Already handled by `$BUILD_NUMBER + 8`; if it recurs the Codemagic counter was reset — raise the offset in `codemagic.yaml` |
| `fetch-signing-files` fails with HTTP 409 | Apple distribution-certificate limit reached | Section 4 — inspect first, do **not** blind-revoke |
| Guard message "certificate NOT deleted" | Working as designed | Section 4 |
| Build starts but none of the yaml scripts run | Build configuration source is still "Workflow Editor" | Step 6.2 |
| `$CERTIFICATE_PRIVATE_KEY` empty, a new certificate every build | Variable group name mismatch between the UI and `environment.groups` | Step 6.4 |
| `pod install` fails on the deployment target | The three iOS-15 declarations disagree | Section 1.1 — they currently agree; never change one alone |
| Push token never arrives on device | APNs `.p8` not uploaded to Firebase, or the profile predates the Push capability | Steps 1 and 2, then delete the stale profile so a fresh one is minted |
| Google Sign-In does nothing or crashes | O1 / O2 — missing `GoogleService-Info.plist`, or the unreplaced `REVERSED_CLIENT_ID` placeholder | Step 3 |
| Sign in with Apple throws at runtime | O3 — missing `com.apple.developer.applesignin` entitlement, or the capability is off on the App ID | Step 1 plus `Runner.entitlements` |
| Upload rejected over the app icon | Alpha channel on the 1024 icon | Already clean (RGB, no alpha); if it recurs, check `remove_alpha_ios: true` in `pubspec.yaml` |
| App Store Connect asks about export compliance | `ITSAppUsesNonExemptEncryption` missing from the built Info.plist | It is present; answer "No" to the exempt-encryption question and check the build used the right Info.plist |

---

## 7. What Claude can and cannot do here

**Cannot**, because they need your Apple ID, a password, or an interactive web session: the Apple
Developer portal (steps 1 and 2), the Firebase console (steps 2.4 and 3.1), App Store Connect
(steps 4, 5 and 8) and the Codemagic UI (steps 6 and 7). Every one of those is a human step.

**Can:** everything inside the repo — Info.plist and entitlements edits, `codemagic.yaml`, Dart
fixes, and these documents. The listing copy, privacy answers, age-rating reasoning and reviewer
notes are already written in `APP_STORE_METADATA.md`; they only need pasting.
