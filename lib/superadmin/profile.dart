import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatbot/superadmin/editprofile.dart';
import 'package:chatbot/superadmin/settings.dart';
import 'package:chatbot/superadmin/auditlogs.dart';
import 'package:chatbot/superadmin/chatlogs.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/userinfo.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/feedbacks.dart';
import 'package:chatbot/adminlogin.dart';
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
  final String? updatedProfileUrl;
  const AdminProfilePage({super.key, this.updatedProfileUrl});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  String firstName = '';
  String lastName = '';
  String email = '';
  String userType = '';
  String birthday = '';
  String gender = '';
  String staffID = '';
  String? _profileImageUrl;

  String? _applicationLogoUrl;
  bool _logoLoaded = false;
  bool _adminInfoLoaded = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _aesKeyStorageKey = 'app_aes_key_v1';
  encrypt.Key? _cachedKey;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadApplicationLogo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        
        // ✅ Decrypt email on refresh
        final encryptedEmail = data['email'] ?? '';
        String decryptedEmail = email; 
        
        if (encryptedEmail.isNotEmpty) {
          final result = await _decryptValue(encryptedEmail);
          if (result != null) {
            decryptedEmail = result;
          }
        }
        
        setState(() {
          email = decryptedEmail;
          _profileImageUrl = doc['profileImageUrl'] ?? _profileImageUrl;
        });
      }
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
        _logoLoaded = true;
      }
    } catch (e) {
      print('Error loading application logo: $e');
      _logoLoaded = true;
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
    
    print('❌ Profile: No encryption key found!');
    throw Exception('No encryption key found. Please re-register.');
  }

  Future<String?> _decryptValue(String encoded) async {
    if (encoded.isEmpty) {
      print('⚠️ Profile: Empty encoded value');
      return null;
    }
    
    if (!encoded.contains('+') && !encoded.contains('/') && !encoded.contains('=')) {
      print('⚠️ Profile: Value appears to be plaintext');
      return encoded;
    }
    
    try {
      final key = await _getOrCreateAesKey();
      final combined = base64Decode(encoded);
      
      if (combined.length < 17) {
        print('❌ Profile: Data too short: ${combined.length} bytes');
        return null;
      }
      
      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);
      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc)
      );
      final encrypted = encrypt.Encrypted(cipherBytes);
      
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      print('✅ Profile: Decryption successful');
      return decrypted;
    } catch (e, stackTrace) {
      print('❌ Profile: Decryption error: $e');
      print('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      
      if (encoded.contains('@')) {
        print('⚠️ Profile: Encoded value contains @, returning as plaintext');
        return encoded;
      }
      
      return 'Email unavailable';
    }
  }

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('SuperAdmin')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          
          final encryptedEmail = data['email'] ?? '';
          String decryptedEmail = 'Loading...';
          
          if (encryptedEmail.isNotEmpty) {
            final result = await _decryptValue(encryptedEmail);
            decryptedEmail = result ?? 'Email unavailable';
          }
          
          print('👤 SuperAdmin Profile: ${data['firstName']} - Email: $decryptedEmail');
          
          setState(() {
            firstName = capitalizeEachWord(data['firstName'] ?? '');
            lastName = capitalizeEachWord(data['lastName'] ?? '');
            email = decryptedEmail; // ✅ Use decrypted email
            userType = capitalizeEachWord(data['userType'] ?? 'Super Admin');
            birthday = _formatBirthday(data['birthday']);
            gender = data['gender'] ?? '';
            staffID = data['staffID']?.toString() ?? '';
            _profileImageUrl =
                widget.updatedProfileUrl ??
                data['profileImageUrl'] ??
                data['profilePicture'];
            _adminInfoLoaded = true;
          });
        } else {
          setState(() {
            _adminInfoLoaded = true;
          });
        }
      } else {
        setState(() {
          _adminInfoLoaded = true;
        });
      }
    } catch (e) {
      print('❌ Error fetching Super Admin info: $e');
      setState(() {
        _adminInfoLoaded = true;
      });
    }
  }

  String _formatBirthday(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return '';
    try {
      final parsed = DateFormat('MM/dd/yyyy').parse(rawDate.trim());
      // Convert to desired display format
      return DateFormat('MMMM d, yyyy').format(parsed);
    } catch (e) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: lightBackground,
      drawer: NavigationDrawer(
        applicationLogoUrl: _applicationLogoUrl,
        activePage: "Your Profile",
      ),
      appBar: AppBar(
        backgroundColor: lightBackground,
        iconTheme: const IconThemeData(color: primarycolordark),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 12),
            Text(
              "Your Profile",
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
              imageUrl: _profileImageUrl ?? "assets/images/defaultDP.jpg",
              name: fullName.trim().isNotEmpty ? fullName : "Loading...",
              role: "Super Admin",
              onTap: () {},
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Card(
            color: const Color.fromARGB(255, 249, 240, 224),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Column(
              children: [
                _header(fullName),
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

  Widget _header(String fullName) {
    return Container(
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
          CircleAvatar(
            radius: 40,
            backgroundImage:
                _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? NetworkImage(_profileImageUrl!)
                    : const AssetImage('assets/images/defaultDP.jpg')
                        as ImageProvider,
          ),
          const SizedBox(width: 16),
          Column(
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
                email,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
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
                CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                          ? NetworkImage(_profileImageUrl!)
                          : const AssetImage('assets/images/defaultDP.jpg')
                              as ImageProvider,
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
                Text(
                  'Super Admin',
                  style: GoogleFonts.poppins(color: dark),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final updatedUrl = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditAdminProfilePage(),
                      ),
                    );
                    if (updatedUrl != null && updatedUrl is String) {
                      setState(() => _profileImageUrl = updatedUrl);
                    }
                  },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: Text(
                    "Edit Profile",
                    style: GoogleFonts.poppins(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primarycolor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
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
                InfoRow(
                    label: "Staff ID", value: staffID, icon: Icons.badge_outlined),
                InfoRow(
                    label: "First Name",
                    value: firstName,
                    icon: Icons.person_outline),
                InfoRow(
                    label: "Last Name",
                    value: lastName,
                    icon: Icons.person_outline),
                InfoRow(
                    label: "Email", value: email, icon: Icons.email_outlined),
                InfoRow(
                    label: "Birthday",
                    value: birthday,
                    icon: Icons.cake_outlined),
                InfoRow(
                    label: "Gender",
                    value: gender,
                    icon: _getGenderIcon(gender)),
                InfoRow(
                    label: "Usertype",
                    value: userType,
                    icon: Icons.security_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getGenderIcon(String gender) {
    switch (gender.toLowerCase()) {
      case "male":
        return Icons.male;
      case "female":
        return Icons.female;
      case "other":
        return Icons.transgender;
      default:
        return Icons.help_outline;
    }
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
            ),
          ),
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
          transform:
              isHovered ? (Matrix4.identity()..scale(1.07)) : Matrix4.identity(),
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
              MaterialPageRoute(
                builder: (_) => const SuperAdminDashboardPage(),
              ),
            );
          }),
          _drawerItem(context, Icons.people_outline, "Users Info", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UserinfoPage()),
            );
          }),
          // _drawerItem(context, Icons.chat_outlined, "Chat Logs", () {
          //   Navigator.pushReplacement(
          //     context,
          //     MaterialPageRoute(builder: (_) => const ChatsPage()),
          //   );
          // }),
          _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FeedbacksPage()),
            );
          }),
          _drawerItem(context, Icons.admin_panel_settings_outlined,
              "Admin Management", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminManagementPage()),
            );
          }),
          // _drawerItem(context, Icons.warning_amber_rounded,
          //     "Emergency Requests", () {
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
                      content:
                          Text("Logout failed. Please try again.", style: GoogleFonts.poppins())),
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