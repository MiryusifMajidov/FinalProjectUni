import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = Color(0xFF0A0A0B);
const _kSurface      = Color(0xFF131316);
const _kCard         = Color(0xFF1A1A1E);
const _kAmber        = Color(0xFFE8B960);
const _kAmberGlow    = Color(0x24E8B960);
const _kInk          = Color(0xFFF5F3EF);
const _kInkDim       = Color(0xFFB0A898);
const _kInkMute      = Color(0xFF706860);
const _kBorder       = Color(0xFF2A2520);

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static const _langs = [
    (code: 'en', native: 'English',      english: 'English'),
    (code: 'az', native: 'Azərbaycan',   english: 'Azerbaijani'),
    (code: 'tr', native: 'Türkçe',       english: 'Turkish'),
    (code: 'ru', native: 'Русский',      english: 'Russian'),
    (code: 'de', native: 'Deutsch',      english: 'German'),
    (code: 'es', native: 'Español',      english: 'Spanish'),
    (code: 'fr', native: 'Français',     english: 'French'),
    (code: 'hi', native: 'हिन्दी',       english: 'Hindi'),
    (code: 'ur', native: 'اردو',         english: 'Urdu'),
    (code: 'zh', native: '中文',          english: 'Chinese'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentCode = context.locale.languageCode;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: _kInkDim,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'language'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                ],
              ),
            ),

            // ── Subtitle ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Text(
                'Choose the language for the app interface. Move notation uses standard algebraic notation (SAN) across all languages.',
                style: GoogleFonts.inter(fontSize: 13, color: _kInkDim),
              ),
            ),

            // ── Language list ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: ListView.separated(
                    itemCount: _langs.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(left: 68),
                      child: Container(height: 1, color: _kBorder),
                    ),
                    itemBuilder: (context, i) {
                      final lang = _langs[i];
                      final selected = lang.code == currentCode;
                      return _LangRow(
                        lang: lang,
                        selected: selected,
                        onTap: () {
                          context.setLocale(Locale(lang.code));
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _LangRow extends StatelessWidget {
  final ({String code, String native, String english}) lang;
  final bool selected;
  final VoidCallback onTap;

  const _LangRow({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Language code pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? _kAmberGlow : _kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? _kAmber : _kBorder,
                ),
              ),
              child: Center(
                child: Text(
                  lang.code.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? _kAmber : _kInkDim,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Names
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.native,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selected ? _kInk : _kInkDim,
                    ),
                  ),
                  Text(
                    lang.english,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _kInkMute,
                    ),
                  ),
                ],
              ),
            ),
            // Check icon
            if (selected)
              Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: _kAmber,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
