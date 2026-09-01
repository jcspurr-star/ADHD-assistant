import 'dart:convert';

import 'package:http/http.dart' as http;

import '../secrets.dart';

class FirebaseSyncService {
  static bool _initialized = false;
  static String? _lastError;

  // Bounds every Firestore/auth request so a slow or unreachable network
  // can't hang a save/load for a long time (previously unbounded).
  static const Duration _requestTimeout = Duration(seconds: 6);

  static String? _idToken;
  static String? _refreshToken;
  static DateTime? _idTokenExpiryUtc;

  static String? get lastError => _lastError;

  static bool get isConfigured {
    final hasProject = firebaseProjectId.trim().isNotEmpty;
    final hasApiKey =
        firebaseApiKey.trim().isNotEmpty && !firebaseApiKey.startsWith('YOUR_');
    final hasAppId =
        firebaseAppId.trim().isNotEmpty && !firebaseAppId.startsWith('YOUR_');
    final hasSenderId =
        firebaseMessagingSenderId.trim().isNotEmpty &&
        !firebaseMessagingSenderId.startsWith('YOUR_');
    return hasProject && hasApiKey && hasAppId && hasSenderId;
  }

  static Future<bool> initializeIfAvailable() async {
    if (!isConfigured) {
      _lastError = 'Firebase sync is not configured.';
      return false;
    }

    if (_initialized && _hasUsableAccessToken) {
      return true;
    }

    final ok = await _ensureAnonymousAuthToken();
    _initialized = ok;
    return ok;
  }

  static Future<bool> isSignedIn() async {
    final ready = await initializeIfAvailable();
    if (!ready) {
      return false;
    }

    final signedIn = _hasUsableAccessToken;
    if (!signedIn) {
      _lastError = 'Firebase auth token is not available.';
    }
    return signedIn;
  }

  static Future<bool> canReachCloudState() async {
    final ready = await initializeIfAvailable();
    if (!ready) {
      return false;
    }

    final token = await _getValidIdToken();
    if (token == null) {
      _lastError = 'Unable to get a valid Firebase auth token.';
      return false;
    }

    try {
      final response = await http
          .get(_documentUri(), headers: _authHeaders(token))
          .timeout(_requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 404) {
        _lastError = null;
        return true;
      }

      _lastError =
          'Firestore access failed (${response.statusCode}): ${_shortBody(response.body)}';
      return false;
    } catch (error) {
      _lastError = 'Firestore access failed: $error';
      return false;
    }
  }

  static Future<Map<String, dynamic>?> downloadState() async {
    final ready = await initializeIfAvailable();
    if (!ready) {
      return null;
    }

    final token = await _getValidIdToken();
    if (token == null) {
      _lastError = 'Unable to get a valid Firebase auth token.';
      return null;
    }

    try {
      final response = await http
          .get(_documentUri(), headers: _authHeaders(token))
          .timeout(_requestTimeout);

      if (response.statusCode == 404) {
        _lastError = null;
        return null;
      }

      if (response.statusCode != 200) {
        _lastError =
            'Download failed (${response.statusCode}): ${_shortBody(response.body)}';
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = body['fields'];
      if (fields is! Map<String, dynamic>) {
        _lastError = null;
        return null;
      }

      final payloadJson =
          (fields['payload_json'] as Map<String, dynamic>?)?['stringValue']
              ?.toString() ??
          '';

      if (payloadJson.trim().isEmpty) {
        _lastError = null;
        return null;
      }

      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) {
        _lastError = null;
        return decoded;
      }

      if (decoded is Map) {
        _lastError = null;
        return Map<String, dynamic>.from(decoded);
      }

      _lastError = 'Download failed: payload_json is not an object.';
      return null;
    } catch (error) {
      _lastError = 'Download failed: $error';
      return null;
    }
  }

  static Future<bool> uploadState(Map<String, dynamic> state) async {
    final ready = await initializeIfAvailable();
    if (!ready) {
      return false;
    }

    final token = await _getValidIdToken();
    if (token == null) {
      _lastError = 'Unable to get a valid Firebase auth token.';
      return false;
    }

    try {
      final response = await http
          .patch(
            _documentUri(),
            headers: _authHeaders(token),
            body: jsonEncode({
              'fields': {
                'payload_json': {'stringValue': jsonEncode(state)},
                'updated_at_utc': {
                  'stringValue': DateTime.now().toUtc().toIso8601String(),
                },
              },
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        _lastError = null;
        return true;
      }

      _lastError =
          'Upload failed (${response.statusCode}): ${_shortBody(response.body)}';
      return false;
    } catch (error) {
      _lastError = 'Upload failed: $error';
      return false;
    }
  }

  static Future<bool> uploadBackupHistory(
    List<Map<String, dynamic>> history,
  ) async {
    final ready = await initializeIfAvailable();
    if (!ready) {
      return false;
    }

    final token = await _getValidIdToken();
    if (token == null) {
      _lastError = 'Unable to get a valid Firebase auth token.';
      return false;
    }

    try {
      final response = await http
          .patch(
            _backupDocumentUri(),
            headers: _authHeaders(token),
            body: jsonEncode({
              'fields': {
                'payload_json': {'stringValue': jsonEncode(history)},
                'updated_at_utc': {
                  'stringValue': DateTime.now().toUtc().toIso8601String(),
                },
              },
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        _lastError = null;
        return true;
      }

      _lastError =
          'Backup upload failed (${response.statusCode}): ${_shortBody(response.body)}';
      return false;
    } catch (error) {
      _lastError = 'Backup upload failed: $error';
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> downloadBackupHistory() async {
    final ready = await initializeIfAvailable();
    if (!ready) {
      return <Map<String, dynamic>>[];
    }

    final token = await _getValidIdToken();
    if (token == null) {
      _lastError = 'Unable to get a valid Firebase auth token.';
      return <Map<String, dynamic>>[];
    }

    try {
      final response = await http
          .get(_backupDocumentUri(), headers: _authHeaders(token))
          .timeout(_requestTimeout);

      if (response.statusCode == 404) {
        _lastError = null;
        return <Map<String, dynamic>>[];
      }

      if (response.statusCode != 200) {
        _lastError =
            'Backup download failed (${response.statusCode}): ${_shortBody(response.body)}';
        return <Map<String, dynamic>>[];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = body['fields'];
      if (fields is! Map<String, dynamic>) {
        _lastError = null;
        return <Map<String, dynamic>>[];
      }

      final payloadJson =
          (fields['payload_json'] as Map<String, dynamic>?)?['stringValue']
              ?.toString() ??
          '';
      if (payloadJson.trim().isEmpty) {
        _lastError = null;
        return <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(payloadJson);
      if (decoded is List) {
        _lastError = null;
        return decoded
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
      }

      _lastError = 'Backup download failed: payload_json is not an array.';
      return <Map<String, dynamic>>[];
    } catch (error) {
      _lastError = 'Backup download failed: $error';
      return <Map<String, dynamic>>[];
    }
  }

  static Map<String, String> _authHeaders(String idToken) {
    return {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    };
  }

  static Uri _documentUri() {
    final encodedDocId = Uri.encodeComponent(firebaseSyncDocumentId);
    final path =
        '/v1/projects/$firebaseProjectId/databases/(default)/documents/app_state/$encodedDocId';
    return Uri.https('firestore.googleapis.com', path);
  }

  static Uri _backupDocumentUri() {
    final encodedDocId = Uri.encodeComponent('backup');
    final path =
        '/v1/projects/$firebaseProjectId/databases/(default)/documents/app_state/$encodedDocId';
    return Uri.https('firestore.googleapis.com', path);
  }

  static Future<bool> _ensureAnonymousAuthToken() async {
    if (_hasUsableAccessToken) {
      _lastError = null;
      return true;
    }

    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      final refreshed = await _refreshWithRefreshToken();
      if (refreshed) {
        _lastError = null;
        return true;
      }
    }

    try {
      final response = await http
          .post(
            Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:signUp', {
              'key': firebaseApiKey,
            }),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'returnSecureToken': true}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        _lastError =
            'Firebase anonymous auth failed (${response.statusCode}): ${_shortBody(response.body)}';
        return false;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final idToken = (body['idToken'] ?? '').toString();
      final refreshToken = (body['refreshToken'] ?? '').toString();
      final expiresIn = (body['expiresIn'] ?? '3600').toString();

      if (idToken.isEmpty || refreshToken.isEmpty) {
        _lastError = 'Firebase anonymous auth returned incomplete tokens.';
        return false;
      }

      _idToken = idToken;
      _refreshToken = refreshToken;
      final seconds = int.tryParse(expiresIn) ?? 3600;
      _idTokenExpiryUtc = DateTime.now().toUtc().add(
        Duration(seconds: seconds),
      );
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = 'Firebase anonymous auth request failed: $error';
      return false;
    }
  }

  static Future<bool> _refreshWithRefreshToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.https('securetoken.googleapis.com', '/v1/token', {
              'key': firebaseApiKey,
            }),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        _lastError =
            'Firebase token refresh failed (${response.statusCode}): ${_shortBody(response.body)}';
        return false;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final idToken = (body['id_token'] ?? '').toString();
      final newRefreshToken = (body['refresh_token'] ?? '').toString();
      final expiresIn = (body['expires_in'] ?? '3600').toString();

      if (idToken.isEmpty || newRefreshToken.isEmpty) {
        _lastError = 'Firebase token refresh returned incomplete tokens.';
        return false;
      }

      _idToken = idToken;
      _refreshToken = newRefreshToken;
      final seconds = int.tryParse(expiresIn) ?? 3600;
      _idTokenExpiryUtc = DateTime.now().toUtc().add(
        Duration(seconds: seconds),
      );
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = 'Firebase token refresh request failed: $error';
      return false;
    }
  }

  static Future<String?> _getValidIdToken() async {
    if (_hasUsableAccessToken) {
      return _idToken;
    }

    final ok = await _ensureAnonymousAuthToken();
    if (!ok) {
      return null;
    }

    return _idToken;
  }

  static bool get _hasUsableAccessToken {
    final token = _idToken;
    final expiry = _idTokenExpiryUtc;
    if (token == null || token.isEmpty || expiry == null) {
      return false;
    }

    return DateTime.now().toUtc().isBefore(
      expiry.subtract(const Duration(seconds: 60)),
    );
  }

  static String _shortBody(String body) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 220) {
      return normalized;
    }
    return '${normalized.substring(0, 220)}...';
  }
}
