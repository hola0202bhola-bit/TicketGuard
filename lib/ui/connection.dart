import 'package:flutter/material.dart';

import '../data/app_config.dart';
import 'design.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key, required this.onConnect, this.error});

  final Future<void> Function(AppConfig) onConnect;
  final String? error;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final config = AppConfig.parse(_url.text, _key.text);
    if (config == null) {
      setState(
        () => _error =
            'Ingresa una URL HTTPS y la clave publicable del proyecto.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConnect(config);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos guardar la conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BoundedList(
        children: [
          const SizedBox(height: 30),
          const Align(
            alignment: Alignment.centerLeft,
            child: BrandMark(size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            'Conecta TicketGuard',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ingresa los datos públicos del proyecto de Supabase configurado para TicketGuard.',
          ),
          const SizedBox(height: 24),
          if ((_error ?? widget.error) case final String message) ...[
            Notice(message, warning: true),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _url,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'URL del proyecto',
              hintText: 'https://proyecto.supabase.co',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            enabled: !_busy,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Clave publicable',
              hintText: 'sb_publishable_…',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _connect,
            child: const Text('Guardar conexión'),
          ),
        ],
      ),
    ),
  );
}
