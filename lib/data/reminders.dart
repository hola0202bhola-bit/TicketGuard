import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

import '../domain/ticket.dart';

enum ReminderResult { off, scheduled, past, permission, unavailable }

tz.TZDateTime? reminderDate(Ticket ticket, tz.Location zone) {
  final due = ticket.data.warranty;
  final days = ticket.data.leadDays;
  if (ticket.status != TicketStatus.ready || due == null || days == null) {
    return null;
  }
  return tz.TZDateTime(zone, due.year, due.month, due.day - days, 9);
}

class Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  bool _initialized = false;

  Future<void> initialize() async {
    zones.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    _initialized = true;
  }

  Future<tz.Location> _zone() async {
    final info = await FlutterTimezone.getLocalTimezone();
    return tz.getLocation(info.identifier);
  }

  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'warranty_reminders',
      'Garantías',
      channelDescription: 'Recordatorios de vencimiento de garantías',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
    ),
  );

  Future<ReminderResult> apply(Ticket ticket, {bool request = false}) async {
    if (!_initialized) return ReminderResult.unavailable;
    try {
      await _plugin.cancel(ticket.notificationId);
      if (ticket.data.leadDays == null) return ReminderResult.off;
      final zone = await _zone();
      final date = reminderDate(ticket, zone);
      if (date == null) return ReminderResult.off;
      if (!date.isAfter(tz.TZDateTime.now(zone))) return ReminderResult.past;
      if (request) await _android?.requestNotificationsPermission();
      if (await _android?.areNotificationsEnabled() != true) {
        return ReminderResult.permission;
      }
      await _plugin.zonedSchedule(
        ticket.notificationId,
        'Aviso de garantía',
        'Abre TicketGuard para consultar tus garantías.',
        date,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return ReminderResult.scheduled;
    } catch (_) {
      return ReminderResult.unavailable;
    }
  }

  Future<void> reconcile(List<Ticket> tickets) async {
    if (!_initialized) return;
    final valid = tickets
        .where((t) => t.status == TicketStatus.ready && t.data.leadDays != null)
        .map((t) => t.notificationId)
        .toSet();
    final pending = await _plugin.pendingNotificationRequests();
    for (final item in pending.where((item) => !valid.contains(item.id))) {
      await _plugin.cancel(item.id);
    }
    for (final ticket in tickets.where(
      (t) => valid.contains(t.notificationId),
    )) {
      await apply(ticket);
    }
  }

  Future<void> cancel(Ticket ticket) async {
    if (_initialized) await _plugin.cancel(ticket.notificationId);
  }

  Future<void> clear() async {
    if (_initialized) await _plugin.cancelAll();
  }
}

String? reminderFeedback(ReminderResult result) => switch (result) {
  ReminderResult.off => null,
  ReminderResult.scheduled => 'Aviso programado en este teléfono.',
  ReminderResult.past => 'La fecha del aviso ya pasó.',
  ReminderResult.permission =>
    'Activa las notificaciones de TicketGuard en los ajustes de Android.',
  ReminderResult.unavailable =>
    'Android no pudo programar el aviso. Puedes reintentarlo.',
};
