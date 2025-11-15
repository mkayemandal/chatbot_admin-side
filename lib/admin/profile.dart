import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'dart:async';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/feedbacks.dart';
import 'package:chatbot/admin/chatbotdata.dart';
import 'package:chatbot/admin/dashboard.dart';
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
      .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
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

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  String firstName = '';
  String lastName = '';
  String email = '';
  String decryptedEmail = '';
  String userType = '';
  String phone = '';
  String staffID = '';
  String department = '';

  bool _adminInfoLoaded = false;

  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _aesKeyStorageKey = 'app_aes_key_v1';
  encrypt.Key? _cachedKey;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadApplicationLogo();
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
        print('✅ Profile: Loaded encryption key from Firestore');
        return _cachedKey!;
      }
    } catch (e) {
      print('⚠️ Profile: Error loading key from Firestore: $e');
    }
    
    final existing = await _secureStorage.read(key: _aesKeyStorageKey);
    if (existing != null) {
      final bytes = base64Decode(existing);
      _cachedKey = encrypt.Key(bytes);
      print('✅ Profile: Loaded encryption key from local storage');
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
      print('✅ Profile: Created new encryption key in Firestore');
    } catch (e) {
      print('⚠️ Profile: Could not save key to Firestore: $e');
    }
    
    await _secureStorage.write(
      key: _aesKeyStorageKey,
      value: keyBase64,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
    
    _cachedKey = generated;
    print('✅ Profile: Created new encryption key locally');
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

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('Admin')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          
          // Get encrypted email
          final encryptedEmail = data['email'] ?? '';
          
          // Decrypt email
          String displayEmail = '';
          if (encryptedEmail.isNotEmpty) {
            final decrypted = await _decryptValue(encryptedEmail);
            if (decrypted != null && decrypted.isNotEmpty) {
              displayEmail = decrypted;
              print('✅ Profile: Successfully decrypted email');
            } else {
              // Fallback to Firebase Auth email
              displayEmail = user.email ?? 'No email';
              print('⚠️ Profile: Email decryption failed, using Firebase Auth email');
            }
          } else {
            // Fallback to Firebase Auth email if no encrypted email stored
            displayEmail = user.email ?? 'No email';
          }
          
          setState(() {
            firstName = capitalizeEachWord(data['firstName'] ?? '');
            lastName = capitalizeEachWord(data['lastName'] ?? '');
            email = encryptedEmail; // Keep encrypted for storage reference
            decryptedEmail = displayEmail; // Store decrypted for display
            userType = capitalizeEachWord(data['userType'] ?? 'Admin');
            phone = _formatPhone(data['phone'] ?? '');
            department = data['department'] ?? '';
            staffID = data['staffID']?.toString() ?? '';
            _adminInfoLoaded = true;
          });
        } else {
          setState(() {
            decryptedEmail = user.email ?? 'No email';
            _adminInfoLoaded = true;
          });
        }
      } else {
        setState(() => _adminInfoLoaded = true);
      }
    } catch (e) {
      print('Error fetching Admin info: $e');
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        decryptedEmail = user?.email ?? 'No email';
        _adminInfoLoaded = true;
      });
    }
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

  String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    if (digits.startsWith('63')) {
      final number = digits.substring(2);
      return '0$number';
    }
    if (raw.startsWith('+63')) {
      final number = digits.substring(2);
      return '0$number';
    }
    if (digits.startsWith('0')) return digits;

    return '0$digits';
  }

  @override
  Widget build(BuildContext context) {
    final poppinsTextTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
        .apply(bodyColor: dark, displayColor: dark);

    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final fullName = '$firstName $lastName';

    if (!_adminInfoLoaded) {
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

    return Theme(
      data: Theme.of(context).copyWith(textTheme: poppinsTextTheme, primaryTextTheme: poppinsTextTheme),
      child: Scaffold(
        backgroundColor: lightBackground,
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Your Profile",
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: primarycolordark),
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  "Your Profile",
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
                role: "Admin - ${department.isNotEmpty ? department : 'No Department'}",
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
          padding: const EdgeInsets.all(16),
          child: Card(
            color: const Color.fromARGB(255, 249, 240, 224),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: const BoxDecoration(
                    color: primarycolordark,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundImage: AssetImage('assets/images/defaultDP.jpg'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.isNotEmpty ? fullName : 'Loading...',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              decryptedEmail,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: isWideScreen
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _leftCard(fullName)),
                              const SizedBox(width: 24),
                              Expanded(flex: 2, child: _rightCard()),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _leftCard(fullName),
                            const SizedBox(height: 16),
                            _rightCard(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftCard(String fullName) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: primarycolordark,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              'Personal Picture',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundImage: AssetImage('assets/images/defaultDP.jpg'),
                ),
                const SizedBox(height: 12),
                Text(
                  fullName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Admin',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: dark,
                  ),
                ),
                if (department.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      department,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: dark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rightCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: primarycolordark,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              'Personal Information',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                InfoRow(label: "Staff ID", value: staffID, icon: Icons.badge_outlined),
                InfoRow(label: "First Name", value: firstName, icon: Icons.person_outline),
                InfoRow(label: "Last Name", value: lastName, icon: Icons.person_outline),
                InfoRow(label: "Email", value: decryptedEmail, icon: Icons.email_outlined),
                InfoRow(label: "Department", value: department, icon: Icons.apartment_outlined),
                InfoRow(label: "Phone Number", value: phone, icon: Icons.phone_outlined),
                InfoRow(label: "Usertype", value: userType, icon: Icons.security_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primarycolor),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: dark,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(color: dark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
            );
          }, isActive: activePage == "Dashboard",),
          _drawerItem(context, Icons.analytics_outlined, "Statistics", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotStatisticsPage()),
            );
          }, isActive: activePage == "Statistics",),
          _drawerItem(context, Icons.chat_outlined, "Chat Logs", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatsPage()),
            );
          }, isActive: activePage == "Chat Logs",),
          _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbacksPage()),
            );
         },
          isActive: activePage == "Feedbacks",),
          _drawerItem(context, Icons.receipt_long_outlined, "Chatbot Data", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotDataPage()),
            );
          },
          isActive: activePage == "Chatbot Data",),
          _drawerItem(context, Icons.folder_open_outlined, "Chatbot Files", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotFilesPage()),
            );
          },
          isActive: activePage == "Chatbot Files",),
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

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isLogout = false,
    required bool isActive,
  }) {
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