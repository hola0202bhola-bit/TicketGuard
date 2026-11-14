import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ticket.dart';
import 'ticket_cache.dart';

class TicketRepository {
  TicketRepository(this._client, this.owner, this._cache);

  final SupabaseClient _client;
  final String owner;
  final TicketCache _cache;

  static const _timeout = Duration(seconds: 12);
  static const _pageSize = 200;

  SupabaseQueryBuilder get _tickets => _client.from('tickets');
  StorageFileApi get _photos => _client.storage.from('receipt-images');

  Future<List<Ticket>?> cachedTickets() => _cache.readIndex();

  Future<List<Ticket>> sync() async {
    final tickets = <Ticket>[];
    for (var start = 0; ; start += _pageSize) {
      final rows = await _tickets
          .select()
          .eq('user_id', owner)
          .order('notification_id')
          .range(start, start + _pageSize - 1)
          .timeout(_timeout);
      tickets.addAll(rows.map(Ticket.fromJson));
      if (rows.length < _pageSize) break;
    }
    tickets.sort((a, b) {
      final byDate = b.data.purchased.compareTo(a.data.purchased);
      return byDate == 0
          ? b.notificationId.compareTo(a.notificationId)
          : byDate;
    });
    await _bestEffort(() => _cache.writeIndex(tickets));
    return tickets;
  }

  Future<Ticket> create(String id, TicketData data, Uint8List photo) async {
    final path = '$owner/$id.jpg';
    await _tickets
        .upsert(
          {'id': id, 'user_id': owner, ...data.toJson()},
          onConflict: 'id',
          ignoreDuplicates: true,
        )
        .timeout(_timeout);
    final current = await _read(id);
    if (current.status == TicketStatus.deleting) {
      throw const TicketUnavailable();
    }
    if (current.status == TicketStatus.pending) {
      await _photos
          .uploadBinary(
            path,
            photo,
            fileOptions: const FileOptions(
              cacheControl: '0',
              contentType: 'image/jpeg',
              upsert: true,
            ),
            retryAttempts: 0,
          )
          .timeout(_timeout);
    }
    // Use the same identifier after an interrupted response, including after finalization.
    final saved = await _update(id, {
      ...data.toJson(),
      'status': TicketStatus.ready.name,
    });
    // Read from Storage even after retry so the local image matches the published object.
    await _bestEffort(() async {
      final bytes = await _photos.download(path).timeout(_timeout);
      await _cache.writePhoto(id, bytes);
    });
    await _bestEffort(() => _updateCache(saved));
    return saved;
  }

  Future<Ticket> update(Ticket ticket, TicketData data) async {
    final saved = await _update(ticket.id, data.toJson(), onlyReady: true);
    await _bestEffort(() => _updateCache(saved));
    return saved;
  }

  Future<Ticket> _read(String id) async {
    final row = await _tickets
        .select()
        .eq('user_id', owner)
        .eq('id', id)
        .maybeSingle()
        .timeout(_timeout);
    if (row == null) throw const TicketUnavailable();
    return Ticket.fromJson(row);
  }

  Future<Ticket> _update(
    String id,
    Map<String, Object?> updates, {
    bool onlyReady = false,
  }) async {
    var request = _tickets.update(updates).eq('user_id', owner).eq('id', id);
    if (onlyReady) request = request.eq('status', 'ready');
    final row = await request.select().maybeSingle().timeout(_timeout);
    if (row == null) throw const TicketUnavailable();
    return Ticket.fromJson(row);
  }

  Future<void> _updateCache(Ticket ticket) async {
    final existing = await _cache.readIndex() ?? [];
    await _cache.writeIndex([
      ticket,
      ...existing.where((other) => other.id != ticket.id),
    ]);
  }

  Future<Uint8List> photo(Ticket ticket, {required bool localOnly}) async {
    final cached = await _cache.readPhoto(ticket.id);
    if (cached != null) return cached;
    if (localOnly) throw const ReceiptNotCached();
    final bytes = await _photos.download(ticket.photoPath).timeout(_timeout);
    await _bestEffort(() => _cache.writePhoto(ticket.id, bytes));
    return bytes;
  }

  Future<void> remove(Ticket ticket) async {
    final row = await _tickets
        .update({'status': 'deleting'})
        .eq('user_id', owner)
        .eq('id', ticket.id)
        .select()
        .maybeSingle()
        .timeout(_timeout);
    if (row != null) {
      final deleting = Ticket.fromJson(row);
      await _bestEffort(() => _updateCache(deleting));
      await _photos.remove([deleting.photoPath]).timeout(_timeout);
      await _tickets
          .delete()
          .eq('user_id', owner)
          .eq('id', ticket.id)
          .select()
          .single()
          .timeout(_timeout);
    }
    await _bestEffort(() async {
      final existing = await _cache.readIndex() ?? [];
      await _cache.writeIndex(
        existing.where((other) => other.id != ticket.id).toList(),
      );
    });
  }

  Future<void> clearCache() => _cache.clear();

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // A local cache or download failure must not turn a confirmed server write into a retry.
    }
  }
}

class TicketUnavailable implements Exception {
  const TicketUnavailable();
}

class ReceiptNotCached implements Exception {
  const ReceiptNotCached();
}
