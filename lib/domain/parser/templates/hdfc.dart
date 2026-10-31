import '../../models.dart';
import '../template.dart';

final hdfcTemplates = [
  MessageTemplate(
    TransactionType.debit,
    r'Sent Rs\.(?<amount>[\d,]+\.?\d*) From HDFC Bank A/C \*(?<last4>\d{4}) '
    r'To (?<party>.+?) On (?<date>'
    '$datePattern'
    r') Ref (?<ref>\d+)',
  ),
  MessageTemplate(
    TransactionType.credit,
    r'INR (?<amount>[\d,]+\.?\d*) deposited in HDFC Bank A/c XX(?<last4>\d{4}) '
    r'on (?<date>'
    '$datePattern'
    r') for (?<party>.+?)\.Avl bal',
  ),
];
