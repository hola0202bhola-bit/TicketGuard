import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/receipt_image.dart';
import '../data/reminders.dart';
import '../data/ticket_repository.dart';
import '../domain/ticket.dart';
import 'design.dart';

typedef ReceiptPicker = Future<Uint8List?> Function(ImageSource);

Future<Uint8List?> pickReceipt(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    requestFullMetadata: false,
  );
  return file == null ? null : prepareReceipt(file);
}

class TicketEditor extends StatefulWidget {
  const TicketEditor({
    super.key,
    required this.repository,
    required this.reminders,
    this.ticket,
    this.pick = pickReceipt,
  });

  final TicketRepository repository;
  final Reminders reminders;
  final Ticket? ticket;
  final ReceiptPicker pick;

  @override
  State<TicketEditor> createState() => _TicketEditorState();
}

class _TicketEditorState extends State<TicketEditor> {
  final _form = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _product;
  late final TextEditingController _store;
  late final TextEditingController _amount;
  late DateTime _purchased;
  DateTime? _warranty;
  int? _leadDays;
  Uint8List? _photo;
  bool _busy = false;
  bool _picking = false;
  String? _note;

  bool get _editing => widget.ticket?.status == TicketStatus.ready;
  bool get _locked => _busy || _picking;

  @override
  void initState() {
    super.initState();
    final data = widget.ticket?.data;
    _id = widget.ticket?.id ?? const Uuid().v4();
    _product = TextEditingController(text: data?.product);
    _store = TextEditingController(text: data?.store);
    _amount = TextEditingController(
      text: data == null ? null : inputAmount(data.cents),
    );
    _purchased = data?.purchased ?? DateUtils.dateOnly(DateTime.now());
    _warranty = data?.warranty;
    _leadDays = data?.leadDays;
  }

  @override
  void dispose() {
    _product.dispose();
    _store.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _picking = true;
      _note = null;
    });
    try {
      final photo = await widget.pick(source);
      if (mounted && photo != null) setState(() => _photo = photo);
    } on InvalidReceipt {
      if (mounted) {
        setState(
          () => _note = 'Elige una foto JPG o PNG válida y de menor tamaño.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _note =
              'No se pudo abrir la imagen. Prueba con Cámara o Galería.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _date({required bool warranty}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = warranty ? _purchased : DateTime(1900);
    final last = warranty ? DateTime(2199, 12, 31) : today;
    final initial = warranty ? _warranty ?? _purchased : _purchased;
    final selected = await showDatePicker(
      context: context,
      firstDate: first,
      initialDate: initial.isAfter(last) ? last : initial,
      lastDate: last,
      helpText: warranty ? 'Vencimiento de garantía' : 'Fecha de compra',
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (warranty) {
        _warranty = selected;
      } else {
        _purchased = selected;
        if (_warranty?.isBefore(selected) ?? false) {
          _warranty = null;
          _leadDays = null;
        }
      }
    });
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    if (!_editing && _photo == null) {
      setState(() => _note = 'Agrega una foto del comprobante.');
      return;
    }
    if (!valid) return;
    if (_purchased.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      setState(
        () => _note = 'Selecciona una fecha de compra que no sea futura.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final data = TicketData(
        product: _product.text.trim(),
        store: _store.text.trim(),
        purchased: _purchased,
        cents: parseAmount(_amount.text)!,
        warranty: _warranty,
        leadDays: _leadDays,
      );
      final saved = _editing
          ? await widget.repository.update(widget.ticket!, data)
          : await widget.repository.create(_id, data, _photo!);
      if (!mounted) return;
      final reminder = await widget.reminders.apply(
        saved,
        request: _leadDays != null,
      );
      if (mounted) Navigator.pop(context, (ticket: saved, reminder: reminder));
    } catch (_) {
      if (mounted) {
        setState(() {
          _note = 'No se confirmó el guardado. Revisa la conexión y vuelve a guardar.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value) {
    final length = value?.trim().runes.length ?? 0;
    if (length == 0) return 'Completa este campo.';
    if (length > 100) return 'Usa hasta 100 caracteres.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Editar ticket' : 'Nuevo ticket';
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_locked,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Form(
            key: _form,
            child: BoundedList(
              children: [
                if (!_editing) ...[
                  Text('Comprobante', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Container(
                    height: 138,
                    clipBehavior: Clip.antiAlias,
                    decoration: cardDecoration(color: mint),
                    child: _photo == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.document_scanner_outlined,
                                color: pine,
                                size: 35,
                              ),
                              SizedBox(height: 8),
                              Text('Agrega la foto de tu ticket'),
                            ],
                          )
                        : Image.memory(
                            _photo!,
                            fit: BoxFit.contain,
                            semanticLabel: 'Vista previa del comprobante',
                          ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _locked
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Cámara'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _locked
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ],
                  ),
                  if (_picking) const LinearProgressIndicator(),
                  const SizedBox(height: 22),
                ],
                Text('Datos de compra', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('product'),
                  enabled: !_locked,
                  controller: _product,
                  validator: _required,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Producto'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('store'),
                  enabled: !_locked,
                  controller: _store,
                  validator: _required,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Tienda'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('amount'),
                  enabled: !_locked,
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => parseAmount(value ?? '') == null
                      ? 'Escribe un importe mayor que cero, con hasta dos decimales.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Importe (MXN)',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                _dateTile(
                  'Fecha de compra',
                  labelDate(_purchased),
                  () => _date(warranty: false),
                ),
                const SizedBox(height: 24),
                Text('Garantía', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _dateTile(
                  'Vencimiento',
                  _warranty == null ? 'Agregar fecha' : labelDate(_warranty!),
                  () => _date(warranty: true),
                  clear: _warranty == null
                      ? null
                      : () => setState(() {
                          _warranty = null;
                          _leadDays = null;
                        }),
                ),
                if (_warranty != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _leadDays ?? 0,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Recordatorio',
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Sin aviso')),
                      DropdownMenuItem(value: 7, child: Text('7 días antes')),
                      DropdownMenuItem(value: 1, child: Text('1 día antes')),
                    ],
                    onChanged: _locked
                        ? null
                        : (value) => setState(() {
                            _leadDays = value == 0 ? null : value;
                          }),
                  ),
                  if (_leadDays != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'A partir de las 09:00, hora local del teléfono.',
                    ),
                  ],
                ],
                const SizedBox(height: 22),
                if (_note != null) ...[
                  Notice(_note!, warning: true),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _locked ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_busy ? 'Guardando…' : 'Guardar ticket'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile(
    String title,
    String value,
    VoidCallback onTap, {
    VoidCallback? clear,
  }) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(19),
      side: const BorderSide(color: border),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: const Icon(Icons.calendar_today_outlined, color: pine),
      title: Text(title),
      subtitle: Text(value),
      onTap: _locked ? null : onTap,
      trailing: clear == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: 'Quitar garantía',
              onPressed: _locked ? null : clear,
              icon: const Icon(Icons.close),
            ),
    ),
  );
}

typedef SavedTicket = ({Ticket ticket, ReminderResult reminder});
