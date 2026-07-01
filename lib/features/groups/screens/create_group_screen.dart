import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/group_service.dart';
import '../../../core/models/group_model.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg           = AppColors.background;
const _kSurface      = AppColors.surface;
const _kCard         = AppColors.card;
const _kAmber        = AppColors.amber;
const _kAmberDeep    = AppColors.amberDeep;
const _kAmberGlow    = AppColors.amberGlow;
const _kInk          = AppColors.ink;
const _kInkDim       = AppColors.inkDim;
const _kInkMute      = AppColors.inkMute;
const _kBorder       = AppColors.border;
const _kBorderStrong = AppColors.borderStrong;

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  XFile? _pickedImage;
  bool _uploadingPhoto = false;
  GroupPrivacy _privacy = GroupPrivacy.public;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a group name.');
      return;
    }
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groupId = await ref.read(groupServiceProvider).createGroup(
            name: _nameCtrl.text.trim(),
            description:
                _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            privacy: _privacy,
            adminId: me.uid,
            adminUsername: me.username,
          );

      if (_pickedImage != null) {
        setState(() => _uploadingPhoto = true);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('group_photos/$groupId.jpg');
        await storageRef.putFile(File(_pickedImage!.path));
        final url = await storageRef.getDownloadURL();
        await ref.read(groupServiceProvider).updateGroupPhoto(groupId, url);
        setState(() => _uploadingPhoto = false);
      }

      if (mounted) context.replace('/home/groups/$groupId');
    } catch (e) {
      setState(() {
        _error = 'Failed to create group. Try again.';
        _loading = false;
        _uploadingPhoto = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──
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
                    'create_group'.tr(),
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

            // ── Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Dashed avatar picker ──
                    Center(
                      child: GestureDetector(
                        onTap: _pickedImage == null ? _pickImage : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _pickedImage != null
                                    ? Colors.transparent
                                    : _kAmberGlow,
                                border: _pickedImage == null
                                    ? Border.all(
                                        color: _kAmber.withOpacity(0.5),
                                        width: 2,
                                        strokeAlign: BorderSide.strokeAlignInside,
                                      )
                                    : null,
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: _pickedImage != null
                                  ? Image.file(
                                      File(_pickedImage!.path),
                                      fit: BoxFit.cover,
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          PhosphorIcons.camera(PhosphorIconsStyle.regular),
                                          color: _kAmber,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Photo',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _kAmber,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            if (_pickedImage != null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _kAmber,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: _kBg, width: 2),
                                    ),
                                    child: Icon(
                                      PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold),
                                      size: 12,
                                      color: const Color(0xFF1A1205),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Name field ──
                    _Label('group_name'.tr()),
                    const SizedBox(height: 8),
                    _DesignField(
                      controller: _nameCtrl,
                      hint: 'e.g. Chess Enthusiasts',
                      icon: PhosphorIcons.usersThree(PhosphorIconsStyle.regular),
                    ),

                    const SizedBox(height: 16),

                    // ── Description field ──
                    _Label('Description (optional)'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: TextField(
                        controller: _descCtrl,
                        maxLines: 3,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _kInk,
                        ),
                        decoration: InputDecoration(
                          hintText: 'What is this group about?',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: _kInkMute,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Privacy selector ──
                    _Label('Privacy'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PrivacyCard(
                            icon: PhosphorIcons.globe(PhosphorIconsStyle.regular),
                            label: 'Public',
                            desc: 'Anyone can join',
                            selected: _privacy == GroupPrivacy.public,
                            onTap: () => setState(() => _privacy = GroupPrivacy.public),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrivacyCard(
                            icon: PhosphorIcons.lock(PhosphorIconsStyle.regular),
                            label: 'Private',
                            desc: 'Invite only',
                            selected: _privacy == GroupPrivacy.private,
                            onTap: () => setState(() => _privacy = GroupPrivacy.private),
                          ),
                        ),
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.lossSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.loss.withOpacity(0.3)),
                        ),
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.loss,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── CTA ──
                    GestureDetector(
                      onTap: _loading ? null : _create,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: _loading
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_kAmber, _kAmberDeep],
                                ),
                          color: _loading ? _kCard : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _loading
                              ? null
                              : [
                                  BoxShadow(
                                    color: _kAmber.withOpacity(0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: _kAmber,
                                  ),
                                )
                              : Text(
                                  'create_group'.tr(),
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A1205),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Label ──────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

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

// ── Design Field ───────────────────────────────────────────────────────────────

class _DesignField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _DesignField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, color: _kInkMute, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(fontSize: 14, color: _kInk),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(fontSize: 14, color: _kInkMute),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Privacy Card ───────────────────────────────────────────────────────────────

class _PrivacyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  const _PrivacyCard({
    required this.icon,
    required this.label,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _kAmberGlow : _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kAmber : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? _kAmber.withOpacity(0.2)
                    : _kSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? _kAmber : _kInkMute,
                size: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? _kAmber : _kInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: selected ? _kAmber.withOpacity(0.7) : _kInkMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
