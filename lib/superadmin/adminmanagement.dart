import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/userinfo.dart';
import 'package:chatbot/superadmin/auditlogs.dart';
import 'package:chatbot/superadmin/chatlogs.dart';
import 'package:chatbot/superadmin/feedbacks.dart';
import 'package:chatbot/superadmin/settings.dart';
import 'package:chatbot/superadmin/profile.dart';
import 'package:chatbot/superadmin/emergencypage.dart';

const primarycolor = Color(0xFFffc803);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFF800000);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const lightBackground = Color(0xFFFEFEFE);

const storage = FlutterSecureStorage();
const _possibleAesKeyNames = ['app_aes_key_v1', 'app_aes_key_v1_superadmin'];

String capitalizeEachWord(String text) {
  return text
      .toLowerCase()
      .split(' ')
      .map(
        (word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '',
      )
      .join(' ');
}

class ProfileButton extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String role;
  final VoidCallback onTap;

  const ProfileButton({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.role,
    required this.onTap,
  });

  @override
  State<ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends State<ProfileButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          height: 46,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.grey.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: isSmallScreen
              ? CircleAvatar(
                  radius: 18,
                  backgroundImage: widget.imageUrl.startsWith('http')
                      ? NetworkImage(widget.imageUrl)
                      : AssetImage(widget.imageUrl) as ImageProvider,
                  backgroundColor: Colors.grey[200],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: widget.imageUrl.startsWith('http')
                          ? NetworkImage(widget.imageUrl)
                          : AssetImage(widget.imageUrl) as ImageProvider,
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: dark,
                          ),
                        ),
                        Text(
                          widget.role,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: dark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({super.key});

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> users = [];
  int totalAdmins = 0;
  int activeAdmins = 0;
  int inactiveAdmins = 0;

  String firstName = "";
  String lastName = "";
  String profilePictureUrl = "assets/images/defaultDP.jpg";

  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  bool _adminInfoLoaded = false;
  bool _userDataLoaded = false;

  String get fullName => '$firstName $lastName';

  String _displayStatusLabel(dynamic status) {
    final s = status?.toString().toLowerCase() ?? '';
    if (s == 'inactive' || s == 'pending') return 'PENDING';
    return s.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _ensureEncryptionKeyConsistency();
    _loadUserDataList();
    _loadAdminInfo();
    _loadApplicationLogo();
  }

  Widget _buildDebugPanel() {
    if (users.isEmpty) return const SizedBox.shrink();
    
    final statusCounts = <String, int>{};
    for (var user in users) {
      final status = user['emailStatus'] as String? ?? 'UNKNOWN';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Encryption Status',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...statusCounts.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: GoogleFonts.poppins()),
                    Text(entry.value.toString(), style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadApplicationLogo() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('SystemSettings').doc('global').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _applicationLogoUrl = data['applicationLogoUrl'] as String?;
          _logoLoaded = true;
        });
      } else {
        setState(() {
          _applicationLogoUrl = null;
          _logoLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading application logo: $e');
      setState(() {
        _applicationLogoUrl = null;
        _logoLoaded = true;
      });
    }
  }

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('SuperAdmin').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            firstName = capitalizeEachWord(doc['firstName'] ?? '');
            lastName = capitalizeEachWord(doc['lastName'] ?? '');
            profilePictureUrl = doc['profilePicture'] ?? "assets/images/defaultDP.jpg";
            _adminInfoLoaded = true;
          });
        } else {
          setState(() => _adminInfoLoaded = true);
        }
      } else {
        setState(() => _adminInfoLoaded = true);
      }
    } catch (e) {
      print('Error loading super admin info: $e');
      setState(() => _adminInfoLoaded = true);
    }
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: dark,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: dark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyManagementPanel() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encryption Key Management',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Re-encrypt All Emails?', style: GoogleFonts.poppins()),
                        content: Text(
                          'This will decrypt all emails with any available key and re-encrypt them with the current master key. This may fix encryption inconsistencies.',
                          style: GoogleFonts.poppins(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancel', style: GoogleFonts.poppins()),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primarycolordark,
                            ),
                            child: Text('Fix All Emails', style: GoogleFonts.poppins(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirmed == true) {
                      await _fixAllEncryptedEmails();
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text('Fix All Encrypted Emails', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fixAllEncryptedEmails() async {
    print('🔧 Starting email re-encryption process...');
    
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Admin').get();
      final currentKey = await _getOrCreateAesKey();
      
      int fixed = 0;
      int failed = 0;
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final emailField = data['email'] ?? '';
          
          if (emailField.isNotEmpty) {
            // Try to decrypt with any available key
            final decrypted = await _decryptValue(emailField);
            
            if (decrypted != null && !decrypted.startsWith('❌') && decrypted.contains('@')) {
              // Re-encrypt with current key
              final iv = encrypt.IV.fromSecureRandom(16);
              final encrypter = encrypt.Encrypter(encrypt.AES(currentKey, mode: encrypt.AESMode.cbc));
              final encrypted = encrypter.encrypt(decrypted, iv: iv);
              final combined = <int>[]..addAll(iv.bytes)..addAll(encrypted.bytes);
              final newEncrypted = base64Encode(combined);
              
              // Update in Firestore
              await FirebaseFirestore.instance
                  .collection('Admin')
                  .doc(doc.id)
                  .update({'email': newEncrypted});
              
              fixed++;
              print('✅ Fixed email for ${data['firstName']} ${data['lastName']}');
            } else {
              failed++;
              print('❌ Failed to decrypt email for ${data['firstName']} ${data['lastName']}');
            }
          }
        } catch (e) {
          failed++;
          print('❌ Error processing ${doc.id}: $e');
        }
      }
      
      print('📊 Re-encryption complete: $fixed fixed, $failed failed');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Re-encryption complete: $fixed emails fixed, $failed failed',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: fixed > 0 ? Colors.green : Colors.orange,
          ),
        );
        
        // Reload the data
        await _loadUserDataList();
      }
      
    } catch (e) {
      print('❌ Re-encryption failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-encryption failed: $e', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  encrypt.Key? _cachedKey;
  static const String _primaryAesKeyStorageKey = 'app_aes_key_v1';

  Future<encrypt.Key> _getOrCreateAesKey() async {
    if (_cachedKey != null) return _cachedKey!;
    
    print('🔑 Starting key retrieval process...');
    
    // ALWAYS prioritize Firestore as the single source of truth
    try {
      print('📡 Checking Firestore for encryption key...');
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .get();
      
      if (doc.exists && doc.data()?['key'] != null) {
        final firestoreKeyBase64 = doc.data()!['key'] as String;
        final keyBytes = base64Decode(firestoreKeyBase64);
        final key = encrypt.Key(keyBytes);
        
        print('✅ Found key in Firestore: ${firestoreKeyBase64.substring(0, 10)}...');
        
        // Save to local storage for faster access
        await storage.write(
          key: _primaryAesKeyStorageKey,
          value: firestoreKeyBase64,
          aOptions: const AndroidOptions(encryptedSharedPreferences: true),
          iOptions: const IOSOptions(),
        );
        
        _cachedKey = key;
        print('🔑 Key cached successfully');
        return key;
      }
    } catch (e) {
      print('⚠️ Error fetching key from Firestore: $e');
    }
    
    // If Firestore fails, check local storage
    print('💾 Checking local storage for backup key...');
    final localKey = await storage.read(key: _primaryAesKeyStorageKey);
    if (localKey != null) {
      try {
        final keyBytes = base64Decode(localKey);
        final key = encrypt.Key(keyBytes);
        _cachedKey = key;
        print('✅ Using local backup key: ${localKey.substring(0, 10)}...');
        return key;
      } catch (e) {
        print('⚠️ Local key is corrupted: $e');
      }
    }
    
    // Last resort: create new key and save everywhere
    print('🔧 Creating new encryption key...');
    final generated = encrypt.Key.fromSecureRandom(32);
    final keyBase64 = base64Encode(generated.bytes);
    
    // Save to Firestore first
    try {
      await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .set({
        'key': keyBase64,
        'createdAt': FieldValue.serverTimestamp(),
        'version': 'v1',
      });
      print('✅ New key saved to Firestore');
    } catch (e) {
      print('⚠️ Could not save key to Firestore: $e');
    }
    
    // Save to local storage
    await storage.write(
      key: _primaryAesKeyStorageKey,
      value: keyBase64,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
    
    _cachedKey = generated;
    print('🔑 New key created and cached: ${keyBase64.substring(0, 10)}...');
    return _cachedKey!;
  }

  Future<String?> _decryptValue(String encoded) async {
    if (encoded.isEmpty) {
      print('⚠️ Empty encoded value');
      return 'No email';
    }
    
    // Check if it's already plaintext
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (emailRegex.hasMatch(encoded)) {
      print('✅ Email is already plaintext');
      return encoded;
    }
    
    print('🔑 Attempting decryption...');
    
    try {
      final combined = base64Decode(encoded);
      print('📦 Combined length: ${combined.length} bytes');
      
      if (combined.length < 17) {
        print('❌ Data too short: ${combined.length} bytes');
        return '❌ Invalid data';
      }
      
      // Try with current key
      try {
        final currentKey = await _getOrCreateAesKey();
        final result = await _tryDecryptWithKey(combined, currentKey);
        if (result != null && emailRegex.hasMatch(result)) {
          print('✅ Decryption successful: ${result.substring(0, 5)}...');
          return result;
        }
      } catch (e) {
        print('⚠️ Current key failed: $e');
      }
      
      // Try with alternative keys (for migration purposes)
      print('🔧 Trying alternative keys...');
      final alternativeKeys = await _getAllPossibleKeys();
      
      for (int i = 0; i < alternativeKeys.length; i++) {
        try {
          final result = await _tryDecryptWithKey(combined, alternativeKeys[i]);
          if (result != null && emailRegex.hasMatch(result)) {
            print('✅ Decryption successful with alternative key ${i + 1}: ${result.substring(0, 5)}...');
            
            // Re-encrypt with current key for consistency
            await _reEncryptEmail(result, encoded);
            
            return result;
          }
        } catch (e) {
          print('⚠️ Alternative key ${i + 1} failed: $e');
        }
      }
      
      print('❌ All decryption attempts failed');
      return '❌ Decryption failed';
      
    } catch (e) {
      print('❌ Decryption error: $e');
      return '❌ Decryption failed';
    }
  }

  Future<String?> _tryDecryptWithKey(Uint8List combined, encrypt.Key key) async {
    final ivBytes = combined.sublist(0, 16);
    final cipherBytes = combined.sublist(16);
    final iv = encrypt.IV(ivBytes);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc)
    );
    final encrypted = encrypt.Encrypted(cipherBytes);
    
    return encrypter.decrypt(encrypted, iv: iv);
  }

  Future<List<encrypt.Key>> _getAllPossibleKeys() async {
    List<encrypt.Key> keys = [];
    
    // Try to get all possible keys from local storage
    for (String keyName in _possibleAesKeyNames) {
      try {
        final keyBase64 = await storage.read(key: keyName);
        if (keyBase64 != null) {
          final keyBytes = base64Decode(keyBase64);
          keys.add(encrypt.Key(keyBytes));
        }
      } catch (e) {
        print('⚠️ Could not load key $keyName: $e');
      }
    }
    
    return keys;
  }

  Future<void> _reEncryptEmail(String plainEmail, String oldEncrypted) async {
    // This function would re-encrypt the email with the current key
    // and update it in Firestore. For now, just log it.
    print('📝 Email needs re-encryption: ${plainEmail.substring(0, 5)}...');
  }


  Future<void> _loadUserDataList() async {
  setState(() {
    _userDataLoaded = false;
  });

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('Admin')
        .orderBy('createdAt', descending: true)
        .get();

    int active = 0;
    int inactive = 0;
    List<Map<String, dynamic>> fetchedUsers = [];

    print('📊 Loading ${snapshot.docs.length} admin records...');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['createdAt'];
      String formattedDate = '';
      Timestamp? rawTimestamp;

      if (timestamp != null) {
        rawTimestamp = timestamp;
        final date = timestamp.toDate();
        formattedDate = DateFormat('MMMM dd, yyyy').format(date);
      }

      // Handle email decryption with better error handling
      final String emailField = data['email'] ?? '';
      String email = 'No email';
      String emailStatus = ''; // Track status for debugging
      
      if (emailField.isNotEmpty) {
        try {
          final decryptedEmail = await _decryptValue(emailField);
          if (decryptedEmail != null) {
            if (decryptedEmail.startsWith('❌')) {
              email = decryptedEmail;
              emailStatus = 'DECRYPTION FAILED';
            } else {
              email = decryptedEmail;
              emailStatus = 'DECRYPTED SUCCESSFULLY';
            }
          } else {
            email = '❌ Null result';
            emailStatus = 'NULL RESULT';
          }
        } catch (e) {
          print('Error processing email for ${data['firstName']}: $e');
          email = '❌ Processing error';
          emailStatus = 'PROCESSING ERROR';
        }
      } else {
        emailStatus = 'NO EMAIL FIELD';
      }

      print('👤 Admin: ${data['firstName']} ${data['lastName']} - Email: $email [$emailStatus]');

      final String firestoreStatus = (data['status'] ?? 'inactive').toString().toLowerCase();

      if (firestoreStatus == 'active') {
        active++;
      } else {
        inactive++;
      }

      final String fName = data['firstName'] ?? '';
      final String lName = data['lastName'] ?? '';
      final String combinedName = capitalizeEachWord(
        '${fName.toString().trim()} ${lName.toString().trim()}'.trim()
      );

      fetchedUsers.add({
        'name': combinedName,
        'firstName': capitalizeEachWord(fName),
        'lastName': capitalizeEachWord(lName),
        'email': email,
        'emailStatus': emailStatus, // Add for debugging
        'department': data['department'] ?? '',
        'position': data['accountType'] ?? '',
        'date': formattedDate,
        'type': firestoreStatus,
        'phonenumber': data['phone'] ?? '',
        'createdAt': rawTimestamp,
        'status': firestoreStatus,
        'uid': doc.id,
      });
    }

    setState(() {
      users = fetchedUsers
          .where((user) => user['position'].toString().toLowerCase() == 'admin')
          .toList();
      totalAdmins = users.length;
      activeAdmins = active;
      inactiveAdmins = inactive;
      _userDataLoaded = true;
    });

    print('✅ Loaded ${users.length} admin users successfully');
    
    // Print summary of email statuses
    final statusCounts = <String, int>{};
    for (var user in users) {
      final status = user['emailStatus'] as String;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    
    print('📊 Email Status Summary:');
    statusCounts.forEach((status, count) {
      print('  $status: $count');
    });
    
  } catch (e, stackTrace) {
    print('❌ Error loading user data: $e');
    print('Stack trace: $stackTrace');
    
    setState(() {
      _userDataLoaded = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading admin data. Please try again.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

  List<Map<String, dynamic>> get _filteredCustomers {
    final query = _searchController.text.toLowerCase();
    final filter = _selectedFilter.toLowerCase();

    return users.where((item) {
      final name = item['name'].toString().toLowerCase();
      final type = item['type'].toString().toLowerCase();
      final matchesQuery = name.contains(query);

      final isPendingType = (type == 'inactive' || type == 'pending');

      final matchesFilter =
          filter == 'all' ||
          (filter == 'active' && type == 'active') ||
          (filter == 'pending' && isPendingType);

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureEncryptionKeyConsistency() async {
    try {
      print('🔑 Checking encryption key consistency...');
      
      // Try to get the key from Firestore first
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .get();
      
      if (doc.exists && doc.data()?['key'] != null) {
        final firestoreKeyBase64 = doc.data()!['key'] as String;
        
        // Check local storage
        bool localKeyMatches = false;
        for (String keyName in _possibleAesKeyNames) {
          final localKey = await storage.read(key: keyName);
          if (localKey == firestoreKeyBase64) {
            localKeyMatches = true;
            print('✅ Local key matches Firestore key');
            break;
          }
        }
        
        if (!localKeyMatches) {
          print('🔄 Syncing encryption key from Firestore to local storage...');
          // Sync the key from Firestore to local storage
          for (String keyName in _possibleAesKeyNames) {
            await storage.write(
              key: keyName,
              value: firestoreKeyBase64,
              aOptions: const AndroidOptions(encryptedSharedPreferences: true),
              iOptions: const IOSOptions(),
            );
          }
          print('✅ Encryption key synced successfully');
        }
      } else {
        print('⚠️ No encryption key found in Firestore, will create on demand');
      }
    } catch (e) {
      print('⚠️ Error checking encryption key consistency: $e');
    }
  }

  Future<void> _approveAdmin(String uid, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Approve Admin?',
          style: GoogleFonts.poppins(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to approve admin $displayName? This will allow them to login to the admin dashboard.',
          style: GoogleFonts.poppins(
            color: dark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: primarycolordark),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(backgroundColor: primarycolordark, foregroundColor: Colors.white),
            child: Text('Approve', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('Admin').doc(uid).update({
        'status': 'active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin $displayName has been approved.', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _loadUserDataList();
    } catch (e) {
      print('Error approving admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve admin.', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteAdmin(String uid, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Delete Admin Account?',
          style: GoogleFonts.poppins(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete admin $displayName? This will permanently remove access to the Admin Management Page.',
          style: GoogleFonts.poppins(
            color: dark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: primarycolordark),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(backgroundColor: primarycolordark, foregroundColor: Colors.white),
            child: Text('Confirm Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('Admin').doc(uid).delete();

      try {
        final callable = FirebaseFunctions.instance.httpsCallable('deleteUser');
        await callable.call(<String, dynamic>{'uid': uid});
      } catch (e) {
        print('deleteUser cloud function failed or not available: $e');
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid == uid) {
          await currentUser.delete();
        } else {
          print('Cannot delete other users from client without Admin SDK / Cloud Function.');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Admin $displayName deleted successfully.", style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: primarycolor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _loadUserDataList();
    } catch (e) {
      print("Error deleting user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete admin.", style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> migrateAllEmailsToEncrypted() async {
    print('🔄 Starting email encryption migration...');
    
    try {
      final key = await _getOrCreateAesKey();
      final adminSnapshot = await FirebaseFirestore.instance.collection('Admin').get();
      
      int totalProcessed = 0;
      int alreadyEncrypted = 0;
      int newlyEncrypted = 0;
      int errors = 0;
      
      for (var doc in adminSnapshot.docs) {
        totalProcessed++;
        final data = doc.data();
        final String emailField = data['email'] ?? '';
        
        if (emailField.isEmpty) {
          print('⚠️ Skipping ${doc.id} - no email field');
          continue;
        }
        
        // Check if already encrypted (base64 format)
        if (emailField.contains('+') || emailField.contains('/') || emailField.contains('=')) {
          // Try to decrypt to verify it's valid encryption
          try {
            final combined = base64Decode(emailField);
            if (combined.length >= 17) {
              // Looks like valid encryption
              final ivBytes = combined.sublist(0, 16);
              final cipherBytes = combined.sublist(16);
              final iv = encrypt.IV(ivBytes);
              final encrypter = encrypt.Encrypter(
                encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7')
              );
              final encrypted = encrypt.Encrypted(cipherBytes);
              final decrypted = encrypter.decrypt(encrypted, iv: iv);
              
              if (decrypted.contains('@')) {
                print('✅ ${doc.id} - Already properly encrypted');
                alreadyEncrypted++;
                continue;
              }
            }
          } catch (e) {
            print('⚠️ ${doc.id} - Invalid encryption, will re-encrypt');
          }
        }
        
        // Check if it's plaintext email
        final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
        if (emailRegex.hasMatch(emailField)) {
          print('🔐 Encrypting plaintext email for ${doc.id}');
          
          try {
            // Encrypt the email
            final iv = encrypt.IV.fromSecureRandom(16);
            final encrypter = encrypt.Encrypter(
              encrypt.AES(key, mode: encrypt.AESMode.cbc)
            );
            final encrypted = encrypter.encrypt(emailField, iv: iv);
            final combined = <int>[]..addAll(iv.bytes)..addAll(encrypted.bytes);
            final encryptedEmail = base64Encode(combined);
            
            // Update Firestore
            await FirebaseFirestore.instance
                .collection('Admin')
                .doc(doc.id)
                .update({'email': encryptedEmail});
            
            print('✅ ${doc.id} - Successfully encrypted email');
            newlyEncrypted++;
          } catch (e) {
            print('❌ ${doc.id} - Error encrypting: $e');
            errors++;
          }
        } else {
          print('⚠️ ${doc.id} - Invalid email format: $emailField');
          errors++;
        }
      }
      
      print('\n📊 Migration Summary:');
      print('Total processed: $totalProcessed');
      print('Already encrypted: $alreadyEncrypted');
      print('Newly encrypted: $newlyEncrypted');
      print('Errors: $errors');
      print('✅ Migration complete!');
      
    } catch (e, stackTrace) {
      print('❌ Migration failed: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Add this button to your admin management page to trigger migration
  Widget _buildMigrationButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Encrypt All Emails?', style: GoogleFonts.poppins()),
              content: Text(
                'This will encrypt all plaintext emails in the database. This operation cannot be undone.',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primarycolordark,
                  ),
                  child: Text('Encrypt All', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            ),
          );
          
          if (confirmed == true) {
            await migrateAllEmailsToEncrypted();
            await _loadUserDataList(); // Reload data
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Email encryption migration completed!',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.lock_outline),
        label: Text('Encrypt All Emails', style: GoogleFonts.poppins()),
        style: ElevatedButton.styleFrom(
          backgroundColor: primarycolor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_adminInfoLoaded || !_userDataLoaded) {
      return Scaffold(
        backgroundColor: lightBackground,
        body: Center(
          child: Lottie.asset(
            'assets/animations/Live chatbot.json',
            width: 200,
            height: 200,
          ),
        ),
      );
    }

    final poppinsTextTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
        .apply(bodyColor: dark, displayColor: dark);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: poppinsTextTheme,
        primaryTextTheme: poppinsTextTheme,
      ),
      child: Scaffold(
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Admin Management",
        ),
        backgroundColor: lightBackground,
        appBar: AppBar(
          backgroundColor: lightBackground,
          iconTheme: const IconThemeData(color: primarycolordark),
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  "Admin Management",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: primarycolordark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ProfileButton(
                imageUrl: profilePictureUrl,
                name: fullName.trim().isNotEmpty ? fullName : "Loading...",
                role: "Super Admin",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminProfilePage()),
                  );
                },
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int columns = constraints.maxWidth > 800 ? 3 : 1;
                  double spacing = 12;
                  double totalSpacing = (columns - 1) * spacing;
                  double cardWidth = (constraints.maxWidth - totalSpacing) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      StatCard(
                        title: "Total Admin",
                        value: totalAdmins.toString(),
                        color: primarycolordark,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Active",
                        value: activeAdmins.toString(),
                        color: primarycolor,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Pending",
                        value: inactiveAdmins.toString(),
                        color: primarycolordark,
                        width: cardWidth,
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SearchBar(controller: _searchController),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 150,
                    child: FilterDropdown(
                      selectedFilter: _selectedFilter,
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value ?? 'All';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: Card(
                    color: primarycolordark,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Name',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Text(
                                'Email',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Department',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Date Created',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Status',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Text(
                                'Action',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: _filteredCustomers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/images/web-search.png",
                            width: 240,
                            height: 240,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No admin to show.",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final c = _filteredCustomers[index];
                        final fullName = c['name'] ?? '';
                        final joinedDate = c['date'] ?? '';
                        final department = c['department'] ?? '';

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            bool isSmallScreen = constraints.maxWidth < 600;
                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: isSmallScreen
                                    ? Stack(
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: secondarycolor,
                                                    child: Text(
                                                      fullName.isNotEmpty ? fullName[0] : '?',
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          fullName,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.poppins(
                                                            fontWeight: FontWeight.bold,
                                                            color: dark,
                                                          ),
                                                        ),
                                                        Text(
                                                          c['email'],
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 13,
                                                            color: dark,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Department: ${department.isEmpty ? "N/A" : department}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: dark,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Date Created: $joinedDate',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: dark,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            final firstName = c['firstName'] ?? '';
                                                            final lastName = c['lastName'] ?? '';
                                                            final fullName = '$firstName $lastName'.trim();
                                                            final dept = c['department'] ?? '';
                                                            String phoneNumber = c['phonenumber'] ?? '';
                                                            if (phoneNumber.isNotEmpty && !phoneNumber.startsWith('+63')) {
                                                              phoneNumber = '+63$phoneNumber';
                                                            }
                                                            return Dialog(
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(16),
                                                              ),
                                                              child: Container(
                                                                width: 400,
                                                                padding: const EdgeInsets.all(24),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.white,
                                                                  borderRadius: BorderRadius.circular(16),
                                                                ),
                                                                child: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const CircleAvatar(
                                                                      radius: 35,
                                                                      backgroundImage: AssetImage('assets/images/defaultDP.jpg'),
                                                                    ),
                                                                    const SizedBox(height: 12),
                                                                    Text(
                                                                      fullName,
                                                                      style: GoogleFonts.poppins(
                                                                        fontWeight: FontWeight.bold,
                                                                        fontSize: 18,
                                                                        color: dark,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 4),
                                                                    Text(
                                                                      c['email'] ?? '',
                                                                      style: GoogleFonts.poppins(
                                                                        fontSize: 13,
                                                                        color: dark,
                                                                      ),
                                                                    ),
                                                                    const Divider(height: 30),
                                                                    _buildProfileRow("First Name", firstName),
                                                                    _buildProfileRow("Last Name", lastName),
                                                                    Padding(
                                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Text(
                                                                            "Department",
                                                                            style: GoogleFonts.poppins(
                                                                              fontSize: 14,
                                                                              color: dark,
                                                                            ),
                                                                          ),
                                                                          Flexible(
                                                                            child: Text(
                                                                              dept.isEmpty ? 'N/A' : dept,
                                                                              style: GoogleFonts.poppins(
                                                                                fontSize: 14,
                                                                                color: dark,
                                                                              ),
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    _buildProfileRow("Mobile Number", phoneNumber.isEmpty ? 'Add number' : phoneNumber),
                                                                    _buildProfileRow("Date Created", c['date']),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                      icon: Icon(Icons.visibility, size: 16),
                                                      label: Text('View', style: GoogleFonts.poppins()),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFFD88C1B),
                                                        foregroundColor: Colors.white,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                                        textStyle: GoogleFonts.poppins(),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (c['status'] != 'active')
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () async {
                                                          await _approveAdmin(c['uid'], c['name'] ?? '');
                                                        },
                                                        icon: Icon(Icons.check_circle, size: 16),
                                                        label: Text('Approve', style: GoogleFonts.poppins()),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.green[700],
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                                          textStyle: GoogleFonts.poppins(),
                                                        ),
                                                      ),
                                                    ),
                                                  if (c['status'] != 'active') const SizedBox(width: 8),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: () async {
                                                        await _deleteAdmin(c['uid'], c['name'] ?? '');
                                                      },
                                                      icon: Icon(Icons.delete, size: 16),
                                                      label: Text('Delete', style: GoogleFonts.poppins()),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: secondarycolor,
                                                        foregroundColor: Colors.white,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                                        textStyle: GoogleFonts.poppins(),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Align(
                                            alignment: Alignment.topRight,
                                            child: Container(
                                              margin: const EdgeInsets.only(top: 4, right: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: c['status'] == 'active' ? Colors.green[100] : Colors.red[100],
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _displayStatusLabel(c['status']),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: c['status'] == 'active' ? Colors.green[800] : Colors.red[800],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: secondarycolor,
                                                    child: Text(
                                                      fullName.isNotEmpty ? fullName[0] : '?',
                                                      style: GoogleFonts.poppins(color: Colors.white),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      fullName,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.poppins(
                                                        color: dark,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Center(
                                              child: Text(
                                                c['email'],
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(color: dark),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                department.isEmpty ? 'N/A' : department,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(color: dark),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                joinedDate,
                                                style: GoogleFonts.poppins(color: dark),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: c['status'] == 'active' ? Colors.green[100] : Colors.red[100],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  c['status'].toString().toUpperCase(),
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: c['status'] == 'active' ? Colors.green[800] : Colors.red[800],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) {
                                                          final firstName = c['firstName'] ?? '';
                                                          final lastName = c['lastName'] ?? '';
                                                          final fullName = '$firstName $lastName'.trim();
                                                          final dept = c['department'] ?? '';
                                                          String phoneNumber = c['phonenumber'] ?? '';
                                                          if (phoneNumber.isNotEmpty && !phoneNumber.startsWith('+63')) {
                                                            phoneNumber = '+63$phoneNumber';
                                                          }
                                                          return Dialog(
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                            child: Container(
                                                              width: 400,
                                                              padding: const EdgeInsets.all(24),
                                                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  const CircleAvatar(radius: 35, backgroundImage: AssetImage('assets/images/defaultDP.jpg')),
                                                                  const SizedBox(height: 12),
                                                                  Text(
                                                                    fullName,
                                                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: dark),
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Text(
                                                                    c['email'] ?? '',
                                                                    style: GoogleFonts.poppins(fontSize: 13, color: dark),
                                                                  ),
                                                                  const Divider(height: 30),
                                                                  _buildProfileRow("First Name", firstName),
                                                                  _buildProfileRow("Last Name", lastName),
                                                                  Padding(
                                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                                    child: Row(
                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                      children: [
                                                                        Text(
                                                                          "Department",
                                                                          style: GoogleFonts.poppins(
                                                                            fontSize: 14,
                                                                            color: dark,
                                                                          ),
                                                                        ),
                                                                        Flexible(
                                                                          child: Text(
                                                                            dept.isEmpty ? 'N/A' : dept,
                                                                            style: GoogleFonts.poppins(
                                                                              fontSize: 14,
                                                                              color: dark,
                                                                            ),
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  _buildProfileRow("Mobile Number", phoneNumber.isEmpty ? 'Add number' : phoneNumber),
                                                                  _buildProfileRow("Date Created", c['date']),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                    icon: Icon(Icons.visibility, size: 16),
                                                    label: Text('View', style: GoogleFonts.poppins()),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFD88C1B),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      textStyle: GoogleFonts.poppins(),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (c['status'] != 'active')
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: () async {
                                                        await _approveAdmin(c['uid'], c['name'] ?? '');
                                                      },
                                                      icon: Icon(Icons.check_circle, size: 16),
                                                      label: Text('Approve', style: GoogleFonts.poppins()),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green[700],
                                                        foregroundColor: Colors.white,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                                        textStyle: GoogleFonts.poppins(),
                                                      ),
                                                    ),
                                                  ),
                                                if (c['status'] != 'active') const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      await _deleteAdmin(c['uid'], c['name'] ?? '');
                                                    },
                                                    icon: Icon(Icons.delete, size: 16),
                                                    label: Text('Delete', style: GoogleFonts.poppins()),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: secondarycolor,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      textStyle: GoogleFonts.poppins(),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final Color color;
  final double width;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.width,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeInOut,
        width: widget.width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(isHovered ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.color.withOpacity(isHovered ? 0.54 : 0.31),
            width: 1.5,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.13),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: widget.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: widget.color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedHoverCard extends StatefulWidget {
  final Widget child;
  const AnimatedHoverCard({super.key, required this.child});

  @override
  State<AnimatedHoverCard> createState() => _AnimatedHoverCardState();
}

class _AnimatedHoverCardState extends State<AnimatedHoverCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedScale(
        scale: isHovered ? 1.012 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

class HoverButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color color;
  final Color? textHoverColor;
  final Color? hoverBackground;

  const HoverButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.color = primarycolordark,
    this.textHoverColor,
    this.hoverBackground,
  }) : super(key: key);

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isHovered ? (widget.hoverBackground ?? widget.color) : widget.color;
    final Color? fgColor = isHovered
        ? widget.textHoverColor ?? (widget.color == Colors.transparent ? null : Colors.white)
        : (widget.color == Colors.transparent ? null : Colors.white);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            foregroundColor: fgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const SearchBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: dark),
      decoration: InputDecoration(
        hintText: 'Search admin...',
        hintStyle: GoogleFonts.poppins(color: dark),
        prefixIcon: const Icon(Icons.search, color: primarycolor),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primarycolordark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dark),
        ),
      ),
    );
  }
}

class FilterDropdown extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: dark, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFilter,
          onChanged: onChanged,
          dropdownColor: lightBackground,
          style: GoogleFonts.poppins(color: dark),
          icon: const Icon(Icons.filter_list, color: primarycolordark),
          items: ['All', 'Active', 'Pending'].map((filter) {
            return DropdownMenuItem<String>(
              value: filter,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(filter, style: GoogleFonts.poppins(color: dark)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  final String? applicationLogoUrl;
  final String activePage;

  const NavigationDrawer({
    super.key,
    this.applicationLogoUrl,
    required this.activePage,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: lightBackground),
            child: Center(
              child: applicationLogoUrl != null && applicationLogoUrl!.isNotEmpty
                  ? Image.network(
                      applicationLogoUrl!,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/dhvbot.png',
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset(
                      'assets/images/dhvbot.png',
                      height: double.infinity,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
          _drawerItem(context, Icons.dashboard_outlined, "Dashboard", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminDashboardPage()));
          }),
          _drawerItem(context, Icons.people_outline, "Users Info", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const UserinfoPage()));
          }),
          _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbacksPage()));
          }),
          _drawerItem(context, Icons.admin_panel_settings_outlined, "Admin Management", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManagementPage()));
          }),
          // _drawerItem(context,Icons.warning_amber_rounded, "Emergency Requests", () {
          //   Navigator.pop(context);
          //   Navigator.push( context, MaterialPageRoute(builder: (_) => const EmergencyRequestsPage()),);
          // },),
          _drawerItem(context, Icons.settings_outlined, "Settings", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSettingsPage()));
          }),
          _drawerItem(context, Icons.receipt_long_outlined, "Audit Logs", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogsPage()));
          }),
          const Spacer(),
          _drawerItem(
            context,
            Icons.logout,
            "Logout",
            () async {
              try {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                  (route) => false,
                );
              } catch (e) {
                print("Logout error: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Logout failed. Please try again.", style: GoogleFonts.poppins())),
                );
              }
            },
            isLogout: true,
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isLogout = false}) {
    return _DrawerHoverButton(
      icon: icon,
      title: title,
      onTap: onTap,
      isLogout: isLogout,
      isActive: activePage == title,
    );
  }
}

class _DrawerHoverButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLogout;
  final bool isActive;

  const _DrawerHoverButton({
    Key? key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isLogout = false,
    this.isActive = false,
  }) : super(key: key);

  @override
  State<_DrawerHoverButton> createState() => _DrawerHoverButtonState();
}

class _DrawerHoverButtonState extends State<_DrawerHoverButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isActive ? primarycolor.withOpacity(0.25) : (isHovered ? primarycolor.withOpacity(0.10) : Colors.transparent);

    final textColor = widget.isLogout ? Colors.red : (widget.isActive ? primarycolordark : primarycolordark);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Icon(widget.icon, color: textColor),
          title: Text(
            widget.title,
            style: GoogleFonts.poppins(
              color: textColor,
              fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}