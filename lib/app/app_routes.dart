class AppRouteName {
  static const home = 'home';
  static const messages = 'messages';
  static const messageThread = 'messageThread';
  static const quizzes = 'quizzes';
  static const puzzles = 'puzzles';
  static const you = 'you';
  static const words = 'words';
  static const learn = 'learn';

  static const saved = 'saved';
  static const events = 'events';
  static const eventDetail = 'eventDetail';
  static const article = 'article';
  static const topicFeed = 'topicFeed';
  static const learnTrack = 'learnTrack';
  static const lesson = 'lesson';
  static const quizCategories = 'quizCategories';
  static const quizPlay = 'quizPlay';
  static const quizClashLobby = 'quizClashLobby';
  static const quizClashMatch = 'quizClashMatch';
  static const sudokuPlay = 'sudokuPlay';
  static const eurodlePlay = 'eurodlePlay';
  static const settings = 'settings';
  static const pricing = 'pricing';
  static const creatorStudio = 'creatorStudio';
  static const perks = 'perks';
  static const explore = 'explore';
  static const write = 'write';
  static const signIn = 'signIn';
}

class AppRoutePath {
  static const home = '/home';
  static const messages = '/messages';
  static const messageThread = '/messages/thread/:threadId';
  static const quizzes = '/quizzes';
  static const puzzles = '/puzzles';
  static const you = '/you';
  static const words = '/words';
  static const learn = '/learn';

  static const saved = '/saved';
  static const events = '/events';
  static const eventDetail = '/events/:eventId';
  static const article = '/article/:slug';
  static const topicFeed = '/feed/:topicOrCountryCode';
  static const learnTrack = '/words/track/:trackId';
  static const lesson = '/lesson/:lessonId';
  static const quizCategories = '/quizzes/normal';
  static const quizPlay = '/quizzes/normal/:quizId';
  static const quizClashLobby = '/quizzes/quiz-clash';
  static const quizClashMatch = '/quizzes/quiz-clash/:matchId';
  static const sudokuPlay = '/puzzles/sudoku';
  static const eurodlePlay = '/puzzles/eurodle';
  static const settings = '/settings';
  static const pricing = '/pricing';
  static const creatorStudio = '/creator-studio';
  static const perks = '/perks';
  static const explore = '/explore';
  static const write = '/write';
  static const signIn = '/sign-in';
}
