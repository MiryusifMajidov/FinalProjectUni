import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'firestore_service.dart';
import 'log_service.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirestoreService _firestore;
  final LogService _log = LogService();

  /// Apple hands over the e-mail only on the very first authorization for an
  /// Apple ID. It is kept here so [completeAppleSignUp] can still store it
  /// when Firebase itself did not receive one.
  String? _pendingAppleEmail;

  AuthService(this._firestore);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> register({
    required String email,
    required String password,
    required String username,
    String? avatarId,
    int startingRating = 1200,
    String? skillLevel,
    String? countryCode,
  }) async {
    // Check username uniqueness
    final exists = await _firestore.usernameExists(username);
    if (exists) throw Exception('Username already taken');

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final initialStats = RatingStats(rating: startingRating);
    final user = UserModel(
      uid: cred.user!.uid,
      username: username,
      email: email,
      avatarId: avatarId ?? 'avatar_01',
      skillLevel: skillLevel,
      countryCode: countryCode,
      createdAt: DateTime.now(),
      bulletStats: initialStats,
      blitzStats: initialStats,
      rapidStats: initialStats,
      checkersStats: const RatingStats(),
      dominoStats: const RatingStats(),
    );

    await _firestore.createUser(user);

    // Log registration event — awaited so failures surface to the caller
    // instead of being silently dropped.
    await _log.log(
      uid: user.uid,
      username: user.username,
      type: 'register',
      metadata: {
        'platform': defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'other',
      },
    );

    return user;
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = await _firestore.getUser(cred.user!.uid);

    // Log login event
    if (user != null) {
      _log.log(
        uid: user.uid,
        username: user.username,
        type: 'login',
        metadata: {
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'other',
        },
      );
    }

    return user;
  }

  /// Persist device info to Firestore. Returns the session document ID.
  /// Also saves the session ID to SharedPreferences so it survives app restarts.
  Future<String?> saveLoginSession(String uid) async {
    try {
      String deviceModel = 'Unknown';
      String os = 'Unknown';
      final di = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await di.androidInfo;
        deviceModel = '${info.manufacturer} ${info.model}';
        os = 'Android ${info.version.release}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await di.iosInfo;
        deviceModel = info.name;
        os = 'iOS ${info.systemVersion}';
      }
      final sessionId = await _firestore.saveSession(uid, {
        'deviceModel': deviceModel,
        'os': os,
        'uid': uid,
      });
      // Persist so we can restore the same session on every cold-start.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_session_id', sessionId);
      return sessionId;
    } catch (_) {
      return null;
    }
  }

  /// On cold-start: restore the stored session if it still exists in Firestore,
  /// or create a fresh one if not (first install, cleared data, or revoked
  /// from another device).
  Future<String?> restoreOrCreateSession(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('pref_session_id');
      if (stored != null && stored.isNotEmpty) {
        try {
          // Refreshes lastActiveAt — throws if document was deleted.
          await _firestore.refreshSession(uid, stored);
          return stored;
        } catch (_) {
          // Session was revoked (deleted from another device) — fall through
          // to create a new one.
        }
      }
      // No valid stored session: create a brand-new one.
      return saveLoginSession(uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> changeUsername(String newUsername) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final newLower = newUsername.toLowerCase();

    // Use a transaction to atomically check-and-claim the username.
    // The old read→batch approach had a TOCTOU race: two users could both read
    // "username not taken" and then both write, silently overwriting each other.
    await _fs.runTransaction((t) async {
      final newRef = _fs.collection('usernames').doc(newLower);
      final userRef = _fs.collection('users').doc(user.uid);

      final newDoc = await t.get(newRef);
      if (newDoc.exists && (newDoc.data()?['uid'] as String?) != user.uid) {
        throw Exception('Username already taken');
      }

      final userDoc = await t.get(userRef);
      final oldUsername = (userDoc.data()?['username'] as String?)?.toLowerCase();

      if (oldUsername != null && oldUsername != newLower) {
        t.delete(_fs.collection('usernames').doc(oldUsername));
      }
      t.set(newRef, {'uid': user.uid});
      t.update(userRef, {'username': newUsername});
    });
  }

  Future<void> changeEmail(String currentPassword, String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final credential = EmailAuthProvider.credential(
      email: user.email!, password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final credential = EmailAuthProvider.credential(
      email: user.email!, password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<bool> usernameExists(String username) =>
      _firestore.usernameExists(username.toLowerCase());

  /// Signs in with Google. Returns (user, isNewUser).
  /// If isNewUser is true, the caller must prompt for a username.
  Future<({UserModel? user, bool isNewUser, User firebaseUser})>
      signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final fbUser = userCred.user!;

    final existing = await _firestore.getUser(fbUser.uid);
    if (existing != null) {
      // Returning Google user — log the login event (fire-and-forget is fine
      // here; we don't want a log failure to block the sign-in flow).
      _log.log(
        uid: existing.uid,
        username: existing.username,
        type: 'login',
        metadata: {'platform': 'google'},
      );
      return (user: existing, isNewUser: false, firebaseUser: fbUser);
    }
    return (user: null, isNewUser: true, firebaseUser: fbUser);
  }

  /// Signs in with Apple. Returns (user, isNewUser).
  /// If isNewUser is true, the caller must prompt for a username.
  ///
  /// Only available on Apple platforms.
  Future<({UserModel? user, bool isNewUser, User firebaseUser})>
      signInWithApple() async {
    // Apple requires a nonce: the SHA-256 digest goes to Apple, the raw value
    // goes to Firebase, which re-hashes it to prove the token is ours.
    final rawNonce = _generateNonce();
    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256Hex(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('cancelled');
      }
      rethrow;
    }

    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      // Apple's authorizationCode goes in accessToken. firebase_auth 5.x on
      // iOS rejects the credential with
      // [firebase_auth/invalid-credential] Invalid OAuth response from apple.com
      // when this is absent, so Apple sign-in fails outright — and the error
      // points at the provider config rather than at this line.
      accessToken: appleCredential.authorizationCode,
    );

    final userCred = await _auth.signInWithCredential(credential);
    var fbUser = userCred.user!;

    // givenName / familyName / email arrive ONLY on the first authorization
    // for this Apple ID — persist them now or they are gone for good.
    final fullName = [appleCredential.givenName, appleCredential.familyName]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');
    if (fullName.isNotEmpty && (fbUser.displayName ?? '').isEmpty) {
      await fbUser.updateDisplayName(fullName);
      await fbUser.reload();
      fbUser = _auth.currentUser ?? fbUser;
    }
    // A hidden-relay address (…@privaterelay.appleid.com) is a normal e-mail
    // and is stored like any other.
    _pendingAppleEmail = appleCredential.email ?? fbUser.email;

    final existing = await _firestore.getUser(fbUser.uid);
    if (existing != null) {
      // Returning Apple user — on later sign-ins Apple sends no profile data,
      // so the stored Firestore profile is the source of truth.
      _log.log(
        uid: existing.uid,
        username: existing.username,
        type: 'login',
        metadata: {'platform': 'apple'},
      );
      return (user: existing, isNewUser: false, firebaseUser: fbUser);
    }
    return (user: null, isNewUser: true, firebaseUser: fbUser);
  }

  /// Random nonce for the Apple authorization request.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => charset[rand.nextInt(charset.length)],
    ).join();
  }

  String _sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

  /// Completes Google sign-in for a new user by creating their Firestore profile.
  Future<UserModel> completeGoogleSignUp({
    required User firebaseUser,
    required String username,
    String? countryCode,
    String? skillLevel,
  }) =>
      _completeProviderSignUp(
        firebaseUser: firebaseUser,
        username: username,
        countryCode: countryCode,
        skillLevel: skillLevel,
        platform: 'google',
      );

  /// Completes Apple sign-in for a new user by creating their Firestore profile.
  /// Falls back to the e-mail captured during the first authorization when
  /// Firebase has none.
  Future<UserModel> completeAppleSignUp({
    required User firebaseUser,
    required String username,
    String? countryCode,
    String? skillLevel,
  }) =>
      _completeProviderSignUp(
        firebaseUser: firebaseUser,
        username: username,
        countryCode: countryCode,
        skillLevel: skillLevel,
        platform: 'apple',
        fallbackEmail: _pendingAppleEmail,
      );

  Future<UserModel> _completeProviderSignUp({
    required User firebaseUser,
    required String username,
    required String platform,
    String? countryCode,
    String? skillLevel,
    String? fallbackEmail,
  }) async {
    final exists = await _firestore.usernameExists(username);
    if (exists) throw Exception('Username already taken');

    const initialStats = RatingStats(rating: 1200);
    final user = UserModel(
      uid: firebaseUser.uid,
      username: username,
      email: firebaseUser.email ?? fallbackEmail ?? '',
      avatarId: 'avatar_01',
      photoUrl: firebaseUser.photoURL,
      countryCode: countryCode,
      skillLevel: skillLevel,
      createdAt: DateTime.now(),
      bulletStats: initialStats,
      blitzStats: initialStats,
      rapidStats: initialStats,
      checkersStats: const RatingStats(),
      dominoStats: const RatingStats(),
    );

    await _firestore.createUser(user);

    // Log registration event for the new provider user.
    _log.log(
      uid: user.uid,
      username: user.username,
      type: 'register',
      metadata: {'platform': platform},
    );

    return user;
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Fetch username before signing out
      try {
        final userDoc = await _fs.collection('users').doc(user.uid).get();
        final username = userDoc.data()?['username'] as String? ?? 'unknown';
        await _log.log(
          uid: user.uid,
          username: username,
          type: 'logout',
        );
      } catch (_) {}
    }
    return _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Permanently deletes the current account (Firestore data + Firebase Auth).
  ///
  /// - Email/password accounts: pass [currentPassword] to re-authenticate.
  /// - Google accounts: [currentPassword] is ignored; re-auth via Google Sign-In.
  /// - Apple accounts: [currentPassword] is ignored; re-auth via Sign in with
  ///   Apple. Without it Firebase throws 'requires-recent-login' and the
  ///   account can never be deleted (App Store guideline 5.1.1(v)).
  Future<void> deleteAccount(String? currentPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Determine sign-in provider and re-authenticate accordingly
    final providers = user.providerData.map((p) => p.providerId).toList();

    if (providers.contains('google.com')) {
      // Google account — re-authenticate silently via Google Sign-In
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else if (providers.contains('apple.com')) {
      // Apple account — re-authenticate with a fresh Apple credential
      final rawNonce = _generateNonce();
      final AuthorizationCredentialAppleID appleCredential;
      try {
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: _sha256Hex(rawNonce),
        );
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
          throw Exception('Apple sign-in cancelled');
        }
        rethrow;
      }
      final credential = OAuthProvider('apple.com').credential(
        idToken:  appleCredential.identityToken,
        rawNonce: rawNonce,
        // Same as in signInWithApple: without accessToken the credential is
        // rejected, so the account could never be re-authenticated and so
        // never deleted — which is the guideline 5.1.1(v) path.
        accessToken: appleCredential.authorizationCode,
      );
      await user.reauthenticateWithCredential(credential);
      // Apple also requires the sign-in token to be revoked on deletion.
      // Non-fatal: a failed revocation must not block the deletion itself.
      final String? authCode = appleCredential.authorizationCode;
      if (authCode != null && authCode.isNotEmpty) {
        try {
          await _auth.revokeTokenWithAuthorizationCode(authCode);
        } catch (e) {
          // Still non-fatal — a failed revocation must not block the deletion.
          // But it is logged rather than swallowed: revocation depends on the
          // Apple provider's OAuth code flow being configured in Firebase
          // (services id, team id, key id, private key), and when that is
          // wrong this is the only signal that anything went wrong at all.
          debugPrint('[Auth] Apple token revocation failed: $e');
        }
      }
    } else if (providers.contains('password')) {
      // Email/password account
      if (currentPassword == null || currentPassword.isEmpty) {
        throw Exception('Password required to delete this account');
      }
      final credential = EmailAuthProvider.credential(
        email:    user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      // Other providers (Apple, etc.) — attempt deletion without re-auth
      // Firebase may throw requires-recent-login; caller should handle it
    }

    final uid = user.uid;

    // Subcollections first, while users/{uid} still exists: the security rules
    // key off that document, so deleting the parent first can lock us out of
    // its own children. Firestore never cascade-deletes, so anything missed
    // here simply survives the account forever.
    try {
      final friendsSnap =
          await _fs.collection('users').doc(uid).collection('friends').get();
      for (var i = 0; i < friendsSnap.docs.length; i += 400) {
        final chunk = friendsSnap.docs.skip(i).take(400);
        final friendBatch = _fs.batch();
        for (final doc in chunk) {
          friendBatch.delete(doc.reference);
        }
        await friendBatch.commit();
      }
    } catch (e) {
      debugPrint('[Auth] Deleting friends subcollection failed: $e');
    }

    // The profile photo lives in Storage, which Firestore deletion never
    // touches. The privacy policy promises it goes.
    try {
      await FirebaseStorage.instance.ref('profile_photos/$uid.jpg').delete();
    } on FirebaseException catch (e) {
      // object-not-found just means the user never set one.
      if (e.code != 'object-not-found') {
        debugPrint('[Auth] Deleting profile photo failed: $e');
      }
    }

    // Remove Firestore documents
    final userDoc = await _fs.collection('users').doc(uid).get();
    final username = (userDoc.data()?['username'] as String?)?.toLowerCase();
    final batch = _fs.batch();
    batch.delete(_fs.collection('users').doc(uid));
    if (username != null && username.isNotEmpty) {
      batch.delete(_fs.collection('usernames').doc(username));
    }
    await batch.commit();

    // Delete subcollections that Firestore does not cascade-delete automatically.
    // Sessions are small and bounded; delete them in one batch.
    try {
      final sessionsSnap = await _fs
          .collection('sessions')
          .doc(uid)
          .collection('devices')
          .get();
      if (sessionsSnap.docs.isNotEmpty) {
        final sessionBatch = _fs.batch();
        for (final doc in sessionsSnap.docs) {
          sessionBatch.delete(doc.reference);
        }
        await sessionBatch.commit();
      }
    } catch (_) {
      // Non-fatal: sessions will expire on their own after 30 days
    }

    // Finally remove the Auth account
    await user.delete();
  }

  /// Returns true if the current Firebase user has an email/password
  /// sign-in provider (as opposed to Google-only accounts).
  bool get hasEmailPasswordProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  /// Returns true if the current Firebase user signed in with Apple.
  bool get hasAppleProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'apple.com') ??
      false;
}

// Providers
final firestoreServiceProvider = Provider((_) => FirestoreService());

final authServiceProvider = Provider((ref) {
  return AuthService(ref.read(firestoreServiceProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).authStateChanges;
});

/// Stores the Firestore document ID of the current session.
/// Set once after login; used by the Active Sessions screen to mark
/// "This device" and prevent the user from revoking their own session.
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// Streams the current user's Firestore document in real-time.
/// Any field update (campaignProgress, ratings, etc.) is instantly reflected
/// everywhere this provider is watched — no manual invalidation needed.
final currentUserProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final uid = authAsync.valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchUser(uid);
});
