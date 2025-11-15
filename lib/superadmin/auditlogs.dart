import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/userinfo.dart';
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
            color: isHovered ? Colors.grey.withOpacity(0.15) : Colors.transparent,
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
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: dark),
                        ),
                        Text(
                          widget.role,
                          style: GoogleFonts.poppins(fontSize: 12, color: dark),
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

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  int totalLogs = 0;
  int superAdminLogs = 0;
  int adminLogs = 0;
  List<String> actionChoices = [];
  String? selectedAction;
  String firstName = "";
  String lastName = "";
  String userRole = 'Super Admin';
  String profilePictureUrl = "assets/images/defaultDP.jpg";
  String? selectedUser;
  DateTime? selectedDate;

  bool _adminInfoLoaded = false;
  bool _actionChoicesLoaded = false;
  bool _logsCountLoaded = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _aesKeyStorageKey = 'app_aes_key_v1';
  encrypt.Key? _cachedKey;
  
  final Map<String, String> _emailCache = {};

  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  bool get _allDataLoaded =>
      _adminInfoLoaded && _actionChoicesLoaded && _logsCountLoaded && _logoLoaded;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _emailCache.clear();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _loadUserInfo(),
      _loadActionChoices(),
      _countLogs(),
      _loadApplicationLogo(),
    ]);
  }

  Future<encrypt.Key?> _getOrCreateAesKey() async {
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
        print('✅ AuditLogs: Loaded encryption key from Firestore');
        return _cachedKey!;
      }
    } catch (e) {
      print('⚠️ AuditLogs: Error loading key from Firestore: $e');
    }
    
    final existing = await _secureStorage.read(key: _aesKeyStorageKey);
    if (existing != null) {
      final bytes = base64Decode(existing);
      _cachedKey = encrypt.Key(bytes);
      print('✅ AuditLogs: Loaded encryption key from local storage');
      return _cachedKey!;
    }
    
    print('⚠️ AuditLogs: No encryption key found');
    return null;
  }

  Future<String?> _decryptValue(String encoded) async {
    if (encoded.isEmpty) return null;
    
    if (_emailCache.containsKey(encoded)) {
      return _emailCache[encoded];
    }
    
    try {
      final key = await _getOrCreateAesKey();
      if (key == null) {
        print('⚠️ Cannot decrypt: No encryption key available');
        return null;
      }
      
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
      
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      
      _emailCache[encoded] = decrypted;
      
      return decrypted;
    } catch (e) {
      print('❌ Decryption failed for email: $e');
      return null;
    }
  }

  bool _looksEncrypted(String value) {
    if (value.isEmpty) return false;
    
    try {
      base64Decode(value);
      return value.length > 50 && !value.contains('@');
    } catch (_) {
      return false;
    }
  }

  Future<String> _getDisplayEmail(String email) async {
    if (email.isEmpty) return 'No Email';
    
    if (email.contains('@') && email.contains('.')) {
      return email;
    }
    
    if (_looksEncrypted(email)) {
      final decrypted = await _decryptValue(email);
      if (decrypted != null && decrypted.isNotEmpty) {
        return decrypted;
      }
      return '[Encrypted Email]';
    }
    
    return email;
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

  Future<void> _loadActionChoices() async {
    final snapshot = await FirebaseFirestore.instance.collection('AuditLogs').get();

    final uniqueActions = snapshot.docs.map((doc) => doc['action'] as String?).whereType<String>().toSet().toList();
    uniqueActions.sort();

    setState(() {
      actionChoices = uniqueActions;
      _actionChoicesLoaded = true;
    });
  }

  Future<void> _countLogs() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('AuditLogs').get();

      int total = snapshot.docs.length;
      int superAdminCount = 0;
      int adminCount = 0;

      for (var doc in snapshot.docs) {
        final role = doc['role']?.toString().trim() ?? '';
        if (role == 'Super Admin') {
          superAdminCount++;
        } else if (role == 'Admin') {
          adminCount++;
        }
      }

      setState(() {
        totalLogs = total;
        superAdminLogs = superAdminCount;
        adminLogs = adminCount;
        _logsCountLoaded = true;
      });
    } catch (e) {
      print("Error counting logs: $e");
      setState(() => _logsCountLoaded = true);
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _adminInfoLoaded = true);
        return;
      }

      DocumentSnapshot? userDoc = await FirebaseFirestore.instance.collection('SuperAdmin').doc(user.uid).get();

      String role = 'Super Admin';

      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance.collection('Admin').doc(user.uid).get();
        if (userDoc.exists) {
          role = 'Admin';
        }
      }

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          firstName = capitalizeEachWord(data['firstName'] ?? '');
          lastName = capitalizeEachWord(data['lastName'] ?? '');
          profilePictureUrl = data['profilePicture'] ?? "assets/images/defaultDP.jpg";
          userRole = role;
          _adminInfoLoaded = true;
        });
      } else {
        setState(() => _adminInfoLoaded = true);
      }
    } catch (e) {
      print('Error fetching user info: $e');
      setState(() => _adminInfoLoaded = true);
    }
  }

  Stream<List<Map<String, dynamic>>> getAuditLogsStream() {
    return FirebaseFirestore.instance
        .collection('AuditLogs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> logs = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final encryptedEmail = data['email'] ?? '';
        
        final displayEmail = await _getDisplayEmail(encryptedEmail);
        
        logs.add({
          'name': data['performedBy'] ?? '',
          'email': displayEmail, 
          'action': data['action'] ?? '',
          'timestamp': data['timestamp'] ?? '',
          'desc': data['description'] ?? '',
        });
      }
      
      return logs;
    });
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

    final poppinsTextTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(bodyColor: dark, displayColor: dark);

    return Theme(
      data: Theme.of(context).copyWith(textTheme: poppinsTextTheme, primaryTextTheme: poppinsTextTheme),
      child: Scaffold(
        backgroundColor: lightBackground,
        drawer: NavigationDrawer(applicationLogoUrl: _applicationLogoUrl, activePage: "Audit Logs"),
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
                  "Audit Logs",
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
                imageUrl: profilePictureUrl,
                name: fullName.trim().isNotEmpty ? fullName : "Loading...",
                role: userRole,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfilePage()));
                },
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          bool isLargeScreen = constraints.maxWidth > 800;

                          final statCards = [
                            StatCard(title: "Total Logs", value: "$totalLogs", color: primarycolordark),
                            StatCard(title: "By Super Admin", value: "$superAdminLogs", color: primarycolor),
                            StatCard(title: "By Admin", value: "$adminLogs", color: primarycolordark),
                          ];

                          if (isLargeScreen) {
                            return Row(
                              children: [
                                for (int i = 0; i < statCards.length; i++) ...[
                                  Expanded(child: statCards[i]),
                                  if (i != statCards.length - 1) const SizedBox(width: 16),
                                ],
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                for (int i = 0; i < statCards.length; i++) ...[
                                  SizedBox(width: double.infinity, child: statCards[i]),
                                  if (i != statCards.length - 1) const SizedBox(height: 12),
                                ],
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFilters(),
                      const SizedBox(height: 16),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: getAuditLogsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return _buildEmptyAuditLogsMessage();
                          }

                          List<Map<String, dynamic>> allLogs = snapshot.data!;

                          List<Map<String, dynamic>> filteredLogs = allLogs.where((log) {
                            final matchesAction = selectedAction == null || log['action'] == selectedAction;
                            final matchesUser = selectedUser == null || log['name'] == selectedUser;

                            bool matchesDate = true;
                            if (selectedDate != null) {
                              try {
                                final logDate = (log['timestamp'] as Timestamp).toDate();
                                matchesDate = DateFormat('yyyy-MM-dd').format(logDate) == DateFormat('yyyy-MM-dd').format(selectedDate!);
                              } catch (_) {
                                matchesDate = false;
                              }
                            }

                            return matchesAction && matchesUser && matchesDate;
                          }).toList();

                          if (filteredLogs.isEmpty) {
                            return _buildEmptyAuditLogsMessage();
                          }

                          return _buildResponsiveTable(constraints.maxWidth, filteredLogs);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAuditLogsMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/web-search.png', width: 240, height: 240),
            const SizedBox(height: 16),
            Text('No audit logs found.', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getAuditLogsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final userOptions = snapshot.data!.map((log) => log['name']?.toString() ?? '').toSet().toList();
        final isSmallScreen = MediaQuery.of(context).size.width < 800;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildActionDropdown(),
                      const SizedBox(height: 12),
                      _buildUserDropdown(userOptions),
                      const SizedBox(height: 12),
                      _buildDatePicker(),
                      const SizedBox(height: 12),
                      _buildFilterButtons(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildActionDropdown()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildUserDropdown(userOptions)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDatePicker()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildFilterButtons()),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildActionDropdown() {
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<String>(
        decoration: _dropdownDecoration('Select Action'),
        value: selectedAction,
        items: actionChoices.map((action) {
          return DropdownMenuItem(
            value: action,
            child: Text(action, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: dark)),
          );
        }).toList(),
        onChanged: (value) => setState(() => selectedAction = value),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: dark),
        iconEnabledColor: secondarycolor,
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildUserDropdown(List<String> users) {
    final filteredUsers = users.where((u) => u.trim().isNotEmpty).toList();

    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<String>(
        decoration: _dropdownDecoration('Select Users'),
        value: selectedUser != null && filteredUsers.contains(selectedUser) ? selectedUser : null,
        items: filteredUsers.map((user) {
          return DropdownMenuItem<String>(
            value: user,
            child: Text(user, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: dark)),
          );
        }).toList(),
        onChanged: (value) => setState(() => selectedUser = value),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: dark),
        iconEnabledColor: secondarycolor,
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePicker() {
    return SizedBox(
      height: 48,
      child: InputDecorator(
        decoration: _dropdownDecoration('Select Date', isDate: true),
        child: InkWell(
          onTap: _pickDate,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    selectedDate != null ? DateFormat.yMMMMd().format(selectedDate!) : 'Select Date',
                    style: GoogleFonts.poppins(
                      color: selectedDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          setState(() {
            selectedAction = null;
            selectedUser = null;
            selectedDate = null;
          });
        },
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.hovered)) return primarycolordark;
            return secondarycolor;
          }),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
          side: MaterialStateProperty.all(BorderSide.none),
        ),
        child: Text('Clear Filter', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildResponsiveTable(double maxWidth, List<Map<String, dynamic>> filteredLogs) {
    final bool isSmallScreen = maxWidth < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        if (!isSmallScreen)
          Card(
            color: primarycolordark,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Center(child: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
                  Expanded(flex: 3, child: Center(child: Text('Email', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
                  Expanded(flex: 2, child: Center(child: Text('Action', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
                  Expanded(flex: 3, child: Center(child: Text('Timestamp', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
                  Expanded(flex: 4, child: Center(child: Text('Description', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ...filteredLogs.map((log) {
          final String desc = (log['desc'] ?? '').toString();
          final String name = (log['name'] ?? '').toString();
          final String email = (log['email'] ?? '').toString();
          final String action = (log['action'] ?? '').toString();
          final dynamic ts = log['timestamp'];
          String timestampText;
          try {
            if (ts is Timestamp) {
              timestampText = DateFormat.yMMMMd().format((ts as Timestamp).toDate()); 
            } else if (ts is DateTime) {
              timestampText = DateFormat.yMMMMd().format(ts);
            } else {
              timestampText = ts.toString();
            }
          } catch (_) {
            timestampText = ts.toString();
          }

          if (isSmallScreen) {
            return Card(
              color: Colors.white,
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: secondarycolor,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: dark, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: GoogleFonts.poppins(color: dark, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: primarycolor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(action, style: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Date: ',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: dark,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            timestampText,
                            style: GoogleFonts.poppins(color: dark),
                            softWrap: false, 
                            overflow: TextOverflow.ellipsis, 
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (desc.isNotEmpty) ...[
                      Text(
                        'Description:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        style: GoogleFonts.poppins(color: dark),
                        softWrap: true,
                      ),
                    ],
                  ],
                ),
              ),
            );
          } else {
            return Card(
              color: Colors.white,
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: secondarycolor,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: dark),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          action,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: dark),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          timestampText,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: dark),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              desc,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(color: dark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }).toList(),
      ],
    );
  }

  InputDecoration _dropdownDecoration(String label, {bool isDate = false, IconData? icon}) {
    return InputDecoration(
      hintText: isDate ? label : null,
      labelText: isDate ? null : label,
      prefixIcon: icon != null ? Icon(icon, color: secondarycolor) : null,
      filled: true,
      fillColor: Colors.white,
      labelStyle: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
      hintStyle: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
      floatingLabelStyle: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: secondarycolor, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primarycolordark, width: 1.6)),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primarycolordark, onPrimary: Colors.white, onSurface: dark),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primarycolordark, textStyle: GoogleFonts.poppins()),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) setState(() => selectedDate = picked);
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const StatCard({super.key, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.31), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.poppins(fontSize: 14, color: color.withOpacity(0.9))),
        ],
      ),
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
                : (isHovered
                    ? primarycolor.withOpacity(0.10)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Icon(
              widget.icon,
              color: widget.isActive
                  ? primarycolordark
                  : (widget.isLogout ? Colors.red : primarycolordark),
            ),
            title: Text(
              widget.label ?? '',
              style: GoogleFonts.poppins(
                color: widget.isActive
                    ? primarycolordark
                    : (widget.isLogout ? Colors.red : primarycolordark),
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
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset('assets/images/dhvbot.png'),
                    )
                  : Image.asset('assets/images/dhvbot.png'),
            ),
          ),
          _drawerItem(context, Icons.dashboard_outlined, "Dashboard", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SuperAdminDashboardPage()),
            );
          }),
          _drawerItem(context, Icons.people_outline, "Users Info", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UserinfoPage()),
            );
          }),
          _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FeedbacksPage()),
            );
          }),
          _drawerItem(context, Icons.admin_panel_settings_outlined, "Admin Management", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminManagementPage()),
            );
          }),
          // _drawerItem(context, Icons.warning_amber_rounded, "Emergency Requests", () {
          //   Navigator.pop(context);
          //   Navigator.push(
          //     context,
          //     MaterialPageRoute(builder: (_) => const EmergencyRequestsPage()),
          //   );
          // }),
          _drawerItem(context, Icons.settings_outlined, "Settings", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SystemSettingsPage()),
            );
          }),
          _drawerItem(context, Icons.receipt_long_outlined, "Audit Logs", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AuditLogsPage()),
            );
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
                  SnackBar(
                    content: Text(
                      "Logout failed. Please try again.",
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              }
            },
            isLogout: true,
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return HoverButton(
      onPressed: onTap,
      isLogout: isLogout,
      icon: icon,
      label: title,
      isActive: activePage == title,
    );
  }
}