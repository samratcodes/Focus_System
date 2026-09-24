import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;

/// The live backend (../backend, Node.js + Express on Vercel). For local development
/// use --dart-define=API_URL=http://10.0.2.2:4000 (emulator) or set it on the sign-in screen.
const defaultApiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://focus-system-api.vercel.app');

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  bool get isOffline => status == 0;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Persists the server address and session token (the same JWT the website
/// keeps in its cookie, sent here as `Authorization: Bearer`).
class Session {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'token';
  static const _kBaseUrl = 'base_url';

  static Future<String?> token() => _storage.read(key: _kToken);
  static Future<void> setToken(String? t) =>
      t == null ? _storage.delete(key: _kToken) : _storage.write(key: _kToken, value: t);

  static Future<String> baseUrl() async => (await _storage.read(key: _kBaseUrl)) ?? defaultApiUrl;
  static Future<void> setBaseUrl(String url) => _storage.write(key: _kBaseUrl, value: normalizeUrl(url));

  static String normalizeUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return defaultApiUrl;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}

class Api {
  Api({required this.baseUrl, this.token});

  String baseUrl;
  String? token;
  static String? _tz;

  static Future<Api> fromSession() async => Api(baseUrl: await Session.baseUrl(), token: await Session.token());

  static Future<String> timeZone() async {
    if (_tz != null) return _tz!;
    try {
      _tz = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      _tz = 'UTC';
    }
    return _tz!;
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, [Object? body]) => _send('POST', path, body ?? const {});
  Future<Map<String, dynamic>> patch(String path, Object body) => _send('PATCH', path, body);
  Future<Map<String, dynamic>> delete(String path, [Object? body]) => _send('DELETE', path, body);

  Future<Map<String, dynamic>> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    req.headers['Accept'] = 'application/json';
    req.headers['X-Timezone'] = await timeZone();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 15)));
    } on TimeoutException {
      throw ApiException(0, 'The server did not respond. Check the server address.');
    } catch (_) {
      throw ApiException(0, 'Cannot reach the server. Check your connection and server address.');
    }

    Map<String, dynamic> data = const {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        if (res.statusCode < 400) throw ApiException(res.statusCode, 'Unexpected response from server');
      }
    }
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, (data['error'] as String?) ?? 'Request failed (${res.statusCode})');
    }
    return data;
  }
}

/// Public privacy policy (required by Google Play), served by the website.
const privacyPolicyUrl = 'https://focus-system-amber.vercel.app/privacy';
