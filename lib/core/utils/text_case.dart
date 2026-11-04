import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

extension LocaleAwareCase on String {
  /// [toUpperCase] that knows the Turkish/Azerbaijani dotted capital İ.
  ///
  /// Dart's toUpperCase is locale-independent, so "Şifrə" became "ŞIFRƏ" and
  /// "Gizlilik" became "GIZLILIK" in every all-caps label.
  String toUpperCaseFor(BuildContext context) {
    final lang = EasyLocalization.of(context)?.locale.languageCode ??
        Localizations.maybeLocaleOf(context)?.languageCode;
    if (lang == 'tr' || lang == 'az') {
      return replaceAll('i', 'İ').toUpperCase();
    }
    return toUpperCase();
  }
}
