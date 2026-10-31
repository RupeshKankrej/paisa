enum TransactionType { debit, credit }

enum TransactionSource { sms, manual, share }

enum IngestStatus { parsed, ignored, failed }

enum Bank { hdfc }

enum ExpenseFilter {
  all,
  expenses,
  income,
  uncategorised;

  bool matches(TransactionType type, int? categoryId) => switch (this) {
    all => true,
    expenses => type == TransactionType.debit,
    income => type == TransactionType.credit,
    uncategorised => categoryId == null,
  };
}
