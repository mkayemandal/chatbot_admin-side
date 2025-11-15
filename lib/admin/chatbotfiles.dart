import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/feedbacks.dart';
import 'package:chatbot/admin/chatbotdata.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/admin/profile.dart';
import 'package:chatbot/admin/usersinfo.dart';
import 'package:chatbot/admin/statistics.dart';

const primarycolor = Color(0xFFffc803);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFF800000);
const dark = Color(0xFF17110d);
const white = Color(0xFFFFFFFF);
const textdark = Color(0xFF343a40);
const lightBackground = Color(0xFFFEFEFE);

String capitalizeEachWord(String text) {
  return text
      .toLowerCase()
      .split(' ')
      .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
      .join(' ');
}

String _normalizeId(String input) {
  final s = input.toLowerCase().trim();
  final replaced = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return replaced.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
}

void showFloatingSnackBar(BuildContext context, String message, {bool success = true}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.poppins(color: Colors.white),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: success ? Colors.green : Colors.red,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      duration: const Duration(seconds: 3),
    ),
  );
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

class ChatbotFilesPage extends StatefulWidget {
  const ChatbotFilesPage({super.key});

  @override
  State<ChatbotFilesPage> createState() => _ChatbotFilesPageState();
}

class _ChatbotFilesPageState extends State<ChatbotFilesPage> {
  String firstName = '';
  String lastName = '';
  String email = '';
  String gender = '';
  String userType = '';
  String birthday = '';
  String staffID = '';
  String decryptedEmail = '';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _aesKeyStorageKey = 'app_aes_key_v1';
  encrypt.Key? _cachedKey;

  String? _applicationLogoUrl;
  bool _logoLoaded = false;
  bool _adminInfoLoaded = false;
  String? adminDepartment;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadApplicationLogo();
  }

  Future<void> _loadApplicationLogo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('global')
          .get();
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

  Future<encrypt.Key> _getOrCreateAesKey() async {
    if (_cachedKey != null) return _cachedKey!;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .get();
      
      if (doc.exists && doc.data()?['key'] != null) {
        final keyBase64 = doc.data()!['key'] as String;
        final keyBytes = base64Decode(keyBase64);
        
        await _secureStorage.write(
          key: _aesKeyStorageKey,
          value: keyBase64,
          aOptions: const AndroidOptions(encryptedSharedPreferences: true),
          iOptions: const IOSOptions(),
        );
        
        _cachedKey = encrypt.Key(keyBytes);
        print('✅ Settings: Loaded encryption key from Firestore');
        return _cachedKey!;
      }
    } catch (e) {
      print('⚠️ Settings: Error loading key from Firestore: $e');
    }
    
    final existing = await _secureStorage.read(key: _aesKeyStorageKey);
    if (existing != null) {
      final bytes = base64Decode(existing);
      _cachedKey = encrypt.Key(bytes);
      print('✅ Settings: Loaded encryption key from local storage');
      return _cachedKey!;
    }
    
    final generated = encrypt.Key.fromSecureRandom(32);
    final keyBase64 = base64Encode(generated.bytes);
    
    try {
      await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .set({
        'key': keyBase64,
        'createdAt': FieldValue.serverTimestamp(),
        'version': 'v1',
      });
      print('✅ Settings: Created new encryption key in Firestore');
    } catch (e) {
      print('⚠️ Settings: Could not save key to Firestore: $e');
    }
    
    await _secureStorage.write(
      key: _aesKeyStorageKey,
      value: keyBase64,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
    
    _cachedKey = generated;
    print('✅ Settings: Created new encryption key locally');
    return _cachedKey!;
  }

  Future<String?> _decryptValue(String encoded) async {
    if (encoded.isEmpty) return null;
    
    try {
      final key = await _getOrCreateAesKey();
      final combined = base64Decode(encoded);
      
      if (combined.length < 17) {
        print('⚠️ Encrypted data too short');
        return null;
      }
      
      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);
      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypt.Encrypted(cipherBytes);
      
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('❌ Decryption failed: $e');
      return null;
    }
  }

  Future<String?> _encryptValue(String plainText) async {
    if (plainText.isEmpty) return null;

    try {
      final key = await _getOrCreateAesKey();
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      final combinedBytes = iv.bytes + encrypted.bytes;
      return base64Encode(combinedBytes);
    } catch (e) {
      print('❌ Encryption failed: $e');
      return null;
    }
  }

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _adminInfoLoaded = true;
        });
        return;
      }

      final uid = user.uid;
      final emailStr = user.email?.trim();
      DocumentSnapshot<Map<String, dynamic>>? adminDoc;

      try {
        final d = await FirebaseFirestore.instance.collection('Admin').doc(uid).get();
        if (d.exists) adminDoc = d;
      } catch (_) {}

      if ((adminDoc == null || !adminDoc.exists) && emailStr != null && emailStr.isNotEmpty) {
        try {
          final d = await FirebaseFirestore.instance.collection('Admin').doc(emailStr).get();
          if (d.exists) adminDoc = d;
        } catch (_) {}
      }

      if ((adminDoc == null || !adminDoc.exists) && emailStr != null && emailStr.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('Admin')
              .where('email', isEqualTo: emailStr)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) adminDoc = q.docs.first;
        } catch (_) {}
      }

      if (adminDoc != null && adminDoc.exists) {
        final data = adminDoc.data()!;
        setState(() {
          firstName = capitalizeEachWord(data['firstName'] ?? '');
          lastName = capitalizeEachWord(data['lastName'] ?? '');
          email = data['email'] ?? '';
          userType = capitalizeEachWord(data['userType'] ?? 'Admin');
          birthday = data['birthday'] ?? '';
          staffID = data['id']?.toString() ?? '';
          adminDepartment = (data['department'] ?? '').toString().trim();
          _adminInfoLoaded = true;
        });
        decryptedEmail = await _decryptValue(email) ?? user.email ?? '';
        return;
      } else {
        setState(() {
          _adminInfoLoaded = true;
          adminDepartment = null;
        });
        decryptedEmail = user.email ?? '';
        return;
      }
    } catch (e) {
      print('Error fetching Admin info: $e');
      setState(() {
        _adminInfoLoaded = true;
        adminDepartment = null;
      });
      decryptedEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    }
  }

  Future<void> logAuditAction({
    required String action,
    required String description,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      String fullName = 'Unknown';
      String emailAddr = decryptedEmail.isNotEmpty ? decryptedEmail : user.email ?? 'No Email';
      String role = 'Unknown';

      try {
        final adminDoc = await FirebaseFirestore.instance.collection('Admin').doc(uid).get();

        if (adminDoc.exists) {
          final data = adminDoc.data()!;
          fullName = '${capitalizeEachWord(data['firstName'] ?? '')} ${capitalizeEachWord(data['lastName'] ?? '')}'.trim();
          role = data['role'] ?? 'Admin';
        } else {
          final q = await FirebaseFirestore.instance
              .collection('Admin')
              .where('email', isEqualTo: emailAddr)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            final d = q.docs.first.data();
            fullName = '${capitalizeEachWord(d['firstName'] ?? '')} ${capitalizeEachWord(d['lastName'] ?? '')}'.trim();
            role = d['role'] ?? 'Admin';
          }
        }
      } catch (e) {
        print('Admin lookup failed: $e');
      }

      final encryptedEmail = await _encryptValue(emailAddr) ?? emailAddr;

      await FirebaseFirestore.instance.collection('AuditLogs').add({
        'performedBy': fullName.isNotEmpty ? fullName : emailAddr,
        'email': encryptedEmail,
        'role': role,
        'action': action,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Audit log failed: $e');
    }
  }

  Future<void> deleteCSV(BuildContext context, String fileName, String docId, String csvDocId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final csvDataDocRef = firestore.collection('CsvData').doc(csvDocId);
      final uploadedFileDocRef = firestore.collection('UploadedFiles').doc(docId);

      batch.delete(csvDataDocRef);
      batch.delete(uploadedFileDocRef);

      await batch.commit();

      await logAuditAction(
        action: 'Delete CSV File',
        description: 'Deleted CSV file "$fileName".',
      );

      if (mounted) {
        showFloatingSnackBar(context, 'CSV file deleted successfully.', success: true);
      }
    } catch (e) {
      print('Error deleting CSV: $e');
      if (mounted) {
        showFloatingSnackBar(context, 'Failed to delete CSV: ${e.toString()}', success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName';
    
    if (!_adminInfoLoaded) {
      final poppins = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
      return Theme(
        data: Theme.of(context).copyWith(textTheme: poppins, primaryTextTheme: poppins),
        child: Scaffold(
          backgroundColor: lightBackground,
          body: Center(
            child: Lottie.asset(
              'assets/animations/Live chatbot.json',
              width: 200,
              height: 200,
            ),
          ),
        ),
      );
    }

    if (adminDepartment == null || adminDepartment!.isEmpty) {
      final poppins = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
      return Theme(
        data: Theme.of(context).copyWith(textTheme: poppins, primaryTextTheme: poppins),
        child: Scaffold(
          backgroundColor: lightBackground,
          drawer: NavigationDrawer(
            applicationLogoUrl: _applicationLogoUrl,
            activePage: "Chatbot Files",
          ),
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
                    "Chatbot Files",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ProfileButton(
                  imageUrl: "assets/images/defaultDP.jpg",
                  name: fullName.trim().isNotEmpty ? fullName : "Loading...",
                  role: "Admin - ${adminDepartment ?? 'No Department'}",
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
          body: Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 48, color: primarycolordark),
                    const SizedBox(height: 12),
                    Text(
                      "No department assigned",
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Your account is not assigned to any department. Contact an administrator to assign a department before using this page.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final poppins = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return Theme(
      data: Theme.of(context).copyWith(textTheme: poppins, primaryTextTheme: poppins),
      child: Scaffold(
        backgroundColor: lightBackground,
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Chatbot Files",
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: primarycolordark),
          elevation: 0,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              "Chatbot Files",
              style: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ProfileButton(
                imageUrl: "assets/images/defaultDP.jpg",
                name: fullName.trim().isNotEmpty ? fullName : "Loading...",
                role: "Admin - ${adminDepartment ?? 'No Department'}",
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
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                UploadBox(
                  logAuditAction: ({required String action, required String description}) async {
                    await logAuditAction(action: action, description: description);
                  },
                  adminDepartment: adminDepartment,
                  onReplaceExisting: (existingDocId, existingCsvDocId) async {
                    final firestore = FirebaseFirestore.instance;
                    final batch = firestore.batch();
                    batch.delete(firestore.collection('UploadedFiles').doc(existingDocId));
                    batch.delete(firestore.collection('CsvData').doc(existingCsvDocId));
                    await batch.commit();
                  },
                ),
                const SizedBox(height: 30),
                FileTableCard(
                  adminDepartment: adminDepartment,
                  onDeleteCSV: (fileName, docId, csvDocId) {
                    deleteCSV(context, fileName, docId, csvDocId);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UploadBox extends StatefulWidget {
  final Future<void> Function({required String action, required String description}) logAuditAction;
  final String? adminDepartment;
  final Future<void> Function(String existingDocId, String existingCsvDocId)? onReplaceExisting;

  const UploadBox({
    super.key,
    required this.logAuditAction,
    required this.adminDepartment,
    this.onReplaceExisting,
  });

  @override
  State<UploadBox> createState() => _UploadBoxState();
}

class _UploadBoxState extends State<UploadBox> {
  String status = '';
  bool isUploading = false;
  String uploaderName = '';
  String uploaderEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUploaderInfo();
  }

  Future<void> _loadUploaderInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('Admin')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          uploaderName =
            '${capitalizeEachWord(data['firstName'] ?? '')} ${capitalizeEachWord(data['lastName'] ?? '')}';
          uploaderEmail = data['email'] ?? '';
        });
      }
    }
  }

  Future<void> uploadCSV() async {
    if (widget.adminDepartment == null || widget.adminDepartment!.isEmpty) {
      setState(() => status = 'You have no department assigned; upload disabled.');
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('UploadedFiles')
        .where('department', isEqualTo: widget.adminDepartment)
        .get();

    if (existing.docs.isNotEmpty) {
      setState(() {
        status =
            'A file already exists for "${widget.adminDepartment}". Please delete it before uploading a new one.';
      });

      if (mounted) {
        showFloatingSnackBar(context, 'Delete the existing file in ${widget.adminDepartment} before uploading a new one.', success: false);
      }
      return;
    }

    setState(() {
      isUploading = true;
      status = 'Uploading CSV...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() {
          status = 'No file selected.';
          isUploading = false;
        });
        return;
      }

      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      final baseName = fileName.split('.').first;

      final dept = widget.adminDepartment!.trim();
      final deptId = _normalizeId(dept);
      final fileId = _normalizeId(baseName);

      if (!(fileId.contains(deptId) || deptId.contains(fileId))) {
        setState(() {
          status = 'The selected file name does not match your department. '
              'Rename the file so its name includes "${dept}" and try again.';
          isUploading = false;
        });
        return;
      }

      final existingQuery = await FirebaseFirestore.instance
          .collection('UploadedFiles')
          .where('department', isEqualTo: dept)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        final existingDoc = existingQuery.docs.first;
        final existingData = existingDoc.data();
        final existingFileName = existingData['fileName'] ?? 'existing.csv';
        final existingCsvDocId = (existingData['csvDocId'] ?? existingFileName.split('.').first).toString();

        final replace = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('File Already Exists', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Text(
                'A file for "$dept" already exists ("$existingFileName").\n\n'
                'Do you want to replace the existing file with the new one?',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: primarycolordark)),
                ),
                TextButton(
                  style: TextButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Replace', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
        );

        if (replace != true) {
          setState(() {
            status = 'Upload cancelled. Existing file remains.';
            isUploading = false;
          });
          return;
        }

        try {
          final batch = FirebaseFirestore.instance.batch();
          final uploadedRef = FirebaseFirestore.instance.collection('UploadedFiles').doc(existingDoc.id);
          final csvRef = FirebaseFirestore.instance.collection('CsvData').doc(existingCsvDocId);
          batch.delete(uploadedRef);
          batch.delete(csvRef);
          await batch.commit();
        } catch (e) {
          print('Error deleting existing files: $e');
          setState(() {
            status = 'Failed to delete existing file: ${e.toString()}';
            isUploading = false;
          });
          if (mounted) {
            showFloatingSnackBar(context, 'Failed to delete existing file: ${e.toString()}', success: false);
          }
          return;
        }
      }

      final nameCollision = await FirebaseFirestore.instance
          .collection('UploadedFiles')
          .where('fileName', isEqualTo: fileName)
          .limit(1)
          .get();

      if (nameCollision.docs.isNotEmpty) {
        setState(() {
          status = 'A file named "$fileName" already exists (different department). Please rename your file.';
          isUploading = false;
        });
        if (mounted) {
          showFloatingSnackBar(context, 'A file named "$fileName" already exists. Please rename your file.', success: false);
        }
        return;
      }

      final csvString = utf8.decode(fileBytes);
      final csvTable = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (csvTable.isEmpty || csvTable.length < 2) {
        setState(() {
          status = 'CSV is empty or missing data rows.';
          isUploading = false;
        });
        if (mounted) {
          showFloatingSnackBar(context, 'CSV is empty or missing data rows.', success: false);
        }
        return;
      }

      final headers = csvTable.first.map((e) => e.toString().toLowerCase()).toList();
      final questionIndex = headers.indexWhere((h) => h.trim() == 'question');
      final answerIndex = headers.indexWhere((h) => h.trim() == 'answer');
      final languageIndex = headers.indexWhere((h) => h.trim() == 'language' || h.trim() == 'category');
      final departmentIndex = headers.indexWhere((h) => h.trim() == 'department');

      if (questionIndex == -1 || answerIndex == -1) {
        throw Exception('CSV must contain "question" and "answer" columns.');
      }

      final dataList = <Map<String, dynamic>>[];

      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length <= answerIndex) continue;

        final question = row[questionIndex].toString().trim().replaceAll('\\n', '\n');
        final answer = row[answerIndex].toString().trim().replaceAll('\\n', '\n');
        final language = (languageIndex != -1 && languageIndex < row.length)
            ? row[languageIndex].toString().trim()
            : '';

        final department = (departmentIndex != -1 && departmentIndex < row.length)
            ? row[departmentIndex].toString().trim()
            : widget.adminDepartment ?? '';

        if (question.isNotEmpty && answer.isNotEmpty) {
          dataList.add({
            'question': question,
            'answer': answer,
            'language': language,
            'department': department,
          });
        }
      }

      if (dataList.isEmpty) {
        setState(() {
          status = 'CSV has no valid entries.';
          isUploading = false;
        });
        if (mounted) {
          showFloatingSnackBar(context, 'CSV has no valid entries.', success: false);
        }
        return;
      }

      final deptCsvDocId = baseName;

      await FirebaseFirestore.instance.collection('CsvData').doc(deptCsvDocId).set({
        'fileName': fileName,
        'data': dataList,
        'uploadedAt': FieldValue.serverTimestamp(),
        'department': dept,
      });

      await FirebaseFirestore.instance.collection('UploadedFiles').add({
        'fileName': fileName,
        'fileSize': '${(fileBytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
        'timestamp': FieldValue.serverTimestamp(),
        'uploaderName': uploaderName,
        'uploaderEmail': uploaderEmail,
        'csvDocId': deptCsvDocId,
        'department': dept,
      });

      await widget.logAuditAction(
        action: 'Add CSV Files',
        description: 'Uploaded CSV "$fileName" with ${dataList.length} entries for "$dept".',
      );

      setState(() {
        status = '${dataList.length} entries uploaded from "$fileName".';
        isUploading = false;
      });

      if (mounted) {
        showFloatingSnackBar(context, 'CSV uploaded successfully.', success: true);
      }
    } catch (e) {
      print('Upload error: $e');
      setState(() {
        status = 'Upload failed: ${e.toString()}';
        isUploading = false;
      });
      if (mounted) {
        showFloatingSnackBar(context, 'Upload failed: ${e.toString()}', success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : uploadCSV,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: secondarycolor, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 48, color: secondarycolor),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                text: 'Click here ',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: secondarycolor),
                children: [
                  TextSpan(
                    text: 'to upload your file or drag.',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.normal, color: dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.adminDepartment != null && widget.adminDepartment!.isNotEmpty
                  ? 'Only one file per department is allowed.'
                  : 'You have no department assigned; uploading is disabled.',
              style: GoogleFonts.poppins(color: dark, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              status,
              style: GoogleFonts.poppins(fontSize: 14, color: dark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FileTableCard extends StatelessWidget {
  final String? adminDepartment;
  final void Function(String fileName, String docId, String csvDocId) onDeleteCSV;

  const FileTableCard({
    super.key,
    required this.onDeleteCSV,
    required this.adminDepartment,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 700;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('UploadedFiles')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (adminDepartment == null || adminDepartment!.isEmpty) {
              final emptyFiles = <QueryDocumentSnapshot>[];
              return _buildContainer(context, isSmallScreen, emptyFiles, 0, []);
            }

            final allDocs = snapshot.data!.docs;
            final filteredByDept = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final fileName = (data['fileName'] ?? '').toString();
              final csvDocId = (data['csvDocId'] ?? fileName.split('.').first).toString().trim();

              final docDept = (data['department'] ?? '').toString().trim();

              final a = (docDept.isNotEmpty ? docDept : csvDocId).toLowerCase();
              final b = adminDepartment!.trim().toLowerCase();
              if (a == b) return true;
              if (a.contains(b) || b.contains(a)) return true;
              return false;
            }).toList();

            final files = filteredByDept.toList();

            return _buildContainerAsync(context, isSmallScreen, files, files.length);
          },
        );
      },
    );
  }

  Widget _buildContainerAsync(BuildContext context, bool isSmallScreen, List<QueryDocumentSnapshot> files, int count) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _decryptFileEmails(files),
      builder: (context, emailSnapshot) {
        if (!emailSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return _buildContainer(context, isSmallScreen, files, count, emailSnapshot.data!);
      },
    );
  }

  Future<List<Map<String, dynamic>>> _decryptFileEmails(List<QueryDocumentSnapshot> files) async {
    const FlutterSecureStorage secureStorage = FlutterSecureStorage();
    const String aesKeyStorageKey = 'app_aes_key_v1';
    
    encrypt.Key? key;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .get();
      
      if (doc.exists && doc.data()?['key'] != null) {
        final keyBase64 = doc.data()!['key'] as String;
        final keyBytes = base64Decode(keyBase64);
        key = encrypt.Key(keyBytes);
      } else {
        final existing = await secureStorage.read(key: aesKeyStorageKey);
        if (existing != null) {
          final bytes = base64Decode(existing);
          key = encrypt.Key(bytes);
        }
      }
    } catch (e) {
      print('Error loading encryption key: $e');
    }
    
    final result = <Map<String, dynamic>>[];
    for (final doc in files) {
      final data = doc.data() as Map<String, dynamic>;
      final encryptedEmail = data['uploaderEmail'] ?? '';
      String decryptedEmail = encryptedEmail;
      
      if (key != null && encryptedEmail.isNotEmpty) {
        try {
          final combined = base64Decode(encryptedEmail);
          if (combined.length >= 17) {
            final ivBytes = combined.sublist(0, 16);
            final cipherBytes = combined.sublist(16);
            final iv = encrypt.IV(ivBytes);
            final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
            final encrypted = encrypt.Encrypted(cipherBytes);
            decryptedEmail = encrypter.decrypt(encrypted, iv: iv);
          }
        } catch (e) {
          print('Email decryption failed: $e');
        }
      }
      
      result.add({
        'docId': doc.id,
        'decryptedEmail': decryptedEmail,
      });
    }
    
    return result;
  }

  Widget _buildContainer(BuildContext context, bool isSmallScreen, List<QueryDocumentSnapshot> files, int count, List<Map<String, dynamic>> decryptedEmails) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primarycolordark,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            spreadRadius: 2,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isSmallScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Attached Files",
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: primarycolordark),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: secondarycolor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "$count Total",
                            style: GoogleFonts.poppins(color: secondarycolor, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminDepartment != null && adminDepartment!.isNotEmpty
                          ? "Showing files for \"$adminDepartment\""
                          : "Only CSV files are allowed. Manage your uploaded files here.",
                      style: GoogleFonts.poppins(fontSize: 13, color: dark),
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Attached Files",
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: primarycolordark),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: secondarycolor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "$count Total",
                                  style: GoogleFonts.poppins(color: secondarycolor, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adminDepartment != null && adminDepartment!.isNotEmpty
                                ? "Showing files for \"$adminDepartment\""
                                : "Only CSV files are allowed. Manage your uploaded files here.",
                            style: GoogleFonts.poppins(fontSize: 13, color: dark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 20),
          if (!isSmallScreen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: primarycolordark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text("File Name", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(child: Text("File Size", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(child: Text("Uploaded At", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Uploaded By", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(child: Text("Actions", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          if (!isSmallScreen) const SizedBox(height: 12),
          files.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 40 : 60),
                  child: Center(
                    child: Column(
                      children: [
                        Image.asset(
                          "assets/images/web-search.png",
                          width: 140,
                          height: 140,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          adminDepartment != null && adminDepartment!.isNotEmpty
                              ? 'No files to show for "$adminDepartment".'
                              : "No files to show.",
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: files.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    final fileName = data['fileName'] ?? 'Unnamed.csv';
                    final fileSize = data['fileSize'] ?? 'N/A';
                    final uploaderName = data['uploaderName'] ?? 'Unknown';
                    
                    String uploaderEmail = data['uploaderEmail'] ?? '';
                    if (index < decryptedEmails.length) {
                      uploaderEmail = decryptedEmails[index]['decryptedEmail'] ?? uploaderEmail;
                    }
                    
                    final timestamp = data['timestamp'] as Timestamp?;
                    final formattedDate = timestamp != null
                        ? DateFormat.yMMMMd().format(timestamp.toDate())
                        : 'Unknown';
                    final csvDocId = data['csvDocId'] ?? fileName.split('.').first;

                    if (isSmallScreen) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.insert_drive_file, color: secondarycolor, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: dark, fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _infoRow("File Size", fileSize),
                              _infoRow("Uploaded At", formattedDate),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Uploaded by:",
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: dark, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: secondarycolor,
                                        child: Text(
                                          uploaderName.isNotEmpty ? uploaderName[0].toUpperCase() : '?',
                                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(uploaderName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: dark)),
                                            Text(uploaderEmail, style: GoogleFonts.poppins(color: dark, fontSize: 12), overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 35,
                                        height: 35,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                          tooltip: 'Delete file',
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (dialogContext) => AlertDialog(
                                                backgroundColor: lightBackground,
                                                title: Text('Delete Confirmation', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primarycolordark)),
                                                content: Text('Are you sure you want to delete the CSV file "$fileName"? This action cannot be undone.', style: GoogleFonts.poppins(color: dark)),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('Cancel', style: GoogleFonts.poppins(color: primarycolordark))),
                                                  TextButton(
                                                    style: TextButton.styleFrom(backgroundColor: Colors.red, fixedSize: const Size(80, 35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                                    onPressed: () {
                                                      Navigator.of(dialogContext).pop();
                                                      onDeleteCSV(fileName, doc.id, csvDocId);
                                                    },
                                                    child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  const Icon(Icons.insert_drive_file, color: secondarycolor),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(fileName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: dark)),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: Text(fileSize, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: dark))),
                            Expanded(child: Text(formattedDate, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: dark))),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  CircleAvatar(radius: 16, backgroundColor: secondarycolor, child: Text(uploaderName.isNotEmpty ? uploaderName[0].toUpperCase() : '?', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(uploaderName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: primarycolordark)),
                                        Text(uploaderEmail, style: GoogleFonts.poppins(color: dark, fontSize: 12), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                      tooltip: 'Delete file',
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (dialogContext) => AlertDialog(
                                            backgroundColor: lightBackground,
                                            title: Text('Delete Confirmation', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primarycolordark)),
                                            content: Text('Are you sure you want to delete the CSV file "$fileName"? This action cannot be undone.', style: GoogleFonts.poppins(color: dark)),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('Cancel', style: GoogleFonts.poppins(color: primarycolordark))),
                                              TextButton(
                                                style: TextButton.styleFrom(backgroundColor: Colors.red, fixedSize: const Size(80, 35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                                onPressed: () {
                                                  Navigator.of(dialogContext).pop();
                                                  onDeleteCSV(fileName, doc.id, csvDocId);
                                                },
                                                child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 1),
      child: Row(
        children: [
          Text("$label: ", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: dark, fontSize: 13)),
          Expanded(child: Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: dark, fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  final String? applicationLogoUrl;
  final String activePage;
  const NavigationDrawer({super.key, this.applicationLogoUrl, required this.activePage,});

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
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage()));
          }, isActive: activePage == "Dashboard"),
          _drawerItem(context, Icons.analytics_outlined, "Statistics", () {
            Navigator.pop(context);
            Navigator.push(context,MaterialPageRoute(builder: (_) => const ChatbotStatisticsPage()),);
          }, isActive: activePage == "Statistics",),
          _drawerItem(context, Icons.chat_outlined, "Chat Logs", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsPage()));
          }, isActive: activePage == "Chat Logs"),
          _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbacksPage()));
          }, isActive: activePage == "Feedbacks"),
          _drawerItem(context, Icons.receipt_long_outlined, "Chatbot Data", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotDataPage()));
          }, isActive: activePage == "Chatbot Data"),
          _drawerItem(context, Icons.folder_open_outlined, "Chatbot Files", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotFilesPage()));
          }, isActive: activePage == "Chatbot Files"),
          const Spacer(),
          _drawerItem(
            context,
            Icons.logout,
            "Logout",
            () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                print("Logout error: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Logout failed. Please try again.", style: GoogleFonts.poppins())),
                  );
                }
              }
            },
            isLogout: true,
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isLogout = false, required bool isActive,}) {
    return _DrawerHoverButton(icon: icon, title: title, onTap: onTap, isLogout: isLogout, isActive: isActive);
  }
}

class _DrawerHoverButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLogout;
  final bool isActive;

  const _DrawerHoverButton({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isLogout = false,
    this.isActive = false,
  });

  @override
  State<_DrawerHoverButton> createState() => _DrawerHoverButtonState();
}

class _DrawerHoverButtonState extends State<_DrawerHoverButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: widget.isActive ? primarycolor.withOpacity(0.25) : (isHovered ? primarycolor.withOpacity(0.10) : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Icon(widget.icon, color: (widget.isLogout ? Colors.red : primarycolordark)),
          title: Text(widget.title, style: GoogleFonts.poppins(color: (widget.isLogout ? Colors.red : primarycolordark), fontWeight: FontWeight.w600)),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}