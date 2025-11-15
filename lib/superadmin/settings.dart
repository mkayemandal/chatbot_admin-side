import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/userinfo.dart';
import 'package:chatbot/superadmin/auditlogs.dart';
import 'package:chatbot/superadmin/chatlogs.dart';
import 'package:chatbot/superadmin/feedbacks.dart';
import 'package:chatbot/superadmin/profile.dart';
import 'package:chatbot/superadmin/emergencypage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:lottie/lottie.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;

const primarycolor = Color(0xFFffc803);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFF800000);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const lightBackground = Color(0xFFFEFEFE);

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
    // Use MediaQuery to detect small screen
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

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  bool isEditing = false;

  final _siteNameController = TextEditingController();
  final _appNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagline1Controller = TextEditingController();
  final _description1Controller = TextEditingController();
  final _tagline2Controller = TextEditingController();
  final _description2Controller = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _supportWebsiteController = TextEditingController();
  final _supportFacebookController = TextEditingController();
  final _faqControllers = <Map<String, dynamic>>[];

  String _appNameDisplay = '';
  String firstName = "";
  String lastName = "";
  String profilePictureUrl = "assets/images/defaultDP.jpg";

  String? _universityLogoUrl;
  bool _isUploadingUniversityLogo = false;

  String? _applicationLogoUrl;
  bool _isUploadingApplicationLogo = false;

  String? _backgroundImageUrl;
  bool _isUploadingBackgroundImage = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _aesKeyStorageKey = 'app_aes_key_v1';
  encrypt.Key? _cachedKey;

  bool _adminInfoLoaded = false;
  bool _settingsLoaded = false;
  bool _logoLoaded = false;

  Map<String, dynamic> _loadedSettings = {}; 

  bool get _allDataLoaded => _adminInfoLoaded && _settingsLoaded && _logoLoaded;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadSystemSettings();
    _loadApplicationLogo();
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
        
        // Cache locally for faster access
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

  Future<String> _loadSuperAdminEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Unknown';
      
      final doc = await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) return 'Unknown';
      
      final data = doc.data()!;
      final encryptedEmail = data['email'];
      
      if (encryptedEmail == null) {
        return user.email ?? 'Unknown';
      }
      
      final decryptedEmail = await _decryptValue(encryptedEmail);
      
      if (decryptedEmail != null && decryptedEmail.isNotEmpty) {
        print('✅ Successfully decrypted Super Admin email');
        return decryptedEmail;
      } else {
        print('⚠️ Email decryption failed, using Firebase Auth email');
        return user.email ?? 'Unknown';
      }
    } catch (e) {
      print('❌ Error loading Super Admin email: $e');
      return FirebaseAuth.instance.currentUser?.email ?? 'Unknown';
    }
  }

  Future<void> _loadSystemSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('SystemSettings').doc('global').get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _siteNameController.text = data['siteName'] ?? '';
          _appNameController.text = data['appName'] ?? '';
          _appNameDisplay = data['appName'] ?? '';
          _taglineController.text = data['tagline'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _tagline1Controller.text = data['tagline1'] ?? '';
          _description1Controller.text = data['description1'] ?? '';
          _tagline2Controller.text = data['tagline2'] ?? '';
          _description2Controller.text = data['description2'] ?? '';
          _supportEmailController.text = data['supportEmail'] ?? '';
          _supportPhoneController.text = data['supportPhone'] ?? '';
          _supportWebsiteController.text = data['supportWebsite'] ?? '';
          _supportFacebookController.text = data['supportFacebook'] ?? '';
          _universityLogoUrl = data['universityLogoUrl'] ?? null;
          _applicationLogoUrl = data['applicationLogoUrl'] ?? null;
          _backgroundImageUrl = data['backgroundImageUrl'] ?? null;

          _faqControllers.clear();
          if (data['faqs'] != null && data['faqs'] is List) {
            for (var faq in data['faqs']) {
              _faqControllers.add({
                'question': TextEditingController(text: faq['question']),
                'answer': TextEditingController(text: faq['answer']),
                'category': faq['category'] ?? 'General',
              });
            }
          }
          _loadedSettings = {
            'siteName': data['siteName'] ?? '',
            'tagline': data['tagline'] ?? '',
            'description': data['description'] ?? '',
            'appName': data['appName'] ?? '',
            'tagline1': data['tagline1'] ?? '',
            'description1': data['description1'] ?? '',
            'tagline2': data['tagline2'] ?? '',
            'description2': data['description2'] ?? '',
            'supportEmail': data['supportEmail'] ?? '',
            'supportPhone': data['supportPhone'] ?? '',
            'supportWebsite': data['supportWebsite'] ?? '',
            'supportFacebook': data['supportFacebook'] ?? '',
            'universityLogoUrl': data['universityLogoUrl'] ?? null,
            'applicationLogoUrl': data['applicationLogoUrl'] ?? null,
            'backgroundImageUrl': data['backgroundImageUrl'] ?? null,
            'faqs': List.from(data['faqs'] ?? []), 
          };
          _settingsLoaded = true;
        });
      } else {
        setState(() => _settingsLoaded = true);
      }
    } catch (e) {
      print('Error loading system settings: $e');
      setState(() => _settingsLoaded = true);
    }
  }

  Future<void> _saveSystemSettings() async {
    if (_siteNameController.text.trim().isEmpty ||
        _appNameController.text.trim().isEmpty ||
        _taglineController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _tagline1Controller.text.trim().isEmpty ||
        _description1Controller.text.trim().isEmpty ||
        _tagline2Controller.text.trim().isEmpty ||
        _description2Controller.text.trim().isEmpty ||
        _supportEmailController.text.trim().isEmpty ||
        _supportPhoneController.text.trim().isEmpty ||
        _supportWebsiteController.text.trim().isEmpty ||
        _supportFacebookController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    for (var faq in _faqControllers) {
      final question = faq['question'] as TextEditingController?;
      final answer = faq['answer'] as TextEditingController?;
      final category = faq['category'] as String?;

      if ((question?.text.trim().isEmpty ?? true) ||
          (answer?.text.trim().isEmpty ?? true) ||
          (category == null || category.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill in all FAQ fields.', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        return;
      }
    }

    List<String> updatedSections = [];
    bool adminWebsiteInfoChanged =
        _siteNameController.text.trim() != (_loadedSettings['siteName'] ?? '') ||
            _taglineController.text.trim() != (_loadedSettings['tagline'] ?? '') ||
            _descriptionController.text.trim() != (_loadedSettings['description'] ?? '');

    bool applicationInfoChanged =
        _appNameController.text.trim() != (_loadedSettings['appName'] ?? '') ||
        _tagline1Controller.text.trim() != (_loadedSettings['tagline1'] ?? '') ||
        _description1Controller.text.trim() != (_loadedSettings['description1'] ?? '') ||
        _tagline2Controller.text.trim() != (_loadedSettings['tagline2'] ?? '') ||
        _description2Controller.text.trim() != (_loadedSettings['description2'] ?? '');

    bool logoImagesChanged =
        _universityLogoUrl != (_loadedSettings['universityLogoUrl'] ?? null) ||
        _applicationLogoUrl != (_loadedSettings['applicationLogoUrl'] ?? null) ||
        _backgroundImageUrl != (_loadedSettings['backgroundImageUrl'] ?? null);

    bool supportContactChanged =
        _supportEmailController.text.trim() != (_loadedSettings['supportEmail'] ?? '') ||
        _supportPhoneController.text.trim() != (_loadedSettings['supportPhone'] ?? '') ||
        _supportWebsiteController.text.trim() != (_loadedSettings['supportWebsite'] ?? '') ||
        _supportFacebookController.text.trim() != (_loadedSettings['supportFacebook'] ?? '');

    bool faqsChanged = false;
    final List<Map<String, String>> currentFaqs = _faqControllers.map((faq) {
      return {
        'question': (faq['question'] as TextEditingController).text.trim(),
        'answer': (faq['answer'] as TextEditingController).text.trim(),
        'category': faq['category'] as String,
      };
    }).toList();
    
    if (currentFaqs.length != (_loadedSettings['faqs'] as List).length) {
      faqsChanged = true;
    } else {
      for (int i = 0; i < currentFaqs.length; i++) {
        final loadedFaq = _loadedSettings['faqs'][i];
        final currentFaq = currentFaqs[i];
        if (loadedFaq['question'] != currentFaq['question'] ||
            loadedFaq['answer'] != currentFaq['answer'] ||
            loadedFaq['category'] != currentFaq['category']) {
          faqsChanged = true;
          break;
        }
      }
    }
    
    if (adminWebsiteInfoChanged) updatedSections.add("Admin Website Information");
    if (applicationInfoChanged) updatedSections.add("Application Information");
    if (logoImagesChanged) updatedSections.add("Logo & Images");
    if (supportContactChanged) updatedSections.add("Chat Support Contact");
    if (faqsChanged) updatedSections.add("Frequently Asked Questions");

    String actionMessage = "Updated System Settings";
    String description;
    if (updatedSections.isEmpty) {
      description = "System settings were saved, but no changes detected.";
    } else if (updatedSections.length == 1) {
      description = "${updatedSections[0]} were updated.";
    } else if (updatedSections.length == 2) {
      description = "${updatedSections[0]} and ${updatedSections[1]} were updated.";
    } else {
      description = updatedSections.sublist(0, updatedSections.length - 1).join(', ') +
          " and ${updatedSections.last} were updated.";
    }

    try {
      final List<Map<String, String>> faqs = _faqControllers.map((faq) {
        return {
          'question': (faq['question'] as TextEditingController).text.trim(),
          'answer': (faq['answer'] as TextEditingController).text.trim(),
          'category': faq['category'] as String,
        };
      }).toList();

      await FirebaseFirestore.instance.collection('SystemSettings').doc('global').set({
        'siteName': _siteNameController.text.trim(),
        'appName': _appNameController.text.trim(),
        'tagline': _taglineController.text.trim(),
        'tagline1': _tagline1Controller.text.trim(),
        'description1': _description1Controller.text.trim(),
        'tagline2': _tagline2Controller.text.trim(),
        'description2': _description2Controller.text.trim(),
        'description': _descriptionController.text.trim(),
        'supportEmail': _supportEmailController.text.trim(),
        'supportPhone': _supportPhoneController.text.trim(),
        'supportWebsite': _supportWebsiteController.text.trim(),
        'supportFacebook': _supportFacebookController.text.trim(),
        'faqs': faqs,
        'universityLogoUrl': _universityLogoUrl,
        'applicationLogoUrl': _applicationLogoUrl,
        'backgroundImageUrl': _backgroundImageUrl,
      });

      final decryptedEmail = await _loadSuperAdminEmail();
      final encryptedEmailForLog = await _encryptValue(decryptedEmail);

      final log = {
        'action': actionMessage,
        'description': description,
        'performedBy': '$firstName $lastName',
        'email': encryptedEmailForLog ?? 'encrypted_error', 
        'timestamp': FieldValue.serverTimestamp(),
        'role': 'Super Admin',
      };
      
      await FirebaseFirestore.instance.collection('AuditLogs').add(log);

      print('✅ Audit log saved with encrypted email');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully!', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: primarycolor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      
      await _loadSystemSettings();
    } catch (e) {
      print('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings.', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<String?> uploadImageToCloudinary(XFile file, {required String preset}) async {
    try {
      const cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dvfwzl6gp/image/upload';

      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = preset; // use the preset passed from the caller

      if (kIsWeb) {
        Uint8List fileBytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: path.basename(file.name),
            contentType: MediaType.parse(
              lookupMimeType(file.name) ?? 'image/png',
            ),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: MediaType.parse(
              lookupMimeType(file.path) ?? 'image/png',
            ),
          ),
        );
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var data = json.decode(responseData);
        return data['secure_url'];
      } else {
        print('Cloudinary upload failed: ${response.statusCode}');
        print(await response.stream.bytesToString());
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _appNameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _tagline1Controller.dispose();
    _description1Controller.dispose();
    _tagline2Controller.dispose();
    _description2Controller.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _supportWebsiteController.dispose();
    _supportFacebookController.dispose();

    for (var faq in _faqControllers) {
      faq['question']!.dispose();
      faq['answer']!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName';

    if (!_allDataLoaded) {
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
        backgroundColor: lightBackground,
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Settings",
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
                  "System Settings",
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primarycolordark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      '${_appNameDisplay.isNotEmpty ? _appNameDisplay : "App"} Information',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      key: const ValueKey('edit_settings_button'),
                      onPressed: () async {
                        if (isEditing) {
                          bool hasEmptyField =
                              _siteNameController.text.trim().isEmpty ||
                                  _taglineController.text.trim().isEmpty ||
                                  _descriptionController.text.trim().isEmpty ||
                                  _supportEmailController.text.trim().isEmpty ||
                                  _supportPhoneController.text.trim().isEmpty ||
                                  _supportWebsiteController.text.trim().isEmpty ||
                                  _supportFacebookController.text.trim().isEmpty;

                          for (var faq in _faqControllers) {
                            final question = faq['question'] as TextEditingController?;
                            final answer = faq['answer'] as TextEditingController?;
                            final category = faq['category'] as String?;

                            if ((question?.text.trim().isEmpty ?? true) ||
                                (answer?.text.trim().isEmpty ?? true) ||
                                (category == null || category.trim().isEmpty)) {
                              hasEmptyField = true;
                              break;
                            }
                          }

                          if (hasEmptyField) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'All fields including FAQs must be filled in.',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                            return;
                          }
                          await _saveSystemSettings();
                        }

                        setState(() {
                          isEditing = !isEditing;
                        });
                      },
                      icon: Icon(
                        isEditing ? Icons.save : Icons.edit,
                        color: Colors.white,
                      ),
                      label: Text(
                        isEditing ? "Save Settings" : "Edit Settings",
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primarycolor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        elevation: 0,
                        textStyle: GoogleFonts.poppins(),
                      ),
                    ),
                    if (isEditing) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            isEditing = false;
                          });
                          _loadSystemSettings(); // Revert changes
                        },
                        icon: const Icon(Icons.cancel, color: Colors.white),
                        label: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          elevation: 0,
                          textStyle: GoogleFonts.poppins(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _cardSection(
                icon: Icons.description,
                title: "Admin Website Information",
                child: Column(
                  children: [
                    _inputRow("Name of the Website", _siteNameController, Icons.language),
                    _inputRow("Tagline", _taglineController, Icons.loyalty),
                    _inputRow("Description", _descriptionController, Icons.message_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _cardSection(
                icon: Icons.description,
                title: "Application Information",
                child: Column(
                  children: [
                    _inputRow("Name of the App", _appNameController, Icons.language),
                    _inputRow("Tagline 1", _tagline1Controller, Icons.loyalty),
                    _inputRow("Description", _description1Controller, Icons.message_outlined),
                    _inputRow("Tagline 2", _tagline2Controller, Icons.loyalty),
                    _inputRow("Description 2", _description2Controller, Icons.message_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _cardSection(
                icon: Icons.image_outlined,
                title: "Logo & Images",
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(
                            child: _imageUploader(
                              context,
                              "University Logo",
                              _universityLogoUrl,
                              "assets/images/DHVSU-LOGO.png",
                              isEditing,
                              (url) async {
                                setState(() {
                                  _universityLogoUrl = url;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _imageUploader(
                              context,
                              "Application Logo",
                              _applicationLogoUrl,
                              "assets/images/dhvbot.png",
                              isEditing,
                              (url) async {
                                setState(() {
                                  _applicationLogoUrl = url;
                                });
                              },
                              isApplicationLogo: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _imageUploader(
                              context,
                              "Background Image",
                              _backgroundImageUrl,
                              "assets/images/dhvbot.png",
                              isEditing,
                              (url) async {
                                setState(() {
                                  _backgroundImageUrl = url;
                                });
                              },
                              isBackgroundImage: true,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _imageUploader(
                            context,
                            "University Logo",
                            _universityLogoUrl,
                            "assets/images/DHVSU-LOGO.png",
                            isEditing,
                            (url) async {
                              setState(() {
                                _universityLogoUrl = url;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _imageUploader(
                            context,
                            "Application Logo",
                            _applicationLogoUrl,
                            "assets/images/dhvbot.png",
                            isEditing,
                            (url) async {
                              setState(() {
                                _applicationLogoUrl = url;
                              });
                            },
                            isApplicationLogo: true,
                          ),
                          const SizedBox(height: 16),
                          _imageUploader(
                            context,
                            "Background Image",
                            _backgroundImageUrl,
                            "assets/images/dhvbot.png",
                            isEditing,
                            (url) async {
                              setState(() {
                                _backgroundImageUrl = url;
                              });
                            },
                            isBackgroundImage: true,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              _cardSection(
                icon: Icons.support_agent,
                title: "Chat Support Contact",
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _inputRow("Support Website", _supportWebsiteController, Icons.language),
                    _inputRow("Support Facebook", _supportFacebookController, Icons.facebook),
                    _inputRow("Support Email", _supportEmailController, Icons.email_outlined),
                    _inputRow("Support Phone", _supportPhoneController, Icons.phone),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _cardSection(
                icon: Icons.question_answer_outlined,
                title: "Frequently Asked Questions",
                child: Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _faqControllers.length,
                      itemBuilder: (context, index) {
                        var faq = _faqControllers[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _faqItem(
                            faq["question"]!,
                            faq["answer"]!,
                            faq["category"] ?? "General",
                            (newCategory) {
                              setState(() {
                                faq["category"] = newCategory;
                              });
                            },
                          ),
                        );
                      },
                    ),
                    if (isEditing)
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _faqControllers.add({
                                "question": TextEditingController(),
                                "answer": TextEditingController(),
                                "category": "Choose Category",
                              });
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: Text(
                            "Add FAQ",
                            style: GoogleFonts.poppins(color: secondarycolor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primarycolordark),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primarycolordark,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _inputRow(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        readOnly: !isEditing,
        style: GoogleFonts.poppins(
          color: dark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primarycolor),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          labelStyle: GoogleFonts.poppins(
            color: dark,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: GoogleFonts.poppins(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: secondarycolor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primarycolordark, width: 1.6),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: secondarycolor),
          ),
        ),
      ),
    );
  }

  Widget _faqItem(
    TextEditingController question,
    TextEditingController answer,
    String category,
    ValueChanged<String> onCategoryChanged,
  ) {
    List<String> categories = ['General', 'Account', 'Service', 'Others'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: question,
            readOnly: !isEditing,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: dark,
            ),
            decoration: InputDecoration(
              labelText: 'Question',
              prefixIcon: const Icon(Icons.question_answer_outlined, color: primarycolor),
              filled: true,
              fillColor: Colors.white,
              labelStyle: GoogleFonts.poppins(
                color: dark,
                fontWeight: FontWeight.w500,
              ),
              floatingLabelStyle: GoogleFonts.poppins(
                color: primarycolordark,
                fontWeight: FontWeight.bold,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: secondarycolor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primarycolordark, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: answer,
            readOnly: !isEditing,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: dark,
            ),
            decoration: InputDecoration(
              labelText: 'Answer',
              prefixIcon: const Icon(Icons.text_snippet_outlined, color: primarycolor),
              filled: true,
              fillColor: Colors.white,
              labelStyle: GoogleFonts.poppins(
                color: dark,
                fontWeight: FontWeight.w500,
              ),
              floatingLabelStyle: GoogleFonts.poppins(
                color: primarycolordark,
                fontWeight: FontWeight.bold,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: secondarycolor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primarycolordark, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          isEditing
              ? DropdownButtonFormField<String>(
                  value: categories.contains(category) ? category : 'General',
                  items: categories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onCategoryChanged(value);
                  },
                  style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: const Icon(Icons.category, color: primarycolor),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
                    floatingLabelStyle: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondarycolor, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primarycolordark, width: 1.6),
                    ),
                  ),
                )
              : TextFormField(
                  enabled: false,
                  controller: TextEditingController(text: category),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: const Icon(Icons.category, color: primarycolor),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
                    floatingLabelStyle: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondarycolor, width: 1.5),
                    ),
                  ),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: dark),
                ),
          const SizedBox(height: 12),
          if (isEditing)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _faqControllers.removeWhere(
                      (item) => item["question"] == question && item["answer"] == answer && item["category"] == category,
                    );
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageUploader(
    BuildContext context,
    String title,
    String? imageUrl,
    String assetImagePath,
    bool isEditable,
    Future<void> Function(String url)? onImageUploaded, {
    bool isApplicationLogo = false,
    bool isBackgroundImage = false,
  }) {
    final isUploading = isBackgroundImage
        ? _isUploadingBackgroundImage
        : isApplicationLogo
            ? _isUploadingApplicationLogo
            : _isUploadingUniversityLogo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: dark,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          )
                        : Image.asset(
                            assetImagePath,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: isEditable
                    ? GestureDetector(
                        onTap: isUploading
                            ? null
                            : () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? pickedFile =
                                    await picker.pickImage(source: ImageSource.gallery);
                                if (pickedFile != null) {
                                  // Start uploading
                                  setState(() {
                                    if (isBackgroundImage) {
                                      _isUploadingBackgroundImage = true;
                                    } else if (isApplicationLogo) {
                                      _isUploadingApplicationLogo = true;
                                    } else {
                                      _isUploadingUniversityLogo = true;
                                    }
                                  });

                                  // ← Add preset logic here
                                  String preset = isApplicationLogo
                                      ? 'app_logo_preset'
                                      : isBackgroundImage
                                          ? 'background_preset'
                                          : 'university_logo_preset';

                                  // Call upload function with preset
                                  String? url = await uploadImageToCloudinary(pickedFile, preset: preset);

                                  // Stop uploading
                                  setState(() {
                                    if (isBackgroundImage) {
                                      _isUploadingBackgroundImage = false;
                                    } else if (isApplicationLogo) {
                                      _isUploadingApplicationLogo = false;
                                    } else {
                                      _isUploadingUniversityLogo = false;
                                    }
                                  });

                                  if (url != null && onImageUploaded != null) {
                                    await onImageUploaded(url);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${title} updated successfully!',
                                            style: GoogleFonts.poppins()),
                                        backgroundColor: primarycolor,
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Failed to upload image.', style: GoogleFonts.poppins()),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: Row(
                          children: [
                            const Icon(Icons.upload_file, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              isUploading ? "Uploading..." : "Choose File",
                              style: GoogleFonts.poppins(fontSize: 12, color: dark),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          const Icon(Icons.upload_file, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Choose File",
                            style: GoogleFonts.poppins(fontSize: 12, color: dark),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HoverButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget? child;
  final bool isLogout;
  final IconData? icon;
  final String? label;
  final bool isActive;

  const HoverButton({
    Key? key,
    required this.onPressed,
    this.child,
    this.isLogout = false,
    this.icon,
    this.label,
    this.isActive = false,
  }) : super(key: key);

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.icon != null && widget.label != null) {
      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          decoration: BoxDecoration(
            color: widget.isActive
                ? primarycolor.withOpacity(0.25) 
                : (isHovered ? primarycolor.withOpacity(0.10) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Icon(
              widget.icon,
              color: widget.isActive ? primarycolordark : (widget.isLogout ? Colors.red : primarycolordark),
            ),
            title: Text(
              widget.label ?? '',
              style: GoogleFonts.poppins(
                color: widget.isActive ? primarycolordark : (widget.isLogout ? Colors.red : primarycolordark),
                fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            onTap: widget.onPressed,
          ),
        ),
      );
    } else {
      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          transform: isHovered ? (Matrix4.identity()..scale(1.07)) : Matrix4.identity(),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: primarycolordark,
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            onPressed: widget.onPressed,
            child: widget.child ?? const SizedBox(),
          ),
        ),
      );
    }
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
          // _drawerItem(context, Icons.chat_outlined, "Chat Logs", () {
          //   Navigator.pop(context);
          //   Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsPage()));
          // }),
          _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbacksPage()));
          }),
          _drawerItem(context, Icons.admin_panel_settings_outlined, "Admin Management", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManagementPage()));
          }),
          // _drawerItem(
          //   context,
          //   Icons.warning_amber_rounded,
          //   "Emergency Requests",
          //   () {
          //     Navigator.pop(context);
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const EmergencyRequestsPage()),
          //     );
          //   },
          // ),
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
    return HoverButton(
      onPressed: onTap,
      isLogout: isLogout,
      icon: icon,
      label: title,
      isActive: activePage == title,
    );
  }
}