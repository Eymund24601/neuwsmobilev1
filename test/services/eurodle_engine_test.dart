import 'package:flutter_test/flutter_test.dart';
import 'package:neuws_mobile_v1/services/games/eurodle_engine.dart';

void main() {
  test('validates alphabetic length input', () {
    expect(EurodleEngine.isAlphabeticWord('union', expectedLength: 5), isTrue);
    expect(EurodleEngine.isAlphabeticWord('uni0n', expectedLength: 5), isFalse);
    expect(EurodleEngine.isAlphabeticWord('unio', expectedLength: 5), isFalse);
  });

  test('evaluates guess with duplicate letters correctly', () {
    final feedback = EurodleEngine.evaluateGuess(
      guess: 'radar',
      targetWord: 'array',
    );
    expect(feedback.states, [
      EurodleLetterState.present,
      EurodleLetterState.present,
      EurodleLetterState.absent,
      EurodleLetterState.correct,
      EurodleLetterState.present,
    ]);
  });

  test('keyboard merge keeps strongest state', () {
    final first = EurodleGuessFeedback(
      guess: 'voter',
      states: const [
        EurodleLetterState.absent,
        EurodleLetterState.absent,
        EurodleLetterState.present,
        EurodleLetterState.absent,
        EurodleLetterState.absent,
      ],
    );
    final second = EurodleGuessFeedback(
      guess: 'treat',
      states: const [
        EurodleLetterState.correct,
        EurodleLetterState.absent,
        EurodleLetterState.absent,
        EurodleLetterState.absent,
        EurodleLetterState.present,
      ],
    );

    var keyboard = <String, EurodleLetterState>{};
    keyboard = EurodleEngine.mergeKeyboardState(
      current: keyboard,
      feedback: first,
    );
    keyboard = EurodleEngine.mergeKeyboardState(
      current: keyboard,
      feedback: second,
    );

    expect(keyboard['t'], EurodleLetterState.correct);
    expect(keyboard['o'], EurodleLetterState.absent);
    expect(keyboard['e'], EurodleLetterState.absent);
  });
}
