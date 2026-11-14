import 'dart:async';

import 'package:flutter/material.dart';

import '../data/reminders.dart';
import '../data/ticket_repository.dart';
import '../domain/ticket.dart';
import 'design.dart';
import 'detail.dart';
import 'editor.dart';

class TicketHome extends StatefulWidget {
  const TicketHome({
    super.key,
    required this.repository,
    required this.reminders,
    required this.signOut,
    this.pick = pickReceipt,
  });

  final TicketRepository repository;
  final Reminders reminders;
  final Future<void> Function() signOut;
  final ReceiptPicker pick;

  @override
  State<TicketHome> createState() => _TicketHomeState();
}

class _TicketHomeState extends State<TicketHome> {
  final _search = TextEditingController();
  List<Ticket>? _tickets;
  TicketFilter _filter = TicketFilter.all;
  bool _offline = false;
  bool _loading = true;
  bool _signingOut = false;

  bool get _canWrite => !_loading && !_offline && !_signingOut;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_signingOut) return;
    setState(() => _loading = true);
    try {
      final cached = await widget.repository.cachedTickets();
      if (!mounted) return;
      if (_tickets == null && cached != null) {
        setState(() {
          _tickets = cached;
          _offline = true;
        });
      }
      final fresh = await widget.repository.sync();
      if (!mounted) return;
      setState(() {
        _tickets = fresh;
        _offline = false;
      });
      try {
        await widget.reminders.reconcile(fresh);
      } catch (_) {
        // The next refresh or a manual retry can reschedule reminders.
      }
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _open(Ticket ticket) async {
    FocusScope.of(context).unfocus();
    if (ticket.status != TicketStatus.ready) {
      if (!_canWrite) return;
      if (ticket.status == TicketStatus.deleting) {
        await _removeIncomplete(ticket);
      } else {
        await _newTicket(ticket);
      }
      return;
    }
    final offline = _offline;
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetail(
          ticket: ticket,
          repository: widget.repository,
          reminders: widget.reminders,
          offline: offline,
        ),
      ),
    );
    if (!mounted) return;
    if (deleted == true) _message('Ticket eliminado.');
    if (!offline && !_loading) await _refresh();
  }

  Future<void> _newTicket([Ticket? ticket]) async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<SavedTicket>(
      context,
      MaterialPageRoute(
        builder: (_) => TicketEditor(
          repository: widget.repository,
          reminders: widget.reminders,
          ticket: ticket,
          pick: widget.pick,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _tickets = [
          result.ticket,
          ...?_tickets?.where((item) => item.id != result.ticket.id),
        ];
        _search.clear();
        _filter = TicketFilter.all;
      });
      final note = reminderFeedback(result.reminder);
      _message(note == null ? 'Ticket guardado.' : 'Ticket guardado. $note');
      await _open(result.ticket);
    } else {
      await _refresh();
    }
  }

  Future<void> _removeIncomplete(Ticket ticket) async {
    setState(() => _loading = true);
    try {
      await widget.repository.remove(ticket);
      await widget.reminders.cancel(ticket);
      if (mounted) _message('Ticket eliminado.');
    } catch (_) {
      if (mounted) _message('No se confirmó el borrado. Puedes reintentarlo.');
    } finally {
      if (mounted) await _refresh();
    }
  }

  Future<void> _exit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Se quitarán las copias locales y los avisos de este teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    setState(() => _signingOut = true);
    try {
      await widget.signOut();
    } catch (_) {
      if (mounted) _message('No pudimos completar el cierre de sesión.');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final all = _tickets ?? [];
    final ready = all.where((ticket) => ticket.status == TicketStatus.ready);
    final incomplete = all.where(
      (ticket) => ticket.status != TicketStatus.ready,
    );
    final due = ready.where((ticket) => ticket.isDueSoon(now)).length;
    final visible = ready.where(
      (ticket) =>
          ticket.matches(_search.text) &&
          (_filter == TicketFilter.all || ticket.isDueSoon(now)),
    );
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: const Row(
          children: [
            BrandMark(size: 34),
            SizedBox(width: 10),
            Flexible(
              child: Text('TicketGuard', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading || _signingOut ? null : _refresh,
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sincronizar',
          ),
          IconButton(
            onPressed: _loading || _signingOut ? null : _exit,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: BoundedList(
          onRefresh: _loading || _signingOut ? null : _refresh,
          bottom: 100,
          children: [
            const SizedBox(height: 9),
            Text('Mis tickets', style: text.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Consulta tus compras y sus garantías.',
              style: text.bodyLarge?.copyWith(color: stone),
            ),
            const SizedBox(height: 22),
            if (_loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            if (_offline) ...[
              Notice(
                _tickets == null
                    ? 'No pudimos conectar. Sincroniza para cargar tus tickets.'
                    : 'Copia local. Conéctate y sincroniza para hacer cambios.',
                icon: Icons.cloud_off_outlined,
                warning: true,
              ),
              const SizedBox(height: 12),
            ],
            if (_tickets != null) ...[
              InkWell(
                borderRadius: BorderRadius.circular(19),
                onTap: () => setState(() => _filter = TicketFilter.dueSoon),
                child: Ink(
                  decoration: cardDecoration(color: mint),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: pine,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.event_available_outlined, size: 21),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Próximas a vencer', style: text.titleMedium),
                            Text(
                              due == 1
                                  ? '1 garantía en los próximos 30 días'
                                  : '$due garantías en los próximos 30 días',
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: pine),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Buscar producto o tienda',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _filter == TicketFilter.all,
                    onSelected: (_) =>
                        setState(() => _filter = TicketFilter.all),
                  ),
                  FilterChip(
                    label: const Text('Por vencer'),
                    selected: _filter == TicketFilter.dueSoon,
                    onSelected: (_) =>
                        setState(() => _filter = TicketFilter.dueSoon),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              if (visible.isEmpty)
                _Empty(
                  icon: ready.isEmpty
                      ? Icons.receipt_long_outlined
                      : Icons.search_off_rounded,
                  title: ready.isEmpty
                      ? 'Aún no tienes tickets'
                      : 'Sin coincidencias',
                  detail: ready.isEmpty
                      ? 'Toma una foto y registra tu primera compra.'
                      : 'Prueba otra búsqueda o cambia el filtro.',
                ),
              for (final ticket in visible) ...[
                _TicketCard(
                  ticket: ticket,
                  now: now,
                  onTap: () => _open(ticket),
                ),
                const SizedBox(height: 9),
              ],
              if (incomplete.isNotEmpty && !_offline) ...[
                const SizedBox(height: 15),
                Text('Operaciones pendientes', style: text.titleMedium),
                const SizedBox(height: 6),
                for (final ticket in incomplete)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ticket.data.product),
                    subtitle: Text(
                      ticket.status == TicketStatus.deleting
                          ? 'Reintentar borrado'
                          : 'Completar guardado',
                    ),
                    enabled: _canWrite,
                    trailing: ticket.status == TicketStatus.pending
                        ? IconButton(
                            tooltip: 'Descartar ticket pendiente',
                            onPressed: _canWrite
                                ? () => _confirmDiscard(ticket)
                                : null,
                            icon: const Icon(Icons.close),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => _open(ticket),
                  ),
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              backgroundColor: pine,
              foregroundColor: Colors.white,
              onPressed: _newTicket,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo ticket'),
            )
          : null,
    );
  }

  Future<void> _confirmDiscard(Ticket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar el ticket pendiente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await _removeIncomplete(ticket);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    decoration: cardDecoration(),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: Column(
      children: [
        Icon(icon, color: pine, size: 32),
        const SizedBox(height: 9),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(detail, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.now,
    required this.onTap,
  });

  final Ticket ticket;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = ticket.daysLeft(now);
    final due = switch (days) {
      null => 'Sin garantía',
      < 0 => 'Garantía vencida',
      0 => 'Vence hoy',
      1 => 'Vence mañana',
      <= 30 => 'Vence en $days días',
      _ => 'Garantía vigente',
    };
    final soon = ticket.isDueSoon(now);
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: mint,
                foregroundColor: pine,
                child: Icon(Icons.receipt_outlined, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket.data.product, style: text.titleMedium),
                    Text(
                      '${ticket.data.store} · ${labelDate(ticket.data.purchased)}',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${labelMoney(ticket.data.cents)} MXN',
                      style: text.titleMedium?.copyWith(color: pine),
                    ),
                    Text(
                      due,
                      style: text.bodySmall?.copyWith(
                        color: soon ? amber : stone,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              const Icon(Icons.chevron_right_rounded, color: stone),
            ],
          ),
        ),
      ),
    );
  }
}
