import '../models.dart';

/// DD/MM/YY, DD-MMM-YY or DD-MM-YY (SPEC 5.1).
const datePattern = r'\d{2}[/-](?:\d{2}|[A-Z]{3})[/-]\d{2}';

/// Named groups: amount, date, last4, party, and optionally ref.
/// Patterns run on normalised text, so line breaks are single spaces.
class MessageTemplate {
  MessageTemplate(this.type, String pattern)
    : pattern = RegExp(pattern, caseSensitive: false);

  final TransactionType type;
  final RegExp pattern;
}
