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

## OneDrive Sync Setup (Windows + Android)

This app supports single-user OneDrive sync using Microsoft device-code login.

### 1) Register a Microsoft app (free)

1. Open Azure Portal -> App registrations -> New registration.
2. Choose account type: `Personal Microsoft accounts only`.
3. Create the app and copy the `Application (client) ID`.

### 2) Add Microsoft Graph permission

1. In your app registration, open `API permissions`.
2. Add delegated permission: `Files.ReadWrite.AppFolder`.
3. Add delegated permission: `offline_access`.

### 3) Configure the app client ID

1. Open [lib/secrets.dart](lib/secrets.dart).
2. Set `oneDriveClientId` to your Azure app client ID.

### 4) Link and sync in the app

1. Launch the app.
2. Click the cloud-sync icon in the Task List header.
3. Follow the URL + code steps shown in the dialog.
4. After linking, click cloud-sync any time to force a sync.

The sync file is stored in your OneDrive App Folder as:

- `adhd_assistant_app_state.json`
