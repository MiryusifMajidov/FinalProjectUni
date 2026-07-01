'use strict';

const { onDocumentCreated }      = require('firebase-functions/v2/firestore');
const { onCall, HttpsError }     = require('firebase-functions/v2/https');
const { defineSecret }           = require('firebase-functions/params');
const { initializeApp }          = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging }           = require('firebase-admin/messaging');
const crypto                     = require('crypto');
const nodemailer                 = require('nodemailer');

initializeApp();

const db = getFirestore();

// SMTP credentials stored in Firebase Secret Manager (not in source code).
// Set via: firebase functions:secrets:set SMTP_EMAIL / SMTP_PASSWORD
const smtpEmail    = defineSecret('SMTP_EMAIL');
const smtpPassword = defineSecret('SMTP_PASSWORD');

// ─── ELO helpers (mirrors Dart EloService) ───────────────────────────────────

function kFactor(rating, games) {
  if (games < 30)      return 40;
  if (rating >= 2400)  return 16;
  if (rating >= 2000)  return 24;
  return 32;
}

function calculateElo(whiteRating, blackRating, result, whiteGames, blackGames) {
  let score;
  if (result === 'white')     score = 1.0;
  else if (result === 'black') score = 0.0;
  else if (result === 'draw')  score = 0.5;
  else throw new HttpsError('invalid-argument', `Invalid result: ${result}`);

  const expected = 1.0 / (1.0 + Math.pow(10, (blackRating - whiteRating) / 400.0));

  const wK = kFactor(whiteRating, whiteGames);
  const bK = kFactor(blackRating, blackGames);

  const whiteDelta = Math.round(wK * (score - expected));
  const blackDelta = Math.round(bK * ((1.0 - score) - (1.0 - expected)));

  return {
    whiteNew:   Math.max(100, Math.min(3200, whiteRating + whiteDelta)),
    blackNew:   Math.max(100, Math.min(3200, blackRating + blackDelta)),
    whiteDelta,
    blackDelta,
  };
}

// ─── 0. Process Game Rating (Callable) ───────────────────────────────────────
//
// Called by Flutter after a rated game ends.
// Validates the game result, recalculates ELO server-side, and writes stats.
//
// Request: { gameId: string }
// Response: { myDelta: number, myNewRating: number, alreadyProcessed: boolean }

exports.processGameRating = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Login required');

  const { gameId } = request.data ?? {};
  if (!gameId) throw new HttpsError('invalid-argument', 'gameId required');

  const gameRef  = db.collection('games').doc(gameId);
  const gameSnap = await gameRef.get();

  if (!gameSnap.exists) throw new HttpsError('not-found', 'Game not found');

  const game = gameSnap.data();

  // Verify caller is a participant
  if (game.whiteUid !== uid && game.blackUid !== uid) {
    throw new HttpsError('permission-denied', 'Not a player in this game');
  }

  // Only process rated games (isRated defaults to false for legacy games without the field)
  if (game.isRated !== true) return { myDelta: 0, myNewRating: 0, alreadyProcessed: false };

  // Idempotency guard — prevent double-processing
  if (game.ratingProcessed === true) {
    const isWhite   = game.whiteUid === uid;
    const myDelta   = isWhite ? (game.whiteRatingChange ?? 0) : (game.blackRatingChange ?? 0);
    const myBefore  = isWhite ? (game.whiteRatingBefore ?? 1200) : (game.blackRatingBefore ?? 1200);
    return { myDelta, myNewRating: myBefore + myDelta, alreadyProcessed: true };
  }

  const result = game.result;
  if (!result || result === 'ongoing' || result === 'aborted') {
    throw new HttpsError('failed-precondition', 'Game not finished yet');
  }

  const isWhite = game.whiteUid === uid;
  const category = game.timeControlCategory ?? 'blitz';
  const statsField = category === 'bullet' ? 'bulletStats'
                   : category === 'rapid'  ? 'rapidStats'
                   : 'blitzStats';

  // Fetch both players' current stats
  const [mySnap, oppSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    game.blackUid && game.whiteUid
      ? db.collection('users').doc(isWhite ? game.blackUid : game.whiteUid).get()
      : Promise.resolve(null),
  ]);

  if (!mySnap.exists) throw new HttpsError('not-found', 'User not found');

  const myStats  = mySnap.data()?.[statsField] ?? { rating: 1200, games: 0, wins: 0, draws: 0, losses: 0 };
  const oppStats = oppSnap?.exists
    ? (oppSnap.data()?.[statsField] ?? { rating: 1200, games: 999 })
    : { rating: game.opponentRating ?? 1200, games: 999 };

  const whiteRating = isWhite ? myStats.rating  : oppStats.rating;
  const blackRating = isWhite ? oppStats.rating  : myStats.rating;
  const whiteGames  = isWhite ? myStats.games    : oppStats.games ?? 999;
  const blackGames  = isWhite ? oppStats.games ?? 999 : myStats.games;

  const { whiteNew, blackNew, whiteDelta, blackDelta } =
    calculateElo(whiteRating, blackRating, result, whiteGames, blackGames);

  const myDelta    = isWhite ? whiteDelta : blackDelta;
  const myNewRating = isWhite ? whiteNew   : blackNew;
  const myOldRating = myStats.rating;

  // Determine win/draw/loss for stats counters
  const won  = (isWhite && result === 'white') || (!isWhite && result === 'black');
  const drew = result === 'draw';

  const updatedStats = {
    rating: myNewRating,
    games:  (myStats.games  ?? 0) + 1,
    wins:   (myStats.wins   ?? 0) + (won  ? 1 : 0),
    draws:  (myStats.draws  ?? 0) + (drew ? 1 : 0),
    losses: (myStats.losses ?? 0) + (!won && !drew ? 1 : 0),
  };

  // Write atomically: update user stats + mark game as processed
  const batch = db.batch();

  batch.update(db.collection('users').doc(uid), {
    [statsField]: updatedStats,
  });

  batch.update(gameRef, {
    ratingProcessed:    true,
    whiteRatingChange:  isWhite ? myDelta   : (game.whiteRatingChange ?? 0),
    blackRatingChange:  isWhite ? (game.blackRatingChange ?? 0) : myDelta,
    whiteRatingBefore:  isWhite ? myOldRating : (game.whiteRatingBefore ?? whiteRating),
    blackRatingBefore:  isWhite ? (game.blackRatingBefore ?? blackRating) : myOldRating,
  });

  await batch.commit();

  console.log(`[ELO] game=${gameId} uid=${uid} delta=${myDelta} newRating=${myNewRating}`);

  return { myDelta, myNewRating, alreadyProcessed: false };
});
const messaging = getMessaging();

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Reads /users/{userId} and returns { fcmToken, notifPrefs }.
 * notifPrefs contains all notifXxx booleans from the user document.
 */
async function getUserData(userId) {
  try {
    const snap = await db.collection('users').doc(userId).get();
    if (!snap.exists) return { fcmToken: null, notifPrefs: {} };
    const data = snap.data() ?? {};
    return {
      fcmToken: data.fcmToken ?? null,
      notifPrefs: {
        notifGameInvites:    data.notifGameInvites    !== false,
        notifYourTurn:       data.notifYourTurn       !== false,
        notifMessages:       data.notifMessages       !== false,
        notifFriendRequests: data.notifFriendRequests !== false,
        notifTournaments:    data.notifTournaments    !== false,
      },
    };
  } catch (err) {
    console.error(`[FCM] getUserData(${userId}) failed:`, err.message);
    return { fcmToken: null, notifPrefs: {} };
  }
}

/** Legacy helper kept for callers that only need the token. */
async function getFcmToken(userId) {
  return (await getUserData(userId)).fcmToken;
}

/**
 * Sends an FCM V1 message via the Admin SDK.
 * Silently swallows errors so one bad token never breaks the whole function.
 */
async function sendNotification({ token, title, body, data = {} }) {
  if (!token) {
    console.log('[FCM] No token — skipping push');
    return;
  }

  // FCM data values must all be strings
  const stringData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );

  try {
    const messageId = await messaging.send({
      token,
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: { sound: 'default', priority: 'high' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
        headers:  { 'apns-priority': '10' },
      },
    });
    console.log('[FCM] Sent:', messageId);
  } catch (err) {
    // Common causes: token expired / unregistered — safe to ignore
    console.error('[FCM] send error:', err.code, err.message);
  }
}

// ─── 1. Game Invite Notification ─────────────────────────────────────────────
//
// Triggered by:  Flutter writes to gameInvites/{userId}/pending/{inviteId}
//
// Expected document fields:
//   fromUid          – UID of the inviting player
//   fromUsername     – display name of the inviting player
//   timeControlLabel – e.g. "5 min", "3+2"
//   isWhite          – bool: colour assigned to the INVITING player
//   sentAt           – server timestamp

exports.sendGameInviteNotification = onDocumentCreated(
  'gameInvites/{userId}/pending/{inviteId}',
  async (event) => {
    const { userId, inviteId } = event.params;
    const data = event.data?.data();
    if (!data) return;

    const {
      fromUid          = '',
      fromUsername     = 'Someone',
      timeControlLabel = '5 min',
      isWhite          = true,
    } = data;

    const recipientIsWhite = !isWhite;
    const colorText = recipientIsWhite ? 'Ağ' : 'Qara';

    const { fcmToken: token, notifPrefs } = await getUserData(userId);
    if (!notifPrefs.notifGameInvites) {
      console.log(`[FCM] User ${userId} disabled game invite notifications`);
      return;
    }

    await sendNotification({
      token,
      title: `${fromUsername} sizi oyuna dəvət edir!`,
      body:  `${timeControlLabel} • Siz ${colorText} oynayacaqsınız`,
      data: {
        type:             'game_invite',
        inviteId,
        fromUid,
        fromUsername,
        timeControlLabel,
        isWhite:          String(isWhite),
      },
    });
  }
);

// ─── 2. Direct Chat Message Notification ─────────────────────────────────────
//
// Triggered by:  Flutter writes to chats/{chatId}/messages/{messageId}.
//
// chatId format:  "{uidA}_{uidB}" — both UIDs sorted alphabetically.
// Mute check: reads chats/{chatId}.mutedBy — skips if recipient muted this chat.
//
// Expected document fields:
//   senderUid       – UID of the message author
//   senderUsername  – display name (not yet stored in messages, looked up)
//   text            – message body
//   createdAt       – server timestamp

exports.sendChatNotification = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const { chatId, messageId } = event.params;
    const data = event.data?.data();
    if (!data) return;

    const senderUid = data['senderUid'] ?? '';
    const text      = data['text']      ?? '';

    if (!senderUid || !text) return;

    // Derive recipient: the UID in chatId that is NOT the sender
    const parts = chatId.split('_');
    if (parts.length !== 2) {
      console.warn('[Chat] Unexpected chatId format:', chatId);
      return;
    }
    const recipientUid = parts.find((uid) => uid !== senderUid);
    if (!recipientUid) return;

    // ── Mute check ────────────────────────────────────────────────────────────
    try {
      const chatDoc = await db.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        const mutedBy = chatDoc.data()?.mutedBy ?? [];
        if (mutedBy.includes(recipientUid)) {
          console.log(`[Chat] Skipping push — ${recipientUid} muted this chat`);
          return;
        }
      }
    } catch (err) {
      console.warn('[Chat] Mute check failed:', err.message);
      // Non-fatal — proceed to send
    }

    // Resolve sender's username from /users collection
    let senderUsername = 'Someone';
    try {
      const senderSnap = await db.collection('users').doc(senderUid).get();
      senderUsername = senderSnap.data()?.username ?? 'Someone';
    } catch (_) {}

    const { fcmToken: token, notifPrefs } = await getUserData(recipientUid);
    if (!notifPrefs.notifMessages) {
      console.log(`[FCM] User ${recipientUid} disabled message notifications`);
      return;
    }
    const preview = text.length > 100 ? `${text.slice(0, 100)}…` : text;

    await sendNotification({
      token,
      title: senderUsername,
      body:  preview,
      data: {
        type:           'chat_message',
        chatId,
        messageId,
        senderUid,
        senderUsername,
      },
    });
  }
);

// ─── 3. Group Message Notification ───────────────────────────────────────────
//
// Triggered by:  Flutter writes to groups/{groupId}/messages/{messageId}.
//
// Fan-out: sends to ALL members except the sender.
// Mute check: reads groups/{groupId}.mutedBy — skips muted members.
//
// Expected message document fields:
//   senderUid       – UID of the sender
//   senderUsername  – display name
//   text            – message body
//   createdAt       – server timestamp

exports.sendGroupMessageNotification = onDocumentCreated(
  'groups/{groupId}/messages/{messageId}',
  async (event) => {
    const { groupId, messageId } = event.params;
    const data = event.data?.data();
    if (!data) return;

    const senderUid      = data['senderUid']      ?? '';
    const senderUsername = data['senderUsername']  ?? 'Someone';
    const text           = data['text']            ?? '';

    if (!senderUid || !text) return;

    // Load the group to get members, name, and mutedBy list
    let groupDoc;
    try {
      groupDoc = await db.collection('groups').doc(groupId).get();
    } catch (err) {
      console.error('[Group] Failed to load group:', err.message);
      return;
    }
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName  = groupData?.name      ?? 'Group';
    const memberIds  = groupData?.memberIds ?? [];
    const mutedBy    = groupData?.mutedBy   ?? [];

    // Recipients = all members except the sender, excluding muted members
    const recipients = memberIds.filter(
      (uid) => uid !== senderUid && !mutedBy.includes(uid)
    );

    if (recipients.length === 0) {
      console.log('[Group] No recipients after mute filter');
      return;
    }

    const preview = text.length > 100 ? `${text.slice(0, 100)}…` : text;
    const notifBody = `${senderUsername}: ${preview}`;

    // Fan-out: fetch all tokens in parallel, then send in parallel
    const tokenResults = await Promise.all(
      recipients.map((uid) => getFcmToken(uid))
    );

    const sendPromises = recipients
      .map((uid, i) => ({ uid, token: tokenResults[i] }))
      .filter(({ token }) => !!token)
      .map(({ uid, token }) =>
        sendNotification({
          token,
          title: groupName,
          body:  notifBody,
          data: {
            type:           'group_message',
            groupId,
            messageId,
            senderUid,
            senderUsername,
          },
        })
      );

    await Promise.all(sendPromises);
    console.log(
      `[Group] Sent to ${sendPromises.length}/${recipients.length} recipients`
    );
  }
);

// ─── 4. Friend Request Notification ──────────────────────────────────────────
//
// Triggered by:  Flutter writes to friendRequests/{userId}/received/{fromUserId}.
//
// Expected document fields (all optional — function falls back to Firestore lookup):
//   fromUsername  – display name of the requester
//   sentAt        – server timestamp

exports.sendFriendRequestNotification = onDocumentCreated(
  'friendRequests/{userId}/received/{fromUserId}',
  async (event) => {
    const { userId, fromUserId } = event.params;
    const data = event.data?.data();

    // fromUsername can come from the document or be looked up in /users
    let fromUsername = data?.fromUsername;
    if (!fromUsername) {
      const fromSnap = await db.collection('users').doc(fromUserId).get();
      fromUsername = fromSnap.data()?.username ?? 'Someone';
    }

    const { fcmToken: token, notifPrefs } = await getUserData(userId);
    if (!notifPrefs.notifFriendRequests) {
      console.log(`[FCM] User ${userId} disabled friend request notifications`);
      return;
    }

    await sendNotification({
      token,
      title: 'Yeni dostluq ərizəsi!',
      body:  `${fromUsername} sizi dost olaraq əlavə etmək istəyir.`,
      data: {
        type:         'friend_request',
        fromUid:      fromUserId,
        fromUsername: String(fromUsername),
      },
    });
  }
);

// ─── 5. Send OTP (Callable) ─────────────────────────────────────────────────
//
// Generates a 6-digit OTP, stores its SHA-256 hash in Firestore, and sends
// the plaintext code via Gmail SMTP.  SMTP credentials come from Secret Manager.
//
// Request: { email: string }

exports.sendOtp = onCall({ secrets: [smtpEmail, smtpPassword] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Login required');

  const { email } = request.data ?? {};
  if (!email) throw new HttpsError('invalid-argument', 'email required');

  const otp = String(100000 + Math.floor(Math.random() * 900000));
  const otpHash = crypto.createHash('sha256').update(otp).digest('hex');
  const emailKey = email.toLowerCase();

  await db.collection('emailOtps').doc(emailKey).set({
    otpHash,
    email: emailKey,
    attempts: 0,
    expiresAt: new Date(Date.now() + 10 * 60 * 1000),
  });

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: smtpEmail.value(), pass: smtpPassword.value() },
  });

  await transporter.sendMail({
    from: `"CheckMate" <${smtpEmail.value()}>`,
    to: email,
    subject: 'Your CheckMate verification code',
    html: `
<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#1a1a2e;color:#ffffff;border-radius:16px;">
  <h2 style="color:#c9a84c;margin-bottom:8px;">CheckMate</h2>
  <p style="color:#aaa;margin-bottom:24px;">Email verification</p>
  <p style="margin-bottom:16px;">Your one-time verification code:</p>
  <div style="font-size:36px;font-weight:bold;letter-spacing:12px;color:#c9a84c;background:#0d0d1a;padding:20px;border-radius:12px;text-align:center;">
    ${otp}
  </div>
  <p style="color:#aaa;font-size:13px;margin-top:24px;">This code expires in 10 minutes. Do not share it with anyone.</p>
</div>`,
  });

  console.log(`[OTP] sent to ${emailKey}`);
  return { success: true };
});

// ─── 6. Verify OTP (Callable) ───────────────────────────────────────────────
//
// Compares SHA-256 hashes server-side. Deletes OTP on success or after 5 fails.
//
// Request: { email: string, code: string }
// Response: { valid: boolean }

exports.verifyOtp = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Login required');

  const { email, code } = request.data ?? {};
  if (!email || !code) throw new HttpsError('invalid-argument', 'email and code required');

  const emailKey = email.toLowerCase();
  const docRef = db.collection('emailOtps').doc(emailKey);
  const doc = await docRef.get();

  if (!doc.exists) return { valid: false };

  const data = doc.data();
  const expiresAt = data.expiresAt?.toDate?.() ?? new Date(data.expiresAt);
  if (new Date() > expiresAt) {
    await docRef.delete();
    return { valid: false };
  }

  const attempts = data.attempts ?? 0;
  if (attempts >= 5) {
    await docRef.delete();
    return { valid: false };
  }

  const inputHash = crypto.createHash('sha256').update(code).digest('hex');
  const match = (data.otpHash ?? '') === inputHash;

  if (!match) {
    await docRef.update({ attempts: (data.attempts ?? 0) + 1 });
    return { valid: false };
  }

  await docRef.delete();
  return { valid: true };
});

// ─── 7. Send Feedback Email (Callable) ──────────────────────────────────────
//
// Request: { text, isBug, fromUsername, fromEmail, appVersion?, deviceInfo? }

exports.sendFeedbackEmail = onCall({ secrets: [smtpEmail, smtpPassword] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Login required');

  const { text, isBug, fromUsername, fromEmail, appVersion, deviceInfo } = request.data ?? {};
  if (!text) throw new HttpsError('invalid-argument', 'text required');

  const subject = isBug
    ? `Bug Report — ${fromUsername || 'Unknown'}`
    : `Feedback — ${fromUsername || 'Unknown'}`;

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: smtpEmail.value(), pass: smtpPassword.value() },
  });

  await transporter.sendMail({
    from: `"CheckMate App" <${smtpEmail.value()}>`,
    to: smtpEmail.value(),
    subject,
    html: `
<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:24px;background:#1a1a2e;color:#fff;border-radius:12px;">
  <h2 style="color:#c9a84c;">${isBug ? 'Bug Report' : 'Feedback'}</h2>
  <table style="width:100%;border-collapse:collapse;margin-bottom:16px;">
    <tr><td style="color:#aaa;padding:4px 0;width:120px;">From</td><td style="color:#fff;">${fromUsername || 'Unknown'} (${fromEmail || 'N/A'})</td></tr>
    <tr><td style="color:#aaa;padding:4px 0;">Type</td><td style="color:#fff;">${isBug ? 'Bug Report' : 'Feedback'}</td></tr>
    ${appVersion ? `<tr><td style="color:#aaa;padding:4px 0;">Version</td><td style="color:#fff;">${appVersion}</td></tr>` : ''}
    ${deviceInfo ? `<tr><td style="color:#aaa;padding:4px 0;">Device</td><td style="color:#fff;">${deviceInfo}</td></tr>` : ''}
  </table>
  <div style="background:#0d0d1a;padding:16px;border-radius:8px;color:#e0e0e0;white-space:pre-wrap;font-size:14px;line-height:1.6;">${text}</div>
</div>`,
  });

  console.log(`[Feedback] ${subject} from ${fromUsername}`);
  return { success: true };
});
