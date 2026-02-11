enum EurodleLetterState { unknown, absent, present, correct }

class EurodleGuessFeedback {
  const EurodleGuessFeedback({required this.guess, required this.states});

  final String guess;
  final List<EurodleLetterState> states;

  bool get isWin =>
      states.isNotEmpty &&
      states.every((state) => state == EurodleLetterState.correct);
}

class EurodleEngine {
  const EurodleEngine._();

  static String normalizeWord(String value) {
    return value.trim().toLowerCase();
  }

  static bool isAlphabeticWord(String value, {required int expectedLength}) {
    final normalized = normalizeWord(value);
    if (normalized.length != expectedLength) {
      return false;
    }
    final pattern = RegExp(r'^[a-z]+$');
    return pattern.hasMatch(normalized);
  }

  static EurodleGuessFeedback evaluateGuess({
    required String guess,
    required String targetWord,
  }) {
    final normalizedGuess = normalizeWord(guess);
    final normalizedTarget = normalizeWord(targetWord);
    final guessChars = normalizedGuess.split('');
    final targetChars = normalizedTarget.split('');
    final length = guessChars.length;
    final states = List<EurodleLetterState>.filled(
      length,
      EurodleLetterState.absent,
    );

    final remaining = <String, int>{};
    for (var i = 0; i < targetChars.length; i++) {
      final targetChar = targetChars[i];
      final guessChar = i < guessChars.length ? guessChars[i] : '';
      if (guessChar == targetChar) {
        states[i] = EurodleLetterState.correct;
      } else {
        remaining[targetChar] = (remaining[targetChar] ?? 0) + 1;
      }
    }

    for (var i = 0; i < length; i++) {
      if (states[i] == EurodleLetterState.correct) {
        continue;
      }
      final char = guessChars[i];
      final count = remaining[char] ?? 0;
      if (count > 0) {
        states[i] = EurodleLetterState.present;
        remaining[char] = count - 1;
      }
    }

    return EurodleGuessFeedback(guess: normalizedGuess, states: states);
  }

  static Map<String, EurodleLetterState> mergeKeyboardState({
    required Map<String, EurodleLetterState> current,
    required EurodleGuessFeedback feedback,
  }) {
    final next = Map<String, EurodleLetterState>.from(current);
    final letters = feedback.guess.split('');
    for (var i = 0; i < letters.length; i++) {
      final letter = letters[i];
      final incoming = feedback.states[i];
      final existing = next[letter] ?? EurodleLetterState.unknown;
      if (_priority(incoming) >= _priority(existing)) {
        next[letter] = incoming;
      }
    }
    return next;
  }

  static int _priority(EurodleLetterState state) {
    switch (state) {
      case EurodleLetterState.unknown:
        return 0;
      case EurodleLetterState.absent:
        return 1;
      case EurodleLetterState.present:
        return 2;
      case EurodleLetterState.correct:
        return 3;
    }
  }
}
