import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../secrets.dart';

class OneDriveDeviceCodeSession {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final String message;
  final int intervalSeconds;
  final int expiresInSeconds;
  final String? codeVerifier;
  final String? redirectUri;
  final String? state;

  const OneDriveDeviceCodeSession({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.message,
    required this.intervalSeconds,
    required this.expiresInSeconds,
    this.codeVerifier,
    this.redirectUri,
    this.state,
  });
}

class OutlookCalendarEvent {
  final String id;
  final String subject;
  final DateTime? start;
  final DateTime? end;
  final bool isAllDay;
  final String calendarSource;

  const OutlookCalendarEvent({
    required this.id,
    required this.subject,
    required this.start,
    required this.end,
    required this.isAllDay,
    this.calendarSource = 'home',
  });
}

class OneDriveSyncService {
  static final RegExp _dateTimeHasExplicitZone = RegExp(r'(Z|[+-]\d\d:\d\d)$');

  static const Set<String> _workCalendarKeywords = {
    'work',
    'office',
    'business',
    'job',
  };

  static String get _authorityTenant {
    final trimmed = oneDriveAuthorityTenant.trim();
    return trimmed.isEmpty ? 'consumers' : trimmed;
  }

  static String get _tokenEndpoint =>
      'https://login.microsoftonline.com/$_authorityTenant/oauth2/v2.0/token';
  static String get _deviceCodeEndpoint =>
      'https://login.microsoftonline.com/$_authorityTenant/oauth2/v2.0/devicecode';
  static const String _scope =
      'offline_access User.Read Calendars.Read Files.ReadWrite.AppFolder';
  static const String _stateFileName = 'adhd_assistant_app_state.json';

  static const String _accessTokenKey = 'onedrive_access_token';
  static const String _refreshTokenKey = 'onedrive_refresh_token';
  static const String _accessTokenExpiryEpochKey =
      'onedrive_access_token_expiry_epoch';
  static const String _pendingOutlookAuthStateKey =
      'onedrive_pending_auth_state';
  static const String _pendingOutlookAuthCodeVerifierKey =
      'onedrive_pending_auth_code_verifier';
  static const String _pendingOutlookAuthRedirectUriKey =
      'onedrive_pending_auth_redirect_uri';

  static bool get isConfigured {
    return configurationIssues.isEmpty;
  }

  static List<String> get configurationIssues {
    final issues = <String>[];

    final clientId = oneDriveClientId.trim();
    if (clientId.isEmpty || clientId.startsWith('YOUR_')) {
      issues.add('Set oneDriveClientId in secrets.dart.');
    }

    final redirectUri = oneDriveRedirectUri.trim();
    if (redirectUri.isEmpty || redirectUri.contains('your-app.web.app')) {
      issues.add(
        'Set oneDriveRedirectUri in secrets.dart to your real web redirect URI.',
      );
    }

    return issues;
  }

  static String get configurationHelpText {
    if (configurationIssues.isEmpty) {
      return 'Outlook / Microsoft sign-in is configured.';
    }

    return '${configurationIssues.join('\n')}\n\nThese values are local only and need to be set on each machine.';
  }

  static Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_refreshTokenKey);
    return refreshToken != null && refreshToken.trim().isNotEmpty;
  }

  static bool isExpectedWebCallbackUri(Uri uri) {
    if (!kIsWeb) {
      return false;
    }

    var expectedPath = '/outlook-callback';
    final configuredRedirectUri = oneDriveRedirectUri.trim();
    if (configuredRedirectUri.isNotEmpty) {
      final configuredUri = Uri.tryParse(configuredRedirectUri);
      final configuredPath = configuredUri?.path ?? '';
      if (configuredPath.isNotEmpty) {
        expectedPath = configuredPath;
      }
    }

    return _normalizePath(uri.path) == _normalizePath(expectedPath);
  }

  static Future<OneDriveDeviceCodeSession> beginDeviceCodeFlow() async {
    if (!isConfigured) {
      throw Exception('Outlook / Microsoft client ID is not configured.');
    }

    if (!kIsWeb) {
      final response = await http.post(
        Uri.parse(_deviceCodeEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'client_id': oneDriveClientId, 'scope': _scope},
      );

      if (response.statusCode != 200) {
        final oauthError = _extractOauthError(response.body);
        throw Exception('Unable to start Microsoft sign-in. $oauthError');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final deviceCode = (body['device_code'] ?? '').toString();
      final userCode = (body['user_code'] ?? '').toString();
      final verificationUri =
          (body['verification_uri_complete'] ?? body['verification_uri'] ?? '')
              .toString();

      if (deviceCode.isEmpty || userCode.isEmpty || verificationUri.isEmpty) {
        throw Exception(
          'Microsoft sign-in response did not include a valid device-code session.',
        );
      }

      final intervalSeconds = (body['interval'] as num?)?.toInt() ?? 5;
      final expiresInSeconds = (body['expires_in'] as num?)?.toInt() ?? 900;

      return OneDriveDeviceCodeSession(
        deviceCode: deviceCode,
        userCode: userCode,
        verificationUri: verificationUri,
        message: (body['message'] ?? '').toString(),
        intervalSeconds: intervalSeconds,
        expiresInSeconds: expiresInSeconds,
      );
    }

    final codeVerifier = _generateCodeVerifier();
    final redirectUri = _redirectUriForCurrentPlatform();
    final state = _generateState();

    await _persistPendingAuthSession(
      state: state,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
    );

    final authorizationUrl = buildAuthorizationUrl(
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
      state: state,
    );

    return OneDriveDeviceCodeSession(
      deviceCode: '',
      userCode: '',
      verificationUri: authorizationUrl.toString(),
      message: kIsWeb
          ? 'Complete the Microsoft sign-in in your browser and return to this app when prompted.'
          : 'Open the sign-in page and continue.',
      intervalSeconds: 0,
      expiresInSeconds: 900,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
      state: state,
    );
  }

  static Future<bool> completeDeviceCodeFlow([
    OneDriveDeviceCodeSession? session,
  ]) async {
    if (session != null && session.deviceCode.isNotEmpty) {
      return _completeDesktopDeviceCodeFlow(session);
    }

    final code = Uri.base.queryParameters['code'];
    final error = Uri.base.queryParameters['error'];
    final returnedState = Uri.base.queryParameters['state'];

    if ((code == null || code.isEmpty) && (error == null || error.isEmpty)) {
      return false;
    }

    if (error != null && error.isNotEmpty) {
      return false;
    }

    final pending = await _loadPendingAuthSession();
    if (pending.state != null &&
        pending.state!.isNotEmpty &&
        pending.state != returnedState) {
      return false;
    }

    final redirectUri = pending.redirectUri ?? _redirectUriForCurrentPlatform();
    final codeVerifier = pending.codeVerifier ?? '';

    if (codeVerifier.isEmpty || code == null || code.isEmpty) {
      return false;
    }

    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': oneDriveClientId,
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode != 200) {
      final oauthError = _extractOauthError(response.body);
      throw Exception('Unable to finish Microsoft sign-in. $oauthError');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _storeTokenResponse(body);
    await _clearPendingAuthSession();
    return true;
  }

  static Future<bool> _completeDesktopDeviceCodeFlow(
    OneDriveDeviceCodeSession session,
  ) async {
    var pollIntervalSeconds = session.intervalSeconds <= 0
        ? 5
        : session.intervalSeconds;
    final deadline = DateTime.now().add(
      Duration(
        seconds: session.expiresInSeconds <= 0 ? 900 : session.expiresInSeconds,
      ),
    );

    while (DateTime.now().isBefore(deadline)) {
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': oneDriveClientId,
          'device_code': session.deviceCode,
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        await _storeTokenResponse(body);
        return true;
      }

      final oauthErrorCode = _extractOauthErrorCode(response.body);
      if (oauthErrorCode == 'authorization_pending') {
        await Future.delayed(Duration(seconds: pollIntervalSeconds));
        continue;
      }

      if (oauthErrorCode == 'slow_down') {
        pollIntervalSeconds += 5;
        await Future.delayed(Duration(seconds: pollIntervalSeconds));
        continue;
      }

      if (oauthErrorCode == 'authorization_declined' ||
          oauthErrorCode == 'expired_token' ||
          oauthErrorCode == 'bad_verification_code') {
        return false;
      }

      final oauthError = _extractOauthError(response.body);
      throw Exception('Unable to finish Microsoft sign-in. $oauthError');
    }

    return false;
  }

  static String buildAuthorizationUrl({
    required String redirectUri,
    required String codeVerifier,
    String? state,
  }) {
    final resolvedState = state ?? _generateState();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    return Uri.https(
      'login.microsoftonline.com',
      '/$_authorityTenant/oauth2/v2.0/authorize',
      {
        'client_id': oneDriveClientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': _scope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': resolvedState,
      },
    ).toString();
  }

  static String _generateCodeVerifier() {
    final bytes = List<int>.generate(
      64,
      (_) => math.Random.secure().nextInt(256),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier)).bytes;
    return base64UrlEncode(digest).replaceAll('=', '');
  }

  static String _generateState() {
    final bytes = List<int>.generate(
      16,
      (_) => math.Random.secure().nextInt(256),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _redirectUriForCurrentPlatform() {
    final configuredRedirectUri = oneDriveRedirectUri.trim();
    if (configuredRedirectUri.isNotEmpty) {
      return configuredRedirectUri;
    }

    if (kIsWeb) {
      final uri = Uri.base;
      final normalizedPath = uri.path.isEmpty || uri.path == '/'
          ? '/outlook-callback'
          : uri.path.endsWith('/outlook-callback')
          ? uri.path
          : '${uri.path}/outlook-callback';
      return '${uri.origin}$normalizedPath';
    }

    return 'http://localhost/outlook-callback';
  }

  static String _normalizePath(String rawPath) {
    if (rawPath.isEmpty) {
      return '/';
    }

    final withLeadingSlash = rawPath.startsWith('/') ? rawPath : '/$rawPath';
    if (withLeadingSlash.length > 1 && withLeadingSlash.endsWith('/')) {
      return withLeadingSlash.substring(0, withLeadingSlash.length - 1);
    }

    return withLeadingSlash;
  }

  static Future<void> _persistPendingAuthSession({
    required String state,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingOutlookAuthStateKey, state);
    await prefs.setString(_pendingOutlookAuthCodeVerifierKey, codeVerifier);
    await prefs.setString(_pendingOutlookAuthRedirectUriKey, redirectUri);
  }

  static Future<({String? state, String? codeVerifier, String? redirectUri})>
  _loadPendingAuthSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      state: prefs.getString(_pendingOutlookAuthStateKey),
      codeVerifier: prefs.getString(_pendingOutlookAuthCodeVerifierKey),
      redirectUri: prefs.getString(_pendingOutlookAuthRedirectUriKey),
    );
  }

  static Future<void> _clearPendingAuthSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingOutlookAuthStateKey);
    await prefs.remove(_pendingOutlookAuthCodeVerifierKey);
    await prefs.remove(_pendingOutlookAuthRedirectUriKey);
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_accessTokenExpiryEpochKey);
  }

  static Future<Map<String, dynamic>?> downloadState() async {
    final accessToken = await _getValidAccessToken();
    if (accessToken == null) return null;

    final response = await http.get(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/special/approot:/$_stateFileName:/content',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      // Force relink when refresh token has become invalid or revoked.
      if (response.statusCode == 400) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = (body['error'] ?? '').toString();
        if (error == 'invalid_grant' || error == 'interaction_required') {
          await signOut();
        }
      }
      return null;
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<bool> uploadState(Map<String, dynamic> state) async {
    final accessToken = await _getValidAccessToken();
    if (accessToken == null) return false;

    final response = await http.put(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/special/approot:/$_stateFileName:/content',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(state),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<List<OutlookCalendarEvent>> fetchUpcomingCalendarEvents({
    Duration lookAhead = const Duration(days: 7),
    int maxItems = 10,
  }) async {
    final accessToken = await _getValidAccessToken();
    if (accessToken == null) {
      throw Exception('No Microsoft sign-in session found.');
    }

    final nowUtc = DateTime.now().toUtc();
    final endUtc = nowUtc.add(lookAhead);
    final calendars = await _fetchCalendars(accessToken);
    final calendarEvents = <OutlookCalendarEvent>[];

    if (calendars.isEmpty) {
      return _fetchDefaultCalendarView(
        accessToken: accessToken,
        nowUtc: nowUtc,
        endUtc: endUtc,
        maxItems: maxItems,
      );
    }

    for (final calendar in calendars) {
      final calendarId = (calendar['id'] ?? '').toString();
      if (calendarId.isEmpty) {
        continue;
      }
      final calendarName = (calendar['name'] ?? '').toString();
      final source = _inferCalendarSource(calendarName);

      final events = await _fetchCalendarViewForCalendar(
        accessToken: accessToken,
        calendarId: calendarId,
        nowUtc: nowUtc,
        endUtc: endUtc,
        maxItems: maxItems,
        calendarSource: source,
      );
      calendarEvents.addAll(events);
    }

    calendarEvents.sort((a, b) {
      final left =
          a.start ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final right =
          b.start ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return left.compareTo(right);
    });

    return calendarEvents;
  }

  static Future<List<Map<String, dynamic>>> _fetchCalendars(
    String accessToken,
  ) async {
    final response = await http.get(
      Uri.https('graph.microsoft.com', '/v1.0/me/calendars', {
        r'$select': 'id,name',
        r'$top': '50',
      }),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      await signOut();
      throw Exception(
        'Your Microsoft session expired or was revoked. Please link again.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'Calendar permission denied. Ensure Calendars.Read is granted in your Azure app registration.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to list Outlook calendars. ${_extractGraphError(response.body)}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawCalendars = body['value'] as List<dynamic>? ?? const [];
    return rawCalendars
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<OutlookCalendarEvent>> _fetchDefaultCalendarView({
    required String accessToken,
    required DateTime nowUtc,
    required DateTime endUtc,
    required int maxItems,
  }) async {
    final query = {
      'startDateTime': nowUtc.toIso8601String(),
      'endDateTime': endUtc.toIso8601String(),
      r'$top': maxItems.toString(),
      r'$orderby': 'start/dateTime',
      r'$select': 'id,subject,isAllDay,start,end',
    };

    final response = await http.get(
      Uri.https('graph.microsoft.com', '/v1.0/me/calendarView', query),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Prefer': 'outlook.timezone="UTC"',
      },
    );

    if (response.statusCode == 401) {
      await signOut();
      throw Exception(
        'Your Microsoft session expired or was revoked. Please link again.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'Calendar permission denied. Ensure Calendars.Read is granted in your Azure app registration.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load Outlook calendar events. ${_extractGraphError(response.body)}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawEvents = body['value'] as List<dynamic>? ?? const [];
    return _mapGraphEvents(rawEvents, calendarSource: 'home');
  }

  static Future<List<OutlookCalendarEvent>> _fetchCalendarViewForCalendar({
    required String accessToken,
    required String calendarId,
    required DateTime nowUtc,
    required DateTime endUtc,
    required int maxItems,
    required String calendarSource,
  }) async {
    final query = {
      'startDateTime': nowUtc.toIso8601String(),
      'endDateTime': endUtc.toIso8601String(),
      r'$top': maxItems.toString(),
      r'$orderby': 'start/dateTime',
      r'$select': 'id,subject,isAllDay,start,end',
    };

    final response = await http.get(
      Uri.https(
        'graph.microsoft.com',
        '/v1.0/me/calendars/$calendarId/calendarView',
        query,
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Prefer': 'outlook.timezone="UTC"',
      },
    );

    if (response.statusCode == 401) {
      await signOut();
      throw Exception(
        'Your Microsoft session expired or was revoked. Please link again.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'Calendar permission denied. Ensure Calendars.Read is granted in your Azure app registration.',
      );
    }

    if (response.statusCode != 200) {
      return const <OutlookCalendarEvent>[];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawEvents = body['value'] as List<dynamic>? ?? const [];
    return _mapGraphEvents(rawEvents, calendarSource: calendarSource);
  }

  static List<OutlookCalendarEvent> _mapGraphEvents(
    List<dynamic> rawEvents, {
    required String calendarSource,
  }) {
    return rawEvents.map((raw) {
      final event = Map<String, dynamic>.from(raw as Map);
      return OutlookCalendarEvent(
        id: (event['id'] ?? '').toString(),
        subject: (event['subject'] ?? '').toString().trim().isEmpty
            ? '(No title)'
            : (event['subject'] ?? '').toString(),
        start: _parseGraphDateTimeField(event['start']),
        end: _parseGraphDateTimeField(event['end']),
        isAllDay: event['isAllDay'] == true,
        calendarSource: calendarSource,
      );
    }).toList();
  }

  static String _inferCalendarSource(String calendarName) {
    final normalized = calendarName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'home';
    }
    for (final keyword in _workCalendarKeywords) {
      if (normalized.contains(keyword)) {
        return 'work';
      }
    }
    return 'home';
  }

  static Future<String?> _getValidAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    final accessToken = prefs.getString(_accessTokenKey);
    final expiresAt = prefs.getInt(_accessTokenExpiryEpochKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (accessToken != null && accessToken.isNotEmpty && now < expiresAt - 60) {
      return accessToken;
    }

    final refreshToken = prefs.getString(_refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': oneDriveClientId,
        'refresh_token': refreshToken,
        'scope': _scope,
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _storeTokenResponse(body);
    return body['access_token']?.toString();
  }

  static Future<void> _storeTokenResponse(Map<String, dynamic> body) async {
    final accessToken = (body['access_token'] ?? '').toString();
    final refreshToken = (body['refresh_token'] ?? '').toString();
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;

    if (accessToken.isEmpty) {
      throw Exception('Microsoft sign-in did not return an access token.');
    }

    final prefs = await SharedPreferences.getInstance();
    final expiresAt =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresIn;

    await prefs.setString(_accessTokenKey, accessToken);
    if (refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
    await prefs.setInt(_accessTokenExpiryEpochKey, expiresAt);
  }

  static String _extractOauthError(String rawBody) {
    try {
      final body = jsonDecode(rawBody) as Map<String, dynamic>;
      final error = (body['error'] ?? '').toString();
      final description = (body['error_description'] ?? '').toString();
      if (error.isEmpty && description.isEmpty) {
        return 'HTTP response: $rawBody';
      }
      if (description.isEmpty) {
        return 'Error: $error';
      }
      return 'Error: $error. $description';
    } catch (_) {
      return 'HTTP response: $rawBody';
    }
  }

  static String _extractOauthErrorCode(String rawBody) {
    try {
      final body = jsonDecode(rawBody) as Map<String, dynamic>;
      return (body['error'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  static DateTime? _parseGraphDateTimeField(dynamic rawValue) {
    if (rawValue is Map<String, dynamic>) {
      final dateTimeText = (rawValue['dateTime'] ?? '').toString();
      final timeZone = (rawValue['timeZone'] ?? '').toString();
      if (dateTimeText.isEmpty) {
        return null;
      }

      final parsed = DateTime.tryParse(dateTimeText);
      if (parsed == null) {
        return null;
      }

      if (timeZone.toUpperCase() == 'UTC' &&
          !_dateTimeHasExplicitZone.hasMatch(dateTimeText)) {
        return DateTime.parse('${dateTimeText}Z');
      }

      return parsed;
    }

    return null;
  }

  static String _extractGraphError(String rawBody) {
    try {
      final body = jsonDecode(rawBody) as Map<String, dynamic>;
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final code = (error['code'] ?? '').toString();
        final message = (error['message'] ?? '').toString();
        if (code.isEmpty && message.isEmpty) {
          return rawBody;
        }
        if (message.isEmpty) {
          return 'Error: $code';
        }
        return 'Error: $code. $message';
      }
      return rawBody;
    } catch (_) {
      return rawBody;
    }
  }
}
