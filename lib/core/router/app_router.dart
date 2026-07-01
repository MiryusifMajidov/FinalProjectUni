import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/game/screens/game_screen.dart';
import '../../features/game/screens/bot_setup_screen.dart';
import '../../features/game/screens/local_setup_screen.dart';
import '../../features/campaign/screens/campaign_map_screen.dart';
import '../../features/campaign/screens/campaign_chapter_screen.dart';
import '../../features/matchmaking/screens/matchmaking_screen.dart';
import '../../features/matchmaking/screens/friend_invite_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/map/screens/player_map_screen.dart';
import '../../features/friends/screens/friends_screen.dart';
import '../../features/friends/screens/user_search_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/leaderboard/screens/leaderboard_screen.dart';
import '../../features/tournaments/screens/tournament_list_screen.dart';
import '../../features/tournaments/screens/arena_lobby_screen.dart';
import '../../features/tournaments/screens/create_tournament_screen.dart';
import '../../features/groups/screens/groups_screen.dart';
import '../../features/groups/screens/group_screen.dart';
import '../../features/groups/screens/group_settings_screen.dart';
import '../../features/groups/screens/create_group_screen.dart';
import '../../features/game/screens/spectator_screen.dart';
import '../../features/game/screens/game_replay_screen.dart';
import '../../features/auth/screens/skill_level_screen.dart';
import '../../features/auth/screens/profile_photo_prompt_screen.dart';
import '../../features/settings/screens/account_screen.dart';
import '../../features/settings/screens/privacy_screen.dart';
import '../../features/settings/screens/about_screen.dart';
import '../../features/settings/screens/game_settings_screen.dart';
import '../../features/settings/screens/sound_screen.dart';
import '../../features/settings/screens/notifications_screen.dart';
import '../../features/settings/screens/language_screen.dart';
import '../../features/settings/screens/help_feedback_screen.dart';
import '../../features/settings/screens/two_factor_screen.dart';
import '../../features/settings/screens/active_sessions_screen.dart';
import '../../features/settings/screens/blocked_users_screen.dart';
import '../../features/auth/screens/two_factor_verify_screen.dart';
import '../../features/matchmaking/screens/invite_friend_config_screen.dart';
import '../../features/matchmaking/screens/matchmaking_search_screen.dart';
import '../../features/map/screens/map_challenge_sent_screen.dart';
import '../../features/map/screens/map_search_screen.dart';
import '../../features/game/screens/in_game_calm_screen.dart';
import '../../features/game/screens/in_game_calm_replay_screen.dart';
import '../../features/checkers/screens/checkers_bot_setup_screen.dart';
import '../../features/checkers/screens/checkers_game_screen.dart';
import '../../features/domino/screens/domino_bot_setup_screen.dart';
import '../../features/domino/screens/domino_table_setup_screen.dart';
import '../../features/domino/screens/domino_game_screen.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Notifies GoRouter when auth state changes so redirect re-evaluates
/// without recreating the GoRouter instance.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final _routerNotifierProvider =
    ChangeNotifierProvider<_RouterNotifier>((ref) => _RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  // ref.read — intentionally NOT watching, so the GoRouter is created once.
  // Auth changes are handled via refreshListenable below.
  final notifier = ref.read(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      // Always read current auth state (not a captured closure value).
      final authState = ref.read(authStateProvider);
      final isLoading = authState.isLoading;
      if (isLoading) return '/splash';

      final isLoggedIn = authState.valueOrNull != null;
      final onAuthPath = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/splash';

      // Post-registration screens that require auth but aren't "home" yet.
      final onPostRegPath = state.matchedLocation == '/email-verification' ||
          state.matchedLocation == '/auth/profile-photo';

      if (!isLoggedIn && !onAuthPath && !onPostRegPath) return '/login';
      if (isLoggedIn && onAuthPath && state.matchedLocation != '/splash') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadeTransition(
          state.pageKey,
          const LoginScreen(),
        ),
        routes: [
          GoRoute(
            path: '2fa-verify',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              TwoFactorVerifyScreen(email: state.extra as String? ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => _slideTransition(
          state.pageKey,
          const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/email-verification',
        pageBuilder: (_, state) => _fadeTransition(
          state.pageKey,
          const EmailVerificationScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/skill-level',
        pageBuilder: (_, state) => _slideTransition(
          state.pageKey,
          const SkillLevelScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/profile-photo',
        pageBuilder: (_, state) => _slideTransition(
          state.pageKey,
          const ProfilePhotoPromptScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, state) => _fadeTransition(
          state.pageKey,
          const HomeScreen(),
        ),
        routes: [
          GoRoute(
            path: 'profile/:uid',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              ProfileScreen(uid: state.pathParameters['uid']!),
            ),
          ),
          GoRoute(
            path: 'settings',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const SettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'account',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const AccountScreen(),
                ),
                routes: [
                  GoRoute(
                    path: '2fa',
                    pageBuilder: (_, state) => _slideTransition(
                      state.pageKey,
                      TwoFactorScreen(enabling: state.extra as bool? ?? true),
                    ),
                  ),
                  GoRoute(
                    path: 'sessions',
                    pageBuilder: (_, state) => _slideTransition(
                      state.pageKey,
                      const ActiveSessionsScreen(),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'privacy',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const PrivacyScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'blocked',
                    pageBuilder: (_, state) => _slideTransition(
                      state.pageKey,
                      const BlockedUsersScreen(),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'feedback',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const HelpFeedbackScreen(),
                ),
              ),
              GoRoute(
                path: 'about',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const AboutScreen(),
                ),
              ),
              GoRoute(
                path: 'game',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const GameSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'sound',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const SoundScreen(),
                ),
              ),
              GoRoute(
                path: 'notifications',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const NotificationsScreen(),
                ),
              ),
              GoRoute(
                path: 'language',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const LanguageScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'bot-setup',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const BotSetupScreen(),
            ),
          ),
          GoRoute(
            path: 'local-setup',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const LocalSetupScreen(),
            ),
          ),
          GoRoute(
            path: 'matchmaking',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const MatchmakingScreen(),
            ),
          ),
          GoRoute(
            path: 'invite',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              FriendInviteScreen(
                preselected: state.extra as UserModel?,
              ),
            ),
          ),
          GoRoute(
            path: 'invite-config',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              InviteFriendConfigScreen(
                opponent: state.extra as UserModel,
              ),
            ),
          ),
          GoRoute(
            path: 'map',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const PlayerMapScreen(),
            ),
            routes: [
              GoRoute(
                path: 'search',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const MapSearchScreen(),
                ),
              ),
              GoRoute(
                path: 'challenge-sent',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  MapChallengeSentScreen(
                    opponent: state.extra as UserModel,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'campaign',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const CampaignMapScreen(),
            ),
            routes: [
              GoRoute(
                path: ':chapter',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  CampaignChapterScreen(
                    chapter: (int.tryParse(
                                state.pathParameters['chapter'] ?? '') ??
                            1)
                        .clamp(1, 100),
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'friends',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const FriendsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'search',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const UserSearchScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'chat/:uid',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              ChatScreen(otherUid: state.pathParameters['uid']!),
            ),
          ),
          GoRoute(
            path: 'leaderboard',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const LeaderboardScreen(),
            ),
          ),
          GoRoute(
            path: 'groups',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const GroupsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const CreateGroupScreen(),
                ),
              ),
              GoRoute(
                path: ':groupId',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  GroupScreen(groupId: state.pathParameters['groupId']!),
                ),
                routes: [
                  GoRoute(
                    path: 'settings',
                    pageBuilder: (_, state) => _slideTransition(
                      state.pageKey,
                      GroupSettingsScreen(
                          groupId: state.pathParameters['groupId']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'tournaments',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const TournamentListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  const CreateTournamentScreen(),
                ),
              ),
              GoRoute(
                path: ':tournamentId',
                pageBuilder: (_, state) => _slideTransition(
                  state.pageKey,
                  ArenaLobbyScreen(
                    tournamentId: state.pathParameters['tournamentId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'spectate/:gameId',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              SpectatorScreen(
                gameId: state.pathParameters['gameId']!,
                watchedUid: state.extra as String? ?? '',
              ),
            ),
          ),
          GoRoute(
            path: 'game-replay/:gameId',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              GameReplayScreen(
                gameId: state.pathParameters['gameId']!,
                viewerUid: state.extra as String? ?? '',
              ),
            ),
          ),
          GoRoute(
            path: 'game-calm-replay/:gameId',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              InGameCalmReplayScreen(
                gameId: state.pathParameters['gameId']!,
                viewerUid: state.extra as String? ?? '',
              ),
            ),
          ),
          // ── Checkers routes ─────────────────────────────────────────
          GoRoute(
            path: 'checkers-bot-setup',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const CheckersBotSetupScreen(),
            ),
          ),
          // ── Domino routes ───────────────────────────────────────────
          GoRoute(
            path: 'domino-bot-setup',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const DominoBotSetupScreen(),
            ),
          ),
          GoRoute(
            path: 'domino-table',
            pageBuilder: (_, state) => _slideTransition(
              state.pageKey,
              const DominoTableSetupScreen(),
            ),
          ),
          GoRoute(
            path: 'matchmaking-search',
            pageBuilder: (_, state) {
              final extra =
                  state.extra as Map<String, dynamic>? ?? {};
              return _slideTransition(
                state.pageKey,
                MatchmakingSearchScreen(
                  timeLabel: extra['timeLabel'] as String? ?? '5 MIN',
                  isRated: extra['isRated'] as bool? ?? true,
                  minElo: extra['minElo'] as int? ?? 1000,
                  maxElo: extra['maxElo'] as int? ?? 1400,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/game/:gameId',
        pageBuilder: (_, state) => _slideTransition(
          state.pageKey,
          GameScreen(
            gameId: state.pathParameters['gameId']!,
            extra: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: '/checkers-game/:gameId',
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _slideTransition(
            state.pageKey,
            CheckersGameScreen(
              gameId: state.pathParameters['gameId']!,
              extra: extra,
            ),
          );
        },
      ),
      GoRoute(
        path: '/domino-game/:gameId',
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _slideTransition(
            state.pageKey,
            DominoGameScreen(
              gameId: state.pathParameters['gameId']!,
              extra: extra,
            ),
          );
        },
      ),
      GoRoute(
        path: '/game-calm/:gameId',
        pageBuilder: (_, state) => _slideTransition(
          state.pageKey,
          InGameCalmScreen(
            gameId: state.pathParameters['gameId']!,
            extra: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.error}'),
      ),
    ),
  );
});

CustomTransitionPage<void> _fadeTransition(
  LocalKey key,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

CustomTransitionPage<void> _slideTransition(
  LocalKey key,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}
