// encryption_service.dart
// ⚠️ WARNING: This implementation stores passwords in encrypted form
// This matches your admin pattern but is NOT a security best practice
// Consider using Firebase Auth tokens instead for production

import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // ✅ MATCHING YOUR ADMIN PATTERN: Using same key for both users and admins
  static const String _aesKeyStorageKey = 'app_aes_key_v1'; // Same as admin
  encrypt.Key? _cachedKey;

  /// Get or create AES encryption key (EXACTLY matching your admin implementation)
  Future<encrypt.Key> _getOrCreateAesKey() async {
  if (_cachedKey != null) return _cachedKey!;

  String? keyBase64;

  try {
    // Always check Firestore first (to avoid stale local keys)
    var doc = await FirebaseFirestore.instance
        .collection('SystemSettings')
        .doc('user_encryption_key')
        .get();

    if (!doc.exists) {
      doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .get();
    }

    if (doc.exists && doc.data()?['key'] != null) {
      keyBase64 = doc.data()!['key'] as String;
    }
  } catch (e) {
    print('Could not fetch key from Firestore: $e');
  }

  // Fallback: use locally stored key only if Firestore fetch failed
  keyBase64 ??= await _secureStorage.read(key: _aesKeyStorageKey);

  if (keyBase64 != null) {
    final bytes = base64Decode(keyBase64);
    _cachedKey = encrypt.Key(bytes);
    await _secureStorage.write(
      key: _aesKeyStorageKey,
      value: keyBase64,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
    return _cachedKey!;
  }

  // Final fallback: generate new one
  final generated = encrypt.Key.fromSecureRandom(32);
  final newKeyBase64 = base64Encode(generated.bytes);

  await FirebaseFirestore.instance
      .collection('SystemSettings')
      .doc('user_encryption_key')
      .set({
    'key': newKeyBase64,
    'createdAt': FieldValue.serverTimestamp(),
    'version': 'v1',
  });

  await _secureStorage.write(key: _aesKeyStorageKey, value: newKeyBase64);

  _cachedKey = generated;
  return _cachedKey!;
}


  /// Encrypts a value and returns base64(iv + ciphertext)
  /// EXACTLY matching your admin encryption method
  Future<String> encryptValue(String plainText) async {
    try {
      final key = await _getOrCreateAesKey();
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      final combined = <int>[]..addAll(iv.bytes)..addAll(encrypted.bytes);
      
      return base64Encode(combined);
    } catch (e) {
      print('Encryption error: $e');
      rethrow;
    }
  }

  /// Decrypts base64(iv + ciphertext) back to plain text
  /// EXACTLY matching your admin decryption method
  Future<String> decryptValue(String encodedValue) async {
    try {
      final key = await _getOrCreateAesKey();
      final combined = base64Decode(encodedValue);
      
      if (combined.length < 17) {
        throw Exception('Invalid encrypted data');
      }
      
      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);
      final iv = encrypt.IV(ivBytes);
      
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      
      final encrypted = encrypt.Encrypted(cipherBytes);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Decryption error: $e');
      rethrow;
    }
  }

  /// Clear cached key (useful for logout)
  void clearCache() {
    _cachedKey = null;
  }

  /// ⚠️ SECURITY WARNING METHOD
  /// This method explains why storing encrypted passwords is risky
  void printSecurityWarning() {
    print('''
    ⚠️ ⚠️ ⚠️ SECURITY WARNING ⚠️ ⚠️ ⚠️
    
    This app stores ENCRYPTED PASSWORDS in Firestore.
    
    RISKS:
    1. If encryption key is compromised, ALL passwords are exposed
    2. Violates security best practices (OWASP, NIST)
    3. May fail compliance audits (PCI-DSS, SOC 2, GDPR)
    4. Firebase Auth already handles passwords securely
    
    RECOMMENDED ALTERNATIVES:
    1. Remove password encryption entirely
    2. Use Firebase Auth tokens for authentication
    3. Use password hashing (bcrypt, scrypt) if needed
    4. Store only hashed passwords, never recoverable ones
    
    CURRENT IMPLEMENTATION:
    - Matches admin pattern for consistency
    - Encryption key stored in Firestore
    - Anyone with Firestore access can decrypt passwords
    
    ⚠️ ⚠️ ⚠️ USE AT YOUR OWN RISK ⚠️ ⚠️ ⚠️
    ''');
  }
}

// ===== USAGE EXAMPLES =====

/*
// Example 1: Encrypt during registration
final encryptionService = EncryptionService();
final encryptedEmail = await encryptionService.encryptValue('user@example.com');
final encryptedPassword = await encryptionService.encryptValue('SecurePass123');

await FirebaseFirestore.instance.collection('users').doc(uid).set({
  'email': encryptedEmail,
  'password': encryptedPassword,  // ⚠️ Security risk
  'plainEmail': 'user@example.com', // For queries
});

// Example 2: Decrypt during login
final userData = await FirebaseFirestore.instance.collection('users').doc(uid).get();
final decryptedEmail = await encryptionService.decryptValue(userData['email']);
final decryptedPassword = await encryptionService.decryptValue(userData['password']);

// Example 3: Verify credentials
if (decryptedEmail == inputEmail && decryptedPassword == inputPassword) {
  // Login successful
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: decryptedEmail,
    password: decryptedPassword,
  );
}

// Example 4: Clear cache on logout
await FirebaseAuth.instance.signOut();
encryptionService.clearCache();
*/