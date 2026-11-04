'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Guest profiles
//
//  setupGuestProfile — called by the app right after an anonymous sign-in.
//  Reserves the next guest name ("user#0001", "user#0002", …) and guesses the
//  guest's country from the IP address the request came from, so the flag is
//  where the player actually is rather than whatever the phone's language
//  setting implies. The app then creates users/{uid} with that name.
//
//  The IP → country data is the GeoFeed + Whois + ASN database from
//  ip-location-db (CC BY 4.0, by NRO — see NOTICE). The IP is only looked up
//  in memory and never stored.
// ─────────────────────────────────────────────────────────────────────────────

const fs = require('fs');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const db = () => getFirestore();

/** Guest numbers are padded to this many digits: user#0001. */
const GUEST_DIGITS = 4;

let reader; // loaded on first use, then kept for the instance's lifetime

function countryReader() {
  if (reader !== undefined) return reader;
  try {
    const { Reader } = require('mmdb-lib');
    const file = require.resolve(
      '@ip-location-db/geo-whois-asn-country-mmdb/geo-whois-asn-country.mmdb');
    reader = new Reader(fs.readFileSync(file));
  } catch (e) {
    console.warn('[Guest] country database unavailable:', e.message);
    reader = null;
  }
  return reader;
}

/** The caller's public IP as seen by Google's front end. */
function clientIp(req) {
  const forwarded = String(req?.headers?.['x-forwarded-for'] || '').split(',')[0].trim();
  return forwarded || req?.ip || '';
}

/** Two-letter country code for the request, or null when unknown. */
function countryFor(req) {
  // Some Google front ends add the country themselves; prefer that.
  const header = String(req?.headers?.['x-appengine-country'] || '').toUpperCase();
  if (/^[A-Z]{2}$/.test(header) && header !== 'ZZ') return header;
  const ip = clientIp(req);
  if (!ip) return null;
  try {
    const hit = countryReader()?.get(ip);
    const code = String(hit?.country_code || '').toUpperCase();
    return /^[A-Z]{2}$/.test(code) ? code : null;
  } catch (_) {
    return null; // not an IP address
  }
}

function guestName(n) {
  return `user#${String(n).padStart(GUEST_DIGITS, '0')}`;
}

/**
 * Reserves the next free guest name for [uid] (idempotent: a retry returns
 * the name reserved the first time).
 */
async function reserveGuestName(uid) {
  const fsdb = db();
  const markerRef = fsdb.collection('guestNames').doc(uid);
  const counterRef = fsdb.collection('meta').doc('guestCounter');
  return fsdb.runTransaction(async (tx) => {
    const [marker, counter] = await Promise.all([tx.get(markerRef), tx.get(counterRef)]);
    if (marker.exists && marker.data().username) return marker.data().username;

    let n = Math.max(1, Number(counter.exists ? counter.data().next : 1) || 1);
    // Skip numbers someone already owns (e.g. a player who picked "user#0007"
    // for themselves before guests used the scheme). All reads first.
    let username = null;
    let nameRef = null;
    for (let i = 0; i < 25 && !username; i++, n++) {
      const candidate = guestName(n);
      const ref = fsdb.collection('usernames').doc(candidate.toLowerCase());
      const snap = await tx.get(ref);
      if (!snap.exists) {
        username = candidate;
        nameRef = ref;
      }
    }
    if (!username) throw new HttpsError('resource-exhausted', 'No free guest name');

    tx.set(counterRef, { next: n }, { merge: true });
    tx.set(nameRef, { uid });
    tx.set(markerRef, { username, createdAt: FieldValue.serverTimestamp() });
    return username;
  });
}

exports.setupGuestProfile = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Login required');
  if (request.auth.token?.firebase?.sign_in_provider !== 'anonymous') {
    throw new HttpsError('permission-denied', 'Only guest accounts');
  }

  const countryCode = countryFor(request.rawRequest);
  const existing = await db().collection('users').doc(uid).get();
  if (existing.exists) {
    return { username: existing.data().username, countryCode, existing: true };
  }
  const username = await reserveGuestName(uid);
  console.log(`[Guest] ${uid} → ${username} (${countryCode || 'no country'})`);
  return { username, countryCode };
});

// Exposed for unit tests.
exports._internal = { countryFor, clientIp, guestName };
