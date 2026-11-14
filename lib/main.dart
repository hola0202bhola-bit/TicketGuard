import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/app_config.dart';
import 'data/reminders.dart';
import 'data/ticket_cache.dart';
import 'data/ticket_repository.dart';
import 'ui/connection.dart';
import 'ui/design.dart';
import 'ui/home.dart';
import 'ui/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  final root = await getApplicationSupportDirectory();
  final reminders = Reminders();
  try {
    await reminders.initialize();
  } catch (_) {
    // Ticket operations remain available if Android cannot initialize notifications.
  }
  runApp(TicketGuard(root: root, reminders: reminders));
}

class TicketGuard extends StatefulWidget {
  const TicketGuard({super.key, required this.root, required this.reminders});

  final Directory root;
  final Reminders reminders;

  @override
  State<TicketGuard> createState() => _TicketGuardState();
}

class _TicketGuardState extends State<TicketGuard> {
  SupabaseClient? _client;
  bool _loading = true;
  bool _fixedConnection = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_setup());
  }

  Future<void> _setup() async {
    try {
      final configured = AppConfig.parse(
        AppConfig.fromBuild.url,
        AppConfig.fromBuild.key,
        allowLocal: !kReleaseMode,
      );
      _fixedConnection = configured != null;
      final config = configured ?? await AppConfig.read(widget.root);
      if (config != null) await _initialize(config);
    } catch (_) {
      _error = 'No pudimos abrir la conexión guardada. Verifica los datos del proyecto.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initialize(AppConfig config) async {
    final instance = await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      debug: false,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    if (mounted) setState(() => _client = instance.client);
  }

  Future<void> _connect(AppConfig config) async {
    await config.write(widget.root);
    await _initialize(config);
  }

  Future<void> _resetConnection() async {
    await Supabase.instance.dispose();
    await AppConfig.clear(widget.root);
    if (mounted) setState(() => _client = null);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TicketGuard',
    debugShowCheckedModeBanner: false,
    theme: ticketTheme(),
    locale: const Locale('es', 'MX'),
    supportedLocales: const [Locale('es', 'MX')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: _loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _client == null
        ? ConnectionScreen(onConnect: _connect, error: _error)
        : _SessionGate(
            client: _client!,
            root: widget.root,
            reminders: widget.reminders,
            resetConnection: _fixedConnection ? null : _resetConnection,
          ),
  );
}

class _SessionGate extends StatefulWidget {
  const _SessionGate({
    required this.client,
    required this.root,
    required this.reminders,
    this.resetConnection,
  });

  final SupabaseClient client;
  final Directory root;
  final Reminders reminders;
  final VoidCallback? resetConnection;

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  StreamSubscription<AuthState>? _changes;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.client.auth.currentSession?.user;
    _changes = widget.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      final previous = _user;
      final next = event.session?.user;
      if (previous?.id == next?.id) return;
      if (previous != null) {
        unawaited(_clear(previous.id));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      setState(() => _user = next);
    }, onError: (Object _) {});
  }

  Future<void> _clear(String id) async {
    try {
      await widget.reminders.clear();
      await TicketCache(widget.root, id).clear();
    } catch (_) {
      // A different account never reads this directory.
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return LoginScreen(
        client: widget.client,
        onResetConnection: widget.resetConnection,
      );
    }
    return TicketHome(
      key: ValueKey(user.id),
      repository: TicketRepository(
        widget.client,
        user.id,
        TicketCache(widget.root, user.id),
      ),
      reminders: widget.reminders,
      signOut: () async {
        await _clear(user.id);
        await widget.client.auth.signOut().timeout(const Duration(seconds: 12));
      },
    );
  }
}
