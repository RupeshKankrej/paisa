import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/domain/categories.dart';

void main() {
  test('the palette has 42 distinct swatches', () {
    expect(categoryPalette.toSet(), hasLength(42));
    expect(categoryPalette.first, defaultCategoryColor);
  });

  test('names clash per list, ignoring case and spaces', () {
    expect(nameTaken(['Food'], ' fOOd '), isTrue);
    expect(nameTaken(['Food'], 'Foods'), isFalse);
  });

  test('lastEmoji keeps whole emoji and refuses text', () {
    expect(lastEmoji('🎯🐶'), '🐶');
    expect(lastEmoji('🏝️'), '🏝️', reason: 'with a variation selector');
    expect(lastEmoji('👨‍👩‍👧'), '👨‍👩‍👧', reason: 'joined');
    expect(lastEmoji('🇮🇳'), '🇮🇳', reason: 'a flag');
    expect(lastEmoji('1️⃣'), '1️⃣', reason: 'a keycap');
    expect(lastEmoji('🎯a'), isNull);
    expect(lastEmoji('क'), isNull);
    expect(lastEmoji(''), isNull);
  });

  test('toggleFilter goes from all to a subset and back', () {
    const all = [1, 2, 3];
    final two = toggleFilter(null, 1, all);
    expect(two, {2, 3});
    expect(toggleFilter(two, 1, all), isNull);
    expect(toggleFilter(const {}, 2, all), {2});
  });

  test('filterMatches: all includes uncategorised, a subset does not', () {
    expect(filterMatches(null, null), isTrue);
    expect(filterMatches({1}, 1), isTrue);
    expect(filterMatches({1}, 2), isFalse);
    expect(filterMatches({1}, null), isFalse);
    expect(filterMatches(const {}, 1), isFalse);
  });

  test('delete copy counts the transactions that move', () {
    expect(deleteCategoryMessage(0), startsWith('No transactions use it.'));
    expect(
      deleteCategoryMessage(1),
      startsWith('Its 1 transaction will be moved to Uncategorised.'),
    );
    expect(
      deleteCategoryMessage(12),
      startsWith('Its 12 transactions will be moved to Uncategorised.'),
    );
  });

  test('filter label and storage', () {
    expect(filterLabel(null), 'All categories');
    expect(filterLabel({1}), '1 category');
    expect(filterLabel({1, 2, 3}), '3 categories');
    expect(decodeFilter(encodeFilter({4, 9})), {4, 9});
    expect(decodeFilter(encodeFilter(const {})), isEmpty);
  });
}
