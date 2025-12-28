// lib/repositories/storage_repository.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

abstract class StorageRepository {
  Future<String?> uploadFile(String path, String folder);
  Future<void> deleteFile(String url);
}

class FirebaseStorageRepository implements StorageRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<String?> uploadFile(String path, String folder) async {
    try {
      final ref = _storage.ref(folder);
      final metadata = SettableMetadata(contentType: "image/jpeg");
      final uploadTask = await ref.putFile(File(path), metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
