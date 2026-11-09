import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'legal_texts.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/moulded.dart';
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
                  style: AppFonts.ui(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last updated: $kLegalUpdated',
                  style: AppFonts.ui(fontSize: 11, color: _kInkMute),
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
                          style: AppFonts.ui(
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
  const LegalConsentNotice({super.key, this.accent = const Color(0xFFF0A93B)});

  /// The screen's own accent, so the links read as links in either palette.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final base = AppFonts.ui(
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

// ── Terms agreement ────────────────────────────────────────────────────────

/// Bump the suffix when the terms change enough that everyone should agree
/// again.
const _kTermsAcceptedKey = 'terms_accepted_v1';
const _kTermsAcceptedAtKey = 'terms_accepted_at_v1';

/// Asks the player to agree to the terms before any sign-in or sign-up, once
/// per device. Returns true when they have agreed, now or earlier.
///
/// Guideline 1.2: submission 4f7981be was rejected because nobody had to
/// agree to anything on the way in, and the reviewer asked to see "the EULA
/// or terms of use agreement presented to users before registering or logging
/// in". A line of small print under the buttons is not an agreement; this
/// sheet is, and every sign-in path (guest, Apple, Google, e-mail, sign-up)
/// goes through it. Offline play creates no account and shows no content from
/// other people, so it does not ask.
Future<bool> ensureTermsAccepted(BuildContext context) async {
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kTermsAcceptedKey) ?? false) return true;
  } catch (_) {
    // Storage unavailable: ask anyway, and simply ask again next time.
  }
  if (!context.mounted) return false;
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: _kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _TermsAgreementSheet(),
  );
  if (agreed != true) return false;
  try {
    await prefs?.setBool(_kTermsAcceptedKey, true);
    await prefs?.setString(
        _kTermsAcceptedAtKey, DateTime.now().toUtc().toIso8601String());
  } catch (_) {}
  return true;
}

class _TermsAgreementSheet extends StatelessWidget {
  const _TermsAgreementSheet();

  static const _accent = AppColors.amber;
  static const _onAccent = Color(0xFF241703);

  @override
  Widget build(BuildContext context) {
    final linkStyle = AppFonts.ui(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _accent,
      decoration: TextDecoration.underline,
      decorationColor: _accent,
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'terms_gate_title'.tr(),
                style: AppFonts.ui(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'terms_gate_intro'.tr(),
                style: AppFonts.ui(fontSize: 14, color: _kInkDim, height: 1.5),
              ),
              const SizedBox(height: 18),
              _Rule(
                icon: PhosphorIcons.prohibit(PhosphorIconsStyle.bold),
                text: 'terms_gate_zero'.tr(),
                strong: true,
              ),
              _Rule(
                icon: PhosphorIcons.flag(PhosphorIconsStyle.bold),
                text: 'terms_gate_report'.tr(),
              ),
              _Rule(
                icon: PhosphorIcons.userCircle(PhosphorIconsStyle.bold),
                text: 'terms_gate_age'.tr(),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 18,
                runSpacing: 4,
                children: [
                  _LinkButton(
                    label: 'terms_gate_read_terms'.tr(),
                    style: linkStyle,
                    onTap: () => showLegalDocSheet(
                      context,
                      title: 'terms_gate_terms_doc'.tr(),
                      paragraphs: kTermsParagraphs,
                    ),
                  ),
                  _LinkButton(
                    label: 'terms_gate_privacy_doc'.tr(),
                    style: linkStyle,
                    onTap: () => showLegalDocSheet(
                      context,
                      title: 'terms_gate_privacy_doc'.tr(),
                      paragraphs: kPolicyParagraphs,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: Moulded(
                  color: _accent,
                  radius: 14,
                  semanticLabel: 'terms_gate_agree'.tr(),
                  onTap: () => Navigator.of(context).pop(true),
                  child: Center(
                    child: Text(
                      'terms_gate_agree'.tr(),
                      style: AppFonts.ui(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _onAccent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'terms_gate_decline'.tr(),
                    style: AppFonts.ui(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kInkDim,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kBorder,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 18, color: strong ? AppColors.loss : _kInkDim),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppFonts.ui(
                fontSize: 14,
                height: 1.45,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                color: strong ? _kInk : _kInkDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}

/// A [TapGestureRecognizer] is disposable, but one created per build for a
/// short-lived span in a stateless widget is the pattern Flutter's own
/// documentation uses; the span outlives no more than the frame it is built in.
TapGestureRecognizer _tap(VoidCallback onTap) =>
    TapGestureRecognizer()..onTap = onTap;
