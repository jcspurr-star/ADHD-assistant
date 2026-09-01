import 'backup_file_service_stub.dart'
    if (dart.library.html) 'backup_file_service_web.dart'
    as platform;

// Lets the user keep a backup entirely outside browser storage (a plain
// JSON file they save/share themselves) — decoupled from localStorage's
// quota limits and from accidentally sharing a browser origin/profile with
// another instance of the app.
class BackupFileService {
  static Future<void> downloadBackup(String jsonContent, String filename) {
    return platform.BackupFileServicePlatform.downloadBackup(
      jsonContent,
      filename,
    );
  }

  static Future<String?> pickAndReadBackupFile() {
    return platform.BackupFileServicePlatform.pickAndReadBackupFile();
  }
}
