import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../services/supabase/supabase_bootstrap.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'app_routes.dart';

class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  StreamSubscription<AuthState>? _authStateSubscription;
  String _lastAuthUserId = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(enableStartupPrefetchProvider)) {
        unawaited(ref.read(startupPrefetchProvider.future));
      }
    });
    _bindAuthSync();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useMockData = ref.watch(useMockDataProvider);
    final hasSession = ref.watch(hasSupabaseSessionProvider);
    final showSignIn = !useMockData && !hasSession;

    return Scaffold(
      body: widget.navigationShell,
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 28,
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.78,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: _DrawerProfile(
                  onTap: () => _openDrawerTab(
                    context,
                    showSignIn ? AppRouteName.signIn : AppRouteName.you,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final linkCount = showSignIn ? 7 : 6;
                    const spacing = 8.0;
                    final tileHeight =
                        (((constraints.maxHeight -
                                        ((linkCount - 1) * spacing) -
                                        8) /
                                    linkCount)
                                .clamp(46.0, 74.0))
                            .toDouble();
                    final fontSize = (tileHeight * 0.45)
                        .clamp(24.0, 30.0)
                        .toDouble();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _DrawerLink(
                            label: 'Premium',
                            icon: Icons.workspace_premium_outlined,
                            tileHeight: tileHeight,
                            fontSize: fontSize,
                            onTap: () =>
                                _openDrawerRoute(context, AppRouteName.pricing),
                          ),
                          const SizedBox(height: spacing),
                          _DrawerLink(
                            label: 'Explore',
                            icon: Icons.explore_outlined,
                            tileHeight: tileHeight,
                            fontSize: fontSize,
                            onTap: () =>
                                _openDrawerRoute(context, AppRouteName.explore),
                          ),
                          const SizedBox(height: spacing),
                          _DrawerLink(
                            label: 'Perks',
                            icon: Icons.local_offer_outlined,
                            tileHeight: tileHeight,
                            fontSize: fontSize,
                            onTap: () =>
                                _openDrawerRoute(context, AppRouteName.perks),
                          ),
                          const SizedBox(height: spacing),
                          _DrawerLink(
                            label: 'Events',
                            icon: Icons.event_outlined,
                            tileHeight: tileHeight,
                            fontSize: fontSize,
                            onTap: () =>
                                _openDrawerRoute(context, AppRouteName.events),
                          ),
                          const SizedBox(height: spacing),
                          _DrawerLink(
                            label: 'Creative Studio',
                            icon: Icons.edit_note_outlined,
                            tileHeight: tileHeight,
                            fontSize: fontSize,
                            onTap: () => _openDrawerRoute(
                              context,
                              AppRouteName.creatorStudio,
                            ),
                          ),
                          const SizedBox(height: spacing),
                          _DrawerLink(
                            label: 'Settings',
                            icon: Icons.settings_outlined,
                            tileHeight: tileHeight,
                            fontSize: fontSize,
                            onTap: () => _openDrawerRoute(
                              context,
                              AppRouteName.settings,
                            ),
                          ),
                          if (showSignIn) ...[
                            const SizedBox(height: spacing),
                            _DrawerLink(
                              label: 'Sign In',
                              icon: Icons.login,
                              tileHeight: tileHeight,
                              fontSize: fontSize,
                              onTap: () => _openDrawerRoute(
                                context,
                                AppRouteName.signIn,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.mode,
                    builder: (context, mode, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dark_mode_outlined),
                          const SizedBox(width: 8),
                          Switch(
                            value: mode == ThemeMode.dark,
                            onChanged: ThemeController.setDarkMode,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          BottomNavigationBarItem(icon: _WordsNavIcon(), label: 'Words'),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Play',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'You',
          ),
        ],
      ),
    );
  }

  void _openDrawerRoute(BuildContext context, String routeName) {
    Navigator.of(context).pop();
    context.pushNamed(routeName);
  }

  void _openDrawerTab(BuildContext context, String routeName) {
    Navigator.of(context).pop();
    context.goNamed(routeName);
  }

  void _bindAuthSync() {
    if (!SupabaseBootstrap.isConfigured || !SupabaseBootstrap.isInitialized) {
      return;
    }

    final client = Supabase.instance.client;
    _lastAuthUserId = client.auth.currentUser?.id ?? '';
    _authStateSubscription = client.auth.onAuthStateChange.listen((event) {
      if (!mounted) {
        return;
      }
      final nextUserId = event.session?.user.id ?? '';
      if (nextUserId == _lastAuthUserId) {
        return;
      }
      _lastAuthUserId = nextUserId;
      _syncAuthScopedProviders(nextUserId: nextUserId);
    });
  }

  void _syncAuthScopedProviders({required String nextUserId}) {
    ref.invalidate(profileProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(messageThreadsProvider);
    ref.invalidate(messageContactsProvider);
    ref.invalidate(savedArticlesProvider);
    ref.invalidate(userCollectionsProvider);
    ref.invalidate(userPerksProvider);
    ref.invalidate(userProgressionProvider);
    ref.invalidate(repostedArticlesProvider);
    ref.invalidate(creatorStudioProvider);

    if (nextUserId.isEmpty) {
      return;
    }

    unawaited(_primeSignedInScopedData());
  }

  Future<void> _primeSignedInScopedData() async {
    try {
      await Future.wait([
        ref.read(profileProvider.future),
        ref.read(settingsProvider.future),
        ref.read(messageThreadsProvider.future),
        ref.read(messageContactsProvider.future),
        ref.read(savedArticlesProvider.future),
        ref.read(userCollectionsProvider.future),
        ref.read(userPerksProvider.future),
        ref.read(userProgressionProvider.future),
        ref.read(repostedArticlesProvider.future),
      ]);
    } catch (_) {
      // Keep auth transition resilient even if one provider fetch fails.
    }
  }
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tileHeight,
    required this.fontSize,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double tileHeight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileHeight,
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 24),
        minLeadingWidth: 28,
        title: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontSize: fontSize),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        onTap: onTap,
      ),
    );
  }
}

class _DrawerProfile extends ConsumerWidget {
  const _DrawerProfile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final profile = ref.watch(profileProvider).valueOrNull;
    final name = profile?.displayName ?? 'Your profile';
    final location = profile == null
        ? 'Set your location'
        : '${profile.city}, ${profile.countryCode}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/placeholder-user.jpg',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordsNavIcon extends StatelessWidget {
  const _WordsNavIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.grey;
    return Text(
      'W',
      style: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
        fontSize: 20,
        color: color,
      ),
    );
  }
}
