import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/feature_data_providers.dart';
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(enableStartupPrefetchProvider)) {
        unawaited(ref.read(startupPrefetchProvider.future));
      }
    });
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => _openDrawerTab(context, AppRouteName.you),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: (constraints.maxHeight * 0.12).clamp(
                                  20.0,
                                  120.0,
                                ),
                              ),
                              _DrawerLink(
                                label: 'Premium',
                                icon: Icons.workspace_premium_outlined,
                                onTap: () => _openDrawerRoute(
                                  context,
                                  AppRouteName.pricing,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DrawerLink(
                                label: 'Explore',
                                icon: Icons.explore_outlined,
                                onTap: () => _openDrawerRoute(
                                  context,
                                  AppRouteName.explore,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DrawerLink(
                                label: 'Perks',
                                icon: Icons.local_offer_outlined,
                                onTap: () => _openDrawerRoute(
                                  context,
                                  AppRouteName.perks,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DrawerLink(
                                label: 'Events',
                                icon: Icons.event_outlined,
                                onTap: () => _openDrawerRoute(
                                  context,
                                  AppRouteName.events,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DrawerLink(
                                label: 'Creative Studio',
                                icon: Icons.edit_note_outlined,
                                onTap: () => _openDrawerRoute(
                                  context,
                                  AppRouteName.creatorStudio,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DrawerLink(
                                label: 'Settings',
                                icon: Icons.settings_outlined,
                                onTap: () => _openDrawerRoute(
                                  context,
                                  AppRouteName.settings,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 30),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onTap: onTap,
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
