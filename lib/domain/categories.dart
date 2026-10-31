import 'package:characters/characters.dart';

/// Default colour of a new category and the first swatch (reference 13).
const defaultCategoryColor = 0xFFE8737A;
const defaultCategoryEmoji = '🎯';

/// SPEC 5.12 category colours; seeds and quick adds cycle through them.
const categoryColors = [
  0xFF5AA9F5,
  0xFFE8737A,
  0xFF7B6CF6,
  0xFFF2A65A,
  0xFFF0C36A,
  0xFFB36CF6,
  0xFFF07AC8,
  0xFF4CC38A,
];

/// The 42 swatches of the new-category sheet, read off reference 13.
const categoryPalette = [
  0xFFE8737A,
  0xFFE46C68,
  0xFFD4736D,
  0xFFB9564B,
  0xFFE98A6E,
  0xFFE69C6C,
  0xFFEC9650, //
  0xFFE8A23E,
  0xFFD08F33,
  0xFFC05A24,
  0xFFA1501B,
  0xFF993A1F,
  0xFFF2CB4A,
  0xFFF3BD4A, //
  0xFFEDD36A,
  0xFFF0C672,
  0xFF98893E,
  0xFF8F6B2C,
  0xFFB1E255,
  0xFFAECB6A,
  0xFFAFB65A, //
  0xFF9EA878,
  0xFF7ADE88,
  0xFF78C65C,
  0xFF66CF9A,
  0xFF54A968,
  0xFF66D1BE,
  0xFF5FCDEA, //
  0xFF4FB4FA,
  0xFF6FA6F8,
  0xFF7E8AF0,
  0xFF6C68F5,
  0xFF9F8AF0,
  0xFFB281F2,
  0xFFB16CF8, //
  0xFF7866AD,
  0xFF9059AE,
  0xFFD478F0,
  0xFF914085,
  0xFFE070AE,
  0xFF62708A,
  0xFFFFFFFF, //
];

typedef QuickAdd = ({String name, String emoji});

/// SPEC 5.14 suggestions.
const expenseQuickAdds = <QuickAdd>[
  (name: 'Miscellaneous', emoji: '📁'),
  (name: 'Loan', emoji: '🏦'),
  (name: 'Bills', emoji: '🧾'),
  (name: 'Healthcare', emoji: '❤️'),
  (name: 'Taxi', emoji: '🚕'),
  (name: 'Public transport', emoji: '🚝'),
  (name: 'Pets', emoji: '🐶'),
  (name: 'Gifts', emoji: '🎁'),
  (name: 'Travel', emoji: '🌍'),
  (name: 'Education', emoji: '🎓'),
  (name: 'Kids', emoji: '🧸'),
  (name: 'Donations', emoji: '🤝'),
];

const incomeQuickAdds = <QuickAdd>[
  (name: 'Part-time', emoji: '💼'),
  (name: 'Savings', emoji: '💵'),
  (name: 'Emergency fund', emoji: '🤕'),
  (name: 'Tips', emoji: '🪙'),
  (name: 'Retirement fund', emoji: '🏝️'),
  (name: 'Refunds', emoji: '💸'),
  (name: 'Interest', emoji: '📈'),
];

/// Names are unique per type, ignoring case and outer spaces (SPEC 5.14).
bool nameTaken(Iterable<String> names, String name) {
  final wanted = name.trim().toLowerCase();
  return names.any((n) => n.trim().toLowerCase() == wanted);
}

bool _isEmoji(String grapheme) => grapheme.runes.any(
  (r) =>
      r == 0x20E3 || // keycap
      r == 0x3030 ||
      r == 0x303D ||
      r == 0x3297 ||
      r == 0x3299 ||
      (r >= 0x203C && r <= 0x2049) ||
      (r >= 0x2190 && r <= 0x2BFF) ||
      (r >= 0x1F000 && r <= 0x1FAFF),
);

/// The last emoji typed into the emoji field, or null if the text ends in
/// anything else, as iOS cannot limit a field to the emoji keyboard.
String? lastEmoji(String text) {
  if (text.isEmpty) return null;
  final last = text.characters.last;
  return _isEmoji(last) ? last : null;
}

/// The delete confirmation's copy (SPEC 5.14): nothing is lost but the label.
String deleteCategoryMessage(int transactions) {
  final moved = switch (transactions) {
    0 => 'No transactions use it.',
    1 => 'Its 1 transaction will be moved to Uncategorised.',
    final n => 'Its $n transactions will be moved to Uncategorised.',
  };
  return '$moved Its budget limits will be removed. This cannot be undone.';
}

/// Null means every category, uncategorised rows included. A set narrows to
/// exactly those categories (SPEC 5.14).
bool filterMatches(Set<int>? filter, int? categoryId) =>
    filter == null || filter.contains(categoryId);

String filterLabel(Set<int>? filter) => switch (filter?.length) {
  null => 'All categories',
  1 => '1 category',
  final n => '$n categories',
};

/// Flips a tile. From "all" every tile counts as ticked, and ticking the last
/// one returns to "all", so uncategorised rows come back.
Set<int>? toggleFilter(Set<int>? filter, int id, Iterable<int> allIds) {
  final all = allIds.toSet();
  final next = {...filter ?? all};
  if (!next.remove(id)) next.add(id);
  return next.containsAll(all) ? null : next;
}

String encodeFilter(Set<int> filter) => filter.join(',');

Set<int> decodeFilter(String text) =>
    text.split(',').map(int.tryParse).nonNulls.toSet();
