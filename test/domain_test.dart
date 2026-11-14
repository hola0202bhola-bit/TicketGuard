import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ticketguard/data/app_config.dart';
import 'package:ticketguard/data/receipt_image.dart';
import 'package:ticketguard/data/reminders.dart';
import 'package:ticketguard/data/ticket_cache.dart';
import 'package:ticketguard/domain/ticket.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

const id = 'd7ed0c71-2123-4f2e-8090-a0ed7c785dbc';
const user = 'afec7c80-d65a-4ebb-8b50-d5e9af073b8e';

Ticket sample({TicketStatus status = TicketStatus.ready}) => Ticket(
  id: id,
  owner: user,
  notificationId: 12,
  status: status,
  data: TicketData(
    product: 'Audífonos',
    store: 'Tienda Centro',
    purchased: DateTime(2026, 11, 1),
    cents: 129900,
    warranty: DateTime(2027, 1, 2),
    leadDays: 7,
  ),
);

void main() {
  test('El importe se guarda en centavos y se valida sin coma flotante', () {
    expect(parseAmount('1299,01'), 129901);
    expect(parseAmount('0.01'), 1);
    expect(parseAmount(' 23.4 '), 2340);
    expect(parseAmount('9999999.99'), 999999999);
    for (final invalid in [
      '',
      '0',
      '-1.50',
      '1.234',
      '1e2',
      '10000000',
      '1,000.00',
    ]) {
      expect(parseAmount(invalid), isNull, reason: invalid);
    }
  });

  test('El filtro por palabras ignora mayúsculas y acentos', () {
    final ticket = sample();
    expect(ticket.matches('CENTRO audifonos'), isTrue);
    expect(ticket.matches('  '), isTrue);
    expect(ticket.matches('otro producto'), isFalse);
    expect(ticket.isDueSoon(DateTime(2026, 12, 3)), isTrue);
    expect(ticket.isDueSoon(DateTime(2026, 12, 2)), isFalse);
    expect(ticket.isDueSoon(DateTime(2027, 1, 3)), isFalse);
  });

  test('El aviso utiliza la fecha civil local al cruzar mes o año', () {
    zones.initializeTimeZones();
    final zone = tz.getLocation('America/Mexico_City');
    final alarm = reminderDate(sample(), zone)!;
    expect((alarm.year, alarm.month, alarm.day, alarm.hour), (2026, 12, 26, 9));
    expect(reminderDate(sample(status: TicketStatus.deleting), zone), isNull);
  });

  test('La conexión de distribución exige HTTPS y clave de cliente', () {
    expect(
      AppConfig.parse('https://example.com', 'sb_publishable_example'),
      isNotNull,
    );
    expect(AppConfig.parse('https://example.com', 'sb_secret_example'), isNull);
    expect(
      AppConfig.parse('https://example.com/path', 'sb_publishable_example'),
      isNull,
    );
    expect(
      AppConfig.parse('http://10.0.2.2:54321', 'sb_publishable_example'),
      isNull,
    );
    expect(
      AppConfig.parse(
        'http://10.0.2.2:54321',
        'sb_publishable_example',
        allowLocal: true,
      ),
      isNotNull,
    );
  });

  test('La foto queda como JPEG acotado y sin EXIF original', () {
    final original = image.Image(width: 2550, height: 18);
    original.exif.imageIfd.make = 'GPS privado';
    final result = normalizeReceipt(image.encodeJpg(original));
    final decoded = image.decodeJpg(result)!;
    expect(decoded.width, 2200);
    expect(decoded.exif.imageIfd.make, isNull);
    expect(result.length, lessThanOrEqualTo(maxReceiptBytes));
    expect(
      () => normalizeReceipt(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<InvalidReceipt>()),
    );
  });

  test(
    'La copia local persiste, aísla cuentas y retira fotografías obsoletas',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'ticketguard-cache-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final cache = TicketCache(folder, user);
      await cache.writeIndex([sample()]);
      await cache.writePhoto(id, Uint8List.fromList([1, 2, 3]));
      final reopened = TicketCache(folder, user);
      expect((await reopened.readIndex())!.single.data.product, 'Audífonos');
      expect(await reopened.readPhoto(id), [1, 2, 3]);
      expect(await TicketCache(folder, 'otra-cuenta').readIndex(), isNull);
      await reopened.writeIndex([]);
      expect(await reopened.readPhoto(id), isNull);
      await reopened.clear();
      expect(await reopened.readIndex(), isNull);
    },
  );
}
