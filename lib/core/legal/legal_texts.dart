/// Canonical legal copy for the app.
///
/// Both the About screen and Settings -> Privacy render these, and the same
/// wording is published at the hosted URLs below. Keeping one source avoids the
/// situation App Review penalises: two privacy policies in one app that
/// disclose different things.
library;

const kSupportEmail  = 'privacy@grandmasterapp.com';
const kPrivacyUrl    = 'https://chess-ac4eb.web.app/privacy';
const kTermsUrl      = 'https://chess-ac4eb.web.app/terms';

const kPolicyParagraphs = [
  'This policy explains what CheckMate collects, why, and what you can do '
  'about it. The same text is published at $kPrivacyUrl.',

  '1. Information We Collect\n'
  'Account: your email address and username, handled by Firebase '
  'Authentication. Profile: an optional profile photo, stored in Firebase '
  'Storage. Play: game history, moves, ratings and tournament results. '
  'Social: chat messages, friend lists, group membership and block lists, '
  'stored in Cloud Firestore. Technical: app version, device model and OS '
  'version, attached to feedback and bug reports you send us. We do not ask '
  'for your real name, phone number or payment details.',

  '2. Location and the Player Map\n'
  'The nearby-players map is opt-in and off by default. If you turn on '
  '"Appear on Player Map" in Settings → Privacy, the app asks the operating system '
  'for your location and stores your latest coordinates so other players can '
  'see your pin on a public map. Anyone using the app can see the pins. Turn '
  '"Appear on Player Map" off at any time to stop sharing and remove your pin; you '
  'can also revoke location permission in your device settings.',

  '3. Notifications\n'
  'If you allow notifications, Firebase Cloud Messaging issues a device token '
  'that we store so we can send you game invites, move alerts and messages. '
  'You can turn notifications off in Settings → Notifications or in your '
  'device settings.',

  '4. How We Use Your Information\n'
  'To run your account and your games; to show ratings and leaderboards; to '
  'deliver the notifications you opted into; to answer support requests; and '
  'to detect cheating, abuse and other conduct that breaks our terms.',

  '5. Third-Party Services\n'
  'Firebase (Google) hosts authentication, the database, file storage, '
  'messaging and server functions. Bot moves and post-game analysis send the '
  'board position to the Stockfish Online API at stockfish.online, which also '
  'receives your IP address; we do not send your username or email with it. '
  'The player map loads tiles from tile.openstreetmap.org, which receives '
  'your IP address and the area of the map you are viewing. Interface fonts '
  'are fetched from fonts.gstatic.com, which receives your IP address. Each '
  'of these providers handles that data under its own privacy policy.',

  '6. Information Sharing\n'
  'We do not sell your personal information and we do not run advertising '
  'networks in the app. Your username, rating, game history and — if you '
  'enabled it — your map pin are visible to other players. Your email address '
  'is never shown publicly. We may disclose information if the law requires '
  'it, or to investigate abuse or security incidents.',

  '7. Deleting Your Account\n'
  'You can delete your account from inside the app: Settings → Account → '
  'Delete account. Deleting removes your profile, photo, chat messages, '
  'friend and block lists, map location and device tokens. Finished games may '
  'be kept in a form that no longer identifies you, so that your opponents\' '
  'own game records and ratings stay intact.',

  '8. Data Retention\n'
  'Account and profile data is kept while your account exists. Chat messages '
  'are kept until you or your account are deleted. Map coordinates are '
  'overwritten each time they update and removed when you leave the map. '
  'Feedback and bug reports are kept for up to 24 months. Backups may hold '
  'deleted data for up to 30 days before they roll over.',

  '9. Security\n'
  'Traffic is encrypted with TLS, and access to stored data is restricted by '
  'Firebase security rules. No method of transmission or storage is completely '
  'secure, so we cannot guarantee absolute security.',

  '10. Children\'s Privacy\n'
  'CheckMate is not directed to children under 13, and we do not knowingly '
  'collect personal information from them. If you believe a child under 13 has '
  'created an account, write to $kSupportEmail and we will remove it.',

  '11. Your Choices\n'
  'Settings → Privacy controls who can message, challenge or friend you, who '
  'sees your online status, and whether you appear on the map. Settings → '
  'Privacy → Request data download shows a copy of your account data. '
  'Settings → Account → Delete account removes it.',

  '12. Changes to This Policy\n'
  'We may update this policy. Significant changes will be reflected in the '
  '"Last updated" date above and in the published web version.',

  '13. Contact\n'
  'Questions about this policy or your data: $kSupportEmail.',
];

const kTermsParagraphs = [
  'These terms are an agreement between you and the developer of CheckMate, '
  'not with Apple or Google. The same text is published at $kTermsUrl.',

  '1. Acceptance\n'
  'By downloading or using CheckMate you accept these terms. If you do not '
  'accept them, do not use the app.',

  '2. Licence\n'
  'We grant you a personal, non-transferable, non-exclusive licence to use '
  'CheckMate on any device that you own or control, as permitted by the App '
  'Store or Google Play usage rules for the store you installed it from. The '
  'app is licensed, not sold. You may not copy, sell, rent, sublicense, '
  'reverse-engineer or modify the app, or attempt to extract its source code, '
  'except where the law expressly allows it.',

  '3. Your Account\n'
  'You are responsible for the account you create and for everything done '
  'through it. Keep your credentials to yourself, give accurate information, '
  'and tell us at $kSupportEmail if you believe someone else is using your '
  'account. You must be at least 13 years old to hold an account.',

  '4. Acceptable Use\n'
  'While using CheckMate you must not: harass, threaten, stalk or abuse other '
  'players; use a chess engine, external assistance or another person to '
  'choose your moves in rated or tournament play; use multiple accounts, '
  'sandbag or manipulate ratings and leaderboards; post or send illegal, '
  'hateful, sexual or otherwise offensive content, including in usernames, '
  'profile photos and chat; impersonate anyone; upload malware; or scrape, '
  'automate or overload the service.',

  '5. Your Content\n'
  'You keep ownership of the content you upload, such as your profile photo '
  'and messages. You give us the limited right to store, display and transmit '
  'that content so the app can work — for example, showing your photo to your '
  'opponents. You are responsible for having the rights to whatever you '
  'upload.',

  '6. Moderation and Termination\n'
  'We may limit, suspend or terminate an account that breaks these terms, '
  'including for cheating or harassment, and may remove content that breaks '
  'them. You may stop using the app at any time and delete your account from '
  'Settings → Account → Delete account. Termination ends the licence in '
  'section 2.',

  '7. No Warranty\n'
  'CheckMate is provided "as is" and "as available", without warranties of '
  'any kind, whether express or implied, including merchantability, fitness '
  'for a particular purpose and non-infringement. We do not warrant that the '
  'app will be uninterrupted, error-free or free of harmful components. Some '
  'jurisdictions do not allow the exclusion of implied warranties, so parts '
  'of this section may not apply to you.',

  '8. Limitation of Liability\n'
  'To the extent permitted by law, we are not liable for indirect, '
  'incidental, special or consequential damages, or for lost data or lost '
  'profits, arising out of your use of the app. Nothing here limits liability '
  'that cannot be limited by law.',

  '9. Third-Party Services\n'
  'The app relies on services we do not control, including Firebase (Google), '
  'the Stockfish Online API and OpenStreetMap tiles. Their availability is '
  'not guaranteed, and their own terms apply to your use of them. '
  'Attributions for bundled artwork and open-source components are listed '
  'under About → Third-party licences.',

  '10. Apple\n'
  'If you installed CheckMate from the App Store: this agreement is between '
  'you and us only, and Apple is not responsible for the app or its content. '
  'Apple has no obligation to provide maintenance or support. If the app '
  'fails to conform to any applicable warranty, you may notify Apple and '
  'Apple will refund the purchase price, if any; to the maximum extent '
  'permitted by law, Apple has no other warranty obligation. We, not Apple, '
  'are responsible for addressing claims about the app, including product '
  'liability, legal compliance and intellectual-property claims. You confirm '
  'you are not located in a country subject to a U.S. Government embargo or '
  'designated as terrorist-supporting, and that you are not on any U.S. '
  'restricted-party list. Apple and its subsidiaries are third-party '
  'beneficiaries of this agreement and may enforce it against you.',

  '11. Changes\n'
  'We may update these terms. Continuing to use the app after an update means '
  'you accept the revised terms, which will carry a new "Last updated" date.',

  '12. Contact\n'
  'Questions about these terms: $kSupportEmail.',
];
