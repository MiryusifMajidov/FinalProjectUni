# App Store-a ilk yükləmə — CheckMate 1.3.0 (iOS)

Bu fayl App Store-a ilk göndərişin tam yoludur: addımlar sırası ilə, hər sahəyə
yapışdırılacaq mətn hazırdır. Mağaza mətnləri ingiliscədir (əsas dil English).

Köhnə sənədlər: `IOS_BUILD_NOTES.md` bölmə 3, 4 və 6 (build-in uğurunu necə
yoxlamaq, sertifikat təhlükəsizliyi, xətalar) hələ də doğrudur. Mağaza mətnləri
və cavablar üçün isə bu fayl əsasdır, `APP_STORE_METADATA.md` 1.1.0 dövründən
qalıb.

---

## 0. Repo tərəfi — hazırdır

8 noyabr 2026-da yoxlanıldı:

| Nə | Vəziyyət |
|---|---|
| Bundle ID `com.ludodo.checkmate`, yalnız iPhone, iOS 15+ | ✓ |
| Push + Sign in with Apple entitlement-ləri | ✓ |
| `ITSAppUsesNonExemptEncryption = false` (şifrələmə sualı avtomatik cavablanır) | ✓ |
| Kamera, foto, məkan icazə mətnləri | ✓ |
| Google Sign-In üçün `REVERSED_CLIENT_ID`, `GoogleService-Info.plist` | ✓ |
| 1024 ikon alfa kanalsız | ✓ |
| Hesab silmə, şikayət, bloklama, söyüş filtri | ✓ |
| Qonaq rejimi və oflayn oyun (yoxlayıcı qeydiyyatsız girə bilir) | ✓ |
| `https://chess-ac4eb.web.app/privacy`, `/support`, `/terms` | ✓ hamısı HTTP 200 |
| "Alpha" fiqur dəsti | **Çıxarıldı.** Lisenziyası "free for personal non commercial use" idi, mağazada paylamağa icazə vermir. Onu seçənlərdə CBurnett açılır. |
| Ekran şəkilləri, 8 ədəd, alfa kanalsız | ✓ 6.9″ və 6.5″ üçün ayrıca dəstlər, bax 5.1 |

**Kod GitHub-a push olunmalıdır.** Codemagic `master` budağından build edir; bu
dəyişikliklər push olunmasa, köhnə kod yığılar.

---

## 1. Apple Developer — developer.apple.com/account

Əvvəlki cəhddən bəziləri artıq mövcud ola bilər. Hər addımda əvvəlcə **yoxla**,
yalnız olmayanı yarat.

### 1.1 App ID
Certificates, Identifiers & Profiles → **Identifiers** → `com.ludodo.checkmate`.
- Yoxdursa: **+** → App IDs → App → Bundle ID (Explicit) `com.ludodo.checkmate`.
- Capabilities-də bu ikisi **işarəli** olsun:
  - **Push Notifications**
  - **Sign In with Apple**
- Bunlardan biri sonradan işarələnibsə, **Profiles** bölməsində
  `com.ludodo.checkmate` üçün köhnə profili sil. Codemagic yenisini yaradacaq;
  köhnə profildə bu imkanlar olmur.

### 1.2 Push açarı (APNs)
**Keys** bölməsində "Apple Push Notifications service" açarı varsa, yenisi lazım
deyil: bir açar komandanın bütün tətbiqlərinə işləyir (laptops.az ilə ortaqdır).
- Yoxdursa: **+** → APNs işarələ → `.p8` faylını **dərhal yüklə** (bir dəfə verilir).
  Key ID-ni yaz.
- Firebase Console → `chess-ac4eb` → Project settings → **Cloud Messaging** →
  iOS app `com.ludodo.checkmate` → **APNs Authentication Key** → `.p8`, Key ID,
  Team ID `PLY98763D4`.
- Bu olmasa tətbiq işləyir, sadəcə iPhone-a bildiriş gəlmir.

### 1.3 Firebase-də Apple ilə giriş
Firebase Console → Authentication → Sign-in method → **Apple** → Enabled.
Bu olmasa "Sign in with Apple" düyməsi xəta verir və Apple bunu yoxlayır (4.8).

---

## 2. App Store Connect — appstoreconnect.apple.com

### 2.1 Müqavilə
**Business** (və ya Agreements, Tax, and Banking) → **Free Apps** müqaviləsi
**Active** olmalıdır. Pulsuz tətbiq üçün bank və vergi formu lazım deyil.

### 2.2 Tətbiq qeydi
**Apps** siyahısında CheckMate artıq varsa, yenisini **yaratma**, onu aç.
Yoxdursa: **+** → New App:

| Sahə | Dəyər |
|---|---|
| Platforms | iOS |
| Name | `CheckMate: Chess Dama Domino` |
| Primary Language | English (U.S.) |
| Bundle ID | `com.ludodo.checkmate` |
| SKU | `checkmate-ios` |
| User Access | Full Access |

Ad başqa tətbiqdə tutulubsa, Apple xəta verəcək. Onda `CheckMate: Chess & Draughts`
yaz və mənə de.

---

## 3. Codemagic — build

### 3.1 Bir dəfəlik yoxlama (codemagic.io → CheckMate tətbiqi)
- **Build configuration source** = `codemagic.yaml`. "Workflow Editor" seçilibsə,
  yaml-dakı heç bir addım işləmir.
- Team settings → Integrations → App Store Connect açarının adı
  **`laptops_az_asc_key`** olmalıdır.
- Environment variables → qrup **`ios_signing`** → `CERTIFICATE_PRIVATE_KEY`
  (Secure). laptops.az-dakı ilə **eyni dəyər** olsun.

### 3.2 Build-i başlat
**Start new build** → branch **master** → workflow **ios-appstore**.
Təxminən 25–40 dəqiqə çəkir.

### 3.3 Uğurlu olduğunu necə bilərsən
Yaşıl işarə hələ heç nə demək deyil. Hər iki şərt ödənməlidir:
1. Codemagic-də sonda **"App Store Connect"** publishing addımı da yaşıl olmalıdır.
2. App Store Connect → tətbiq → **TestFlight** sekmasında **yeni build** sətri
   görünməlidir (versiya 1.3.0). Əvvəl "Processing" yazılır, 5–30 dəqiqəyə
   hazır olur.

Qırmızı olsa: log-da `ITMS-`, `already been used`, `No suitable application
records` sözlərini axtar. Ən yaxşısı log-u mənə göndər.

---

## 4. TestFlight — göndərməzdən əvvəl öz iPhone-unda yoxla

Apple-ın ən çox rədd etdiyi hal tətbiqin yoxlayıcının telefonunda çökməsidir.
Göndərməzdən əvvəl özün sına:

1. iPhone-a **TestFlight** tətbiqini App Store-dan yüklə.
2. App Store Connect → TestFlight → **Internal Testing** → **+** → qrup yarat →
   öz Apple ID-ni əlavə et → build-i qrupa əlavə et.
3. Telefona gələn dəvətlə tətbiqi yüklə və bunları yoxla:

- [ ] Tətbiq açılır, ağ ekranda qalmır
- [ ] **Play now as guest** işləyir
- [ ] **Play offline** → bot ilə şahmat oyunu, sonra dama, sonra domino
- [ ] **Sign in with Apple** ilə giriş
- [ ] **Google** ilə giriş
- [ ] E-poçt ilə qeydiyyat → doğrulama məktubu gəlir
- [ ] Profil şəkli: kamera və qalereya icazəsi soruşulur, şəkil yüklənir
- [ ] Xəritə: məkan icazəsi soruşulur, xəritə açılır
- [ ] Bildiriş icazəsi soruşulur (rədd etsən də tətbiq işləyir)
- [ ] Arena-ya qoşulmaq, onlayn oyun axtarmaq
- [ ] Ayarlar → Account → **Delete account** (sınaq hesabında!)

Problem çıxsa göndərmə; ekran şəklini mənə at.

---

## 5. Versiya səhifəsi — "1.0 Prepare for Submission"

Sol menyuda iOS App altındakı versiya. Versiya nömrəsini **1.3.0** et.

### 5.1 Previews and Screenshots
Versiya səhifəsində şəkillərə bas, **Media Manager** açılır. Orada hansı qutu
"Required" kimi göstərilirsə, ona uyğun qovluqdan yüklə:

| Media Manager-də görünən qutu | Qovluq (`marketing/store-screenshots/out/`) | Fayllar |
|---|---|---|
| **iPhone with Dynamic Island (medium display)**: 1206×2622 / 1179×2556 | `appstore-iphone-medium-1206x2622` | `iphone-medium-01.png` … `08` |
| iPhone 6.9" Display: 1320×2868 | `appstore-iphone-6.9in-1320x2868` | `iphone69-01.png` … `08` |
| iPhone 6.5" Display: 1284×2778 | `appstore-iphone-6.5in-1284x2778` | `iphone65-01.png` … `08` |

9 noyabr 2026-da Apple yalnız **medium display** qutusunu tələb edirdi. Digər
iPhone ölçüləri üçün şəkilləri özü uyğunlaşdırır. Qutuda köhnə dizaynın solğun
şəkilləri ("Using Existing Assets") görünsə, əvvəlcə **Remove All**, sonra
**Upload**.
`googleplay` qovluğundakı `01.png` … `08.png` faylları Apple-a uyğun **deyil**
(1080×1920): onları yükləsən "File dimensions are invalid" xətası çıxır.
iPad bölməsi görünməyəcək (tətbiq yalnız iPhone üçündür).

### 5.2 Promotional Text (≤170) — 142 simvol
```
A new arena starts every 30 minutes. Play chess, draughts and dominoes online, against a six-level bot, or offline with a friend on one phone.
```

### 5.3 Description (≤4000)
```
Chess, draughts and dominoes at one table. Play online, join an arena, or practise against the bot. No ads, nothing to buy.

THREE GAMES
• Chess: full rules, including castling, en passant, promotion, draw offers and resignation.
• Draughts: six rule sets (Russian, International 10×10, German, Brazilian, Turkish and Standard). Forced captures and multi-jumps are handled for you.
• Dominoes: Draw or Block, for two players or four at a table.

PLAY THE WAY YOU LIKE
• Online: ranked games with bullet, blitz and rapid clocks. If nobody is free within 30 seconds, a computer opponent steps in for an unrated game, so you are never left waiting.
• Friends: send an invite, or pass one phone between two players.
• Bot: six levels for chess and draughts, from Beginner to Master. The dominoes bot plays at one steady strength.
• Offline: bot games and two-player games need no account and no internet.

ARENAS
A new arena starts every 30 minutes. A win scores 2 points and a draw 1. Win two in a row and you are on fire: your games score double until you stop winning. You can also create your own arena.

HINTS ON THE BOARD
Stuck? Ask for a hint and the move is drawn on the board.

SOLO QUESTS
A path of chapters for each game: Grandmaster Path for chess, Diagonal Road for draughts and Bones Trail for dominoes.

FRIENDS AND CHAT
Add friends, chat one-to-one or in groups, and watch their games live.

PLAYER MAP
See players around the world on the map. It is off until you switch it on, and your position is shown only roughly, to about a kilometre.

RATINGS
A separate rating for each game and a global leaderboard.

TEN LANGUAGES
English, Azerbaijani, Turkish, Russian, German, Spanish, French, Hindi, Urdu and Chinese.

YOUR ACCOUNT
• Start as a guest in one tap and add an email later to keep your account.
• Sign in with Apple, Google or email.
• Two-factor authentication and a list of your signed-in devices.
• Block or report any player.
• Delete your account inside the app: Settings → Account → Delete account.

Free. Everything in the app is included.
```

### 5.4 Keywords (≤100) — 97 simvol
```
dominoes,board,games,multiplayer,online,tournament,bot,offline,strategy,russian,brazilian,friends
```

### 5.5 URL-lər
| Sahə | Dəyər |
|---|---|
| Support URL | `https://chess-ac4eb.web.app/support` |
| Marketing URL | `https://chess-ac4eb.web.app` |

### 5.6 Build
**Build** bölməsində **+** → TestFlight-da yoxladığın build-i seç.

### 5.7 Copyright
```
2026 Yusif Majidov
```
Apple Developer hesabındakı ad fərqlidirsə, həmin adı yaz.

### 5.8 Version Release
**Manually release this version** seç. Apple təsdiq edəndən sonra "Release"
düyməsini sən basana qədər tətbiq mağazada görünməyəcək.

---

## 6. App Information (sol menyu)

| Sahə | Dəyər |
|---|---|
| Subtitle (≤30) | `Checkers, draughts & arenas` (27) |
| Category | Primary **Games → Board**, Secondary **Games → Strategy** |
| Content Rights | **Yes, it contains third-party content** → "I have the rights" işarələ. (Fiqur dəstləri açıq lisenziyalıdır: CC BY-SA və GPL. Müəlliflər tətbiqin lisenziya səhifəsində göstərilib.) |
| Privacy Policy URL | `https://chess-ac4eb.web.app/privacy` |

### 6.1 Age Rating — sorğuda nə cavab verəcəksən
- Zorakılıq, cinsi məzmun, çılpaqlıq, söyüş, alkoqol/tütün/narkotik, qorxu,
  tibbi məzmun, qumar (simulyasiya da daxil), müsabiqələr: hamısı **None / No**.
- **Unrestricted Web Access:** No
- **User-Generated Content:** **Yes**: istifadəçi adı, profil şəkli, mesajlar
- **Messaging and Chat:** **Yes**
- **Advertising:** No
- **Parental Controls / Age Assurance:** No

Yaşı Apple cavablara görə özü hesablayır. Çat olan tətbiqlərdə adətən 13+ çıxır.
4+ almaq üçün çatı gizlətmə: yoxlayıcı çatı açanda bu, rədd səbəbi olur.

---

## 7. App Privacy (sol menyu)

"Do you or your third-party partners collect data from this app?" → **Yes**.
Hər tip üçün: Purpose = **App Functionality**, Linked to user = **Yes**,
Used for tracking = **No**.

| Kateqoriya | Tip | Nəyə görə |
|---|---|---|
| Contact Info | **Email Address** | qeydiyyat və giriş |
| Contact Info | **Name** | görünən ad; Apple ilə girişdə ad gəlir |
| User Content | **Photos or Videos** | profil şəkli |
| User Content | **Gameplay Content** | oyun tarixçəsi, reytinq |
| User Content | **Other User Content** | mesajlar, istifadəçi adı |
| Location | **Coarse Location** | xəritə; yalnız istifadəçi açanda, ~1 km yuvarlaqlaşdırılıb |
| Identifiers | **User ID** | hesab ID-si |
| Identifiers | **Device ID** | push bildiriş tokeni |
| Other Data | **Other Data Types** | cihaz modeli və iOS versiyası (aktiv cihazlar siyahısı) |

**No** olanlar: Usage Data, Diagnostics, Financial Info, Health, Browsing/Search
History, Purchases, Sensitive Info, Contacts.
Tracking sualı: **No** (reklam yoxdur, IDFA oxunmur).

---

## 8. Pricing and Availability
Price **Free (0)**, Availability **All countries or regions**.
Bu bölmə boş qalsa "Submit" düyməsi aktiv olmur.

---

## 9. App Review Information — ən riskli bölmə

### 9.1 Sınaq hesabı (özün yaratmalısan)
1. Tətbiqdə yeni hesab aç (öz hesabın yox): məsələn `checkmate.review@gmail.com`
   kimi yeni e-poçt.
2. E-poçtu doğrula (məktubdakı linkə bas).
3. İki faktorlu doğrulama **söndürülü** qalsın (Ayarlar → Privacy).
4. Hesabla bir-iki bot oyunu oyna ki, profil boş olmasın.
5. App Store Connect-də **Sign-in required** işarələ, User name və Password
   sahələrinə bu hesabı yaz.

> Yoxlayıcı hesabı silə bilər (biz onu silməyi göstəririk). Rədd olunub yenidən
> göndərsən, əvvəlcə hesabın hələ işlədiyini yoxla.

### 9.2 Contact Information
Ad, soyad, telefon, e-poçt: Apple zəng edə bilər, real məlumat yaz.

### 9.3 Notes — yapışdır
`<VIDEO LINK>` yerinə ekran videosunun linkini qoy (bax 9.4).
```
GUIDELINE 1.2 (previous submission 4f7981be): fixed in this build. Before any sign-in or sign-up (guest, Apple, Google, email), the app now shows the Terms of Use, which state zero tolerance for objectionable content and abusive users, and the user must tap "I agree" to continue. Screen recording on a physical iPhone showing the terms agreement, reporting and blocking: <VIDEO LINK>

The app can be used without an account. On the first screen, tap "Play now as guest" (an anonymous account on this device) or "Play offline" (bot games and two-player games, no account and no internet). Features that keep data across devices (friends, chat, ratings) also work for guests; the demo account above is a regular email account with the email verified and two-factor authentication off.

What to try:
1. Play tab: pick Chess, Checkers or Domino at the top. The whole app switches to that game's colour.
2. Play vs bot: choose one of six levels. On your turn, tap Hint and the suggested move is drawn on the board.
3. Arena tab: join the live arena. A new one starts every 30 minutes. Empty arena seats are filled by computer players marked "BOT".
4. Play online: matchmaking. If no other player is found within 30 seconds, the app starts an unrated game against a computer opponent so nobody is left waiting. That opponent plays under a player name. These games never change ratings.
5. Safety: every user profile and chat has Report and Block. Messages pass a profanity filter, and we review every report. Blocked users are listed in Settings > Privacy > Block list.
6. Map (pin icon at the top of the Play tab): off by default. Location is requested "when in use" only and stored rounded to about 1 km.

Account deletion (5.1.1(v)): Settings (gear icon) > Account > Delete account > confirm. It permanently deletes the account and its data; no support contact needed. If you delete the demo account, contact us and we will recreate it.

Privacy: no ads, no in-app purchases, no analytics SDK, no tracking. Push notifications are optional; declining them blocks nothing.

The app is for iPhone only and needs iOS 15 or later.
```

**Bənd 4 barədə.** Onlayn axtarışda 30 saniyədən sonra gələn rəqiblər oyunçu adı
ilə oynayır. İstifadəçi onların bot olduğunu bilmir. Apple bunu qeyd olunmamış
funksiya (2.3.1) və ya istifadəçini aldatmaq kimi qiymətləndirə bilər. Ona görə
yoxlayıcıya açıq yazmışıq. Yoxlayıcı bunu öz-özünə tapsa, gizlədilmiş kimi
görünər, və bu daha pis nəticə verir. Bu qeydi istifadəçilər görmür.
Yenə də bu, göndərişdə qalan **ən böyük risk**dir: Apple belə rəqiblərin
istifadəçiyə göstərilməsini tələb edə bilər. Belə olsa, düzəliş kiçikdir:
iOS-da onların yanına "Bot" yazısı qoymaq.

### 9.4 Apple-ın əvvəlki rəddi (Guideline 1.2) — video və cavab

Apple 30 sentyabr 2026-da tətbiqi rədd edib: istifadəçi qeydiyyatdan və ya
girişdən **əvvəl** şərtlərlə (EULA) razılaşmalı idi. Bu build-də bu var: ilk
girişdən əvvəl "Terms of Use" pəncərəsi açılır, "I agree" basılmadan heç bir
giriş üsulu işləmir. Apple **real cihazda çəkilmiş ekran videosu** istəyir.

**Videonu iPhone-da çək** (TestFlight-dan yüklənmiş yeni build ilə):
1. Tətbiqi telefondan sil və TestFlight-dan yenidən yüklə. Razılıq yadda
   saxlanılır; təzə quraşdırmada pəncərə yenə açılacaq.
2. Control Center → **Screen Recording** düyməsi ilə yazını başlat.
3. Tətbiqi aç → **Play now as guest** → "Terms of Use" pəncərəsi açılır →
   **Read the full Terms** bas və 4-cü bəndi ("Acceptable Use — zero
   tolerance") göstər → bağla → **I agree**.
4. Başqa real istifadəçinin profilini aç (məsələn, öz əsas hesabının) →
   sağ yuxarı menyu → **Report** → "Inappropriate content" → "Report
   submitted" yazısı görünsün.
5. Həmin menyudan **Block** → təsdiqlə → Settings → Privacy → **Block
   list** siyahısında həmin istifadəçini göstər.
6. Mümkünsə çatda da menyudan Report və Block olduğunu göstər.
7. Yazını dayandır. Video "Photos" tətbiqində olacaq.

Videonu Google Drive və ya YouTube-a (**Unlisted**) yüklə, linki hər kəs
aça bilsin. Həmin linki 9.3-dəki qeyddə `<VIDEO LINK>` yerinə yaz. Videonu
App Review Information → **Attachment** sahəsinə də əlavə et.

"Report submitted" əvəzinə "Could not send report" çıxsa, dayan və mənə yaz.
Bu o deməkdir ki, Firestore qaydaları serverdə köhnədir.

**App Review mesajına cavab** (App Review bölməsində, Apple-ın mesajının
altında **Reply**):
```
Hello,

Thank you for the review. We have addressed Guideline 1.2 in build 1.3.0:

- Terms of Use (EULA): before any sign-in or sign-up (guest, Sign in with Apple, Google or email), the app shows the Terms of Use and the user must tap "I agree" to continue. The terms state that there is no tolerance for objectionable content or abusive users, and that offending accounts are removed.
- Flagging content: every user profile and every chat has a menu in the top-right corner with "Report", where the user picks a reason (for example "Inappropriate content"). We review every report within 24 hours, remove the content and remove the offending account.
- Blocking: the same menu has "Block". Blocked users are listed in Settings > Privacy > Block list.
- Chat messages pass a profanity filter before they are sent.

Screen recording on a physical iPhone: <VIDEO LINK>
The recording is also attached in the App Review Information section.

Best regards,
Miryusif Majidov
```

**24 saat öhdəliyi real olmalıdır.** Şərtlərdə və cavabda "hər şikayətə 24 saat
ərzində baxırıq" yazılıb. Şikayətlər Firebase Console → Firestore →
**reports** kolleksiyasına düşür. Ora hər gün bax. Pozuntu varsa, mesajı sil
və hesabı Authentication bölməsində **Disable** et.

---

## 10. Göndərmək
Versiya səhifəsində yuxarıda **Add for Review** → **Submit to App Review**.
Vəziyyət belə dəyişir: "Waiting for Review" → "In Review" → "Pending Developer
Release". Adətən 1–3 gün çəkir.

**Rədd olunsa:** App Store Connect-də **App Review** bölməsində Apple-ın mesajı
olacaq. Mesajı olduğu kimi mənə göndər; çox vaxt yeni build lazım olmur,
cavab yazmaq və ya bir sahəni düzəltmək kifayət edir.

---

## 11. İlk uğurlu build-dən sonra (mənlik)
Codemagic artifacts-dan `Podfile.lock` faylını endir, repo-ya `ios/Podfile.lock`
kimi əlavə et. Bundan sonra hər build eyni kitabxana versiyaları ilə yığılacaq.
