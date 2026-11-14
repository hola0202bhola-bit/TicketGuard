import 'package:intl/intl.dart';

enum TicketStatus { pending, ready, deleting }

enum TicketFilter { all, dueSoon }

class Ticket {
  const Ticket({
    required this.id,
    required this.owner,
    required this.notificationId,
    required this.status,
    required this.data,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json['id'] as String,
    owner: json['user_id'] as String,
    notificationId: json['notification_id'] as int,
    status: TicketStatus.values.byName(json['status'] as String),
    data: TicketData(
      product: json['product'] as String,
      store: json['store'] as String,
      purchased: DateTime.parse(json['purchased_on'] as String),
      cents: json['amount_cents'] as int,
      warranty: json['warranty_until'] == null
          ? null
          : DateTime.parse(json['warranty_until'] as String),
      leadDays: json['lead_days'] as int?,
    ),
  );

  final String id;
  final String owner;
  final int notificationId;
  final TicketStatus status;
  final TicketData data;

  String get photoPath => '$owner/$id.jpg';

  Map<String, Object?> toJson() => {
    'id': id,
    'user_id': owner,
    'notification_id': notificationId,
    'status': status.name,
    ...data.toJson(),
  };

  bool matches(String input) {
    final haystack = normalizeSearch('${data.product} ${data.store}');
    return normalizeSearch(input)
        .split(RegExp(r'\s+'))
        .every(haystack.contains);
  }

  int? daysLeft(DateTime now) {
    final date = data.warranty;
    if (date == null) return null;
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  bool isDueSoon(DateTime now) {
    final days = daysLeft(now);
    return status == TicketStatus.ready &&
        days != null &&
        days >= 0 &&
        days <= 30;
  }
}

class TicketData {
  const TicketData({
    required this.product,
    required this.store,
    required this.purchased,
    required this.cents,
    this.warranty,
    this.leadDays,
  });

  final String product;
  final String store;
  final DateTime purchased;
  final int cents;
  final DateTime? warranty;
  final int? leadDays;

  Map<String, Object?> toJson() => {
    'product': product,
    'store': store,
    'purchased_on': isoDate(purchased),
    'amount_cents': cents,
    'warranty_until': warranty == null ? null : isoDate(warranty!),
    'lead_days': leadDays,
  };
}

String isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
String labelDate(DateTime date) => DateFormat('d MMM y', 'es_MX').format(date);
String labelMoney(int cents) => NumberFormat.simpleCurrency(
  locale: 'es_MX',
  name: 'MXN',
).format(cents / 100);

String normalizeSearch(String value) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  return value.toLowerCase().trim().replaceAllMapped(
    RegExp('[áéíóúü]'),
    (match) => accents[match[0]]!,
  );
}

int? parseAmount(String raw) {
  final value = raw.trim();
  if (!RegExp(r'^\d{1,7}(?:[.,]\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split(RegExp(r'[.,]'));
  final decimals = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final cents = int.parse(parts[0]) * 100 + decimals;
  return cents > 0 ? cents : null;
}

String inputAmount(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
