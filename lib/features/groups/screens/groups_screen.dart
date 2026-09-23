import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/group_service.dart';
import '../../../core/models/group_model.dart';
import '../../../core/widgets/user_avatar.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg       = AppColors.background;
const _kCard     = AppColors.card;
const _kSurface  = AppColors.surface;
const _kAmber    = AppColors.amber;
const _kAmberDeep = AppColors.amberDeep;
const _kAmberGlow = AppColors.amberGlow;
const _kInk      = AppColors.ink;
const _kInkDim   = AppColors.inkDim;
const _kInkMute  = AppColors.inkMute;
const _kBorder   = AppColors.border;

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider).valueOrNull?.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                    Expanded(
                      child: Text(
                        'groups'.tr(),
                        style: GoogleFonts.fraunces(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: _kInk,
                        ),
                      ),
                    ),
                    // Create group button
                    GestureDetector(
                      onTap: () => context.push('/home/groups/create'),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kAmberGlow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kAmber.withOpacity(0.4)),
                        ),
                        child: Icon(
                          PhosphorIcons.plus(PhosphorIconsStyle.bold),
                          color: _kAmber, size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Tabs ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kAmber, _kAmberDeep],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: const Color(0xFF1A1205),
                    unselectedLabelColor: _kInkMute,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'My Groups'),
                      Tab(text: 'Discover'),
                    ],
                  ),
                ),
              ),

              // ── Tab content ───────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  children: [
                    myUid == null
                        ? const Center(
                            child: CircularProgressIndicator(color: _kAmber),
                          )
                        : _MyGroupsTab(myUid: myUid),
                    _DiscoverTab(myUid: myUid ?? ''),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── My Groups Tab ─────────────────────────────────────────────────────────────

class _MyGroupsTab extends ConsumerWidget {
  final String myUid;
  const _MyGroupsTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<GroupModel>>(
      stream: ref.read(groupServiceProvider).watchMyGroups(myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kAmber),
          );
        }
        final groups = snap.data ?? [];
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: _kAmberGlow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    PhosphorIcons.usersThree(PhosphorIconsStyle.regular),
                    size: 30, color: _kAmber,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No groups yet',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create or discover groups',
                  style: GoogleFonts.inter(fontSize: 13, color: _kInkMute),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: groups.length,
          itemBuilder: (_, i) => _GroupCard(group: groups[i], myUid: myUid),
        );
      },
    );
  }
}

// ── Discover Tab ──────────────────────────────────────────────────────────────

class _DiscoverTab extends ConsumerWidget {
  final String myUid;
  const _DiscoverTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<GroupModel>>(
      stream: ref.read(groupServiceProvider).watchPublicGroups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kAmber),
          );
        }
        final groups = snap.data ?? [];
        if (groups.isEmpty) {
          return Center(
            child: Text(
              'No public groups',
              style: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: groups.length,
          itemBuilder: (_, i) => _GroupCard(group: groups[i], myUid: myUid),
        );
      },
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────

class _GroupCard extends ConsumerWidget {
  final GroupModel group;
  final String myUid;
  const _GroupCard({required this.group, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMember = group.memberIds.contains(myUid);

    return GestureDetector(
      onTap: isMember ? () => context.push('/home/groups/${group.id}') : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            // Avatar
            group.photoUrl != null && group.photoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: UserAvatar(
                      username: group.name,
                      photoUrl: group.photoUrl,
                      size: 48,
                    ),
                  )
                : Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _kAmberGlow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        group.avatarEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kInk,
                          ),
                        ),
                      ),
                      if (group.privacy == GroupPrivacy.private)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            PhosphorIcons.lock(PhosphorIconsStyle.fill),
                            size: 12, color: _kInkMute,
                          ),
                        ),
                    ],
                  ),
                  if (group.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      group.description!,
                      style: GoogleFonts.inter(
                        fontSize: 12, color: _kInkMute,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '${group.memberCount} members',
                    style: GoogleFonts.inter(
                      fontSize: 11, color: _kInkMute,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action
            if (!isMember)
              GestureDetector(
                onTap: () async {
                  await ref.read(groupServiceProvider).joinGroup(group.id, myUid);
                  if (context.mounted) {
                    context.push('/home/groups/${group.id}');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kAmber, _kAmberDeep],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'join'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1205),
                    ),
                  ),
                ),
              )
            else
              Icon(
                PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                color: _kInkMute, size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
