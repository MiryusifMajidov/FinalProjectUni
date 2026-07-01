import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OtpService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Calls the server-side sendOtp Cloud Function.
  /// OTP is generated and sent entirely on the server — no SMTP credentials on client.
  Future<void> sendOtp(String email) async {
    try {
      await _functions.httpsCallable('sendOtp').call({'email': email});
      if (kDebugMode) debugPrint('[OTP] requested for $email');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[OTP] sendOtp failed: ${e.code} ${e.message}');
      rethrow;
    }
  }

  /// Calls the server-side verifyOtp Cloud Function.
  /// Hash comparison happens entirely on the server.
  Future<bool> verifyOtp(String email, String code) async {
    try {
      final result = await _functions
          .httpsCallable('verifyOtp')
          .call({'email': email, 'code': code});
      return result.data['valid'] == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[OTP] verifyOtp failed: ${e.code} ${e.message}');
      return false;
    }
  }

  /// Calls the server-side sendFeedbackEmail Cloud Function.
  Future<void> sendFeedbackEmail({
    required String fromUsername,
    required String fromEmail,
    required String text,
    required bool isBug,
    String? appVersion,
    String? deviceInfo,
  }) async {
    try {
      await _functions.httpsCallable('sendFeedbackEmail').call({
        'fromUsername': fromUsername,
        'fromEmail': fromEmail,
        'text': text,
        'isBug': isBug,
        'appVersion': appVersion,
        'deviceInfo': deviceInfo,
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[Feedback] send failed: ${e.code} ${e.message}');
      rethrow;
    }
  }

  /// 2FA OTP reuses the same send mechanism.
  Future<void> send2faOtp(String email) => sendOtp(email);
}

final otpServiceProvider = Provider<OtpService>((_) => OtpService());
