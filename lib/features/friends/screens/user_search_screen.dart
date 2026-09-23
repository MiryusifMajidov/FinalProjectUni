import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/friends_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/user_avatar.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg      = AppColors.background;
const _kCard    = AppColors.card;
const _kSurface = AppColors.surface;
const _kAmber   = AppColors.amber;
const _kAmberDeep = AppColors.amberDeep;
const _kAmberGlow = AppColors.amberGlow;
const _kInk     = AppColors.ink;
const _kInkDim  = AppColors.inkDim;
const _kInkMute = AppColors.inkMute;
const _kBorder  = AppColors.border;
const _kWin     = AppColors.win;
const _kWinSoft = AppColors.winSoft;

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _ctrl = TextEditingController();
  UserModel? _result;
  bool _loading = false;
  String? _error;
  String? _successMsg;
  bool? _areFriends;
  final _recentSearches = <UserModel>[];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final username = _ctrl.text.trim();
    if (username.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _successMsg = null;
      _areFriends = null;
    });
    try {
      final user = await ref.read(firestoreServiceProvider).getUserByUsername(username);
      if (user == null) {
        setState(() { _error = 'No player found with that username.'; _loading = false; });
        return;
      }
      final myUser = ref.read(currentUserProvider).valueOrNull;
      final myUid = myUser?.uid;
      if (user.uid == myUid) {
        setState(() { _error = "That's your own account!"; _loading = false; });
        return;
      }
      // Respect friendRequestPrivacy == 'nobody' — user is invisible in search
      if (user.friendRequestPrivacy == 'nobody') {
        setState(() { _error = 'No player found with that username.'; _loading = false; });
        return;
      }
      // Block check — hide blocked/blocking users from search results
      if (myUser != null) {
        final iBlockedThem = myUser.blockedUsers.contains(user.uid);
        final theyBlockedMe = user.blockedUsers.contains(myUid ?? '');
        if (iBlockedThem || theyBlockedMe) {
          setState(() { _error = 'No player found with that username.'; _loading = false; });
          return;
        }
      }
      final isFriend = myUid != null &&
          await ref.read(friendsServiceProvider).areFriends(myUid, user.uid);
      // Track recent searches (keep unique, max 5)
      _recentSearches
        ..removeWhere((u) => u.uid == user.uid)
        ..insert(0, user);
      if (_recentSearches.length > 5) _recentSearches.removeLast();
      setState(() { _result = user; _areFriends = isFriend; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Search failed. Please try again.'; _loading = false; });
    }
  }

  Future<void> _sendRequest() async {
    final myUser = ref.read(currentUserProvider).valueOrNull;
    if (myUser == null || _result == null) return;
    setState(() { _loading = true; _error = null; _successMsg = null; });
    try {
      await ref.read(friendsServiceProvider).sendRequest(
        fromUid: myUser.uid,
        fromUsername: myUser.username,
        toUid: _result!.uid,
      );
      setState(() {
        _successMsg = 'Friend request sent!';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
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
            // ── Header ──────────────────────────────────────────────────────
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
                    'add_friend'.tr(),
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

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Search field ──
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular),
                            color: _kInkMute, size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              style: GoogleFonts.inter(fontSize: 14, color: _kInk),
                              decoration: InputDecoration(
                                hintText: 'search_players'.tr(),
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 14, color: _kInkMute,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _search(),
                              textInputAction: TextInputAction.search,
                            ),
                          ),
                          if (_ctrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                setState(() {
                                  _result = null;
                                  _error = null;
                                  _successMsg = null;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(
                                  PhosphorIcons.x(PhosphorIconsStyle.regular),
                                  color: _kInkMute, size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Search button ──
                    GestureDetector(
                      onTap: _loading ? null : _search,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 50,
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
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: _kAmber,
                                  ),
                                )
                              : Text(
                                  'Search',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A1205),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // ── Error ──
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lossSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.loss.withOpacity(0.3)),
                        ),
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.loss),
                        ),
                      ),
                    ],

                    // ── Success ──
                    if (_successMsg != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kWinSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kWin.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                              color: _kWin, size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _successMsg!,
                              style: GoogleFonts.inter(fontSize: 13, color: _kWin),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Recently searched ──
                    if (_result == null && _recentSearches.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'RECENTLY SEARCHED',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kInkMute,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._recentSearches.map((u) => GestureDetector(
                        onTap: () {
                          _ctrl.text = u.username;
                          _search();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.clockCounterClockwise(
                                    PhosphorIconsStyle.regular),
                                size: 14,
                                color: _kInkMute,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  u.username,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _kInkDim,
                                  ),
                                ),
                              ),
                              Text(
                                '${u.overallRating}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: _kInkMute,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                    ],

                    // ── Result card ──
                    if (_result != null) ...[
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => context.push('/home/profile/${_result!.uid}'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                username: _result!.username,
                                photoUrl: _result!.photoUrl,
                                size: 56,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _result!.username,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _kInk,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_result!.overallRating} ELO'
                                      '${_result!.skillLevel != null ? ' · ${_result!.skillLevel}' : ''}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: _kInkMute,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_areFriends == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _kWinSoft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Friends',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _kWin,
                                    ),
                                  ),
                                )
                              else if (_successMsg == null)
                                GestureDetector(
                                  onTap: _loading ? null : _sendRequest,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [_kAmber, _kAmberDeep],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIcons.userPlus(PhosphorIconsStyle.regular),
                                          size: 14,
                                          color: const Color(0xFF1A1205),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'add'.tr(),
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1A1205),
                                          ),
                                        ),
                                      ],
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}
