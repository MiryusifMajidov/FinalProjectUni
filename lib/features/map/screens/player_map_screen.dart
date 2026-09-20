import 'dart:math';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../settings/screens/settings_screen.dart';

// ── Design tokens (map-specific dark palette) ─────────────────────────────────
const _kMapBg        = Color(0xFF0D1014);
const _kAmber        = Color(0xFFE8B960);
const _kAmberDeep    = Color(0xFFC49A45);
const _kAmberGlow    = Color(0x24E8B960);
const _kInk          = Color(0xFFF5F3EF);
const _kInkDim       = Color(0xFFB0A898);
const _kInkMute      = Color(0xFF706860);
const _kWin          = Color(0xFF5CB85C);
const _kCard         = Color(0xFF1A1A1E);

// Frosted glass backgrounds for overlay panels
const _kFrost        = Color(0xF00F1217); // ~94% opacity dark
const _kDock         = Color(0xF214181E); // ~95% opacity dock bg

// ── Filter model ─────────────────────────────────────────────────────────────

class _MapFilters {
  final RangeValues ratingRange;
  final bool onlineOnly;
  final double distanceKm;

  const _MapFilters({
    this.ratingRange = const RangeValues(800, 2400),
    this.onlineOnly  = false,
    this.distanceKm  = 10.0,
  });
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _mapUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.read(firestoreServiceProvider).watchMapUsers();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class PlayerMapScreen extends ConsumerStatefulWidget {
  const PlayerMapScreen({super.key});

  @override
  ConsumerState<PlayerMapScreen> createState() => _PlayerMapScreenState();
}

class _PlayerMapScreenState extends ConsumerState<PlayerMapScreen> {
  UserModel? _selectedUser;
  String _activeFilter = 'All';
  String _searchQuery = '';
  _MapFilters? _advancedFilters;
  late final TextEditingController _searchCtrl;

  final _mapController = MapController();
  bool _locating = false;
  double? _myLat;
  double? _myLng;

  static const _filters = ['All', 'Online', '1200–1600', 'Rapid'];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAndUpdateLocation());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Filter logic ──────────────────────────────────────────────────────────

  List<UserModel> _applyFilters(List<UserModel> all) {
    final now = DateTime.now();
    var result = List<UserModel>.from(all);

    // Quick chip filter
    switch (_activeFilter) {
      case 'Online':
        result = result.where((u) =>
          u.lastSeen != null &&
          now.difference(u.lastSeen!).inMinutes < 5).toList();
      case '1200–1600':
        result = result.where((u) =>
          u.overallRating >= 1200 && u.overallRating <= 1600).toList();
      case 'Rapid':
        result = result.where((u) =>
          u.rapidStats.rating >= u.blitzStats.rating &&
          u.rapidStats.rating >= u.bulletStats.rating).toList();
    }

    // Advanced filters (from sheet)
    if (_advancedFilters != null) {
      final f = _advancedFilters!;
      if (f.onlineOnly) {
        result = result.where((u) =>
          u.lastSeen != null &&
          now.difference(u.lastSeen!).inMinutes < 5).toList();
      }
      result = result.where((u) =>
        u.overallRating >= f.ratingRange.start.toInt() &&
        u.overallRating <= f.ratingRange.end.toInt()).toList();

      // Distance filter — only applied when we know the user's location
      if (_myLat != null && _myLng != null) {
        result = result.where((u) {
          if (u.latitude == null || u.longitude == null) return false;
          final distMeters = Geolocator.distanceBetween(
            _myLat!, _myLng!, u.latitude!, u.longitude!);
          return distMeters <= f.distanceKm * 1000;
        }).toList();
      }
    }

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((u) => u.username.toLowerCase().contains(q))
          .toList();
    }

    return result;
  }

  // ── Location helpers ──────────────────────────────────────────────────────

  Future<void> _requestAndUpdateLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationDialog('Location Services Off',
              'Please enable location services to show your position on the map.');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationDialog(
            'Location Permission Denied',
            'Location access was permanently denied. Open Settings to allow the app to use your location.',
            showSettings: true,
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Store locally for distance filter
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
      });

      final myUser = ref.read(currentUserProvider).valueOrNull;
      if (myUser != null) {
        if (myUser.showOnMap) {
          // User has already opted in — update location only, don't touch showOnMap
          await ref.read(firestoreServiceProvider).updateLocationOnly(
            myUser.uid, pos.latitude, pos.longitude,
          );
        }
        // If showOnMap=false, we still centre the map but don't expose the user
      }

      // Re-centre the visible map to the current position
      if (mounted) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
      }
    } catch (e) {
      debugPrint('[Map] location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update location. Check your connection and try again.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: _kCard,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationDialog(String title, String message, {bool showSettings = false}) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: Text(title, style: GoogleFonts.fraunces(color: _kInk)),
        content: Text(message, style: GoogleFonts.inter(color: _kInkDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(), style: GoogleFonts.inter(color: _kInkDim)),
          ),
          if (showSettings)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: Text('Open Settings', style: GoogleFonts.inter(color: _kAmber)),
            ),
        ],
      ),
    );
  }

  // ── Enable on map ─────────────────────────────────────────────────────────

  Future<void> _enableOnMap() async {
    final myUser = ref.read(currentUserProvider).valueOrNull;
    if (myUser == null) return;
    try {
      await ref.read(firestoreServiceProvider).updateMapSettings(
        myUser.uid,
        showOnMap: true,
      );
    } catch (e) {
      debugPrint('[Map] enableOnMap error: $e');
    }
    // Request OS permission and update location now that the user opted in
    await _requestAndUpdateLocation();
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  Future<void> _showFiltersSheet() async {
    final result = await showModalBottomSheet<_MapFilters>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FiltersSheet(initial: _advancedFilters),
    );
    if (result != null && mounted) {
      setState(() => _advancedFilters = result);
    }
  }

  void _showChallengeSheet(UserModel user) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ChallengeSheet(user: user),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mapUsersAsync = ref.watch(_mapUsersProvider);
    final myUser = ref.watch(currentUserProvider).valueOrNull;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kMapBg,
      body: Stack(
        children: [
          // ── Full-bleed map ──────────────────────────────────────────────
          mapUsersAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: _kAmber),
            ),
            error: (e, _) => Center(
              child: Text('Could not load map: $e',
                style: GoogleFonts.inter(color: Colors.redAccent)),
            ),
            data: (users) => _MapView(
              users: _applyFilters(users),
              myUid: myUser?.uid,
              selectedUser: _selectedUser,
              mapController: _mapController,
              onPinTap: (u) => setState(() =>
                  _selectedUser = _selectedUser?.uid == u.uid ? null : u),
            ),
          ),

          // ── Top overlay ─────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopOverlay(
              topPad: topPad,
              activeFilter: _activeFilter,
              filters: _filters,
              mapUsersAsync: mapUsersAsync,
              searchCtrl: _searchCtrl,
              hasAdvancedFilters: _advancedFilters != null,
              onBack: () => context.pop(),
              onFilterTap: (f) => setState(() => _activeFilter = f),
              onMoreFilters: _showFiltersSheet,
            ),
          ),

          // ── Right FABs ──────────────────────────────────────────────────
          Positioned(
            right: 14,
            top: topPad + 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapFab(
                  icon: PhosphorIcons.globe(PhosphorIconsStyle.regular),
                  onTap: () async {
                    final result =
                        await context.push<LatLng?>('/home/map/search');
                    if (result != null && mounted) {
                      _mapController.move(result, 13.0);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _MapFab(
                  icon: PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
                  color: _kAmber,
                  borderColor: _kAmber.withValues(alpha: 0.4),
                  loading: _locating,
                  onTap: _requestAndUpdateLocation,
                ),
              ],
            ),
          ),

          // ── Bottom dock / pin card ──────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: mapUsersAsync.maybeWhen(
              data: (users) {
                if (_selectedUser != null) {
                  return _PinCard(
                    user: _selectedUser!,
                    onDismiss: () => setState(() => _selectedUser = null),
                    onViewProfile: () {
                      final uid = _selectedUser!.uid;
                      setState(() => _selectedUser = null);
                      context.push('/home/profile/$uid');
                    },
                    onChallenge: () {
                      final user = _selectedUser!;
                      setState(() => _selectedUser = null);
                      _showChallengeSheet(user);
                    },
                  );
                }
                return _BottomDock(
                  users: _applyFilters(users),
                  myUid: myUser?.uid,
                  activeFilter: _activeFilter,
                  onTap: (u) => setState(() => _selectedUser = u),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // ── Not on map banner ───────────────────────────────────────────
          if (myUser != null && !myUser.showOnMap)
            Positioned(
              bottom: 132,
              left: 16,
              right: 16,
              child: _NotOnMapBanner(
                onEnable: _enableOnMap,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Top Overlay (header + search + chips) ─────────────────────────────────────

class _TopOverlay extends StatefulWidget {
  final double topPad;
  final String activeFilter;
  final List<String> filters;
  final AsyncValue<List<UserModel>> mapUsersAsync;
  final TextEditingController searchCtrl;
  final bool hasAdvancedFilters;
  final VoidCallback onBack;
  final void Function(String) onFilterTap;
  final VoidCallback onMoreFilters;

  const _TopOverlay({
    required this.topPad,
    required this.activeFilter,
    required this.filters,
    required this.mapUsersAsync,
    required this.searchCtrl,
    required this.hasAdvancedFilters,
    required this.onBack,
    required this.onFilterTap,
    required this.onMoreFilters,
  });

  @override
  State<_TopOverlay> createState() => _TopOverlayState();
}

class _TopOverlayState extends State<_TopOverlay> {
  final _focus = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _hasFocus = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: widget.topPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _kFrost,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x550D1014), blurRadius: 12),
                      ],
                    ),
                    child: const Icon(Icons.chevron_left_rounded, color: _kInk, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('player_map'.tr(),
                        style: GoogleFonts.fraunces(
                          fontSize: 18, fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: _kInk, letterSpacing: -0.3,
                        )),
                      Text('500M RADIUS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: _kInkMute, letterSpacing: 0.5,
                        )),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/home/settings/notifications'),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _kFrost,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Icon(
                      PhosphorIcons.bell(PhosphorIconsStyle.regular),
                      color: _kInkDim, size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Search bar – amber border + glow when focused
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _kFrost,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _hasFocus
                            ? _kAmber.withValues(alpha: 0.72)
                            : Colors.white.withValues(alpha: 0.14),
                        width: _hasFocus ? 1.5 : 1.0,
                      ),
                      boxShadow: _hasFocus
                          ? [
                              BoxShadow(
                                color: _kAmber.withValues(alpha: 0.09),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              const BoxShadow(
                                color: Color(0x440D1014),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                    ),
                    child: TextField(
                      controller: widget.searchCtrl,
                      focusNode: _focus,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _kInk,
                        fontWeight: FontWeight.w400,
                      ),
                      cursorColor: _kAmber,
                      cursorWidth: 1.5,
                      decoration: InputDecoration(
                        hintText: 'search_players'.tr(),
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: _kInkMute,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 10),
                          child: Icon(
                            PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular),
                            color: _hasFocus ? _kAmber.withValues(alpha: 0.8) : _kInkDim,
                            size: 15,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixIcon: widget.searchCtrl.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  widget.searchCtrl.clear();
                                  _focus.requestFocus();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(Icons.close_rounded,
                                      color: _kInkMute, size: 14),
                                ),
                              )
                            : widget.mapUsersAsync.maybeWhen(
                                data: (users) {
                                  final online = users
                                      .where((u) =>
                                          u.lastSeen != null &&
                                          DateTime.now()
                                                  .difference(u.lastSeen!)
                                                  .inMinutes <
                                              5)
                                      .length;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _kAmberGlow,
                                        borderRadius: BorderRadius.circular(100),
                                        border: Border.all(
                                            color: _kAmber.withValues(alpha: 0.35)),
                                      ),
                                      child: Text('$online ONLINE',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: _kAmber,
                                          letterSpacing: 0.3,
                                        )),
                                    ),
                                  );
                                },
                                orElse: () => const SizedBox.shrink(),
                              ),
                        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onMoreFilters,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: widget.hasAdvancedFilters ? _kAmberGlow : _kFrost,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.hasAdvancedFilters
                                ? _kAmber.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.14),
                          ),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x660D1014),
                                blurRadius: 18,
                                offset: Offset(0, 6)),
                          ],
                        ),
                        child: Icon(
                          PhosphorIcons.faders(PhosphorIconsStyle.regular),
                          color: widget.hasAdvancedFilters ? _kAmber : _kInkDim,
                          size: 17,
                        ),
                      ),
                      if (widget.hasAdvancedFilters)
                        Positioned(
                          top: -3, right: -3,
                          child: Container(
                            width: 10, height: 10,
                            decoration: const BoxDecoration(
                                color: _kAmber, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Filter chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.filters.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                if (i == widget.filters.length) {
                  return GestureDetector(
                    onTap: widget.onMoreFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kFrost,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold),
                              color: _kInkDim, size: 11),
                          const SizedBox(width: 4),
                          Text('filters'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kInkDim,
                            )),
                        ],
                      ),
                    ),
                  );
                }
                final label = widget.filters[i];
                final active = widget.activeFilter == label;
                return GestureDetector(
                  onTap: () => widget.onFilterTap(label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? _kAmber : _kFrost,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: active
                            ? _kAmber
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? const Color(0xFF1A1205)
                            : _kInkDim,
                      )),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Map View ──────────────────────────────────────────────────────────────────

class _MapView extends StatelessWidget {
  final List<UserModel> users;
  final String? myUid;
  final UserModel? selectedUser;
  final MapController mapController;
  final void Function(UserModel) onPinTap;

  const _MapView({
    required this.users,
    required this.myUid,
    required this.selectedUser,
    required this.mapController,
    required this.onPinTap,
  });

  @override
  Widget build(BuildContext context) {
    final me = users.where((u) => u.uid == myUid).firstOrNull;
    final center = me?.latitude != null
        ? LatLng(me!.latitude!, me.longitude!)
        : const LatLng(20.0, 0.0);

    final validUsers = users.where((u) => u.latitude != null && u.longitude != null).toList();

    // Cluster nearby pins
    final Map<String, List<UserModel>> clusters = {};
    for (final u in validUsers) {
      final key = '${(u.latitude! * 1000).round()}_${(u.longitude! * 1000).round()}';
      clusters.putIfAbsent(key, () => []).add(u);
    }

    final markers = <Marker>[];
    for (final group in clusters.values) {
      for (int i = 0; i < group.length; i++) {
        final u = group[i];
        double lat = u.latitude!;
        double lng = u.longitude!;

        if (group.length > 1) {
          final angle = (2 * pi * i) / group.length;
          const radius = 0.00045;
          lat += radius * cos(angle);
          lng += radius * sin(angle);
        }

        final isMe = u.uid == myUid;
        final isSelected = selectedUser?.uid == u.uid;
        final isOnline = u.lastSeen != null &&
            DateTime.now().difference(u.lastSeen!).inMinutes < 5;

        if (isMe) {
          markers.add(Marker(
            point: LatLng(lat, lng),
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: _MyPin(),
          ));
        } else {
          markers.add(Marker(
            point: LatLng(lat, lng),
            width: 96,
            height: 46,
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: selectedUser != null && !isSelected ? 0.35 : 1.0,
              child: GestureDetector(
                onTap: () => onPinTap(u),
                child: _PillPin(
                  user: u,
                  isOnline: isOnline,
                  isSelected: isSelected,
                ),
              ),
            ),
          ));
        }
      }
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: me != null ? 14.0 : 4.0,
        minZoom: 1.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // !! TILE BACKEND — MUST BE MIGRATED BEFORE OR SHORTLY AFTER LAUNCH !!
        //
        // tile.openstreetmap.org is run by the OpenStreetMap Foundation on
        // donated capacity. Its Tile Usage Policy
        // (https://operations.osmfoundation.org/policies/tiles/) PROHIBITS
        // heavy use, and names distributing an app that draws its tiles from
        // openstreetmap.org as exactly that — these servers may not be the
        // tile backend of a mobile app. Traffic from a shipped app can be
        // throttled or blocked without warning, which breaks this screen for
        // every user at once.
        //
        // Migrate to a keyed provider — MapTiler, Stadia Maps or
        // Thunderforest — and update _MapAttribution below to whatever
        // credit that provider requires (OpenStreetMap data credit is still
        // required on top of the provider's own). Left unchanged here on
        // purpose: switching needs an API key that a human must obtain and
        // store outside the repo.
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.chessapp.chessApp',
        ),
        MarkerLayer(markers: markers),
        const _MapAttribution(),
      ],
    );
  }
}

// ── OpenStreetMap attribution ─────────────────────────────────────────────────

/// Required credit for OpenStreetMap data. It has to stay visible on the map
/// itself, so it sits just above the bottom dock rather than behind it, and
/// carries its own dark chip so it stays readable over pale and dark tiles
/// alike.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: IgnorePointer(
        child: Padding(
          // 168 clears the collapsed bottom dock (148 tall + 14 margin).
          padding: const EdgeInsets.only(right: 10, bottom: 168),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xCC0D1014),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text('© OpenStreetMap contributors',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: _kInkDim,
                letterSpacing: 0.2,
              )),
          ),
        ),
      ),
    );
  }
}

// ── Pill Pin ──────────────────────────────────────────────────────────────────

class _PillPin extends StatelessWidget {
  final UserModel user;
  final bool isOnline;
  final bool isSelected;

  const _PillPin({
    required this.user,
    required this.isOnline,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? _kAmber : const Color(0xFF0F1217);
    final border = isSelected ? _kAmber : Colors.white.withValues(alpha: 0.12);
    final textColor = isSelected ? const Color(0xFF1A1205) : _kInk;
    final initial = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : '?';
    final elo = user.overallRating;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: border, width: 1.5),
            boxShadow: isSelected
                ? [
                    BoxShadow(color: _kAmberGlow, blurRadius: 12, spreadRadius: 2),
                    const BoxShadow(color: Color(0x880D1014), blurRadius: 8, offset: Offset(0, 4)),
                  ]
                : [
                    const BoxShadow(color: Color(0x880D1014), blurRadius: 8, offset: Offset(0, 4)),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar circle
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kAmber, _kAmberDeep],
                        ),
                  color: isSelected ? const Color(0xFF1A1205) : null,
                ),
                alignment: Alignment.center,
                child: Text(initial,
                  style: GoogleFonts.fraunces(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _kAmber : const Color(0xFF1A1205),
                  )),
              ),
              const SizedBox(width: 5),
              // ELO
              Text('$elo',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: textColor, letterSpacing: 0.3,
                )),
              // Online dot
              if (isOnline && !isSelected) ...[
                const SizedBox(width: 5),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kWin,
                    boxShadow: [BoxShadow(color: _kWin.withValues(alpha: 0.5), blurRadius: 4)],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Tail triangle
        SizedBox(
          width: 10, height: 6,
          child: CustomPaint(painter: _TrianglePainter(color: isSelected ? _kAmber : const Color(0xFF0F1217))),
        ),
      ],
    );
  }
}

// ── My Pin (amber dot with pulse) ─────────────────────────────────────────────

class _MyPin extends StatelessWidget {
  const _MyPin();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing outer ring
        Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [_kAmberGlow, Colors.transparent],
              stops: [0.4, 1.0],
            ),
          ),
        )
            .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
            .scaleXY(begin: 0.8, end: 1.4, duration: 1400.ms, curve: Curves.easeInOut)
            .fade(begin: 0.9, end: 0.2, duration: 1400.ms),
        // Core dot
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kAmber,
            border: Border.all(color: const Color(0xFF0A0908), width: 3),
            boxShadow: [
              BoxShadow(color: _kAmberGlow, blurRadius: 10, spreadRadius: 2),
              const BoxShadow(color: Color(0x660D1014), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Triangle tail painter ─────────────────────────────────────────────────────

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Map FAB ───────────────────────────────────────────────────────────────────

class _MapFab extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;
  final bool loading;

  const _MapFab({
    required this.icon,
    this.color = _kInkDim,
    this.borderColor = const Color(0x14FFFFFF),
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _kFrost,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: loading ? color.withValues(alpha: 0.5) : borderColor,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x660D1014), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: loading
            ? Padding(
                padding: const EdgeInsets.all(13),
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: color,
                ),
              )
            : Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Bottom Dock ───────────────────────────────────────────────────────────────

class _BottomDock extends StatefulWidget {
  final List<UserModel> users;
  final String? myUid;
  final String activeFilter;
  final void Function(UserModel) onTap;

  const _BottomDock({
    required this.users,
    required this.myUid,
    required this.activeFilter,
    required this.onTap,
  });

  @override
  State<_BottomDock> createState() => _BottomDockState();
}

class _BottomDockState extends State<_BottomDock> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final screenH    = MediaQuery.of(context).size.height;
    final bottomPad  = MediaQuery.of(context).padding.bottom;

    final nearby = widget.users
        .where((u) => u.uid != widget.myUid && u.latitude != null)
        .toList();

    // collapsed: just the handle + title + horizontal strip
    // expanded : ~half the screen
    const collapsedH = 148.0;
    final expandedH  = screenH * 0.50 - bottomPad;
    final cardH      = _expanded ? expandedH : collapsedH;

    // height of the handle+title area (constant in both states)
    const topAreaH = 74.0; // 10 + 4 + 10 + ~20 + 10 + 10 + 10

    return GestureDetector(
      // swipe up → expand, swipe down → collapse
      onVerticalDragEnd: (d) {
        final vel = d.primaryVelocity ?? 0;
        if (vel < -250 && !_expanded) _toggle();
        if (vel >  250 && _expanded)  _toggle();
      },
      child: Container(
        // gradient fade behind the card
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xF50D1014)],
            stops: [0.0, 0.35],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(0, 60, 0, 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          height: cardH,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: _kDock,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x800D1014),
                blurRadius: 30,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle + title row ────────────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Column(
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Title + action label
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            nearby.isEmpty
                                ? 'No players match filter'
                                : '${nearby.length} ${widget.activeFilter == 'All' ? 'nearby' : '· ${widget.activeFilter}'}',
                            style: GoogleFonts.fraunces(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic, color: _kInk,
                            )),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              _expanded ? 'Collapse ↓' : 'List view ↑',
                              key: ValueKey(_expanded),
                              style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: _kAmber,
                              )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Content ───────────────────────────────────────────
              if (nearby.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Text('no_players_nearby'.tr(),
                    style: GoogleFonts.inter(fontSize: 12, color: _kInkMute)),
                )
              else if (_expanded)
                // Expanded: vertical scrollable list
                SizedBox(
                  height: expandedH - topAreaH,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: nearby.length,
                    itemBuilder: (_, i) {
                      final u = nearby[i];
                      final isOnline = u.lastSeen != null &&
                          DateTime.now().difference(u.lastSeen!).inMinutes < 5;
                      return _DockPlayerRow(
                        user: u,
                        isOnline: isOnline,
                        onTap: () => widget.onTap(u),
                      );
                    },
                  ),
                )
              else
                // Collapsed: horizontal compact cards
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: nearby.length.clamp(0, 8),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final u = nearby[i];
                      final isOnline = u.lastSeen != null &&
                          DateTime.now().difference(u.lastSeen!).inMinutes < 5;
                      return GestureDetector(
                        onTap: () => widget.onTap(u),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [_kAmber, _kAmberDeep],
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  u.username.isNotEmpty
                                      ? u.username[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.fraunces(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A1205),
                                  )),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(u.username,
                                    style: GoogleFonts.inter(
                                      fontSize: 11, fontWeight: FontWeight.w600,
                                      color: _kInk)),
                                  Row(
                                    children: [
                                      Text('${u.overallRating}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9, fontWeight: FontWeight.w700,
                                          color: _kInkMute)),
                                      if (isOnline) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 5, height: 5,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle, color: _kWin),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Expanded-dock detail row ───────────────────────────────────────────────────

class _DockPlayerRow extends StatelessWidget {
  final UserModel user;
  final bool isOnline;
  final VoidCallback onTap;

  const _DockPlayerRow({
    required this.user,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        user.username.isNotEmpty ? user.username[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // Avatar with online dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kAmber, _kAmberDeep],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(initial,
                    style: GoogleFonts.fraunces(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1205),
                    )),
                ),
                if (isOnline)
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kWin,
                        border: Border.all(color: _kDock, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Name + rating + skill level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('${user.overallRating}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: _kAmber)),
                      if (user.skillLevel != null &&
                          user.skillLevel!.isNotEmpty) ...[
                        const Text('  ·  ',
                          style: TextStyle(color: _kInkMute, fontSize: 10)),
                        Text(user.skillLevel!,
                          style: GoogleFonts.inter(
                            fontSize: 10, color: _kInkDim)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
              color: _kInkMute, size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pin Card (selected player) ────────────────────────────────────────────────

class _PinCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onDismiss;
  final VoidCallback onViewProfile;
  final VoidCallback onChallenge;

  const _PinCard({
    required this.user,
    required this.onDismiss,
    required this.onViewProfile,
    required this.onChallenge,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = user.lastSeen != null &&
        DateTime.now().difference(user.lastSeen!).inMinutes < 5;
    final initial = user.username.isNotEmpty ? user.username[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kDock,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(color: Color(0x800D1014), blurRadius: 30, offset: Offset(0, -10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player row
          Row(
            children: [
              // Avatar
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kAmber, _kAmberDeep],
                  ),
                ),
                alignment: Alignment.center,
                child: user.photoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: user.photoUrl!,
                          width: 48, height: 48, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Text(initial,
                            style: GoogleFonts.fraunces(
                              fontSize: 22, fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1205))),
                        ),
                      )
                    : Text(initial,
                        style: GoogleFonts.fraunces(
                          fontSize: 22, fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1205))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username,
                      style: GoogleFonts.fraunces(
                        fontSize: 17, fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: _kInk, letterSpacing: -0.3,
                      )),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text('${user.overallRating} ELO',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _kAmber, letterSpacing: 0.3,
                          )),
                        const Text(' · ', style: TextStyle(color: _kInkMute, fontSize: 10)),
                        Text(user.skillLevel ?? 'Player',
                          style: GoogleFonts.inter(fontSize: 11, color: _kInkDim)),
                        if (isOnline) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, color: _kWin,
                              boxShadow: [
                                BoxShadow(color: _kWin.withValues(alpha: 0.5), blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Dismiss button
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.close_rounded, color: _kInkDim, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onViewProfile,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    alignment: Alignment.center,
                    child: Text('view_profile'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _kInk)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onChallenge,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kAmber,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: _kAmberGlow, blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text('⚔ ${'challenge'.tr()}',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1205))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Challenge Sheet ───────────────────────────────────────────────────────────

class _ChallengeSheet extends StatefulWidget {
  final UserModel user;
  const _ChallengeSheet({required this.user});

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  int _selectedTime = 3; // index into _timeOptions
  int _selectedSide = 1; // 0=White, 1=Random, 2=Black
  bool _rated = true;

  static const _timeOptions = [
    (label: '1+0',  sub: 'Bullet'),
    (label: '3+0',  sub: 'Blitz'),
    (label: '5+0',  sub: 'Blitz'),
    (label: '10+0', sub: 'Rapid'),
    (label: '15+10',sub: 'Rapid'),
    (label: 'Custom',sub: 'Set'),
  ];

  static const _sides = [
    (glyph: '♔', label: 'White'),
    (glyph: '⚂', label: 'Random'),
    (glyph: '♚', label: 'Black'),
  ];

  @override
  Widget build(BuildContext context) {
    final initial = widget.user.username.isNotEmpty
        ? widget.user.username[0].toUpperCase()
        : '?';
    final selectedTimeLabel = _timeOptions[_selectedTime].label;
    final selectedTimeSub   = _timeOptions[_selectedTime].sub;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF3D3530)),
          left: BorderSide(color: Color(0xFF2A2520)),
          right: BorderSide(color: Color(0xFF2A2520)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        22, 10, 22,
        22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3D3530),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Target player
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kAmber, _kAmberDeep],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(initial,
                  style: GoogleFonts.fraunces(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1205))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CHALLENGING',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: _kInkMute, letterSpacing: 0.6)),
                    Text('${widget.user.username} · ${widget.user.overallRating}',
                      style: GoogleFonts.fraunces(
                        fontSize: 17, fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic, color: _kInk)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(PhosphorIcons.x(PhosphorIconsStyle.regular),
                    color: _kInkDim, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time control
          Align(
            alignment: Alignment.centerLeft,
            child: Text('TIME CONTROL',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _kInkMute, letterSpacing: 0.6)),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.0,
            children: List.generate(_timeOptions.length, (i) {
              final t = _timeOptions[i];
              final sel = _selectedTime == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedTime = i),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sel ? _kAmberGlow : const Color(0xFF1A1A1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? _kAmber : const Color(0xFF2A2520),
                      width: 1.5,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: _kAmberGlow, blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _kInk, letterSpacing: 0.2)),
                      Text(t.sub,
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: sel ? _kAmber : _kInkMute)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Side selection
          Align(
            alignment: Alignment.centerLeft,
            child: Text('YOU PLAY AS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _kInkMute, letterSpacing: 0.6)),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_sides.length, (i) {
              final s = _sides[i];
              final sel = _selectedSide == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSide = i),
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? _kAmberGlow : const Color(0xFF1A1A1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? _kAmber : const Color(0xFF2A2520),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(s.glyph,
                          style: GoogleFonts.fraunces(fontSize: 20, color: sel ? _kAmber : _kInkDim)),
                        const SizedBox(height: 4),
                        Text(s.label,
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: sel ? _kInk : _kInkDim)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Rated toggle row
          GestureDetector(
            onTap: () => setState(() => _rated = !_rated),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2520)),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.trophy(PhosphorIconsStyle.regular),
                      color: _kAmber, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('rated_game'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
                        Text('Affects both players\' ELO',
                          style: GoogleFonts.inter(fontSize: 11, color: _kInkMute)),
                      ],
                    ),
                  ),
                  _Toggle(on: _rated, onToggle: () => setState(() => _rated = !_rated)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Send CTA
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Challenge sent to ${widget.user.username} · $selectedTimeLabel $selectedTimeSub',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  backgroundColor: const Color(0xFF1A1A1E),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: _kAmber,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _kAmber.withValues(alpha: 0.3),
                    blurRadius: 16, offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text('⚔  Send challenge · $selectedTimeLabel $selectedTimeSub',
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1205))),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filters Sheet ─────────────────────────────────────────────────────────────

class _FiltersSheet extends StatefulWidget {
  final _MapFilters? initial;
  const _FiltersSheet({this.initial});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late RangeValues _ratingRange;
  late bool _onlineOnly;
  late double _distanceKm;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _ratingRange = f?.ratingRange ?? const RangeValues(800, 2400);
    _onlineOnly  = f?.onlineOnly  ?? false;
    _distanceKm  = f?.distanceKm  ?? 10.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF3D3530)),
          left: BorderSide(color: Color(0xFF2A2520)),
          right: BorderSide(color: Color(0xFF2A2520)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3D3530), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Text('filters'.tr(),
                style: GoogleFonts.fraunces(
                  fontSize: 20, fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic, color: _kInk)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _ratingRange = const RangeValues(800, 2400);
                  _onlineOnly  = false;
                  _distanceKm  = 10.0;
                }),
                child: Text('Reset',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _kAmber)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rating range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RATING RANGE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _kInkMute, letterSpacing: 0.6)),
              Text(
                '${_ratingRange.start.round()} – ${_ratingRange.end.round()}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _kAmber)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kAmber,
              inactiveTrackColor: const Color(0xFF2A2520),
              thumbColor: _kAmber,
              overlayColor: _kAmberGlow,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: RangeSlider(
              values: _ratingRange,
              min: 400,
              max: 3000,
              divisions: 52,
              onChanged: (v) => setState(() => _ratingRange = v),
            ),
          ),
          const SizedBox(height: 12),

          // Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MAX DISTANCE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _kInkMute, letterSpacing: 0.6)),
              Text('${_distanceKm.round()} km',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _kAmber)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kAmber,
              inactiveTrackColor: const Color(0xFF2A2520),
              thumbColor: _kAmber,
              overlayColor: _kAmberGlow,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _distanceKm,
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (v) => setState(() => _distanceKm = v),
            ),
          ),
          const SizedBox(height: 12),

          // Online only
          GestureDetector(
            onTap: () => setState(() => _onlineOnly = !_onlineOnly),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2520)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _kWin),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Online players only',
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
                  ),
                  _Toggle(on: _onlineOnly, onToggle: () => setState(() => _onlineOnly = !_onlineOnly)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Apply / Clear buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, null),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A2520)),
                    ),
                    alignment: Alignment.center,
                    child: Text('Clear',
                      style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: const Color(0xFFB0A898))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => Navigator.pop(
                    context,
                    _MapFilters(
                      ratingRange: _ratingRange,
                      onlineOnly:  _onlineOnly,
                      distanceKm:  _distanceKm,
                    ),
                  ),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: _kAmber,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _kAmber.withValues(alpha: 0.28),
                          blurRadius: 14, offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text('Apply filters',
                      style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1205))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Compact toggle ────────────────────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final bool on;
  final VoidCallback onToggle;

  const _Toggle({required this.on, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40, height: 24,
        decoration: BoxDecoration(
          color: on ? _kAmber : const Color(0xFF131316),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? _kAmber : const Color(0xFF3D3530)),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: on ? const Color(0xFF1A1205) : _kInk,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Not on Map Banner ─────────────────────────────────────────────────────────

class _NotOnMapBanner extends StatelessWidget {
  final VoidCallback onEnable;
  const _NotOnMapBanner({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kDock,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: Color(0x660D1014), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("You're not on the map",
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
                const SizedBox(height: 2),
                Text('appear_on_map_subtitle'.tr(),
                  style: GoogleFonts.inter(fontSize: 11, color: _kInkMute)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEnable,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kAmberGlow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kAmber.withValues(alpha: 0.4)),
              ),
              child: Text('Enable',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _kAmber)),
            ),
          ),
        ],
      ),
    );
  }
}
