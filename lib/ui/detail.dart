import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/reminders.dart';
import '../data/ticket_repository.dart';
import '../domain/ticket.dart';
import 'design.dart';
import 'editor.dart';

class TicketDetail extends StatefulWidget {
  const TicketDetail({
    super.key,
    required this.ticket,
    required this.repository,
    required this.reminders,
    required this.offline,
  });

  final Ticket ticket;
  final TicketRepository repository;
  final Reminders reminders;
  final bool offline;

  @override
  State<TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<TicketDetail> {
  late Ticket _ticket;
  late Future<Uint8List> _photo;
  bool _busy = false;
  String? _note;
  bool _warning = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _loadPhoto();
  }

  void _loadPhoto() {
    _photo = widget.repository.photo(_ticket, localOnly: widget.offline);
  }

  Future<void> _edit() async {
    final result = await Navigator.push<SavedTicket>(
      context,
      MaterialPageRoute(
        builder: (_) => TicketEditor(
          repository: widget.repository,
          reminders: widget.reminders,
          ticket: _ticket,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _ticket = result.ticket;
      _note = reminderFeedback(result.reminder) ?? 'Cambios guardados.';
      _warning =
          result.reminder != ReminderResult.off &&
          result.reminder != ReminderResult.scheduled;
    });
  }

  Future<void> _remind() async {
    setState(() => _busy = true);
    final result = await widget.reminders.apply(_ticket, request: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = reminderFeedback(result);
      _warning = result != ReminderResult.scheduled;
    });
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('¿Eliminar el ticket?'),
        content: const Text('Se borrarán los datos de la compra y su foto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.remove(_ticket);
      try {
        await widget.reminders.cancel(_ticket);
      } catch (_) {
        // The next successful refresh also removes obsolete alarms.
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _note = 'El borrado quedó sin confirmar. Revisa la conexión y vuelve a intentarlo.';
          _warning = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _ticket.data;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del ticket'),
          actions: [
            if (!widget.offline)
              IconButton(
                tooltip: 'Eliminar ticket',
                onPressed: _busy ? null : _remove,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: SafeArea(
          child: BoundedList(
            children: [
              if (widget.offline) ...[
                const Notice(
                  'Viendo una copia local.',
                  icon: Icons.cloud_off_outlined,
                ),
                const SizedBox(height: 14),
              ],
              if (_note != null) ...[
                Notice(_note!, warning: _warning),
                const SizedBox(height: 14),
              ],
              Text(data.product, style: text.headlineLarge),
              const SizedBox(height: 6),
              Text(data.store, style: text.titleMedium?.copyWith(color: stone)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${labelMoney(data.cents)} MXN',
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text('Compra · ${labelDate(data.purchased)}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: cardDecoration(color: mint),
                child: ListTile(
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: pine,
                  ),
                  title: Text(
                    data.warranty == null
                        ? 'Sin garantía registrada'
                        : 'Garantía hasta ${labelDate(data.warranty!)}',
                  ),
                  subtitle: data.leadDays == null
                      ? null
                      : Text('Aviso configurado · ${data.leadDays} d antes'),
                ),
              ),
              if (data.leadDays != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _remind,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Programar aviso en este teléfono'),
                  ),
                ),
              const SizedBox(height: 22),
              Text('Comprobante', style: text.titleLarge),
              const SizedBox(height: 10),
              FutureBuilder<Uint8List>(
                future: _photo,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Notice(
                          widget.offline
                              ? 'La foto todavía no está en este teléfono. Ábrela con conexión para guardarla.'
                              : 'No pudimos recuperar la foto. Revisa la conexión e inténtalo de nuevo.',
                          warning: true,
                        ),
                        if (!widget.offline)
                          TextButton(
                            onPressed: () => setState(_loadPhoto),
                            child: const Text('Volver a cargar'),
                          ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 140,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final photo = snapshot.data!;
                  return Material(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: border),
                    ),
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _PhotoViewer(bytes: photo),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: Image.memory(
                              photo,
                              fit: BoxFit.contain,
                              semanticLabel: 'Foto del comprobante',
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Toca para ampliar'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (!widget.offline) ...[
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar datos'),
                ),
              ],
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comprobante')),
    body: SafeArea(
      child: SizedBox.expand(
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.memory(bytes, semanticLabel: 'Comprobante ampliable'),
          ),
        ),
      ),
    ),
  );
}
