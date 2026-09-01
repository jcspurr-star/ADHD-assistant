// Non-web fallback: exporting/importing a backup file isn't wired up for
// desktop/mobile builds yet — callers treat a null/no-op result as
// "unsupported on this platform".
class BackupFileServicePlatform {
  static Future<void> downloadBackup(
    String jsonContent,
    String filename,
  ) async {}

  static Future<String?> pickAndReadBackupFile() async => null;
}
