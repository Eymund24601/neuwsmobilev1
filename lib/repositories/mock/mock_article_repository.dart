import '../../models/article_detail.dart';
import '../../models/article_summary.dart';
import '../../models/topic_feed.dart';
import '../article_repository.dart';

class MockArticleRepository implements ArticleRepository {
  static const _stories = [
    ArticleSummary(
      id: 'a1',
      slug: 'europe-social-club',
      title:
          'Is Your Social Life Missing Something? This Conversation Is for You.',
      topic: 'Lifestyle',
      countryCode: 'SE,DK,NO',
      readTimeMinutes: 6,
      publishedAtLabel: 'FEBRUARY 3, 2026',
      isPremium: false,
    ),
    ArticleSummary(
      id: 'a2',
      slug: 'midterm-defense',
      title:
          'How Communities Defend Elections Without Waiting for Institutions',
      topic: 'Opinion',
      countryCode: 'DE,AT',
      readTimeMinutes: 7,
      publishedAtLabel: 'FEBRUARY 2, 2026',
      isPremium: true,
    ),
    ArticleSummary(
      id: 'a3',
      slug: 'baltic-night-train',
      title: 'A Night Train Diary Through the Baltics',
      topic: 'Lifestyle',
      countryCode: 'LV,LT,EE',
      readTimeMinutes: 5,
      publishedAtLabel: 'FEBRUARY 1, 2026',
      isPremium: false,
    ),
    ArticleSummary(
      id: 'a4',
      slug: 'portugal-cities',
      title: 'Why Porto Feels Like the Future of Cities',
      topic: 'Tech',
      countryCode: 'PT',
      readTimeMinutes: 8,
      publishedAtLabel: 'JANUARY 31, 2026',
      isPremium: true,
    ),
  ];

  static const _details = [
    ArticleDetail(
      slug: 'europe-social-club',
      title: 'China\'s Generals Are Disappearing',
      byline: 'International Desk',
      date: 'FEBRUARY 3, 2026',
      imageAsset: 'assets/images/placeholder.jpg',
      topic: 'World Politics',
      excerpt:
          'For three years, Xi Jinping has been removing top military figures, reshaping command and raising new questions across Europe.',
      readTime: '6 min read',
      authorName: 'Marta Keller',
      authorLocation: 'Vienna, Austria',
      languageTop: 'Swedish',
      languageBottom: 'English',
      bodyTop:
          'Under tre ar har Xi Jinping rensat sin militarledning. En vag av avskedanden och forsvinnanden har slagit mot flera grenar av armens elit.',
      bodyBottom:
          'For three years, Xi Jinping has been cleaning out the military elite. A wave of dismissals has swept across senior command.',
    ),
    ArticleDetail(
      slug: 'midterm-defense',
      title:
          'How Communities Defend Elections Without Waiting for Institutions',
      byline: 'Democracy Desk',
      date: 'FEBRUARY 2, 2026',
      imageAsset: 'assets/images/placeholder.jpg',
      topic: 'Opinion',
      excerpt:
          'Local groups across Europe are stress-testing election systems before campaigns heat up.',
      readTime: '7 min read',
      authorName: 'Lukas Brenner',
      authorLocation: 'Berlin, Germany',
      languageTop: 'German',
      languageBottom: 'English',
      bodyTop:
          'Buergergruppen in mehreren Staedten organisieren derzeit Trainings, um Wahlhelfer auf Desinformation und lokale Stoerungen vorzubereiten.',
      bodyBottom:
          'Civic groups in multiple cities are running drills to prepare election volunteers for disinformation and local disruptions.',
    ),
    ArticleDetail(
      slug: 'baltic-night-train',
      title: 'A Night Train Diary Through the Baltics',
      byline: 'Creator Story',
      date: 'FEBRUARY 1, 2026',
      imageAsset: 'assets/images/placeholder.jpg',
      topic: 'Lifestyle',
      excerpt:
          'A creator follows overnight routes from Riga to Vilnius and maps the conversations in each carriage.',
      readTime: '5 min read',
      authorName: 'Lea Novak',
      authorLocation: 'Ljubljana, Slovenia',
      languageTop: 'English',
      languageBottom: 'French',
      bodyTop:
          'At 22:40 the train eased out of Riga. By midnight, the dining car had turned into a map of accents and stories.',
      bodyBottom:
          'A 22h40, le train a quitte Riga. A minuit, le wagon-restaurant etait devenu une carte d\'accents et de recits.',
    ),
    ArticleDetail(
      slug: 'portugal-cities',
      title: 'Why Porto Feels Like the Future of Cities',
      byline: 'Urban Futures',
      date: 'JANUARY 31, 2026',
      imageAsset: 'assets/images/placeholder.jpg',
      topic: 'Tech',
      excerpt:
          'Porto\'s compact planning and startup infrastructure are changing how young Europeans choose where to live.',
      readTime: '8 min read',
      authorName: 'Miguel Sousa',
      authorLocation: 'Porto, Portugal',
      languageTop: 'Portuguese',
      languageBottom: 'English',
      bodyTop:
          'Porto tornou-se um laboratorio urbano: mobilidade curta, bairros ativos e um ecossistema digital em crescimento.',
      bodyBottom:
          'Porto has become an urban lab: short-distance mobility, active neighborhoods, and a growing digital ecosystem.',
    ),
  ];

  @override
  Future<ArticleDetail?> getArticleDetailBySlug(String slug) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final detail in _details) {
      if (detail.slug == slug) {
        return detail;
      }
    }
    return null;
  }

  @override
  Future<TopicFeed> getTopicFeed(String topicOrCountryCode) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final key = topicOrCountryCode.toLowerCase();
    final filtered = _stories.where((story) {
      return story.topic.toLowerCase() == key ||
          story.countryCode.toLowerCase() == key;
    }).toList();

    return TopicFeed(
      code: topicOrCountryCode.toUpperCase(),
      displayName: topicOrCountryCode,
      stories: filtered.isEmpty ? _stories : filtered,
    );
  }

  @override
  Future<List<ArticleSummary>> getTopStories() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _stories;
  }
}
