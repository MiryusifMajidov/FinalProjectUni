# App Store Connect — listing metadata (CheckMate / Chess Draughts Dominoes)

> Paste-ready copy for App Store Connect → **App Information**, **Pricing and Availability**,
> **App Privacy**, and the version page (**Localizable Information** + **App Review Information**).
> Character limits below are Apple's, and every proposed string has been counted.
> Structure mirrors `D:\laptops.az\APP_STORE_METADATA.md` so both apps stay consistent.
>
> Lines marked **[VERIFY]** are things the repo could not settle — check them before submitting.

---

## 0. Identity — the fixed facts

| Field | Value | Source of truth |
|---|---|---|
| iOS Bundle ID | `com.chessapp.chessApp` | `ios/Runner.xcodeproj/project.pbxproj`, `lib/firebase_options.dart` |
| Android package (live on Play) | `com.ludodo.checkmate` | Play listing; Android build |
| Apple Team ID | `PLY98763D4` | shared with `laptops.az` |
| Firebase project | `chess-ac4eb` (iOS appId `1:544347300592:ios:9cacaa8632a5e8919f1835`) | `lib/firebase_options.dart` |
| Version / build | `1.1.0` / build `8` in `pubspec.yaml`; iOS build number is overridden at CI time to `$BUILD_NUMBER + 8` | `pubspec.yaml`, `codemagic.yaml` |
| `CFBundleDisplayName` (home-screen name) | `Chess Draughts Dominoes` | `ios/Runner/Info.plist` |
| `CFBundleName` | `chess_app` | `ios/Runner/Info.plist` |
| Devices | **iPhone only** (`TARGETED_DEVICE_FAMILY = "1"`) | `project.pbxproj` |
| Minimum iOS | **15.0** | `project.pbxproj`, `ios/Flutter/AppFrameworkInfo.plist`, `ios/Podfile` |
| Monetisation | none — no IAP, no subscriptions, no ads | no billing/ads packages in `pubspec.yaml` |
| Analytics / crash SDK | none — no `firebase_analytics`, no Crashlytics, no Sentry | `pubspec.yaml` |
| Languages shipped | 10 — az, de, en, es, fr, hi, ru, tr, ur, zh | `assets/translations/` |

---

## 1. App Name (max 30 characters)

The store name and `CFBundleDisplayName` should read as the same app. The binary currently
ships `Chess Draughts Dominoes`, so option A needs no code change at all.

| # | Name | Chars | Notes |
|---|---|---|---|
| **A (recommended)** | `Chess Draughts Dominoes` | **23** | Exactly matches `CFBundleDisplayName`. Three high-volume search nouns in the name field, which Apple weights most heavily. No punctuation to dilute it. |
| B | `CheckMate: Chess & Dominoes` | 27 | Leads with the brand used internally and on Play. Loses "draughts" from the strongest-weighted field; you would have to buy that word back with a keyword. |
| C | `Chess Draughts Dominoes 3in1` | 28 | Same as A plus a differentiator. "3in1" reads as spam to some reviewers and adds no search value. |

**Decision: use A.** If you pick B or C instead, change `CFBundleDisplayName` in
`ios/Runner/Info.plist` to match *before* the build you submit — Apple does compare the two and a
visible mismatch is a routine 2.3.7 ("Accurate Metadata") note.

---

## 2. Subtitle (max 30 characters)

| Subtitle | Chars |
|---|---|
| **`Chess, draughts & dominoes`** (recommended if App Name = B) | 26 |
| **`3 board games, one account`** (recommended if App Name = A) | 26 |
| `Play online, join tournaments` | 29 |

With App Name A the three game nouns are already spent, so the subtitle should buy new terms —
hence "3 board games, one account". Apple indexes the subtitle at nearly the same weight as the
name, so do not waste it on a restatement.

---

## 3. Promotional Text (max 170 characters)

Editable without a new build — use it for events and seasons later.

```
Three classic board games in one app: chess, draughts and dominoes. Play friends or strangers online, enter arena tournaments, or train against the bot.
```
*(152 characters.)*

---

## 4. Description (max 4000 characters)

```
Chess, draughts and dominoes — three classic board games in one app, with real opponents, real
ratings and no ads.

THREE GAMES, ONE ACCOUNT
• CHESS — full rules including castling, en passant, promotion, draw offers and resignation, with a
  move list you can scroll and replay.
• DRAUGHTS (CHECKERS) — forced captures, multi-jumps, kings, and the same online and bot modes as
  chess.
• DOMINOES — classic table play against friends or the bot, with a shared table anyone you invite
  can join.

PLAY ONLINE
Get matched with a player near your strength in seconds, or invite a friend directly and pick the
time control yourself. Bullet, blitz and rapid clocks are all supported, and each game keeps a live
clock for both sides. Leave a game open and friends can watch it as spectators.

TOURNAMENTS AND ARENA
Create a tournament or join one that is already running. Arena format keeps pairing you with a new
opponent for as long as the arena lasts, so there is no waiting between rounds and no elimination —
you play, you score, you climb.

CAMPAIGN
A chapter-by-chapter single-player campaign that unlocks act by act as you win. It is a structured
way to learn the openings and endgames instead of grinding random games.

PLAY THE BOT
Choose a difficulty and play offline-friendly practice games any time. Useful for trying an idea
without risking your rating.

FRIENDS, GROUPS AND CHAT
Add friends, search for players by username, and create groups for your club or your circle.
One-to-one chat, group chat, and a chat panel inside the game itself so you can talk a position
through while you play it.

LEADERBOARD AND RATINGS
Separate ratings for chess, draughts and dominoes, so being sharp at one does not flatter the
others. A global leaderboard shows where you actually stand.

NEARBY PLAYERS MAP
Turn on the map and see other players who have also chosen to appear, then challenge them directly.
This is strictly opt-in: your location is never shared until you switch it on yourself, and
switching it off removes you again.

TEN LANGUAGES
English, Azerbaijani, Turkish, Russian, German, Spanish, French, Hindi, Urdu and Chinese.

PRIVACY AND CONTROL
• No ads, no in-app purchases, no third-party trackers.
• Block any player, and manage your block list from Settings → Privacy.
• Two-factor authentication on sign-in, and a list of your active sessions you can review.
• Delete your account and its data from inside the app: Settings → Account → Delete account.

Free to play. Everything in the app is included.
```

**[VERIFY] before pasting:** confirm that the bot difficulty levels, the arena scoring text and the
campaign act-unlock wording still match the shipping build — the campaign unlock rule lives in
`lib/features/campaign/screens/campaign_map_screen.dart` and the arena flow in
`lib/features/tournaments/screens/arena_lobby_screen.dart`. Describing a mode that does not behave
as written is a 2.3.1 metadata rejection, not a cosmetic issue.

---

## 5. Keywords (max 100 characters, comma-separated, **no spaces**)

```
draughts,checkers,dominoes,domino,board,multiplayer,tournament,arena,online,bot,strategy,club
```
*(93 characters.)*

Rules applied:
- **"chess" is deliberately absent.** Apple indexes App Name + Subtitle + Keywords as one pool;
  repeating a word already in the App Name buys nothing and costs six characters.
- No spaces after commas — a space is an indexed character and Apple does not trim it.
- Singular and plural are indexed separately for some terms, which is why both `dominoes` and
  `domino` are present.

**Ranking reality check:** "chess" is one of the most saturated queries on the App Store —
Chess.com, Lichess and a long tail of clones own the first screen, and a new app with no ratings
will not appear there regardless of keyword choice. Realistic early traffic comes from the
lower-competition terms in the list above (`draughts`, `dominoes`, `arena`) and from combinations
Apple builds across fields, e.g. *draughts online*, *dominoes multiplayer*. Treat "chess" as brand
signalling in the app name, not as an acquisition channel.

---

## 6. URLs, category, copyright

| Field | Value |
|---|---|
| **Support URL** (required) | `https://chess-ac4eb.web.app/support` |
| **Marketing URL** (optional) | `https://chess-ac4eb.web.app` |
| **Privacy Policy URL** (required) | `https://chess-ac4eb.web.app/privacy` |
| **Primary Category** | Games → **Board** |
| **Secondary Category** | Games → **Strategy** |
| **Copyright** | `© 2026 Yusif Majidov` — **[VERIFY]** use whatever legal name / entity matches your Apple Developer account; a mismatch here is picked up in review |

**[VERIFY] — hosting is not configured yet.** `D:\chess\firebase.json` currently has `firestore`,
`database`, `functions` and `flutter` blocks but **no `hosting` block**, so
`chess-ac4eb.web.app/support` and `/privacy` will 404 until the agent building those pages adds
hosting config and runs a deploy. Open both URLs in a browser yourself before you hit Submit.
Apple fetches the Privacy Policy URL during review; a dead link is an automatic 5.1.1 rejection and
costs a full review cycle.

**[VERIFY] — the in-app privacy text is stale.**
`lib/features/settings/screens/privacy_screen.dart` still contains placeholder copy that names the
app "Grandmaster" and gives a contact address of `privacy@grandmasterapp.com`. That text is visible
in the shipping build and contradicts both the store listing and the hosted policy. It must be
corrected and the two policies must agree. This file is owned by another agent — confirm it was
fixed before submitting.

---

## 7. Age Rating — worked through honestly

### Why 4+ is not defensible

The rating questionnaire is not only about violence and profanity. This app ships, as verified in
the source:

| Capability | Where |
|---|---|
| Unfiltered user-to-user text chat (1:1) | `lib/core/services/chat_service.dart`, `lib/features/chat/` |
| Group chat | `lib/core/services/group_service.dart`, `lib/features/groups/` |
| In-game chat with the opponent | `lib/core/services/game_chat_service.dart`, `lib/features/game/widgets/in_game_chat_sheet.dart` |
| Free-text usernames and display names | `lib/features/settings/screens/account_screen.dart` (`change_username`, `display_name`) |
| User-uploaded profile photos | `lib/core/services/photo_service.dart` → Firebase Storage |
| A map of nearby real people, with challenge-by-map | `lib/features/map/`, `showOnMap` in `lib/core/models/user_model.dart` |

There is no server-side moderation, no profanity filter and no image screening anywhere in the
repo. An app that lets a stranger send a minor free text, a chosen handle, a photo, and can show
roughly where that stranger is, is not a 4+ app under any reading of the questionnaire.

### What to expect

Answer the questionnaire truthfully — **all the classic content questions are genuinely "None"**
(no violence, no sexual content, no nudity, no profanity in app-authored content, no alcohol /
tobacco / drugs, no horror, no gambling, no contests, no unrestricted web access). The rating is
driven entirely by the communication and user-generated-content questions.

- Declare that the app **allows users to communicate** and **contains user-generated content**.
- Declare the moderation controls you actually have: **block** (Settings → Privacy → Blocked users,
  and directly from a profile or a chat) and **[VERIFY] report**.
- **Expect 12+.** With open communication declared and moderation controls in place, 12+ is the
  normal outcome. If you answer that the content is unmoderated with no controls at all, the
  questionnaire pushes the rating to 17+/18+, which needlessly halves the addressable audience.

**[VERIFY] — there is no in-app "report user/content" flow.** Searching the repo finds only a
*report a bug* feedback form (`lib/features/settings/screens/about_screen.dart`,
`help_feedback_screen.dart`, writing to the `feedback` collection). Block exists; reporting a
**person or a message** does not. Guideline 1.2 requires *both*. Do not answer the moderation
question as though reporting exists — either it ships in this build, or you answer honestly and
accept the higher rating. See §10.

### The mismatch pattern to avoid

Self-rating a chat app 4+ and then having a reviewer open a chat screen is a well-worn rejection
route: it comes back as **2.3.7 / 1.2** with wording about the rating not reflecting the app's
content, and in some cases as an age-rating reset applied by Apple without a new build. It costs a
review cycle and it flags the account. Rate it 12+ up front.

---

## 8. App Privacy ("nutrition label") — complete answer set

Answer **"Yes, we collect data from this app"**, then declare exactly the following.
"Linked to the user" = yes, because every record is written under the signed-in Firebase UID.

| Category → Data type | Collected | Purposes | Linked to user | Used for tracking | Evidence |
|---|---|---|---|---|---|
| **Contact Info → Email Address** | Yes | App Functionality, **Account Management** | **Yes** | No | `auth_service.dart` register/signIn; email OTP in `otp_service.dart` |
| **User Content → Photos or Videos** | Yes | App Functionality | **Yes** | No | `photo_service.dart` → Firebase Storage profile photo; `image_picker` in `pubspec.yaml` |
| **User Content → Other User Content** | Yes | App Functionality | **Yes** | No | chat messages (1:1, group, in-game), usernames, display names |
| **Location → Precise Location** | Yes | App Functionality | **Yes** | No | `geolocator`; `updateLocation` in `firestore_service.dart` |
| **Identifiers → Device ID** | Yes | App Functionality | **Yes** | No | FCM registration token, `notification_service.dart` / `InviteListener._saveFcmToken` |
| **Usage Data** (any type) | **No** | — | — | — | no analytics SDK in `pubspec.yaml` |
| **Diagnostics** (any type) | **No** | — | — | — | no Crashlytics / Sentry / performance SDK |
| **Tracking** — "Do you or your third-party partners use data for tracking?" | **No** | — | — | — | no ad SDK, no IDFA, no `AppTrackingTransparency` usage, no cross-app data sharing |

Because Tracking = No, **do not** add `NSUserTrackingUsageDescription` and do not call ATT. Adding
a tracking prompt an app does not need is itself a rejection (and contradicts this label).

### Notes you will need when the reviewer or the form pushes back

- **Precise Location is the one entry that draws scrutiny.** The defence is in the code and you
  should say it plainly if asked: `showOnMap` defaults to **`false`**
  (`lib/core/models/user_model.dart:97`, `cache_service.dart:57`), the location stream only starts
  when the user has opted in (`home_screen.dart` — `if (user == null || !user.showOnMap) return;`),
  the map query only returns users with `showOnMap == true`
  (`firestore_service.dart:265,274`), and turning the switch off removes the user from the map.
  Location is never collected in the background: `UIBackgroundModes` contains only
  `remote-notification`, and the app declares `NSLocationWhenInUseUsageDescription` only — there is
  no "Always" authorisation and no background location entitlement.
- **Device ID is the FCM token, nothing else.** No advertising identifier is read anywhere.
- **[VERIFY] — two collection points are not in the list above and you should decide consciously:**
  1. **Device model + OS version stored on the active-sessions list** (`auth_service.dart` ~line 122
     via `device_info_plus`, shown in `active_sessions_screen.dart`). This is not optional and not
     feedback, so it is not covered by Apple's customer-service exemption. Declare it as
     **Other Data → Other Data Types**, purposes *App Functionality* + *Account Management*, linked.
  2. **Device model + OS version attached to a bug report / feedback submission**
     (`about_screen.dart`, `help_feedback_screen.dart` → `feedback` collection). This *is* covered
     by Apple's optional-feedback exemption — user-initiated, optional, support-only, not used for
     tracking — so it does not have to be declared. Keep it that way: do not start using the
     feedback collection for anything other than support.
  3. **Display name** is free text and may contain a real name. If you want to be conservative,
     also declare **Contact Info → Name** (App Functionality, linked). It costs nothing and removes
     an argument.

---

## 9. App Review Information — the highest-risk section

### The problem, stated exactly

The router has **no guest mode**. `lib/core/router/app_router.dart` contains:

```dart
if (!isLoggedIn && !onAuthPath && !onPostRegPath) return '/login';
```

Every route except `/splash`, `/login`, `/register`, `/email-verification` and
`/auth/profile-photo` redirects an unauthenticated visitor to the login screen. A reviewer who
opens the app sees a wall and nothing else. If they cannot get past it, the result is **2.1 App
Completeness** with "we were unable to sign in", and that is the single most common first-submission
rejection for apps shaped like this one.

Worse, there are two further walls behind the first:
1. **Email verification** — `/email-verification` is a real screen in the post-registration flow.
2. **Email OTP / 2FA** — `login_screen.dart:81`: if the Firestore user document has
   `twoFactorEnabled == true`, login pushes `/login/2fa-verify` and a code is emailed. The reviewer
   has no access to that mailbox. This alone will fail the review.

### What you must prepare before submitting

Create a dedicated review account — not your own account — and then, in the Firebase console, put
its Firestore `users/{uid}` document into a state the reviewer can actually use.

1. **Register the account in the app** with an address you control, e.g.
   `applereview@<your-domain>` and a password you are willing to put in App Store Connect.
2. **Email must be verified.** Complete the verification link so the account is past
   `/email-verification` and never shows that screen to the reviewer.
   - Firebase Console → Authentication → Users → the account → confirm it is marked verified.
     If it is not, verify it by clicking the link in the mailbox; this cannot be faked from the app.
3. **`twoFactorEnabled` must be `false`** on `users/{uid}` in Firestore. This is the item that
   silently kills the review. Check the field by hand — do not assume the default.
4. **Seed the account so the reviewer can exercise everything Apple will look for:**
   - a **profile photo** set (so the photo permission and Storage path are visibly in use);
   - at least one **accepted friend**, so Friends is not an empty screen;
   - at least one **finished game** in history, so the profile and replay screens have content;
   - at least one **chat thread with several messages** in it, so chat, **block** and
     **[VERIFY] report** can all be reached without needing a second live human;
   - **[VERIFY]** a second seeded account for the reviewer to block/report/challenge. Blocking
     the app's own support account is fine; blocking nothing is not demonstrable.
5. **Leave `showOnMap` at its default `false`** on the review account, so the reviewer sees the
   opt-in state the privacy label describes. They can turn it on themselves if they want to test it.
6. Fill in **Sign-In Required: Yes**, and put the credentials in the User Name / Password fields —
   not only in the Notes.
7. Provide a **Contact** first/last name, phone and email that you actually answer. Apple uses it.

### App Review Information → Notes — paste this

```
SIGN-IN IS REQUIRED. The app is an online multiplayer board-game service; there is no offline
or guest mode, because every mode (matchmaking, tournaments, friends, chat, leaderboard) is
server-backed and tied to an account.

Demo account (email / password are in the User Name and Password fields above):
  - The email address on this account is already verified, so you will not see the email
    verification screen.
  - Two-factor authentication is DISABLED on this account, so no one-time code will be emailed
    to you during sign-in. If you are ever asked for a code, please contact us in the Resolution
    Center rather than creating a new account - a new account will hit the verification step.
  - The account is pre-seeded with a profile photo, one friend, one completed game and one chat
    thread, so every feature below can be exercised immediately.

What to try:
  1. Home -> pick Chess, Draughts or Dominoes -> "Play bot" for an instant offline-style game
     that needs no second player.
  2. Home -> Play online -> matchmaking. Note that a live opponent may not be available at the
     moment you test; the bot path above covers the same board and clock code.
  3. Chat tab -> open the seeded thread. Chat is user-to-user and is not moderated by us.
  4. Blocking a user: open the other user's profile (or the chat header) -> Block. The block list
     is at Settings -> Privacy -> Blocked users, where a block can be lifted.
  5. Tournaments -> join or create an arena.
  6. Campaign -> single-player chapters.
  7. Map: the nearby-players map is OPT-IN and OFF by default. Nothing about your location is
     collected or shown until you enable it yourself in the app. Location is requested
     "when in use" only; the app has no background location mode.

ACCOUNT DELETION (Guideline 5.1.1(v)):
  Settings -> Account -> "Delete account" (red, at the bottom of the Account screen) -> confirm.
  The account is asked for the current password, then the Firebase Auth user and the associated
  Firestore user data are permanently deleted. This is a full deletion, not a deactivation, and
  it does not require contacting support.

  IMPORTANT: this deletion is real. Once you use it, the demo account above no longer exists.
  If you need to sign in again at any point in this review, please say so in the Resolution
  Center and we will recreate the account within a few hours with the same credentials.

Privacy:
  - No ads, no in-app purchases, no analytics SDK, no third-party trackers, no advertising
    identifier. Data used to track you: No.
  - Push notifications are used for game invites, move alerts and chat, after the standard iOS
    permission prompt. Declining the prompt does not block any feature.
  - Privacy policy: https://chess-ac4eb.web.app/privacy
  - Support: https://chess-ac4eb.web.app/support

The app is iPhone-only (it is not offered for iPad) and requires iOS 15.0 or later.
```

> **Recreate the review account before every resubmission.** If the reviewer exercises Delete
> Account — and you have just told them where it is, so they will — the credentials in App Store
> Connect are dead. The next reviewer hits "invalid email or password", which reads to them as 2.1
> incompleteness. Re-register it, re-verify the email, re-confirm `twoFactorEnabled: false`, and
> re-seed it, every single time.

---

## 10. Known rejection risks and how we answer them

| Guideline | Risk for this app | Answer / what must be true at submission |
|---|---|---|
| **4.8 — Login Services** | The app offers **Google Sign-In** (`google_sign_in`, `lib/features/auth/widgets/google_sign_in_button.dart`). Offering a third-party login without an equivalent privacy-preserving option is the classic 4.8 hit. | **Sign in with Apple is being added in parallel:** `pubspec.yaml` now carries `sign_in_with_apple: ^6.1.4` and `lib/core/services/auth_service.dart` implements the nonce, `SignInWithApple.getAppleIDCredential`, and `completeAppleSignUp`. **[VERIFY] two things before building:** (a) `ios/Runner/Runner.entitlements` must contain a `com.apple.developer.applesignin` key — at the time of writing it contains only `aps-environment`, and without the entitlement the button throws at runtime; (b) the **Sign In with Apple** capability must be enabled on the App ID *before* the provisioning profile is minted (see `IOS_BUILD_NOTES.md` step 1). Secondary defence if SIWA slips: email+password signup exists and collects only email and a user-chosen handle, which is the documented "equivalent option" carve-out — but do not rely on it, reviewers apply it inconsistently. |
| **5.1.1(v) — Account Deletion** | Mandatory for any app that creates an account. Absence = certain rejection. | **Implemented.** `account_screen.dart:259` "Delete account" → `auth_service.dart:306 deleteAccount()`. Path spelled out for the reviewer in §9. Not a deactivation, no support contact required. |
| **1.2 — Safety, User-Generated Content** | Apple requires **all four**: (a) a method to filter objectionable content, (b) a mechanism to **report** offensive content with timely response, (c) the ability to **block** abusive users, (d) published contact info. | (c) **done** — `blockUser`/`unblockUser` in `firestore_service.dart:411`, UI in chat and profile, list at Settings → Privacy → Blocked users. (d) **done** once the support page is live. (a) and (b) **[VERIFY] — NOT FOUND in the repo.** There is no report-user / report-message flow and no content filter; the only "report" in the code is *report a bug*. This is the most likely rejection after 2.1. Either a report action ships in this build, or expect a 1.2 round trip. |
| **2.1 — App Completeness** | Login wall with no guest mode; plus `ios/Runner/Info.plist` still contains the literal placeholder `REPLACE_WITH_REVERSED_CLIENT_ID` in `CFBundleURLSchemes`, which makes Google Sign-In fail on device — a reviewer tapping that button sees a broken feature. | Working demo credentials with verified email and 2FA off (§9). **[VERIFY]** the REVERSED_CLIENT_ID placeholder must be replaced from the real `GoogleService-Info.plist` before the submitted build — see `IOS_BUILD_NOTES.md` step 3. |
| **5.1.1 — Privacy Policy** | Policy URL must be reachable, app-specific, and must match the App Privacy label and the in-app text. | **[VERIFY] twice:** (1) `firebase.json` has no `hosting` block yet, so `/privacy` may 404; (2) the in-app policy in `privacy_screen.dart` still says "Grandmaster" / `privacy@grandmasterapp.com` and claims usage-data collection that the label says is not collected. Both must be fixed or the label and the policy contradict each other in writing. |
| **4.5.4 — Push Notifications** | Push must be optional, must not be required to use the app, and must not be used for advertising or promotion. | Push is genuinely optional: `lib/main.dart` wraps `NotificationService().initialize()` in try/catch before `runApp()` precisely so that a denied or failed registration cannot block launch, and every feature works with notifications declined. Notifications carry game invites, moves and chat only — no marketing. Entitlement `aps-environment = production` is present; `UIBackgroundModes = remote-notification` is declared and used. |
| **2.3.7 / 1.2 — Age rating mismatch** | Self-rating a chat app 4+. | Rate **12+** with communication and UGC declared. See §7. |
| **3.1.1 — In-App Purchase** | N/A — nothing is sold. | Leave the IAP section empty; do not mention any paid feature in the description. |

---

## 11. Screenshots

### Required sizes — read this carefully, it has changed

- **6.9" iPhone display is the current primary requirement: `1290 × 2796` or `1320 × 2868`
  (portrait).** App Store Connect will not let you submit without it.
- **The older 6.5" / `1242 × 2688` set is NOT the current primary requirement.** If you are working
  from an old checklist or an old blog post, ignore it. A 6.5" set alone will be rejected by the
  upload form, not by a human, so you will not even get a review cycle out of it.
- **No iPad set is needed.** `TARGETED_DEVICE_FAMILY = "1"` — the app is iPhone-only and App Store
  Connect will not ask for iPad screenshots. Do not "helpfully" add them; adding them implies iPad
  support the binary does not have.
- Minimum 3, maximum 10 per size. Aim for 8.
- **PNG or JPEG, RGB, and no alpha channel.** A PNG with an alpha channel is rejected at upload
  with a generic error. Simulator screenshots and most design-tool exports carry alpha by default,
  so assume yours do until you have checked.

### Strip alpha and resize — copy/paste

**ImageMagick** (v7 `magick`; on v6 use `convert` / `mogrify`). Run from the folder holding the raw
captures, writing into `out/`:

```bash
mkdir -p out
magick mogrify -path out -alpha remove -alpha off -background black \
  -resize 1290x2796! -colorspace sRGB -strip *.png
```

Verify afterwards — `srgb` is good, `srgba` means alpha is still there:

```bash
magick identify -format "%f  %wx%h  %[channels]\n" out/*.png
```

**Python / Pillow** (no ImageMagick install needed):

```python
from PIL import Image
from pathlib import Path

out = Path("out"); out.mkdir(exist_ok=True)
for p in sorted(Path(".").glob("*.png")):
    Image.open(p).convert("RGB").resize((1290, 2796), Image.LANCZOS).save(out / p.name, "PNG")
```

`.convert("RGB")` is what removes the alpha channel; `.resize(...)` forces the exact pixel size.
If your capture has a different aspect ratio this will stretch it — capture at 6.9" aspect
(iPhone 16 Pro Max / 17 Pro Max simulator) and the resize is a no-op scale.

### Naming

Name the files `01_...` through `08_...`. App Store Connect uploads in the order the OS hands it
the files, which is alphabetical; two-digit zero-padded prefixes make the store order deterministic
and save you from dragging tiles around afterwards.

```
01_home.png
02_chess_game.png
03_draughts_game.png
04_dominoes_game.png
05_tournaments_arena.png
06_campaign.png
07_friends_chat.png
08_leaderboard.png
```

### Screens worth capturing

The first two tiles are what most users ever see — put the strongest boards there.

1. **Chess board mid-game** with both clocks running and the move list visible — this is the app's
   single most convincing image.
2. **Home screen** showing the three-game choice, so the "3 in 1" claim is visible immediately.
3. **Draughts board mid-game** with a multi-jump available.
4. **Dominoes table** in play.
5. **Tournaments / arena lobby** with participants listed — proof it is a live service.
6. **Campaign map** showing locked and unlocked chapters.
7. **Friends + chat**, either the chat thread or the in-game chat panel.
8. **Leaderboard** with the global ranking, or the **nearby-players map**.

If you use the map screenshot, blur or use seeded test accounts — do not publish a screenshot that
shows real users' handles next to real locations.

### Also needed on the version page

- **App Preview video:** optional. Skip it for v1.
- **What's New:** this is the first iOS release, so use:
  ```
  First release on iPhone. Chess, draughts and dominoes in one app: online multiplayer, arena
  tournaments, campaign mode, bot practice, friends, groups and chat, leaderboard, and 10 languages.
  ```
- **1024×1024 marketing icon:** already opaque — `Icon-App-1024x1024@1x.png` is PNG colour type 2
  (RGB, no alpha), and `pubspec.yaml` sets `remove_alpha_ios: true`. Nothing to do.

---

## 12. Pricing and Availability

| Field | Value |
|---|---|
| Price | **Free** (Price Schedule → Free) |
| Availability | **All Countries and Regions** |
| Pre-Orders | No |
| Distribution on Vision Pro / Mac | **Off** — iPhone-only app; leave "Make this app available on Mac" and Vision Pro unchecked |

Set this **before** submitting. If Pricing and Availability is incomplete, the Submit button stays
disabled and it is easy to lose an afternoon looking for the real error somewhere else.

---

## 13. Pre-submit checklist

- [ ] App record exists in App Store Connect with Bundle ID `com.chessapp.chessApp`
- [ ] `https://chess-ac4eb.web.app/privacy` and `/support` both load in a browser
- [ ] In-app privacy text no longer says "Grandmaster"
- [ ] Review account: registered, **email verified**, **`twoFactorEnabled: false`**, photo + friend
      + finished game + chat thread seeded
- [ ] Credentials typed into App Review Information → User Name / Password, Sign-In Required = Yes
- [ ] Notes text from §9 pasted
- [ ] App Privacy answered per §8 — Tracking: **No**
- [ ] Age rating questionnaire completed with communication + UGC declared → **12+**
- [ ] 8 screenshots at 1290×2796, RGB, no alpha, named `01_`…`08_`
- [ ] Description, subtitle, promotional text, keywords pasted; keywords contain no spaces
- [ ] Pricing: Free / All Countries
- [ ] Build visible in TestFlight and selected on the version page
- [ ] Export compliance answered (`ITSAppUsesNonExemptEncryption = false` is already in Info.plist,
      so App Store Connect should not ask — if it does, answer "No" to the exempt-encryption question)
