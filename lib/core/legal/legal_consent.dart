import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'legal_texts.dart';

import '../theme/app_colors.dart';
/// The date shown under a legal document's title. Bump it whenever
/// [kTermsParagraphs] or [kPolicyParagraphs] changes in a way a user would care
/// about — section 11 of the terms promises a new date on every revision.
const kLegalUpdated = '30 September 2026';

// The sheet is its own small design island: the auth screens and the About
// screen use different palettes, and a legal document should look the same from
// both. These match the About screen's tokens.
const _kCard    = AppColors.card;
const _kBorder  = AppColors.border;
const _kInk     = AppColors.ink;
const _kInkDim  = AppColors.inkDim;
const _kInkMute = AppColors.inkMute;

/// Opens a legal document as a draggable bottom sheet.
///
/// Shared rather than private to a screen because Guideline 1.2 requires the
/// terms to be reachable from the sign-in and registration screens, not only
/// from Settings — and App Review checks that the link actually opens the text.
void showLegalDocSheet(
  BuildContext context, {
  required String title,
  required List<String> paragraphs,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kInkMute,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last updated: $kLegalUpdated',
                  style: GoogleFonts.inter(fontSize: 11, color: _kInkMute),
                ),
              ],
            ),
          ),
          const Divider(color: _kBorder, height: 1),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: paragraphs
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          p,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _kInkDim,
                            height: 1.6,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The consent line shown on the sign-in and registration screens.
///
/// Guideline 1.2 requires an app with user-generated content to put the terms
/// in front of the user *before* they register or sign in, and requires those
/// terms to state that objectionable content and abusive users are not
/// tolerated. Submission 4f7981be was rejected on exactly this point: the terms
/// existed but lived three taps deep in Settings → About, so nobody agreed to
/// anything on the way in.
///
/// Both documents open in full here. A link that goes nowhere fails the same
/// check as no link at all.
class LegalConsentNotice extends StatelessWidget {
  const LegalConsentNotice({super.key, this.accent = const Color(0xFFE8B960)});

  /// The screen's own accent, so the links read as links in either palette.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
      fontSize: 11.5,
      height: 1.45,
      color: _kInkMute,
    );
    final link = base.copyWith(
      color: accent,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: accent,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            // Split into five pieces so each language can keep its own word
            // order around the two links.
            TextSpan(text: 'legal_agree_prefix'.tr()),
            TextSpan(
              text: 'legal_terms'.tr(),
              style: link,
              recognizer: _tap(() => showLegalDocSheet(
                    context,
                    title: 'Terms of Service',
                    paragraphs: kTermsParagraphs,
                  )),
            ),
            TextSpan(text: 'legal_and'.tr()),
            TextSpan(
              text: 'legal_privacy'.tr(),
              style: link,
              recognizer: _tap(() => showLegalDocSheet(
                    context,
                    title: 'Privacy Policy',
                    paragraphs: kPolicyParagraphs,
                  )),
            ),
            TextSpan(text: 'legal_suffix'.tr()),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// A [TapGestureRecognizer] is disposable, but one created per build for a
/// short-lived span in a stateless widget is the pattern Flutter's own
/// documentation uses; the span outlives no more than the frame it is built in.
TapGestureRecognizer _tap(VoidCallback onTap) =>
    TapGestureRecognizer()..onTap = onTap;
