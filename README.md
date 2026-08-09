# adhd_assistant

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local Secrets Setup

This project keeps machine-specific secrets out of source control.

1. Copy `lib/secrets.template.dart` to `lib/secrets.dart`.
2. Fill in your real values in `lib/secrets.dart`.

`lib/secrets.dart` is ignored by git and stays local on each machine.

## Outlook / Microsoft Sync Setup

This app uses one Microsoft app registration for two things:

- Outlook calendar access
- app-state file sync in the Microsoft app folder

Some code names still say `OneDrive` because the app-state file is stored in the
Microsoft app folder, but this is also the Outlook sign-in setup.

### 1) Register a Microsoft app (free)

1. Open Azure Portal -> App registrations -> New registration.
2. Choose account type: `Personal Microsoft accounts only`.
3. Create the app and copy the `Application (client) ID`.
4. Under `Authentication`, add the web redirect URI used by this app, for example:
	`https://your-app.web.app/outlook-callback`

### 2) Add Microsoft Graph permission

1. In your app registration, open `API permissions`.
2. Add delegated permission: `Files.ReadWrite.AppFolder`.
3. Add delegated permission: `Calendars.Read`.
4. Add delegated permission: `User.Read`.
5. Add delegated permission: `offline_access`.

### 3) Configure the local secrets file

1. Open `lib/secrets.dart`.
2. Set `oneDriveClientId` to your Azure app client ID.
3. Leave `oneDriveAuthorityTenant` as `consumers` unless you know you need a different tenant.
4. Set `oneDriveRedirectUri` to the exact redirect URI configured in Azure.

If you are moving to another machine, copy the working values from your existing
local `lib/secrets.dart` into the new machine's local `lib/secrets.dart`.

Required local values for Outlook/Microsoft sign-in are:

- `oneDriveClientId`
- `oneDriveAuthorityTenant`
- `oneDriveRedirectUri`

### 4) Link and sync in the app

1. Launch the app.
2. Open the Outlook/Microsoft link flow in the app.
3. Complete Microsoft sign-in in the browser.
4. After linking, use the cloud sync control any time to force a sync.

The synced app-state file is stored in the Microsoft app folder as:

- `adhd_assistant_app_state.json`
