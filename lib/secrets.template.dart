const String geminiApiKey = "YOUR_GEMINI_API_KEY";

// Outlook / Microsoft sign-in for calendar + app data sync.
// These names remain oneDrive* in code because the same Microsoft app is used
// for both Outlook calendar access and app-folder file sync.
const String oneDriveClientId = 'YOUR_ONEDRIVE_CLIENT_ID';
const String oneDriveAuthorityTenant = 'consumers';
// For web builds this must match the redirect URI configured in Azure App
// Registration, for example:
// https://your-app.web.app/outlook-callback
const String oneDriveRedirectUri = 'https://your-app.web.app/outlook-callback';

// Optional work calendar auto-import sources.
// Desktop/native builds can auto-read a local ICS file path.
const String workCalendarAutoImportPath =
    r'C:\Users\jspurr\OneDrive - Ordnance Survey\MyCalendar.ics';

const String firebaseProjectId = 'YOUR_FIREBASE_PROJECT_ID';
const String firebaseApiKey = 'YOUR_FIREBASE_API_KEY';
const String firebaseAppId = 'YOUR_FIREBASE_APP_ID';
const String firebaseMessagingSenderId = 'YOUR_FIREBASE_SENDER_ID';

const String firebaseSyncDocumentId = 'primary';
