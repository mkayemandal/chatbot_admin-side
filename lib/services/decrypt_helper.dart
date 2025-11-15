// lib/services/decrypt_helper.dart
import 'encryption_service.dart';

class DecryptHelper {
  /// Decrypts an encrypted email (or any value) using EncryptionService
  static Future<String> decryptEmail(String encryptedValue) async {
    try {
      final decrypted = await EncryptionService().decryptValue(encryptedValue);
      return decrypted;
    } catch (e) {
      print('Decryption error in DecryptHelper: $e');
      return 'Decryption Failed';
    }
  }
}
