import 'package:adhd_assistant/secrets.dart';
import 'package:adhd_assistant/services/one_drive_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildAuthorizationUrl includes the required OAuth parameters', () {
    const redirectUri = 'https://example.com/auth/callback';

    final authUrl = OneDriveSyncService.buildAuthorizationUrl(
      redirectUri: redirectUri,
      codeVerifier: 'test-verifier',
    );

    final uri = Uri.parse(authUrl);

    expect(uri.scheme, 'https');
    expect(uri.host, 'login.microsoftonline.com');
    expect(uri.path, '/consumers/oauth2/v2.0/authorize');
    expect(uri.queryParameters['client_id'], oneDriveClientId);
    expect(uri.queryParameters['response_type'], 'code');
    expect(uri.queryParameters['redirect_uri'], redirectUri);
    expect(uri.queryParameters['scope'], contains('Calendars.Read'));
    expect(uri.queryParameters['code_challenge_method'], 'S256');
    expect(uri.queryParameters['code_challenge'], isNotEmpty);
    expect(uri.queryParameters['state'], isNotEmpty);
  });
}
