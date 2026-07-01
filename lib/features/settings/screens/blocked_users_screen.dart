import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/widgets/user_avatar.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF0A0A0B);
const _kSurface   = Color(0xFF131316);
const _kCard      = Color(0xFF1A1A1E);
const _kAmber     = Color(0xFFE8B960);
const _kInk       = Color(0xFFF5F3EF);
const _kInkDim    = Color(0xFFB0A898);
const _kInkMute   = Color(0xFF706860);
const _kBorder    = Color(0xFF2A2520);
const _kLoss      = Color(0xFFF07079);

/// Provider that fetches UserModel objects for each blocked UID.
final blockedUsersListProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || user.blockedUsers.isEmpty) return [];
  final fs = ref.read(firestoreServiceProvider);
  final results = await Future.wait(
    user.blockedUsers.map((uid) => fs.getUser(uid)),
  );
  return results.whereType<UserModel>().toList();
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(blockedUsersListProvider);

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
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: _kInkDim, size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'block_list'.tr(),
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
              child: listAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _kAmber),
                ),
                error: (e, _) => Center(
                  child: Text(e.toString(),
                      style: GoogleFonts.inter(color: _kInkMute)),
                ),
                data: (blocked) {
                  if (blocked.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.prohibit(PhosphorIconsStyle.regular),
                            color: _kInkMute, size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'no_blocked_users'.tr(),
                            style: GoogleFonts.inter(
                                fontSize: 15, color: _kInkMute),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'When you block someone they can\'t\nmessage or challenge you.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: _kInkMute, height: 1.5),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
                    itemCount: blocked.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${blocked.length} BLOCKED',
                            style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: _kInkMute, letterSpacing: 1.2,
                            ),
                          ),
                        );
                      }
                      final u = blocked[i - 1];
                      return _BlockedTile(
                        user: u,
                        onUnblock: () async {
                          final myUid = ref
                              .read(authStateProvider)
                              .valueOrNull
                              ?.uid;
                          if (myUid == null) return;
                          await ref
                              .read(firestoreServiceProvider)
                              .unblockUser(myUid, u.uid);
                          ref.invalidate(currentUserProvider);
                          ref.invalidate(blockedUsersListProvider);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Blocked tile ──────────────────────────────────────────────────────────────

class _BlockedTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onUnblock;

  const _BlockedTile({required this.user, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          UserAvatar(username: user.username, photoUrl: user.photoUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kInk,
                  ),
                ),
                Text(
                  '${user.overallRating} ELO',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: _kInkMute),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onUnblock,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kLoss.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kLoss.withValues(alpha: 0.3)),
              ),
              child: Text(
                'unblock_user'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kLoss,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
