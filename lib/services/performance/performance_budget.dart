import 'package:flutter/foundation.dart';

class PerformanceBudgetReporter {
  const PerformanceBudgetReporter._();

  static void report({
    required String key,
    required Duration elapsed,
    required Duration budget,
  }) {
    if (!kDebugMode) {
      return;
    }
    final elapsedMs = elapsed.inMilliseconds;
    final budgetMs = budget.inMilliseconds;
    if (elapsed > budget) {
      debugPrint(
        '[PERF][WARN] $key exceeded budget: ${elapsedMs}ms > ${budgetMs}ms',
      );
      return;
    }
    debugPrint('[PERF][OK] $key: ${elapsedMs}ms <= ${budgetMs}ms');
  }
}
