import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/group_service.dart';
import '../../../core/services/photo_service.dart';
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
const _kLoss     = AppColors.loss;
const _kLossSoft = AppColors.lossSoft;

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _infoSaving = false;
  bool _uploadingPhoto = false;
  String? _loadedGroupId;

  void _initFromGroup(GroupModel group) {
    if (_loadedGroupId == group.id) return;
    _loadedGroupId = group.id;
    _nameCtrl.text = group.name;
    _descCtrl.text = group.description ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeGroupPhoto() async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await ref
          .read(photoServiceProvider)
          .pickAndUploadGroupPhoto(widget.groupId);
      if (url != null) {
        await ref.read(groupServiceProvider).updateGroupPhoto(widget.groupId, url);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveInfo() async {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _infoSaving = true);
    try {
      await ref.read(groupServiceProvider).updateGroupInfo(
            groupId: widget.groupId,
            name: name,
            description: desc.isNotEmpty ? desc : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved',
              style: GoogleFonts.inter(fontSize: 13, color: _kInk),
            ),
            backgroundColor: _kCard,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _infoSaving = false);
    }
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final searchCtrl = TextEditingController();
    List<dynamic> results = [];
    bool searching = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add Member',
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: _kInk,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular),
                        color: _kInkMute, size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          style: GoogleFonts.inter(fontSize: 13, color: _kInk),
                          decoration: InputDecoration(
                            hintText: 'Search username…',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13, color: _kInkMute,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) async {
                            if (val.trim().length < 2) {
                              setDialogState(() => results = []);
                              return;
                            }
                            setDialogState(() => searching = true);
                            final found = await ref
                                .read(firestoreServiceProvider)
                                .searchUsers(val.trim());
                            setDialogState(() {
                              results = found;
                              searching = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (searching)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(color: _kAmber, strokeWidth: 2),
                  )
                else
                  ...results.map(
                    (user) => GestureDetector(
                      onTap: () async {
                        final username = user.username;
                        await ref.read(groupServiceProvider).addMember(
                            widget.groupId, user.uid);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$username added'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(
                              username: user.username,
                              photoUrl: user.photoUrl,
                              size: 36,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              user.username,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'cancel'.tr(),
                style: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, String myUid) async {
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Leave Group?',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: _kInk,
          ),
        ),
        content: Text(
          'You will no longer receive messages from this group.',
          style: GoogleFonts.inter(fontSize: 14, color: _kInkDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kLoss,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(groupServiceProvider).leaveGroup(widget.groupId, myUid);
    if (!mounted) return;
    router.go('/home');
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Group?',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: _kInk,
          ),
        ),
        content: Text(
          'This permanently deletes the group and all messages. This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: _kInkDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'delete'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kLoss,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(groupServiceProvider).deleteGroup(widget.groupId);
    if (!mounted) return;
    router.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider).valueOrNull?.uid ?? '';

    return StreamBuilder<GroupModel?>(
      stream: ref.read(groupServiceProvider).watchGroup(widget.groupId),
      builder: (context, snap) {
        final group = snap.data;
        if (group != null) _initFromGroup(group);
        final isAdmin = group?.isAdmin(myUid) ?? false;

        return Scaffold(
          backgroundColor: _kBg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────
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
                        'Group Settings',
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

                // ── Body ────────────────────────────────────────────────────
                Expanded(
                  child: group == null
                      ? const Center(
                          child: CircularProgressIndicator(color: _kAmber),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                          children: [
                            // ── Group Info ──────────────────────────────────
                            _SectionLabel('GROUP INFO'),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _kCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar
                                  Center(
                                    child: GestureDetector(
                                      onTap: isAdmin ? _changeGroupPhoto : null,
                                      child: Stack(
                                        children: [
                                          _GroupAvatar(group: group, size: 72),
                                          if (isAdmin)
                                            Positioned(
                                              right: 0, bottom: 0,
                                              child: Container(
                                                width: 26, height: 26,
                                                decoration: BoxDecoration(
                                                  color: _kAmber,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: _kBg, width: 2,
                                                  ),
                                                ),
                                                child: _uploadingPhoto
                                                    ? const Padding(
                                                        padding: EdgeInsets.all(5),
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Color(0xFF1A1205),
                                                        ),
                                                      )
                                                    : Icon(
                                                        PhosphorIcons.pencilSimple(
                                                            PhosphorIconsStyle.bold),
                                                        size: 12,
                                                        color: const Color(0xFF1A1205),
                                                      ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Name field
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _kSurface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _kBorder),
                                    ),
                                    child: TextField(
                                      controller: _nameCtrl,
                                      enabled: isAdmin,
                                      style: GoogleFonts.inter(
                                        fontSize: 14, color: _kInk,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'group_name'.tr(),
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 14, color: _kInkMute,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Description field
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _kSurface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _kBorder),
                                    ),
                                    child: TextField(
                                      controller: _descCtrl,
                                      enabled: isAdmin,
                                      maxLines: 3,
                                      style: GoogleFonts.inter(
                                        fontSize: 14, color: _kInk,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Description (optional)',
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 14, color: _kInkMute,
                                        ),
                                        contentPadding: const EdgeInsets.all(14),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(height: 14),
                                    GestureDetector(
                                      onTap: _infoSaving ? null : _saveInfo,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        height: 44,
                                        decoration: BoxDecoration(
                                          gradient: _infoSaving
                                              ? null
                                              : const LinearGradient(
                                                  colors: [_kAmber, _kAmberDeep],
                                                ),
                                          color: _infoSaving ? _kSurface : null,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: _infoSaving
                                              ? const SizedBox(
                                                  width: 16, height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2, color: _kAmber,
                                                  ),
                                                )
                                              : Text(
                                                  'save'.tr(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF1A1205),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // ── Permissions (admin only) ────────────────────
                            if (isAdmin) ...[
                              const SizedBox(height: 24),
                              _SectionLabel('PERMISSIONS'),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _kCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _kBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Who can send messages',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _kInk,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            group.whoCanSend == 'admins'
                                                ? 'Admins only'
                                                : 'Everyone',
                                            style: GoogleFonts.inter(
                                              fontSize: 11, color: _kInkMute,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _PermChip(
                                          label: 'everyone'.tr(),
                                          selected: group.whoCanSend == 'everyone',
                                          onTap: () => ref
                                              .read(groupServiceProvider)
                                              .setWhoCanSend(widget.groupId, 'everyone'),
                                        ),
                                        const SizedBox(width: 8),
                                        _PermChip(
                                          label: 'Admins',
                                          selected: group.whoCanSend == 'admins',
                                          onTap: () => ref
                                              .read(groupServiceProvider)
                                              .setWhoCanSend(widget.groupId, 'admins'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── Members ─────────────────────────────────────
                            const SizedBox(height: 24),
                            _SectionLabel('MEMBERS (${group.memberCount})'),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: _kCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Column(
                                children: [
                                  if (isAdmin) ...[
                                    GestureDetector(
                                      onTap: () => _showAddMemberDialog(context),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            14, 12, 14, 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38, height: 38,
                                              decoration: BoxDecoration(
                                                color: _kAmberGlow,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: _kAmber
                                                        .withOpacity(0.2)),
                                              ),
                                              child: Icon(
                                                PhosphorIcons.plus(
                                                    PhosphorIconsStyle.bold),
                                                color: _kAmber, size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Add Member',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _kAmber,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (group.memberIds.isNotEmpty)
                                      Divider(
                                        height: 1,
                                        color: _kBorder,
                                        indent: 14, endIndent: 14,
                                      ),
                                  ],
                                  ...group.memberIds.map(
                                    (uid) => _MemberTile(
                                      uid: uid,
                                      group: group,
                                      myUid: myUid,
                                      groupId: widget.groupId,
                                      isAdmin: isAdmin,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Danger Zone ──────────────────────────────────
                            const SizedBox(height: 24),
                            _SectionLabel('DANGER ZONE'),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: _kCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _kLoss.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => _confirmLeave(context, myUid),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36, height: 36,
                                            decoration: BoxDecoration(
                                              color: _kLossSoft,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              PhosphorIcons.signOut(
                                                  PhosphorIconsStyle.regular),
                                              color: _kLoss, size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Leave Group',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _kLoss,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    Divider(
                                        height: 1,
                                        color: _kLoss.withOpacity(0.15)),
                                    GestureDetector(
                                      onTap: () => _confirmDelete(context),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36, height: 36,
                                              decoration: BoxDecoration(
                                                color: _kLossSoft,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                PhosphorIcons.trash(
                                                    PhosphorIconsStyle.regular),
                                                color: _kLoss, size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Delete Group',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _kLoss,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _kInkMute,
        letterSpacing: 0.6,
      ),
    );
  }
}

// ── Group avatar ──────────────────────────────────────────────────────────────

class _GroupAvatar extends StatelessWidget {
  final GroupModel group;
  final double size;
  const _GroupAvatar({required this.group, required this.size});

  @override
  Widget build(BuildContext context) {
    if (group.photoUrl != null && group.photoUrl!.isNotEmpty) {
      return UserAvatar(
        username: group.name,
        photoUrl: group.photoUrl,
        size: size,
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _kAmberGlow,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(group.avatarEmoji, style: TextStyle(fontSize: size * 0.42)),
      ),
    );
  }
}

// ── Permission chip ───────────────────────────────────────────────────────────

class _PermChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PermChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_kAmber, _kAmberDeep])
              : null,
          color: selected ? null : _kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kAmber : _kBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF1A1205) : _kInkDim,
          ),
        ),
      ),
    );
  }
}

// ── Member tile ───────────────────────────────────────────────────────────────

class _MemberTile extends ConsumerWidget {
  final String uid;
  final GroupModel group;
  final String myUid;
  final String groupId;
  final bool isAdmin;

  const _MemberTile({
    required this.uid,
    required this.group,
    required this.myUid,
    required this.groupId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMemberAdmin = group.isAdmin(uid);
    final isSelf = uid == myUid;

    return FutureBuilder(
      future: ref.read(firestoreServiceProvider).getUser(uid),
      builder: (context, snap) {
        final user = snap.data;
        final username = user?.username ?? 'CheckMate User';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              UserAvatar(
                username: username,
                photoUrl: user?.photoUrl,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kInk,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· You',
                            style: GoogleFonts.inter(
                              fontSize: 11, color: _kInkMute,
                            ),
                          ),
                        ],
                        if (isMemberAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kAmberGlow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Admin',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kAmber,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isAdmin && !isSelf)
                PopupMenuButton<String>(
                  icon: Icon(
                    PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.regular),
                    color: _kInkMute, size: 18,
                  ),
                  color: _kCard,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) async {
                    final svc = ref.read(groupServiceProvider);
                    switch (val) {
                      case 'make_admin':
                        await svc.addAdmin(groupId, uid);
                        break;
                      case 'remove_admin':
                        await svc.removeAdmin(groupId, uid);
                        break;
                      case 'remove':
                        await svc.removeMember(groupId, uid);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isMemberAdmin)
                      PopupMenuItem(
                        value: 'make_admin',
                        child: Text(
                          'make_admin'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 13, color: _kInk,
                          ),
                        ),
                      ),
                    if (isMemberAdmin)
                      PopupMenuItem(
                        value: 'remove_admin',
                        child: Text(
                          'remove_admin'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 13, color: _kInk,
                          ),
                        ),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'Remove from group',
                        style: GoogleFonts.inter(
                          fontSize: 13, color: _kLoss,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
