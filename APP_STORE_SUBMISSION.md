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
Şəkil qutusunun üstündə ölçü seçimi var. Hər ölçü öz qovluğundan yüklənməlidir:

| App Store Connect-də seçilən | Qovluq (`marketing/store-screenshots/out/`) | Fayllar |
|---|---|---|
| **iPhone 6.9" Display** | `appstore-iphone-6.9in-1320x2868` | `iphone69-01.png` … `08` |
| **iPhone 6.5" Display** | `appstore-iphone-6.5in-1284x2778` | `iphone65-01.png` … `08` |

Biri kifayətdir: 6.9″. Digər iPhone ölçüləri üçün Apple bunları özü kiçildir.
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
• Online: ranked games with bullet, blitz and rapid clocks.
• Friends: send an invite, or pass one phone between two players.
• Bot: six levels, from Beginner to Master.
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
```
The app can be used without an account. On the first screen, tap "Play now as guest" (an anonymous account on this device) or "Play offline" (bot games and two-player games, no account and no internet). Features that keep data across devices (friends, chat, ratings) also work for guests; the demo account above is a regular email account with the email verified and two-factor authentication off.

What to try:
1. Play tab: pick Chess, Checkers or Domino at the top. The whole app switches to that game's colour.
2. Play vs bot: choose one of six levels. On your turn, tap Hint and the suggested move is drawn on the board.
3. Arena tab: join the live arena. A new one starts every 30 minutes. Empty arena seats are filled by computer players marked "BOT".
4. Play online: matchmaking. If no other player is found within 30 seconds, the app starts an unrated game against a computer opponent so nobody is left waiting. That opponent plays under a player name. These games never change ratings.
5. Safety: every user profile and chat has Report and Block. Messages pass a profanity filter, and we review every report. Blocked users are listed in Settings > Privacy.
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
