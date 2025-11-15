import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'dart:async';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/feedbacks.dart';
import 'package:chatbot/admin/profile.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/admin/chatbotfiles.dart';
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
      .map((word) =>
          word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
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

class ChatbotDataPage extends StatefulWidget {
  const ChatbotDataPage({super.key});
  @override
  State<ChatbotDataPage> createState() => _ChatbotDataPageState();
}

class _ChatbotDataPageState extends State<ChatbotDataPage> {
  final TextEditingController _searchController = TextEditingController();
  String firstName = "";
  String lastName = "";
  String? _applicationName;
  String? _applicationLogoUrl;
  bool _logoLoaded = false;
  bool _adminInfoLoaded = false;
  bool _chatbotDataLoaded = false;
  bool get _allDataLoaded => _adminInfoLoaded && _chatbotDataLoaded && _logoLoaded;

  String? adminDepartment;
  bool isSuperAdmin = false;

  List<String> departmentChoices = [];
  Map<String, List<Map<String, dynamic>>> departmentData = {};
  int tabPage = 0;
  int _selectedTabIndex = 0;
  String? selectedLanguage;
  String? searchKeyword;

  // Encryption components
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _aesKeyStorageKey = 'app_aes_key_v1';
  encrypt.Key? _cachedKey;

  @override
  void initState() {
    super.initState();
    _initializePage();
    _searchController.addListener(() {
      setState(() {
        searchKeyword = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _initializePage() async {
    await _loadAdminInfo();
    await Future.wait([
      _loadApplicationSettings(),
      _loadChatbotData(),
    ]);
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
        print('✅ ChatbotData: Loaded encryption key from Firestore');
        return _cachedKey!;
      }
    } catch (e) {
      print('⚠️ ChatbotData: Error loading key from Firestore: $e');
    }
    
    final existing = await _secureStorage.read(key: _aesKeyStorageKey);
    if (existing != null) {
      final bytes = base64Decode(existing);
      _cachedKey = encrypt.Key(bytes);
      print('✅ ChatbotData: Loaded encryption key from local storage');
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
      print('✅ ChatbotData: Created new encryption key in Firestore');
    } catch (e) {
      print('⚠️ ChatbotData: Could not save key to Firestore: $e');
    }
    
    await _secureStorage.write(
      key: _aesKeyStorageKey,
      value: keyBase64,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
    
    _cachedKey = generated;
    print('✅ ChatbotData: Created new encryption key locally');
    return _cachedKey!;
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

  Future<void> _loadApplicationSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('global')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _applicationLogoUrl = data['applicationLogoUrl'] as String?;
          _applicationName = data['appName'] as String? ?? "Chatbot Data";
          _logoLoaded = true;
        });
      } else {
        setState(() {
          _applicationLogoUrl = null;
          _applicationName = "Chatbot Data";
          _logoLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading application settings: $e');
      setState(() {
        _applicationLogoUrl = null;
        _applicationName = "Chatbot Data";
        _logoLoaded = true;
      });
    }
  }

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          adminDepartment = null;
          isSuperAdmin = false;
          _adminInfoLoaded = true;
        });
        return;
      }

      final uid = user.uid;
      final email = user.email?.trim();
      DocumentSnapshot<Map<String, dynamic>>? adminDoc;
      DocumentSnapshot<Map<String, dynamic>>? superDoc;

      try {
        final d = await FirebaseFirestore.instance.collection('Admin').doc(uid).get();
        if (d.exists) adminDoc = d;
      } catch (_) {}

      if ((adminDoc == null || !adminDoc.exists) && email != null && email.isNotEmpty) {
        try {
          final d = await FirebaseFirestore.instance.collection('Admin').doc(email).get();
          if (d.exists) adminDoc = d;
        } catch (_) {}
      }

      if ((adminDoc == null || !adminDoc.exists) && email != null && email.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('Admin')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) adminDoc = q.docs.first;
        } catch (_) {}
      }

      try {
        final d = await FirebaseFirestore.instance.collection('SuperAdmin').doc(uid).get();
        if (d.exists) superDoc = d;
      } catch (_) {}
      if ((superDoc == null || !superDoc.exists) && email != null && email.isNotEmpty) {
        try {
          final d = await FirebaseFirestore.instance.collection('SuperAdmin').doc(email).get();
          if (d.exists) superDoc = d;
        } catch (_) {}
      }
      if ((superDoc == null || !superDoc.exists) && email != null && email.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('SuperAdmin')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) superDoc = q.docs.first;
        } catch (_) {}
      }

      if (adminDoc != null && adminDoc.exists) {
        final data = adminDoc.data()!;
        setState(() {
          firstName = capitalizeEachWord(data['firstName'] ?? '');
          lastName = capitalizeEachWord(data['lastName'] ?? '');
          adminDepartment = (data['department'] ?? '').toString().trim();
          isSuperAdmin = false;
          _adminInfoLoaded = true;
        });
        return;
      } else if (superDoc != null && superDoc.exists) {
        final data = superDoc.data()!;
        setState(() {
          firstName = capitalizeEachWord(data['firstName'] ?? '');
          lastName = capitalizeEachWord(data['lastName'] ?? '');
          adminDepartment = null;
          isSuperAdmin = true;
          _adminInfoLoaded = true;
        });
        return;
      } else {
        setState(() {
          adminDepartment = null;
          isSuperAdmin = false;
          _adminInfoLoaded = true;
        });
        return;
      }
    } catch (e) {
      print('Error loading admin info: $e');
      setState(() {
        adminDepartment = null;
        isSuperAdmin = false;
        _adminInfoLoaded = true;
      });
    }
  }

  Future<void> _loadChatbotData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('CsvData').get();
      final tempDeptMap = <String, List<Map<String, dynamic>>>{};

      for (final doc in snapshot.docs) {
        final departmentName = doc.id;

        if (!isSuperAdmin && adminDepartment != null && adminDepartment!.isNotEmpty) {
          final deptA = departmentName.trim().toLowerCase();
          final deptB = adminDepartment!.trim().toLowerCase();
          if (deptA != deptB) continue;
        }

        final dataList = doc['data'] as List<dynamic>? ?? [];
        tempDeptMap[departmentName] = [];
        for (int i = 0; i < dataList.length; i++) {
          final item = dataList[i];
          if (item is! Map) continue;
          var question =
              item['question']?.toString().replaceAll(r'\n', '\n') ?? '';
          var answer = item['answer']?.toString().replaceAll(r'\n', '\n') ?? '';
          final language = item['language']?.toString();
          question = _stripQuotes(question);
          answer = _stripQuotes(answer);
          if (question.isEmpty || answer.isEmpty) continue;
          tempDeptMap[departmentName]!.add({
            'index': i,
            'question': TextEditingController(text: question),
            'answer': TextEditingController(text: answer),
            'language': language ?? '',
            'department': departmentName,
            'originalDepartment': departmentName,
            'isSaved': true,
          });
        }
      }

      setState(() {
        departmentData = tempDeptMap;
        departmentChoices = tempDeptMap.keys.toList();
        _chatbotDataLoaded = true;
      });
    } catch (e) {
      print('Error loading chatbot data: $e');
      setState(() => _chatbotDataLoaded = true);
    }
  }

  String _stripQuotes(String input) {
    return input.replaceAll(RegExp(r'^"(.*)"$'), r'\1').trim();
  }

  Future<void> _saveDataSet(Map<String, dynamic> dataSet, String department) async {
    final question = (dataSet['question'] as TextEditingController).text.trim();
    final answer = (dataSet['answer'] as TextEditingController).text.trim();
    final language = dataSet['language'] as String;
    final originalIndex = dataSet['index'] as int?;
    final deptList = departmentData[department] ?? [];

    if (question.isEmpty || answer.isEmpty || language.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All fields must be filled.')),
        );
      }
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('CsvData').doc(department);
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        final newDataList = [
          {'question': question, 'answer': answer, 'language': language}
        ];
        await docRef.set({'data': newDataList}, SetOptions(merge: true));
        setState(() {
          dataSet['isSaved'] = true;
          dataSet['index'] = 0;
          dataSet['originalDepartment'] = department;
        });

        await logAuditAction(
          action: 'Added Chatbot Data',
          description:
              'Added chatbot entry to "$department" (Question: $question, Answer: $answer, Lang: $language).',
          department: department,
          index: 0,
          language: language,
          question: question,
          answer: answer,
          before: null,
          after: {'question': question, 'answer': answer, 'language': language},
        );
        return;
      }

      List<Map<String, dynamic>> dataList = [];
      final rawList = snapshot.get('data') as List<dynamic>? ?? [];
      for (final item in rawList) {
        if (item is Map) dataList.add(Map<String, dynamic>.from(item as Map));
      }

      final bool isEdit = originalIndex != null && originalIndex >= 0 && originalIndex < dataList.length;
      Map<String, dynamic>? before;
      if (isEdit) {
        before = Map<String, dynamic>.from(dataList[originalIndex!]);
        dataList[originalIndex!] = {
          'question': question,
          'answer': answer,
          'language': language,
        };
      } else {
        dataList.add({
          'question': question,
          'answer': answer,
          'language': language,
        });
      }

      await docRef.set({'data': dataList}, SetOptions(merge: true));

      await logAuditAction(
        action: isEdit ? 'Edited Chatbot Data' : 'Added Chatbot Data',
        description: isEdit
            ? 'Edited chatbot entry in "$department" (Index: $originalIndex, Question: $question, Answer: $answer, Lang: $language).'
            : 'Added chatbot entry to "$department" (Question: $question, Answer: $answer, Lang: $language).',
        department: department,
        index: isEdit ? originalIndex : (dataList.length - 1),
        language: language,
        question: question,
        answer: answer,
        before: before,
        after: {'question': question, 'answer': answer, 'language': language},
      );

      setState(() {
        dataSet['isSaved'] = true;
        dataSet['index'] = isEdit ? originalIndex : dataList.length - 1;
        dataSet['originalDepartment'] = department;
      });
    } catch (e) {
      print('Error saving data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save data: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteDataSet(Map<String, dynamic> dataSet, String department) async {
    final index = dataSet['index'] as int?;

    if (index == null || department.isEmpty) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('CsvData').doc(department);
      final snapshot = await docRef.get();

      if (!snapshot.exists) return;

      List<Map<String, dynamic>> dataList = [];
      final rawList = snapshot.get('data') as List<dynamic>? ?? [];
      for (final item in rawList) {
        if (item is Map) dataList.add(Map<String, dynamic>.from(item as Map));
      }

      if (index < 0 || index >= dataList.length) return;

      final removedEntry = Map<String, dynamic>.from(dataList.removeAt(index));

      await docRef.set({'data': dataList}, SetOptions(merge: true));

      await logAuditAction(
        action: 'Deleted Chatbot Data',
        description:
            'Deleted chatbot entry from "$department" (Index: $index, Question: ${removedEntry['question']}, Answer: ${removedEntry['answer']}, Lang: ${removedEntry['language']}).',
        department: department,
        index: index,
        language: removedEntry['language']?.toString(),
        question: removedEntry['question']?.toString(),
        answer: removedEntry['answer']?.toString(),
        before: removedEntry,
        after: null,
      );

      setState(() {
        departmentData[department]?.remove(dataSet);
      });
    } catch (e) {
      print('Error deleting dataset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting data: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> logAuditAction({
    required String action,
    required String description,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    String? department,
    int? index,
    String? language,
    String? question,
    String? answer,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String fullName = 'Unknown';
    String emailPlain = user.email ?? 'No Email';
    String role = '';

    try {
      DocumentSnapshot adminDoc =
          await FirebaseFirestore.instance.collection('Admin').doc(user.uid).get();

      if (!adminDoc.exists && emailPlain.isNotEmpty) {
        final byEmailDoc =
            await FirebaseFirestore.instance.collection('Admin').doc(emailPlain).get();
        if (byEmailDoc.exists) {
          adminDoc = byEmailDoc;
        } else {
          final q = await FirebaseFirestore.instance
              .collection('Admin')
              .where('email', isEqualTo: emailPlain)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) adminDoc = q.docs.first;
        }
      }

      if (adminDoc.exists) {
        final data = adminDoc.data() as Map<String, dynamic>;
        final fn = capitalizeEachWord(data['firstName'] ?? '');
        final ln = capitalizeEachWord(data['lastName'] ?? '');
        fullName = '$fn $ln'.trim();
        role = data['role'] ?? 'Admin';
      }

      // Encrypt the email before storing in audit log
      final encryptedEmail = await _encryptValue(emailPlain) ?? emailPlain;

      final auditEntry = <String, dynamic>{
        'performedBy': fullName,
        'email': encryptedEmail, // Now encrypted
        'role': role,
        'action': action,
        'description': description,
        'department': department ?? '',
        'index': index,
        'language': language ?? '',
        'question': question ?? '',
        'answer': answer ?? '',
        'before': before,
        'after': after,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('AuditLogs').add(auditEntry);
      print('✅ Audit log saved with encrypted email');
    } catch (e) {
      print('❌ Audit log failed: $e');
    }
  }

  @override
  void dispose() {
    for (var deptList in departmentData.values) {
      for (var ds in deptList) {
        (ds['question'] as TextEditingController).dispose();
        (ds['answer'] as TextEditingController).dispose();
      }
    }
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getFilteredData(String department) {
    var list = departmentData[department] ?? [];
    return list.where((item) {
      final question = item['question'].text.toLowerCase();
      final answer = item['answer'].text.toLowerCase();
      final lang = (item['language'] ?? '').toString();
      final matchesKeyword = searchKeyword == null || searchKeyword!.isEmpty
          || question.contains(searchKeyword!)
          || answer.contains(searchKeyword!);
      final matchesLang = selectedLanguage == null || selectedLanguage!.isEmpty
          || lang == selectedLanguage;
      return matchesKeyword && matchesLang;
    }).toList();
  }

  Widget _buildSingleDepartmentView(bool isSmallScreen) {
    if (departmentChoices.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                "assets/images/web-search.png",
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 12),
              Text(
                (adminDepartment != null && adminDepartment!.isNotEmpty && !isSuperAdmin)
                    ? 'No data available for "$adminDepartment".'
                    : "No departments available.",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    String deptToShow = departmentChoices.first;

    if (adminDepartment != null && adminDepartment!.isNotEmpty) {
      final match = departmentChoices.firstWhere(
          (d) => d.trim().toLowerCase() == adminDepartment!.trim().toLowerCase(),
          orElse: () => '');
      if (match.isNotEmpty) {
        deptToShow = match;
      } else {
        final containsMatch = departmentChoices.firstWhere(
          (d) => d.trim().toLowerCase().contains(adminDepartment!.trim().toLowerCase()) ||
                 adminDepartment!.trim().toLowerCase().contains(d.trim().toLowerCase()),
          orElse: () => '',
        );
        if (containsMatch.isNotEmpty) deptToShow = containsMatch;
      }
    }

    return Expanded(
      child: _buildDepartmentTab(
        deptToShow,
        departmentData[deptToShow] ?? [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName';
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

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
      data: Theme.of(context).copyWith(textTheme: poppinsTextTheme, primaryTextTheme: poppinsTextTheme),
      child: Scaffold(
        backgroundColor: lightBackground,
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Chatbot Data",
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: primarycolordark),
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 12),
              Text(
                "${_applicationName ?? "Chatbot"} Data",
                style: GoogleFonts.poppins(
                  color: primarycolordark,
                  fontWeight: FontWeight.bold,
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
                role: isSuperAdmin ? "SuperAdmin" : "Admin - ${adminDepartment ?? 'No Department'}",
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                margin: const EdgeInsets.only(bottom: 8, top: 16),
                decoration: BoxDecoration(
                  color: primarycolordark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      "${_applicationName ?? "Chatbot"} Data",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            _buildFilterSection(isSmallScreen),
            const SizedBox(height: 8),
            _buildSingleDepartmentView(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isSmallScreen) {
    final languageOptions = departmentData.values
        .expand((list) => list.map((e) => e['language']?.toString() ?? ''))
        .where((lang) => lang.isNotEmpty)
        .toSet()
        .toList();

    if (isSmallScreen) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(color: dark),
                  decoration: InputDecoration(
                    hintText: 'Search keyword...',
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
                      borderSide: const BorderSide(color: secondarycolor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Language',
                    prefixIcon: const Icon(Icons.language, color: primarycolor),
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
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: secondarycolor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: primarycolordark, width: 1.5),
                    ),
                  ),
                  value: selectedLanguage,
                  items: languageOptions.map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text(
                        lang,
                        style: GoogleFonts.poppins(color: dark),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedLanguage = value;
                    });
                  },
                  style: GoogleFonts.poppins(color: dark),
                  iconEnabledColor: secondarycolor,
                  dropdownColor: Colors.white,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        selectedLanguage = null;
                        searchKeyword = null;
                        _searchController.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: primarycolordark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide.none,
                    ),
                    child: Text(
                      'Clear Filter',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
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
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(color: dark),
                    decoration: InputDecoration(
                      hintText: 'Search keyword...',
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
                        borderSide: const BorderSide(color: secondarycolor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Language',
                      prefixIcon: const Icon(Icons.language, color: primarycolor),
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
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: secondarycolor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: primarycolordark, width: 1.5),
                      ),
                    ),
                    value: selectedLanguage,
                    items: languageOptions.map((lang) {
                      return DropdownMenuItem(
                        value: lang,
                        child: Text(
                          lang,
                          style: GoogleFonts.poppins(color: dark),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLanguage = value;
                      });
                    },
                    style: GoogleFonts.poppins(color: dark),
                    iconEnabledColor: secondarycolor,
                    dropdownColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          selectedLanguage = null;
                          searchKeyword = null;
                          _searchController.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: primarycolordark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide.none,
                      ),
                      child: Text(
                        'Clear Filter',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _cardSection(
      {required IconData icon,
      required String title,
      required Widget child}) {
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
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primarycolordark,
                    ),
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

  Widget _buildDepartmentTab(
    String department, List<Map<String, dynamic>> dataSets) {
    String sectionTitle = "${department} Data";
    // Use the real backing list for this department, not filtered!
    var deptList = departmentData[department] ?? [];
    var filteredList = getFilteredData(department);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardSection(
            icon: Icons.question_answer_outlined,
            title: sectionTitle,
            child: Column(
              children: [
                for (var dataSet in filteredList)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _DataSetItem(dataSet, department),
                  ),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        // Always add to backing list
                        departmentData[department] ??= [];
                        departmentData[department]!.add({
                          "question": TextEditingController(),
                          "answer": TextEditingController(),
                          "language": "",
                          "department": department,
                          "originalDepartment": department,
                          "id": "",
                          "isSaved": false,
                        });
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline,
                        color: secondarycolor),
                    label: Text(
                      "Add Data ",
                      style: GoogleFonts.poppins(color: secondarycolor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _DataSetItem(Map<String, dynamic> DataSet, String department) {
    final question = DataSet['question'] as TextEditingController;
    final answer = DataSet['answer'] as TextEditingController;
    final language = DataSet['language'] as String;
    final isSaved = DataSet['isSaved'] as bool;

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
        children: [
          TextField(
            controller: question,
            readOnly: isSaved,
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
                borderSide: const BorderSide(color: secondarycolor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primarycolordark, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: answer,
            readOnly: isSaved,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: dark,
            ),
            decoration: InputDecoration(
              labelText: 'Answer',
              prefixIcon: const Icon(Icons.text_snippet_outlined, color: primarycolor),
              alignLabelWithHint: true,
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
                borderSide: const BorderSide(color: secondarycolor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primarycolordark, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Department field: always disabled/non-editable, show the current tab's department
          TextFormField(
            enabled: false,
            controller: TextEditingController(text: department),
            decoration: InputDecoration(
              labelText: 'Department',
              prefixIcon: const Icon(Icons.apartment, color: primarycolor),
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
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: secondarycolor, width: 1.5),
              ),
            ),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: dark,
            ),
          ),
          const SizedBox(height: 12),
          isSaved
              ? TextFormField(
                  enabled: false,
                  controller: TextEditingController(text: language),
                  decoration: InputDecoration(
                    labelText: 'Language',
                    prefixIcon: const Icon(Icons.language, color: primarycolor),
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
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: secondarycolor, width: 1.5),
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: dark,
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: language.isEmpty ? null : language,
                  hint: Text(
                    'Choose a Language',
                    style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
                  ),
                  dropdownColor: Colors.white,
                  iconEnabledColor: secondarycolor,
                  style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
                  items: ['English', 'Tagalog', 'Kapampangan']
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        DataSet['language'] = val;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Language',
                    prefixIcon: const Icon(Icons.language, color: primarycolor),
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
                      borderSide: const BorderSide(color: secondarycolor, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primarycolordark, width: 1.6),
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isSaved) ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: primarycolor),
                  onPressed: () {
                    setState(() {
                      DataSet['isSaved'] = false;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: "Delete",
                  onPressed: () async {
                    await _deleteDataSet(DataSet, department);
                  },
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () async {
                    final questionText = question.text.trim();
                    final answerText = answer.text.trim();
                    final languageText = DataSet['language'] as String;

                    if (questionText.isEmpty || answerText.isEmpty || languageText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('All fields must be filled before saving.', style: GoogleFonts.poppins(color: Colors.white)),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    await _saveDataSet(DataSet, department);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  tooltip: "Cancel",
                  onPressed: () {
                    setState(() {
                      departmentData[department]?.remove(DataSet);
                    });
                  },
                ),
              ],
            ],
          )
        ],
      ),
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  final String? applicationLogoUrl;
  final String activePage;
  const NavigationDrawer(
      {super.key, this.applicationLogoUrl, required this.activePage});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: lightBackground),
            child: Center(
              child: applicationLogoUrl != null &&
                      applicationLogoUrl!.isNotEmpty
                  ? Image.network(
                      applicationLogoUrl!,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset(
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
            );
          }, isActive: activePage == "Dashboard"),
          _drawerItem(context, Icons.analytics_outlined, "Statistics", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotStatisticsPage()),
            );
          }, isActive: activePage == "Statistics",),
          // _drawerItem(context, Icons.people_outline, "Users Info", () {
          //   Navigator.pop(context);
          //   Navigator.push(
          //     context,
          //     MaterialPageRoute(builder: (_) => const UserinfoPage()),
          //   );
          // }, isActive: activePage == "Users Info"),
          _drawerItem(context, Icons.chat_outlined, "Chat Logs", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatsPage()),
            );
          }, isActive: activePage == "Chat Logs"),
          _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbacksPage()),
            );
          }, isActive: activePage == "Feedbacks"),
          _drawerItem(context, Icons.receipt_long_outlined, "Chatbot Data", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotDataPage()),
            );
          }, isActive: activePage == "Chatbot Data"),
          _drawerItem(context, Icons.folder_open_outlined, "Chatbot Files", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotFilesPage()),
            );
          }, isActive: activePage == "Chatbot Files"),
          const Spacer(),
          _drawerItem(
            context,
            Icons.logout,
            "Logout",
            () async {
              try {
                // Sign out the user
                await FirebaseAuth.instance.signOut();

                // Optional: Clear local storage if you used SharedPreferences
                // final prefs = await SharedPreferences.getInstance();
                // await prefs.clear();

                // Replace the entire route stack with the login page
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
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title,
      VoidCallback onTap,
      {bool isLogout = false, required bool isActive}) {
    return _DrawerHoverButton(
      icon: icon,
      title: title,
      onTap: onTap,
      isLogout: isLogout,
      isActive: isActive,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: widget.isActive
              ? primarycolor.withOpacity(0.25)
              : (isHovered
                  ? primarycolor.withOpacity(0.10)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Icon(
            widget.icon,
            color: (widget.isLogout ? Colors.red : primarycolordark),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.poppins(
              color: (widget.isLogout ? Colors.red : primarycolordark),
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}