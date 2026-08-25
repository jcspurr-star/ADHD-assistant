import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'browser_url_helper.dart';
import 'storage_service.dart';

class OutlookLinkCoordinator {
  static Future<void> handleOutlookLink({
    required BuildContext context,
    required int outlookLookAheadDays,
    required Future<void> Function() refreshUpcomingOutlookEvents,
    required Future<void> Function(String title, String errorText)
    showCopyableErrorDialog,
  }) async {
    if (!StorageService.isOutlookConfigured) {
      if (!context.mounted) return;
      await showCopyableErrorDialog(
        'Outlook Setup Needed',
        StorageService.outlookConfigurationHelpText,
      );
      return;
    }

    final linked = await StorageService.isOutlookLinked();

    if (linked) {
      if (!context.mounted) return;
      final hasOutlookAccess = await _tryCheckOutlookConnection(
        context: context,
        outlookLookAheadDays: outlookLookAheadDays,
        silent: true,
      );

      if (!hasOutlookAccess) {
        if (!context.mounted) return;
        final relink = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Enable Outlook Access'),
              content: const Text(
                'Your current Microsoft link does not include Outlook calendar write permission yet. Re-link now to grant Calendars.ReadWrite?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Not now'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Re-link'),
                ),
              ],
            );
          },
        );

        if (relink == true) {
          await StorageService.unlinkOutlook();
          if (!context.mounted) return;
          await handleOutlookLink(
            context: context,
            outlookLookAheadDays: outlookLookAheadDays,
            refreshUpcomingOutlookEvents: refreshUpcomingOutlookEvents,
            showCopyableErrorDialog: showCopyableErrorDialog,
          );
          return;
        }
      }
    }

    if (!linked) {
      try {
        final session = await StorageService.beginOutlookLink();
        if (!context.mounted) return;

        final authUri = Uri.parse(session.verificationUri);
        final launched = await launchUrl(
          authUri,
          mode: LaunchMode.externalApplication,
        );

        if (context.mounted) {
          final desktopDeviceCodeInstructions =
              !kIsWeb && session.userCode.trim().isNotEmpty
              ? 'Use this code if Microsoft asks for it:\n${session.userCode}\n\n'
              : '';
          final flowHint = !kIsWeb
              ? '\n\nAfter you complete sign-in in the browser, this app will finish linking automatically.'
              : '';
          await showCopyableErrorDialog(
            'Outlook Auth URL',
            '${session.message}\n\n${desktopDeviceCodeInstructions}Opening this Microsoft sign-in URL:\n\n${authUri.toString()}$flowHint',
          );
        }

        if (!context.mounted) return;

        if (!launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open the Microsoft sign-in page. Please try again.',
              ),
            ),
          );
          return;
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microsoft sign-in opened in your browser. Return to the app after completing sign-in.',
            ),
          ),
        );

        if (!kIsWeb) {
          final authenticated = await StorageService.completeOutlookLink(
            session,
          );
          if (!context.mounted) return;

          if (authenticated) {
            await refreshUpcomingOutlookEvents();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Outlook calendar connected.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Outlook link did not complete. Please try again.',
                ),
              ),
            );
          }
        }

        return;
      } catch (error) {
        if (!context.mounted) return;
        final errorText =
            'Unable to start Outlook link: $error\n\n'
            'Tip: In Azure App Registration, make sure the redirect URI for this app is added under Authentication.';
        await showCopyableErrorDialog('Outlook Link Error', errorText);
        return;
      }
    }

    if (!context.mounted) return;
    final outlookConnected = await _tryCheckOutlookConnection(
      context: context,
      outlookLookAheadDays: outlookLookAheadDays,
      silent: true,
    );
    if (!context.mounted) return;

    await refreshUpcomingOutlookEvents();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outlookConnected
              ? 'Outlook calendar connected.'
              : 'Outlook link active, but calendar permission is missing.',
        ),
      ),
    );
  }

  static Future<void> maybeCompleteOutlookAuthFromCurrentUrl({
    required BuildContext context,
    required Future<void> Function() refreshUpcomingOutlookEvents,
    required Future<void> Function(String title, String errorText)
    showCopyableErrorDialog,
  }) async {
    if (!kIsWeb) {
      return;
    }

    final uri = Uri.base;
    final isExpectedCallback = StorageService.isExpectedWebOutlookCallbackUri(
      uri,
    );
    if (!isExpectedCallback) {
      return;
    }

    if (!uri.queryParameters.containsKey('code') &&
        !uri.queryParameters.containsKey('error')) {
      return;
    }

    try {
      final authenticated = await StorageService.completeOutlookLink();
      if (!context.mounted) return;

      if (authenticated) {
        await refreshUpcomingOutlookEvents();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outlook calendar connected.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outlook link did not complete.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final errorText =
          'Unable to finish Outlook link: $error\n\n'
          'Tip: In Azure App Registration, make sure the redirect URI for this app is added under Authentication.';
      await showCopyableErrorDialog('Outlook Link Error', errorText);
    } finally {
      clearOutlookAuthQueryParameters();
    }
  }

  static void clearOutlookAuthQueryParameters() {
    if (!kIsWeb) {
      return;
    }

    final uri = Uri.base;
    const authQueryKeys = {
      'code',
      'state',
      'error',
      'error_description',
      'session_state',
    };

    final hasAuthParams = uri.queryParameters.keys.any(authQueryKeys.contains);
    if (!hasAuthParams) {
      return;
    }

    final nextQueryParameters = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((key, _) => authQueryKeys.contains(key));
    final sanitizedUri = uri.replace(
      queryParameters: nextQueryParameters.isEmpty ? null : nextQueryParameters,
    );

    replaceBrowserUrl(sanitizedUri.toString());
  }

  static Future<bool> _tryCheckOutlookConnection({
    required BuildContext context,
    required int outlookLookAheadDays,
    required bool silent,
  }) async {
    try {
      final eventCount = await StorageService.getUpcomingOutlookEventCount(
        lookAhead: Duration(days: outlookLookAheadDays),
      );
      if (!context.mounted || silent) {
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Outlook connected. $eventCount upcoming events found.',
          ),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
