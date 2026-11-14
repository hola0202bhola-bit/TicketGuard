import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/ticket.dart';

class TicketCache {
  TicketCache(Directory root, String owner)
    : _folder = Directory('${root.path}/tickets/$owner');

  final Directory _folder;

  Future<List<Ticket>?> readIndex() async {
    try {
      final text = await File('${_folder.path}/index.json').readAsString();
      return (jsonDecode(text) as List)
          .map((row) => Ticket.fromJson(row as Map<String, dynamic>))
          .toList();
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeIndex(List<Ticket> tickets) async {
    await _write(
      'index.json',
      utf8.encode(
        jsonEncode(tickets.map((ticket) => ticket.toJson()).toList()),
      ),
    );
    final valid = tickets
        .where((ticket) => ticket.status == TicketStatus.ready)
        .map((ticket) => '${ticket.id}.jpg')
        .toSet();
    await for (final entry in _folder.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File && name.endsWith('.jpg') && !valid.contains(name)) {
        await entry.delete();
      }
    }
  }

  Future<Uint8List?> readPhoto(String id) async {
    try {
      return await File('${_folder.path}/$id.jpg').readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  Future<void> writePhoto(String id, Uint8List bytes) =>
      _write('$id.jpg', bytes);

  Future<void> _write(String name, List<int> bytes) async {
    await _folder.create(recursive: true);
    final temp = File('${_folder.path}/$name.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename('${_folder.path}/$name');
  }

  Future<void> clear() async {
    if (await _folder.exists()) await _folder.delete(recursive: true);
  }
}
