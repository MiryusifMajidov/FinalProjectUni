import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/constants/countries.dart';

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
const _kBorderStrong = Color(0xFF3D3530);
const _kDanger       = Color(0xFFE05252);


class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

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
                    'account'.tr(),
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

            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const SizedBox(height: 20),

                  // ── Avatar ────────────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: user != null ? () => _uploadPhoto(user) : null,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Avatar circle
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _kAmberGlow,
                                  border: Border.all(
                                    color: _kAmber.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _uploading
                                      ? const Center(
                                          child: SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _kAmber,
                                            ),
                                          ),
                                        )
                                      : user?.photoUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: user!.photoUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  _initials(user),
                                            )
                                          : _initials(user),
                                ),
                              ),
                              // Camera badge
                              Positioned(
                                bottom: -4,
                                right: -4,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _kAmber,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _kBg, width: 3),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      PhosphorIcons.camera(PhosphorIconsStyle.fill),
                                      size: 13,
                                      color: const Color(0xFF1A1205),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'tap_photo_to_change'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── IDENTITY ──────────────────────────────────────────────
                  _sectionLabel('IDENTITY'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.user(PhosphorIconsStyle.regular),
                      label: 'username'.tr(),
                      sub: user?.username ?? '—',
                      onTap: () => _showChangeUsernameSheet(),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.pencilSimple(PhosphorIconsStyle.regular),
                      label: 'display_name'.tr(),
                      sub: user?.username ?? '—',
                      onTap: () => _editDisplayName(context, user),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.envelope(PhosphorIconsStyle.regular),
                      label: 'email'.tr(),
                      sub: _maskEmail(user?.email),
                      onTap: () => _showChangeEmailSheet(),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.flag(PhosphorIconsStyle.regular),
                      label: 'Country',
                      sub: _countryLabel(user),
                      onTap: () => _showChangeCountrySheet(user),
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── SECURITY ──────────────────────────────────────────────
                  _sectionLabel('SECURITY'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.lock(PhosphorIconsStyle.regular),
                      label: 'change_password'.tr(),
                      sub: ref.read(authServiceProvider).hasEmailPasswordProvider
                          ? null
                          : 'Not available for ${_providerLabel()} accounts',
                      onTap: () {
                        if (!ref
                            .read(authServiceProvider)
                            .hasEmailPasswordProvider) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Password change is not available for ${_providerLabel()} accounts.'),
                            ),
                          );
                          return;
                        }
                        _showChangePasswordSheet();
                      },
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.regular),
                      label: 'Two-factor authentication',
                      sub: user?.twoFactorEnabled == true ? 'Enabled' : 'Disabled',
                      onTap: () => context.push(
                        '/home/settings/account/2fa',
                        extra: user?.twoFactorEnabled != true,
                      ),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.deviceMobile(PhosphorIconsStyle.regular),
                      label: 'active_sessions'.tr(),
                      sub: 'Manage logged-in devices',
                      onTap: () => context.push('/home/settings/account/sessions'),
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── ACCOUNT ACTIONS ───────────────────────────────────────
                  _sectionLabel('ACCOUNT ACTIONS'),
                  _SettingsGroup(children: [
                    _SettingsRow(
                      icon: PhosphorIcons.downloadSimple(PhosphorIconsStyle.regular),
                      label: 'Export game history',
                      onTap: () => _exportGameHistory(context, ref, user),
                    ),
                    _SettingsRow(
                      icon: PhosphorIcons.trash(PhosphorIconsStyle.regular),
                      label: 'Delete account',
                      danger: true,
                      onTap: () => _confirmDelete(context),
                      isLast: true,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar helpers ─────────────────────────────────────────────────────────

  Widget _initials(UserModel? user) {
    final name = user?.username ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.fraunces(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: _kAmber,
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(UserModel user) async {
    setState(() => _uploading = true);
    try {
      final url = await ref.read(photoServiceProvider).pickAndUpload(
        user.uid,
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      );
      if (url != null && mounted) {
        ref.invalidate(currentUserProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('photo_updated'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Edit sheets ────────────────────────────────────────────────────────────

  void _showChangeUsernameSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditSheet(
        title: 'change_username'.tr(),
        fields: [
          _FieldDef(label: 'new_username'.tr(), controller: ctrl),
        ],
        onSave: (values) async {
          final v = values[0].trim();
          if (v.length < 3) throw Exception('At least 3 characters');
          await ref.read(authServiceProvider).changeUsername(v);
          ref.invalidate(currentUserProvider);
        },
        successMessage: 'username_updated'.tr(),
      ),
    );
  }

  void _showChangeEmailSheet() {
    final passCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditSheet(
        title: 'change_email'.tr(),
        fields: [
          _FieldDef(
              label: 'current_password'.tr(),
              controller: passCtrl,
              obscure: true),
          _FieldDef(
              label: 'new_email'.tr(),
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress),
        ],
        onSave: (values) async {
          await ref
              .read(authServiceProvider)
              .changeEmail(values[0], values[1].trim());
        },
        successMessage: 'Verification sent to new email!',
      ),
    );
  }

  void _showChangePasswordSheet() {
    final currCtrl = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditSheet(
        title: 'change_password'.tr(),
        fields: [
          _FieldDef(
              label: 'current_password'.tr(),
              controller: currCtrl,
              obscure: true),
          _FieldDef(
              label: 'new_password'.tr(),
              controller: newCtrl,
              obscure: true),
          _FieldDef(
              label: 'confirm_password'.tr(),
              controller: confCtrl,
              obscure: true),
        ],
        onSave: (values) async {
          if (values[1] != values[2]) {
            throw Exception('Passwords do not match');
          }
          if (values[1].length < 6) {
            throw Exception('At least 6 characters');
          }
          await ref
              .read(authServiceProvider)
              .changePassword(values[0], values[1]);
        },
        successMessage: 'password_updated'.tr(),
      ),
    );
  }

  void _showChangeCountrySheet(UserModel? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _CountrySheet(initialCode: user?.countryCode, pRef: ref),
    );
  }

  // ── Export game history ────────────────────────────────────────────────────

  Future<void> _exportGameHistory(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
  ) async {
    if (user == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing game history…')),
    );
    try {
      final games = await ref
          .read(firestoreServiceProvider)
          .getRecentGames(user.uid, limit: 100);

      if (games.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No games found to export.')),
          );
        }
        return;
      }

      final buf = StringBuffer();
      buf.writeln('Grandmaster — Game History Export');
      buf.writeln('Player: ${user.username}');
      buf.writeln('Exported: ${DateTime.now().toString().substring(0, 16)}');
      buf.writeln('═' * 46);
      buf.writeln();

      for (final g in games) {
        final myColor = g.whiteUid == user.uid ? 'White' : 'Black';
        final oppUid  = g.whiteUid == user.uid ? g.blackUid : g.whiteUid;
        buf.writeln('[Date "${g.createdAt.toString().substring(0, 10)}"]');
        buf.writeln('[White "${g.whiteUid == user.uid ? user.username : oppUid}"]');
        buf.writeln('[Black "${g.blackUid == user.uid ? user.username : oppUid}"]');
        buf.writeln('[Result "${g.result.name}"]');
        buf.writeln('[TimeControl "${g.timeControl.label}"]');
        buf.writeln('[MyColor "$myColor"]');
        if (g.moves.isNotEmpty) {
          buf.writeln();
          // Write moves in numbered pairs
          for (int i = 0; i < g.moves.length; i++) {
            if (i % 2 == 0) buf.write('${i ~/ 2 + 1}. ');
            buf.write('${g.moves[i]} ');
          }
          buf.writeln();
        }
        buf.writeln();
      }

      await Share.share(
        buf.toString(),
        subject: 'Grandmaster game history — ${user.username}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  // ── Delete account ─────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context) {
    final passCtrl = TextEditingController();
    // Only email/password accounts need a password; Google and Apple accounts
    // re-authenticate through their own provider sheet inside deleteAccount().
    final auth = ref.read(authServiceProvider);
    final needsPassword = auth.hasEmailPasswordProvider;
    final isApple = auth.hasAppleProvider;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool deleting = false;
        String? error;
        return StatefulBuilder(
        builder: (ctx, setModal) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kDanger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIcons.trash(PhosphorIconsStyle.fill),
                      color: _kDanger,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Delete account?',
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This permanently deletes your profile, games, and all data. This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _kInkMute,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password field — shown only for email/password accounts
                  if (needsPassword) ...[
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      style: GoogleFonts.inter(color: _kInk, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Enter password to confirm',
                        labelStyle: GoogleFonts.inter(color: _kInkMute),
                        errorText: error,
                        filled: true,
                        fillColor: _kSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kDanger),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      isApple
                          ? 'You will be prompted to sign in with Apple to confirm.'
                          : 'You will be prompted to sign in with Google to confirm.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _kInkMute, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                              if (deleting) return;
                              if (needsPassword && passCtrl.text.isEmpty) {
                                setModal(() => error = 'Password required');
                                return;
                              }
                              setModal(() {
                                deleting = true;
                                error = null;
                              });
                              try {
                                await ref
                                    .read(authServiceProvider)
                                    .deleteAccount(
                                      needsPassword ? passCtrl.text : null,
                                    );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) context.go('/login');
                              } catch (e) {
                                setModal(() {
                                  deleting = false;
                                  error = e
                                      .toString()
                                      .replaceFirst('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kDanger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: deleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : Text(
                              'Delete my account',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'cancel'.tr(),
                      style: GoogleFonts.inter(
                          fontSize: 14, color: _kInkDim),
                    ),
                  ),
                ],
              ),
            ),
          ),   // closes Padding
        );     // closes StatefulBuilder
      },       // closes (ctx) { outer builder
    );         // closes showModalBottomSheet
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Name of the federated provider backing a password-less account.
  String _providerLabel() =>
      ref.read(authServiceProvider).hasAppleProvider ? 'Apple' : 'Google';

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return '—';
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email[0]}•••••${email.substring(at)}';
  }

  String _countryLabel(UserModel? user) {
    if (user == null || user.countryCode == null) return '—';
    return '${UserModel.flagEmoji(user.countryCode)} ${user.countryCode}';
  }

  Future<void> _editDisplayName(BuildContext context, UserModel? user) async {
    if (user == null) return;
    final ctrl = TextEditingController(text: user.username);
    String? dialogError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: _kCard,
          title: Text('display_name'.tr(),
              style: GoogleFonts.fraunces(
                  color: _kInk, fontStyle: FontStyle.italic)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                style: GoogleFonts.inter(color: _kInk),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: GoogleFonts.inter(color: _kInkMute),
                  errorText: dialogError,
                  filled: true,
                  fillColor: _kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kAmber),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This also updates your username.',
                style: GoogleFonts.inter(fontSize: 11, color: _kInkMute),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr(), style: GoogleFonts.inter(color: _kInkDim)),
            ),
            TextButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.length < 3) {
                  setDialog(() => dialogError = 'At least 3 characters');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text('save'.tr(),
                  style: GoogleFonts.inter(
                      color: _kAmber, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final newName = ctrl.text.trim();
      if (newName.isEmpty || newName == user.username) return;
      try {
        // changeUsername updates both users doc AND usernames collection
        await ref.read(authServiceProvider).changeUsername(newName);
        ref.invalidate(currentUserProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('display_name_updated'.tr())),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
    }
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kInkMute,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Generic edit sheet ────────────────────────────────────────────────────────

class _FieldDef {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType keyboardType;

  const _FieldDef({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
  });
}

class _EditSheet extends StatefulWidget {
  final String title;
  final List<_FieldDef> fields;
  final Future<void> Function(List<String> values) onSave;
  final String successMessage;

  const _EditSheet({
    required this.title,
    required this.fields,
    required this.onSave,
    required this.successMessage,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _kInkMute, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.title,
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 16),
          // Fields
          ...widget.fields.asMap().entries.map((e) {
            final i = e.key;
            final f = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < widget.fields.length - 1 ? 12 : 0),
              child: TextField(
                controller: f.controller,
                obscureText: f.obscure,
                keyboardType: f.keyboardType,
                style: GoogleFonts.inter(color: _kInk, fontSize: 14),
                autofocus: i == 0,
                decoration: InputDecoration(
                  labelText: f.label,
                  errorText: i == widget.fields.length - 1 ? _error : null,
                  labelStyle: GoogleFonts.inter(color: _kInkMute),
                  filled: true,
                  fillColor: _kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kAmber),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAmber,
                foregroundColor: const Color(0xFF1A1205),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A1205)),
                    )
                  : Text(
                      'save'.tr(),
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSave(widget.fields.map((f) => f.controller.text).toList());
      if (!mounted) return;
      // Capture messenger BEFORE popping — context becomes invalid after pop.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(widget.successMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyAuthError(e);
      });
    }
  }

  static String _friendlyAuthError(Object e) {
    final raw = e.toString();
    if (raw.contains('wrong-password') || raw.contains('invalid-credential') ||
        raw.contains('INVALID_PASSWORD')) {
      return 'Incorrect current password.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (raw.contains('network-request-failed')) {
      return 'No internet connection.';
    }
    if (raw.contains('requires-recent-login')) {
      return 'Please sign out and sign back in, then try again.';
    }
    if (raw.contains('no-such-provider') ||
        raw.contains('no-password') ||
        raw.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'Password change is not available for this account type.';
    }
    return raw.replaceFirst('Exception: ', '');
  }
}

// ── Country picker sheet ───────────────────────────────────────────────────────

class _CountrySheet extends ConsumerStatefulWidget {
  final String? initialCode;
  final WidgetRef pRef;
  const _CountrySheet({required this.initialCode, required this.pRef});

  @override
  ConsumerState<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends ConsumerState<_CountrySheet> {
  String? _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCode;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: _kInkMute, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Text('change_country'.tr(),
              style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: _kInk)),
          const SizedBox(height: 4),
          // No country
          ListTile(
            leading: const Text('🏳️', style: TextStyle(fontSize: 22)),
            title: Text('no_flag'.tr(),
                style: GoogleFonts.inter(fontSize: 14, color: _kInk)),
            trailing: _selected == null
                ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold),
                    color: _kAmber, size: 18)
                : null,
            onTap: () => _save(null),
          ),
          Divider(height: 1, color: _kBorder),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: kCountries.length,
              itemBuilder: (_, i) {
                final (code, name) = kCountries[i];
                final sel = _selected == code;
                return ListTile(
                  leading: Text(UserModel.flagEmoji(code),
                      style: const TextStyle(fontSize: 22)),
                  title:
                      Text(name, style: GoogleFonts.inter(fontSize: 14, color: _kInk)),
                  trailing: sel
                      ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold),
                          color: _kAmber, size: 18)
                      : null,
                  onTap: () => _save(code),
                );
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: _kAmber),
            ),
        ],
      ),
    );
  }

  Future<void> _save(String? code) async {
    setState(() {
      _loading = true;
      _selected = code;
    });
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;
      await ref
          .read(firestoreServiceProvider)
          .updateUser(user.uid, {'countryCode': code});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('country_updated'.tr())));
        ref.invalidate(currentUserProvider);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Shared local widgets ───────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final bool isLast;
  final bool danger;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sub,
    this.onTap,
    this.isLast = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: danger
                        ? _kDanger.withValues(alpha: 0.12)
                        : _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: danger
                          ? _kDanger.withValues(alpha: 0.3)
                          : _kBorder,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: danger ? _kDanger : _kAmber,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: danger ? _kDanger : _kInk,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub!,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _kInkMute),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                  color: danger
                      ? _kDanger.withValues(alpha: 0.5)
                      : _kInkMute,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Container(height: 1, color: _kBorder),
          ),
      ],
    );
  }
}
