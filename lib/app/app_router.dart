import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/article_entry_page.dart';
import '../screens/creator_studio_page.dart';
import '../screens/event_detail_page.dart';
import '../screens/events_page.dart';
import '../screens/explore_page.dart';
import '../screens/games_page.dart';
import '../screens/home_page.dart';
import '../screens/learn_page.dart';
import '../screens/learn_track_page.dart';
import '../screens/lesson_page.dart';
import '../screens/messages_page.dart';
import '../screens/message_thread_page.dart';
import '../screens/perks_page.dart';
import '../screens/pricing_page.dart';
import '../screens/quiz_categories_page.dart';
import '../screens/quiz_play_page.dart';
import '../screens/saved_page.dart';
import '../screens/settings_page.dart';
import '../screens/sign_in_page.dart';
import '../screens/topic_feed_page.dart';
import '../screens/write_page.dart';
import '../screens/you_page.dart';
import 'app_routes.dart';
import 'app_shell_scaffold.dart';

class AppRouter {
  AppRouter._();

  static GoRouter createRouter() {
    final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
    final homeNavigatorKey = GlobalKey<NavigatorState>(
      debugLabel: 'homeBranch',
    );
    final messagesNavigatorKey = GlobalKey<NavigatorState>(
      debugLabel: 'messagesBranch',
    );
    final learnNavigatorKey = GlobalKey<NavigatorState>(
      debugLabel: 'learnBranch',
    );
    final gamesNavigatorKey = GlobalKey<NavigatorState>(
      debugLabel: 'gamesBranch',
    );
    final youNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'youBranch');

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppRoutePath.home,
      routes: [
        GoRoute(path: '/', redirect: (context, state) => AppRoutePath.home),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShellScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              navigatorKey: homeNavigatorKey,
              routes: [
                GoRoute(
                  path: AppRoutePath.home,
                  name: AppRouteName.home,
                  builder: (context, state) => const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: messagesNavigatorKey,
              routes: [
                GoRoute(
                  path: AppRoutePath.messages,
                  name: AppRouteName.messages,
                  builder: (context, state) => const MessagesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: learnNavigatorKey,
              routes: [
                GoRoute(
                  path: AppRoutePath.learn,
                  name: AppRouteName.learn,
                  builder: (context, state) => const LearnPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: gamesNavigatorKey,
              routes: [
                GoRoute(
                  path: AppRoutePath.games,
                  name: AppRouteName.games,
                  builder: (context, state) => const GamesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: youNavigatorKey,
              routes: [
                GoRoute(
                  path: AppRoutePath.you,
                  name: AppRouteName.you,
                  builder: (context, state) => const YouPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutePath.messageThread,
          name: AppRouteName.messageThread,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final threadId = state.pathParameters['threadId'] ?? '';
            final threadTitle = state.extra is String
                ? state.extra as String
                : 'Conversation';
            return MessageThreadPage(
              threadId: threadId,
              threadTitle: threadTitle,
            );
          },
        ),
        GoRoute(
          path: AppRoutePath.saved,
          name: AppRouteName.saved,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const SavedPage(),
        ),
        GoRoute(
          path: AppRoutePath.events,
          name: AppRouteName.events,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const EventsPage(),
        ),
        GoRoute(
          path: AppRoutePath.eventDetail,
          name: AppRouteName.eventDetail,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return EventDetailPage(eventId: eventId);
          },
        ),
        GoRoute(
          path: AppRoutePath.article,
          name: AppRouteName.article,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return ArticleEntryPage(slug: slug);
          },
        ),
        GoRoute(
          path: AppRoutePath.topicFeed,
          name: AppRouteName.topicFeed,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final code = state.pathParameters['topicOrCountryCode'] ?? '';
            return TopicFeedPage(topicOrCountryCode: code);
          },
        ),
        GoRoute(
          path: AppRoutePath.learnTrack,
          name: AppRouteName.learnTrack,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final trackId = state.pathParameters['trackId'] ?? '';
            return LearnTrackPage(trackId: trackId);
          },
        ),
        GoRoute(
          path: AppRoutePath.lesson,
          name: AppRouteName.lesson,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final lessonId = state.pathParameters['lessonId'] ?? '';
            return LessonPage(lessonId: lessonId);
          },
        ),
        GoRoute(
          path: AppRoutePath.quizCategories,
          name: AppRouteName.quizCategories,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const QuizCategoriesPage(),
        ),
        GoRoute(
          path: AppRoutePath.quizPlay,
          name: AppRouteName.quizPlay,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final quizId = state.pathParameters['quizId'] ?? '';
            return QuizPlayPage(quizId: quizId);
          },
        ),
        GoRoute(
          path: AppRoutePath.explore,
          name: AppRouteName.explore,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const ExplorePage(),
        ),
        GoRoute(
          path: AppRoutePath.perks,
          name: AppRouteName.perks,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const PerksPage(),
        ),
        GoRoute(
          path: AppRoutePath.settings,
          name: AppRouteName.settings,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: AppRoutePath.pricing,
          name: AppRouteName.pricing,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const PricingPage(),
        ),
        GoRoute(
          path: AppRoutePath.creatorStudio,
          name: AppRouteName.creatorStudio,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const CreatorStudioPage(),
        ),
        GoRoute(
          path: AppRoutePath.write,
          name: AppRouteName.write,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const WritePage(),
        ),
        GoRoute(
          path: AppRoutePath.signIn,
          name: AppRouteName.signIn,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const SignInPage(),
        ),
      ],
    );
  }
}
