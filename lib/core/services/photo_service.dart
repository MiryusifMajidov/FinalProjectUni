import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Handles profile photo picking (gallery) and upload to Firebase Storage.
class PhotoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  /// Opens the image gallery, uploads the picked image to Storage, and saves
  /// the download URL to the user's Firestore document.
  ///
  /// Returns the download URL on success, null if the user cancelled or an
  /// error occurred.
  Future<String?> pickAndUpload(
    String uid, {
    ImageSource source = ImageSource.gallery,
    void Function(String)? onError,
  }) async {
    // Firebase Storage CORS blocks uploads from web browsers.
    // Direct users to the mobile app instead.
    if (kIsWeb) {
      onError?.call(
        'Profile photo upload is only available on mobile. Please use the Android or iOS app.',
      );
      return null;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final url = await _upload(uid, picked);
      if (url != null) {
        await _saveUrl(uid, url);
      }
      return url;
    } catch (e) {
      debugPrint('[PhotoService] upload error: $e');
      onError?.call('Upload failed. Please try again.');
      return null;
    }
  }

  Future<String?> _upload(String uid, XFile file) async {
    final ref = _storage.ref('profile_photos/$uid.jpg');
    UploadTask task;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      task = ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'Access-Control-Allow-Origin': '*'},
        ),
      );
    } else {
      task = ref.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }
    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _saveUrl(String uid, String url) async {
    // 1. Update the user's own document
    await _firestore.collection('users').doc(uid).update({'photoUrl': url});

    // 2. Update the cached photoUrl in every friend's subcollection entry
    //    so their friend lists also show the new photo without a cold fetch.
    try {
      final friendsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .get();

      if (friendsSnap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final friendDoc in friendsSnap.docs) {
        final friendUid = friendDoc.id;
        // Update this user's entry in the friend's friends subcollection
        final ref = _firestore
            .collection('users')
            .doc(friendUid)
            .collection('friends')
            .doc(uid);
        batch.update(ref, {'photoUrl': url});
      }
      await batch.commit();
    } catch (e) {
      // Non-critical — the profile screen fetches live anyway
      debugPrint('[PhotoService] friend sync failed: $e');
    }
  }

  /// Deletes the user's profile photo from Firebase Storage and clears
  /// the photoUrl field in Firestore (own document + friends' subcollections).
  Future<void> deletePhoto(String uid) async {
    // 1. Delete from Firebase Storage — ignore "object not found" gracefully
    try {
      await _storage.ref('profile_photos/$uid.jpg').delete();
    } catch (_) {}

    // 2. Clear the user's own document
    await _firestore.collection('users').doc(uid).update({'photoUrl': null});

    // 3. Clear cached photoUrl in every friend's subcollection entry
    try {
      final friendsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .get();

      if (friendsSnap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final friendDoc in friendsSnap.docs) {
        final friendUid = friendDoc.id;
        final ref = _firestore
            .collection('users')
            .doc(friendUid)
            .collection('friends')
            .doc(uid);
        batch.update(ref, {'photoUrl': null});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[PhotoService] friend sync on delete failed: $e');
    }
  }

  /// Picks an image from the gallery and uploads it as the group's photo.
  /// Returns the download URL on success, null on cancel or error.
  Future<String?> pickAndUploadGroupPhoto(String groupId) async {
    if (kIsWeb) return null;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final ref = _storage.ref('group_photos/$groupId.jpg');
      final task = ref.putFile(
        File(picked.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('[PhotoService] group upload error: $e');
      return null;
    }
  }
}

final photoServiceProvider = Provider((_) => PhotoService());
