import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ticketguard/data/reminders.dart';
import 'package:ticketguard/data/ticket_cache.dart';
import 'package:ticketguard/data/ticket_repository.dart';
import 'package:ticketguard/domain/ticket.dart';
import 'package:ticketguard/ui/design.dart';
import 'package:ticketguard/ui/home.dart';

const owner = '3c77b225-3ad3-4df5-bce4-cbefa76a6eeb';
const id = 'ddda2891-290f-4bee-97bc-ac2bce6c3db1';

class TestRepository extends TicketRepository {
  TestRepository(this.client)
    : super(client, owner, TicketCache(Directory.systemTemp, owner));

  final SupabaseClient client;
  final tickets = <Ticket>[];
  final photoBytes = File('docs/fixtures/ticket-ensayo.jpg').readAsBytesSync();
  bool network = true;
  bool failNext = false;
  int createCalls = 0;
  final attempts = <String>[];

  @override
  Future<List<Ticket>?> cachedTickets() async => List.of(tickets);

  @override
  Future<List<Ticket>> sync() async {
    if (!network) throw const SocketException('Offline');
    return List.of(tickets);
  }

  @override
  Future<Ticket> create(String id, TicketData data, Uint8List photo) async {
    createCalls++;
    attempts.add(id);
    if (failNext) {
      failNext = false;
      throw const SocketException('Offline');
    }
    final ticket = Ticket(
      id: id,
      owner: owner,
      notificationId: createCalls,
      status: TicketStatus.ready,
      data: data,
    );
    tickets.add(ticket);
    return ticket;
  }

  @override
  Future<Uint8List> photo(Ticket ticket, {required bool localOnly}) async =>
      photoBytes;
}

void main() {
  late TestRepository repository;
  setUpAll(() => initializeDateFormatting('es_MX'));

  setUp(() {
    repository = TestRepository(
      SupabaseClient('https://example.com', 'unused'),
    );
  });
  tearDown(() => repository.client.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ticketTheme(),
        home: TicketHome(
          repository: repository,
          reminders: Reminders(),
          signOut: () async {},
          pick: (_) async => repository.photoBytes,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Captura, valida, reintenta con el mismo UUID y encuentra la compra',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      expect(find.text('Aún no tienes tickets'), findsOneWidget);
      await tester.tap(find.text('Nuevo ticket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cámara'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('product')), 'Audífonos');
      await tester.enterText(find.byKey(const Key('store')), 'Tienda Norte');
      await tester.enterText(find.byKey(const Key('amount')), '0');
      final save = find.text('Guardar ticket');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.createCalls, 0);
      final amount = find.byKey(const Key('amount'));
      await tester.scrollUntilVisible(
        amount,
        -220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(amount, '1299,00');
      repository.failNext = true;
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.textContaining('No se confirmó el guardado'), findsOneWidget);
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.attempts.toSet(), hasLength(1));
      expect(find.text('Detalle del ticket'), findsOneWidget);
      expect(find.text('Audífonos'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'audifonos norte');
      await tester.pumpAndSettle();
      expect(find.text('Audífonos'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'sin resultado');
      await tester.pumpAndSettle();
      expect(find.text('Sin coincidencias'), findsOneWidget);
    },
  );

  testWidgets('La copia local permite abrir detalle y foto sin red', (
    tester,
  ) async {
    repository.network = false;
    repository.tickets.add(
      Ticket(
        id: id,
        owner: owner,
        notificationId: 3,
        status: TicketStatus.ready,
        data: TicketData(
          product: 'Audífonos',
          store: 'Tienda Norte',
          purchased: DateTime(2026, 11, 13),
          cents: 129900,
        ),
      ),
    );
    await open(tester);
    expect(find.textContaining('Copia local.'), findsOneWidget);
    expect(find.text('Nuevo ticket'), findsNothing);
    await tester.tap(find.text('Audífonos'));
    await tester.pumpAndSettle();
    expect(find.text('Viendo una copia local.'), findsOneWidget);
    expect(find.text('Editar datos'), findsNothing);
    expect(find.byTooltip('Eliminar ticket'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
