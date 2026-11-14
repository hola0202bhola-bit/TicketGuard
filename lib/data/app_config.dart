import 'dart:convert';
import 'dart:io';

class AppConfig {
  const AppConfig(this.url, this.key);

  final String url;
  final String key;

  static const fromBuild = AppConfig(
    String.fromEnvironment('SUPABASE_URL'),
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  static AppConfig? parse(String url, String key, {bool allowLocal = false}) {
    final uri = Uri.tryParse(url.trim());
    final token = key.trim();
    final local =
        allowLocal &&
        uri?.scheme == 'http' &&
        const ['10.0.2.2', '127.0.0.1', 'localhost'].contains(uri?.host);
    if (uri == null ||
        (!local && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !_isPublicKey(token)) {
      return null;
    }
    return AppConfig(uri.origin, token);
  }

  static bool _isPublicKey(String key) {
    if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key)) return true;
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return json is Map && json['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }

  static Future<AppConfig?> read(Directory root) async {
    try {
      final json = jsonDecode(
        await File('${root.path}/connection.json').readAsString(),
      );
      return parse(json['url'] as String, json['key'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Directory root) =>
      File('${root.path}/connection.json')
          .writeAsString(jsonEncode({'url': url, 'key': key}), flush: true);

  static Future<void> clear(Directory root) async {
    final file = File('${root.path}/connection.json');
    if (await file.exists()) await file.delete();
  }
}
