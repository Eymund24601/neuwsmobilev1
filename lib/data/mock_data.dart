class HeroStory {
  const HeroStory({
    required this.title,
    required this.date,
    required this.byline,
    required this.imageAsset,
  });

  final String title;
  final String date;
  final String byline;
  final String imageAsset;
}

class ListStory {
  const ListStory({required this.title, required this.date});

  final String title;
  final String date;
}

class CreatorStory {
  const CreatorStory({required this.title, required this.author});

  final String title;
  final String author;
}

class MiniGame {
  const MiniGame({required this.title, required this.tag});

  final String title;
  final String tag;
}

class LearningCardData {
  const LearningCardData({
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final double progress;
}

class SavedStory {
  const SavedStory({required this.title, required this.date});

  final String title;
  final String date;
}

class EventItem {
  const EventItem({
    required this.title,
    required this.location,
    required this.date,
    required this.tag,
  });

  final String title;
  final String location;
  final String date;
  final String tag;
}

class ArticleContent {
  const ArticleContent({
    required this.title,
    required this.byline,
    required this.date,
    required this.imageAsset,
    required this.topic,
    required this.readTime,
    required this.authorName,
    required this.authorLocation,
    required this.languageTop,
    required this.languageBottom,
    required this.bodyTop,
    required this.bodyBottom,
  });

  final String title;
  final String byline;
  final String date;
  final String imageAsset;
  final String topic;
  final String readTime;
  final String authorName;
  final String authorLocation;
  final String languageTop;
  final String languageBottom;
  final String bodyTop;
  final String bodyBottom;
}

class HomeMockData {
  static const hero = HeroStory(
    title: 'Is Your Social Life Missing Something? This Conversation Is for You.',
    date: 'FEBRUARY 3, 2026',
    byline: 'Ezra Klein and Annie Galvin',
    imageAsset: 'assets/images/placeholder.jpg',
  );

  static const listStories = [
    ListStory(
      title: 'Trump Could Interfere With the Midterm Elections. You Can Help Defend Them.',
      date: 'JANUARY 31, 2026',
    ),
    ListStory(
      title: 'Caregiving, the Life-Altering Job You Didn\'t Apply For',
      date: 'FEBRUARY 1, 2026',
    ),
  ];

  static const creators = [
    CreatorStory(
      title: 'A Night Train Diary Through the Baltics',
      author: 'Lea Novak - Slovenia',
    ),
    CreatorStory(
      title: 'Why Porto Feels Like the Future of Cities',
      author: 'Miguel Sousa - Portugal',
    ),
    CreatorStory(
      title: 'The Quiet Politics of Finnish Saunas',
      author: 'Aino Jarvinen - Finland',
    ),
  ];

  static const miniGames = [
    MiniGame(title: 'Quick crossword', tag: '2 min'),
    MiniGame(title: 'Word wheel', tag: 'Daily'),
  ];

  static const learning = LearningCardData(
    title: 'How the EU actually works',
    subtitle: 'Step 6 of 12 - Next: The Parliament vs Commission',
    progress: 0.52,
  );

  static const savedStories = [
    SavedStory(title: 'How Lisbon Rewrote Its Startup Playbook', date: 'JANUARY 30, 2026'),
    SavedStory(title: 'The Quiet Politics of Finnish Saunas', date: 'JANUARY 28, 2026'),
    SavedStory(title: 'What the Balkans Teach Us About Resilience', date: 'JANUARY 24, 2026'),
  ];

  static const events = [
    EventItem(
      title: 'Vienna Culture Night',
      location: 'Vienna, Austria',
      date: 'FEB 14 · 19:00',
      tag: 'Culture',
    ),
    EventItem(
      title: 'EU Elections Watch Party',
      location: 'Brussels, Belgium',
      date: 'FEB 18 · 20:00',
      tag: 'Politics',
    ),
    EventItem(
      title: 'Nordic Design Meetup',
      location: 'Helsinki, Finland',
      date: 'FEB 21 · 18:30',
      tag: 'Design',
    ),
  ];

  static const article = ArticleContent(
    title: 'China\'s Generals Are Disappearing',
    byline: 'International Desk',
    date: 'FEBRUARY 3, 2026',
    imageAsset: 'assets/images/placeholder.jpg',
    topic: 'World Politics',
    readTime: '6 min read',
    authorName: 'Marta Keller',
    authorLocation: 'Vienna, Austria',
    languageTop: 'Swedish',
    languageBottom: 'English',
    bodyTop:
        '''Under tre ar har Xi Jinping rensat sin militarledning. En vag av avskedanden och forsvinnanden har slagit mot flera grenar av armens elit.

Analytiker i Peking menar att detta skickar en tydlig signal om lojalitet. Samtidigt vacker det oro bland regionala befalhavare, som nu ser sin framtid som mer oforutsagbar.

I Europa foljs utvecklingen noga. Diplomater fragar sig hur det kan paverka Kinas utrikespolitik och dess relationer till EU.

Pa kort sikt har utrensningarna gjort kedjan av befalsord mer sluten. Kritiker menar dock att tystnad inte ar detsamma som stabilitet.

Flera forsvarsanalytiker pekar pa att yngre officerare nu avancerar snabbare, men med farre fria ramar.

For vanliga soldater handlar vardagen fortfarande om logistik, ovningar och disciplin, men samtalen i korridorerna ar mer forsiktiga.''',
    bodyBottom:
        '''For three years, Xi Jinping has been cleaning out the military elite. A wave of dismissals and disappearances has swept across multiple branches of senior command.

Analysts in Beijing say the moves send a clear signal about loyalty. At the same time, they create unease among regional commanders who now see their futures as less predictable.

In Europe, the developments are being watched closely. Diplomats are asking how this could shape China's foreign policy and its relationship with the EU.

In the short term, the purge has tightened the chain of command. Critics argue that silence is not the same as stability.

Several defense analysts say younger officers are moving up faster, but with fewer areas of discretion.

For ordinary soldiers, daily life is still about logistics, drills, and discipline, yet the hallway conversations have grown more cautious.''',
  );
}
