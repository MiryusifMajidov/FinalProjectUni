import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF0A0A0B);
const _kSurface   = Color(0xFF131316);
const _kCard      = Color(0xFF1A1A1E);
const _kAmber     = Color(0xFFE8B960);
const _kAmberDeep = Color(0xFFC49A45);
const _kAmberGlow = Color(0x24E8B960);
const _kInk       = Color(0xFFF5F3EF);
const _kInkDim    = Color(0xFFB0A898);
const _kInkMute   = Color(0xFF706860);
const _kInkFaint  = Color(0xFF3D3530);
const _kBorder    = Color(0xFF2A2520);
const _kWin       = Color(0xFF5AB67A);

// ── City dataset ──────────────────────────────────────────────────────────────

class _City {
  final String name;
  final String country;
  final String countryCode;
  final double lat;
  final double lng;
  const _City(this.name, this.country, this.countryCode, this.lat, this.lng);
}

const _kCities = [
  _City('Baku',          'Azerbaijan',     'AZ',  40.4093,   49.8671),
  _City('Ganja',         'Azerbaijan',     'AZ',  40.6820,   46.3606),
  _City('Sumqayit',      'Azerbaijan',     'AZ',  40.5897,   49.6686),
  _City('Tbilisi',       'Georgia',        'GE',  41.6938,   44.8015),
  _City('Batumi',        'Georgia',        'GE',  41.6416,   41.6419),
  _City('Yerevan',       'Armenia',        'AM',  40.1872,   44.5152),
  _City('Istanbul',      'Turkey',         'TR',  41.0082,   28.9784),
  _City('Ankara',        'Turkey',         'TR',  39.9334,   32.8597),
  _City('Izmir',         'Turkey',         'TR',  38.4192,   27.1287),
  _City('Moscow',        'Russia',         'RU',  55.7558,   37.6173),
  _City('Saint Petersburg', 'Russia',      'RU',  59.9311,   30.3609),
  _City('London',        'United Kingdom', 'GB',  51.5074,   -0.1278),
  _City('Paris',         'France',         'FR',  48.8566,    2.3522),
  _City('Berlin',        'Germany',        'DE',  52.5200,   13.4050),
  _City('Madrid',        'Spain',          'ES',  40.4168,   -3.7038),
  _City('Rome',          'Italy',          'IT',  41.9028,   12.4964),
  _City('Warsaw',        'Poland',         'PL',  52.2297,   21.0122),
  _City('Kyiv',          'Ukraine',        'UA',  50.4501,   30.5234),
  _City('Dubai',         'UAE',            'AE',  25.2048,   55.2708),
  _City('Abu Dhabi',     'UAE',            'AE',  24.4539,   54.3773),
  _City('Tehran',        'Iran',           'IR',  35.6892,   51.3890),
  _City('Riyadh',        'Saudi Arabia',   'SA',  24.7136,   46.6753),
  _City('Almaty',        'Kazakhstan',     'KZ',  43.2220,   76.8512),
  _City('Astana',        'Kazakhstan',     'KZ',  51.1694,   71.4491),
  _City('Tashkent',      'Uzbekistan',     'UZ',  41.2995,   69.2401),
  _City('New York',      'United States',  'US',  40.7128,  -74.0060),
  _City('Los Angeles',   'United States',  'US',  34.0522, -118.2437),
  _City('Chicago',       'United States',  'US',  41.8781,  -87.6298),
  _City('Mumbai',        'India',          'IN',  19.0760,   72.8777),
  _City('Delhi',         'India',          'IN',  28.6139,   77.2090),
  _City('Beijing',       'China',          'CN',  39.9042,  116.4074),
  _City('Shanghai',      'China',          'CN',  31.2304,  121.4737),
  _City('Tokyo',         'Japan',          'JP',  35.6762,  139.6503),
  _City('Seoul',         'South Korea',    'KR',  37.5665,  126.9780),
  _City('Sydney',        'Australia',      'AU', -33.8688,  151.2093),
  _City('São Paulo',     'Brazil',         'BR', -23.5505,  -46.6333),
  _City('Buenos Aires',  'Argentina',      'AR', -34.6037,  -58.3816),
  _City('Cairo',         'Egypt',          'EG',  30.0444,   31.2357),
  _City('Lagos',         'Nigeria',        'NG',   6.5244,    3.3792),
  _City('Nairobi',       'Kenya',          'KE',  -1.2921,   36.8219),
  _City('Amsterdam',     'Netherlands',    'NL',  52.3676,    4.9041),
  _City('Brussels',      'Belgium',        'BE',  50.8503,    4.3517),
  _City('Vienna',        'Austria',        'AT',  48.2082,   16.3738),
  _City('Stockholm',     'Sweden',         'SE',  59.3293,   18.0686),
  _City('Oslo',          'Norway',         'NO',  59.9139,   10.7522),
  _City('Helsinki',      'Finland',        'FI',  60.1699,   24.9384),
  _City('Prague',        'Czech Republic', 'CZ',  50.0755,   14.4378),
  _City('Budapest',      'Hungary',        'HU',  47.4979,   19.0402),
  _City('Bucharest',     'Romania',        'RO',  44.4268,   26.1025),
  _City('Athens',        'Greece',         'GR',  37.9838,   23.7275),
];

List<_City> _matchCities(String q) {
  final lower = q.toLowerCase().trim();
  if (lower.length < 2) return [];
  return _kCities.where((c) =>
    c.name.toLowerCase().startsWith(lower) ||
    c.country.toLowerCase().startsWith(lower) ||
    c.countryCode.toLowerCase() == lower,
  ).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MapSearchScreen extends ConsumerStatefulWidget {
  const MapSearchScreen({super.key});

  @override
  ConsumerState<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends ConsumerState<MapSearchScreen> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  int  _activeTab = 0; // 0=Players, 1=Cities, 2=Groups
  bool _hasFocus  = false;

  // Players tab
  List<UserModel> _playerResults = [];
  bool   _playerLoading = false;
  String _lastQuery     = '';

  // Cities tab
  List<_City> _cityMatches = [];

  // Recent searches (persisted via CacheService)
  List<String> _recent = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _hasFocus = _focus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _loadRecents();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Recents ───────────────────────────────────────────────────────────────

  void _loadRecents() {
    final cache = ref.read(cacheServiceProvider);
    if (mounted) setState(() => _recent = List.from(cache.mapRecentSearches));
  }

  void _addRecent(String q) {
    final trimmed = q.trim();
    if (trimmed.length < 2) return;
    final cache   = ref.read(cacheServiceProvider);
    final updated = [
      trimmed,
      ..._recent.where((r) => r.toLowerCase() != trimmed.toLowerCase()),
    ].take(6).toList();
    cache.setMapRecentSearches(updated);
    if (mounted) setState(() => _recent = updated);
  }

  void _removeRecent(int i) {
    final cache   = ref.read(cacheServiceProvider);
    final updated = List<String>.from(_recent)..removeAt(i);
    cache.setMapRecentSearches(updated);
    if (mounted) setState(() => _recent = updated);
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onQueryChanged(String raw) {
    setState(() {});
    _debounce?.cancel();
    final q = raw.trim();

    // Always update city matches immediately
    setState(() => _cityMatches = _matchCities(q));

    if (q.length < 2) {
      setState(() {
        _playerResults  = [];
        _playerLoading  = false;
        _lastQuery      = '';
      });
      return;
    }

    if (_activeTab == 0) {
      setState(() => _playerLoading = true);
      _debounce = Timer(const Duration(milliseconds: 380), () async {
        final myUid = ref.read(currentUserProvider).valueOrNull?.uid;
        final fs    = ref.read(firestoreServiceProvider);
        final found = await fs.searchUsers(q, excludeUid: myUid);
        if (mounted) {
          setState(() {
            _playerResults = found;
            _playerLoading = false;
            _lastQuery     = q;
          });
        }
      });
    }
  }

  // ── Distance helpers ──────────────────────────────────────────────────────

  (double, double)? get _myCoords {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me?.latitude == null) return null;
    return (me!.latitude!, me.longitude!);
  }

  String? _distLabel(UserModel u) {
    if (u.latitude == null) return null;
    final my = _myCoords;
    if (my == null) return null;
    final m = Geolocator.distanceBetween(
        my.$1, my.$2, u.latitude!, u.longitude!);
    if (m < 1000) return '${m.round()}m';
    return '${(m / 1000).toStringAsFixed(1)}km';
  }

  bool _isNear(UserModel u) {
    if (u.latitude == null) return false;
    final my = _myCoords;
    if (my == null) return false;
    return Geolocator.distanceBetween(
            my.$1, my.$2, u.latitude!, u.longitude!) < 500;
  }

  // ── Tab switch ────────────────────────────────────────────────────────────

  void _switchTab(int t) {
    setState(() => _activeTab = t);
    // Trigger player search when switching to Players tab with existing query
    if (t == 0 && _ctrl.text.trim().length >= 2 && _playerResults.isEmpty) {
      _onQueryChanged(_ctrl.text);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasQuery = _ctrl.text.trim().length >= 2;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(
                      PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                      size: 22,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _hasFocus
                              ? _kAmber.withValues(alpha: 0.75)
                              : _kBorder,
                          width: _hasFocus ? 1.5 : 1.0,
                        ),
                        boxShadow: _hasFocus
                            ? [
                                BoxShadow(
                                  color: _kAmber.withValues(alpha: 0.08),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _kInk,
                          fontWeight: FontWeight.w400,
                        ),
                        cursorColor: _kAmber,
                        cursorWidth: 1.5,
                        decoration: InputDecoration(
                          hintText: 'search_players'.tr(),
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: _kInkMute,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Padding(
                            padding:
                                const EdgeInsets.only(left: 14, right: 10),
                            child: Icon(
                              PhosphorIcons.magnifyingGlass(
                                  PhosphorIconsStyle.regular),
                              size: 15,
                              color: _hasFocus
                                  ? _kAmber.withValues(alpha: 0.85)
                                  : _kInkMute,
                            ),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                          suffixIcon: _ctrl.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _ctrl.clear();
                                    _onQueryChanged('');
                                    _focus.requestFocus();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      PhosphorIcons.x(
                                          PhosphorIconsStyle.regular),
                                      size: 14,
                                      color: _kInkMute,
                                    ),
                                  ),
                                )
                              : null,
                          suffixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 14),
                        ),
                        onChanged: _onQueryChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab pills ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Row(
                children: [
                  _TabPill(
                    label: 'Players',
                    count: hasQuery ? _playerResults.length : null,
                    active: _activeTab == 0,
                    onTap: () => _switchTab(0),
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    label: 'Cities',
                    count: hasQuery ? _cityMatches.length : null,
                    active: _activeTab == 1,
                    onTap: () => _switchTab(1),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: switch (_activeTab) {
                0 => _buildPlayersTab(hasQuery),
                _ => _buildCitiesTab(hasQuery),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Players tab ───────────────────────────────────────────────────────────

  Widget _buildPlayersTab(bool hasQuery) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (hasQuery) ...[
          Row(
            children: [
              Text(
                'RESULTS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _kInkMute, letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 6),
              if (_playerLoading)
                SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _kAmber.withValues(alpha: 0.6),
                  ),
                )
              else
                Text(
                  '· ${_playerResults.length} PLAYER'
                  '${_playerResults.length == 1 ? '' : 'S'}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: _kInkMute, letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (!_playerLoading && _playerResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No players found for "$_lastQuery"',
                  style: GoogleFonts.inter(fontSize: 13, color: _kInkMute),
                ),
              ),
            )
          else
            for (int i = 0; i < _playerResults.length; i++)
              _PlayerRow(
                user: _playerResults[i],
                distLabel: _distLabel(_playerResults[i]),
                isNear: _isNear(_playerResults[i]),
                match: _lastQuery,
                isLast: i == _playerResults.length - 1,
                onTap: () {
                  _addRecent(_ctrl.text.trim());
                  context.push('/home/profile/${_playerResults[i].uid}');
                },
              ),

          if (_playerResults.isNotEmpty) const SizedBox(height: 24),
        ],

        // Recent section
        if (_recent.isNotEmpty) ...[
          Text(
            'RECENT',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _kInkMute, letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _recent.length; i++)
            _RecentRow(
              query: _recent[i],
              isLast: i == _recent.length - 1,
              onRemove: () => _removeRecent(i),
              onTap: () {
                _ctrl.text = _recent[i];
                _onQueryChanged(_recent[i]);
              },
            ),
        ],
      ],
    );
  }

  // ── Cities tab ────────────────────────────────────────────────────────────

  Widget _buildCitiesTab(bool hasQuery) {
    if (!hasQuery) {
      return _buildEmptyHint(
        icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular),
        line1: 'Type a city or country name',
        line2: 'e.g. "Baku", "Istanbul", "London"',
      );
    }

    if (_cityMatches.isEmpty) {
      return _buildEmptyHint(
        icon: PhosphorIcons.mapTrifold(PhosphorIconsStyle.regular),
        line1: 'No cities found for "$_lastQuery"',
        line2: 'Try a different city or country name',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _cityMatches.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'CITIES · ${_cityMatches.length} RESULT'
              '${_cityMatches.length == 1 ? '' : 'S'}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _kInkMute, letterSpacing: 0.6,
              ),
            ),
          );
        }
        final city = _cityMatches[i - 1];
        return _CityRow(
          city: city,
          isLast: i == _cityMatches.length,
          onTap: () {
            _addRecent(city.name);
            context.pop(LatLng(city.lat, city.lng));
          },
        );
      },
    );
  }

  Widget _buildEmptyHint({
    required IconData icon,
    required String line1,
    required String line2,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _kInkMute, size: 32),
          const SizedBox(height: 12),
          Text(line1,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: _kInkDim, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(line2,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: _kInkMute)),
        ],
      ),
    );
  }
}

// ── Tab pill ──────────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  final String label;
  final int? count;   // null = don't show badge
  final bool active;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kAmberGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? _kAmber.withValues(alpha: 0.55) : _kBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: active ? _kAmber : _kInkDim,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: (active ? _kAmber : _kInkDim).withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Player result row ─────────────────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  final UserModel user;
  final String? distLabel;
  final bool isNear;
  final String match;
  final bool isLast;
  final VoidCallback onTap;

  const _PlayerRow({
    required this.user,
    required this.distLabel,
    required this.isNear,
    required this.match,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = user.lastSeen != null &&
        DateTime.now().difference(user.lastSeen!).inMinutes < 5;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kAmber, _kAmberDeep],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.fraunces(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1205),
                          ),
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: -1, right: -1,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: _kWin,
                            shape: BoxShape.circle,
                            border: Border.all(color: _kBg, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightedText(name: user.username, match: match),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${user.overallRating}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: _kAmber,
                            ),
                          ),
                          if (distLabel != null) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('·',
                                style: TextStyle(
                                    color: _kInkFaint, fontSize: 12)),
                            ),
                            Text(distLabel!,
                              style: GoogleFonts.inter(
                                fontSize: 11, color: _kInkMute)),
                          ],
                          if (isNear) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _kAmberGlow,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'NEAR',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8, fontWeight: FontWeight.w700,
                                  color: _kAmber, letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                  size: 14, color: _kInkMute,
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Container(height: 1, color: _kBorder),
      ],
    );
  }
}

// ── City row ──────────────────────────────────────────────────────────────────

class _CityRow extends StatelessWidget {
  final _City city;
  final bool isLast;
  final VoidCallback onTap;

  const _CityRow({
    required this.city,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flag = UserModel.flagEmoji(city.countryCode);
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Center(
                    child: Text(flag,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.name,
                        style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        city.country,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kInkMute),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
                  size: 14, color: _kAmber.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Container(height: 1, color: _kBorder),
      ],
    );
  }
}

// ── Highlighted text ──────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String name;
  final String match;
  const _HighlightedText({required this.name, required this.match});

  @override
  Widget build(BuildContext context) {
    final lowerName  = name.toLowerCase();
    final lowerMatch = match.toLowerCase();
    final idx        = lowerName.indexOf(lowerMatch);
    if (idx < 0 || match.isEmpty) {
      return Text(name,
        style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: _kInk));
    }
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: _kInk),
        children: [
          if (idx > 0) TextSpan(text: name.substring(0, idx)),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              color: _kAmberGlow,
              child: Text(
                name.substring(idx, idx + match.length),
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _kAmber,
                ),
              ),
            ),
          ),
          TextSpan(text: name.substring(idx + match.length)),
        ],
      ),
    );
  }
}

// ── Recent row ────────────────────────────────────────────────────────────────

class _RecentRow extends StatelessWidget {
  final String query;
  final bool isLast;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _RecentRow({
    required this.query,
    required this.isLast,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      PhosphorIcons.clockCounterClockwise(
                          PhosphorIconsStyle.regular),
                      size: 13, color: _kInkMute,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(query,
                    style: GoogleFonts.inter(fontSize: 13, color: _kInkDim)),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    PhosphorIcons.x(PhosphorIconsStyle.regular),
                    size: 13, color: _kInkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Container(height: 1, color: _kBorder),
      ],
    );
  }
}
