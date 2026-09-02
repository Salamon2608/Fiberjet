import 'package:backend/config/env_config.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class StorageService {
  final String _baseDir;

  StorageService({String? baseDir}) 
      : _baseDir = baseDir ?? p.join(Directory.current.path, EnvConfig.storagePath) {
    final dir = Directory(_baseDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  /// Saves a file buffer to the local disk abstraction.
  /// 
  /// The [bucket] acts as the primary sub-directory (e.g., 'avatars', 'job_photos', 'kyc').
  Future<String> saveFile(String bucket, String filename, List<int> bytes) async {
    final bucketDir = Directory(p.join(_baseDir, bucket));
    if (!await bucketDir.exists()) {
      await bucketDir.create(recursive: true);
    }
    
    final file = File(p.join(bucketDir.path, filename));
    await file.writeAsBytes(bytes);
    
    // Return the relative storage path to be saved in Postgres
    return '$bucket/$filename';
  }

  /// Reads a file from the local disk. Returns null if missing.
  Future<List<int>?> getFile(String relativePath) async {
    final file = File(p.join(_baseDir, relativePath));
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  /// Deletes a file from the local disk.
  Future<bool> deleteFile(String relativePath) async {
    final file = File(p.join(_baseDir, relativePath));
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}
