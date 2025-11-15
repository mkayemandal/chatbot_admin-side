import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadmin/userinfo.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/auditlogs.dart';
import 'package:chatbot/superadmin/chatlogs.dart';
import 'package:chatbot/superadmin/feedbacks.dart';
import 'package:chatbot/superadmin/settings.dart';
import 'package:chatbot/superadmin/profile.dart';

const primarycolor = Color(0xFFffc803);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFF800000);
const dark = Color(0xFF17110d);
const white = Color(0xFFFFFFFF);
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

class EmergencyRequestsPage extends StatefulWidget {
  const EmergencyRequestsPage({Key? key}) : super(key: key);

  @override
  State<EmergencyRequestsPage> createState() => _EmergencyRequestsPageState();
}

class _EmergencyRequestsPageState extends State<EmergencyRequestsPage> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  int totalRequests = 0;
  int pendingRequests = 0;
  int approvedRequests = 0;
  int deniedRequests = 0;

  String profilePictureUrl = "assets/images/defaultDP.jpg";
  String fullName = "Super Admin";
  bool _adminInfoLoaded = false;

  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  // Cache for decrypted emails
  final Map<String, String> _emailCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadStats();
    _loadAdminInfo();
    _loadApplicationLogo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _allDataLoaded => _adminInfoLoaded && _logoLoaded;

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('SuperAdmin').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          final firstName = data?['firstName'] ?? '';
          final lastName = data?['lastName'] ?? '';
          setState(() {
            fullName = capitalizeEachWord('$firstName $lastName'.trim());
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
      print('Error loading admin info: $e');
      setState(() => _adminInfoLoaded = true);
    }
  }

  Future<encrypt.Key?> _findExistingAesKey() async {
    for (final keyName in _possibleAesKeyNames) {
      final base64Key = await storage.read(key: keyName);
      if (base64Key != null) {
        final keyBytes = base64Decode(base64Key);
        if (keyBytes.length == 32) {
          return encrypt.Key(keyBytes);
        }
      }
    }
    return null;
  }

  Future<String?> _encryptValue(String plainText) async {
    if (plainText.isEmpty) return null;

    final key = await _findExistingAesKey();
    if (key == null) {
      print('❌ AES key not found — cannot encrypt.');
      return null;
    }

    try {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      final combinedBytes = iv.bytes + encrypted.bytes;
      return base64Encode(combinedBytes);
    } catch (e) {
      print('❌ Encryption error: $e');
      return null;
    }
  }

  Future<String?> _decryptValue(String encoded) async {
    // Check cache first
    if (_emailCache.containsKey(encoded)) {
      return _emailCache[encoded];
    }

    try {
      final key = await _findExistingAesKey();
      if (key == null) return null;

      final combined = base64Decode(encoded);
      final iv = encrypt.IV(combined.sublist(0, 16));
      final cipherText = encrypt.Encrypted(combined.sublist(16));
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      final decrypted = encrypter.decrypt(cipherText, iv: iv);
      
      // Cache the result
      _emailCache[encoded] = decrypted;
      
      return decrypted;
    } catch (e) {
      print('❌ Decryption failed: $e');
      return null;
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
        final val = data['applicationLogoUrl'];
        setState(() {
          _applicationLogoUrl =
              val is String && val.isNotEmpty ? val : null;
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

  Future<void> _loadStats() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('EmergencyAccessRequests')
          .get();

      int total = snapshot.docs.length;
      int pending = 0;
      int approved = 0;
      int denied = 0;

      for (var doc in snapshot.docs) {
        final s = (doc.data() as Map<String, dynamic>)['status']
                ?.toString()
                .toLowerCase() ??
            'pending';
        if (s == 'approved')
          approved++;
        else if (s == 'denied')
          denied++;
        else
          pending++;
      }

      if (!mounted) return;
      setState(() {
        totalRequests = total;
        pendingRequests = pending;
        approvedRequests = approved;
        deniedRequests = denied;
      });
    } catch (e) {
      // ignore for now
    }
  }

  Future<void> _updateStatus(String docId, String newStatus, {String? email}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          newStatus == 'approved' ? 'Approve Request' : 'Deny Request',
          style: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold),
        ),
        content: Text(
          newStatus == 'approved'
              ? 'Are you sure you want to approve the request from $email?'
              : 'Are you sure you want to deny the request from $email?',
          style: GoogleFonts.poppins(color: dark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: primarycolordark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final firestore = FirebaseFirestore.instance;

    try {
      if (newStatus == 'approved') {
        if (email == null || email.isEmpty) {
          throw Exception('Email required to approve');
        }

        final querySnapshot = await firestore.collection('SuperAdmin').get();
        final superAdminCount = querySnapshot.size;
        final nextIdNumber = superAdminCount + 1;
        final staffID = 'SA${nextIdNumber.toString().padLeft(3, '0')}';

        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: 'TemporaryPassword123!',
        );

        final generatedPassword = 'AskPSUIT60';

        final encryptedEmail = await _encryptValue(email);
        final encryptedPassword = await _encryptValue(generatedPassword);

        await firestore.collection('SuperAdmin').doc(userCredential.user!.uid).set({
          'email': encryptedEmail ?? '',
          'password': encryptedPassword ?? '',
          'role': 'superadmin',
          'staffID': staffID,
          'createdAt': FieldValue.serverTimestamp(),
          'firstName': 'Null',
          'lastName': 'Null',
          'gender': 'Null',
          'birthday': 'Null',
          'profilePicture': '',
        });

        await firestore.collection('EmergencyAccessRequests').doc(docId).update({
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

        if (mounted) {
          _showFloatingSnackBar(
            context,
            'Super Admin approved with ID $staffID. Password reset email sent to $email.',
            Colors.green[700]!,
          );
        }

      } else if (newStatus == 'denied') {
        await firestore.collection('EmergencyAccessRequests').doc(docId).update({
          'status': 'denied',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showFloatingSnackBar(
            context,
            'Request denied successfully.',
            Colors.redAccent,
          );
        }
      }

      await _loadStats();
    } on FirebaseAuthException catch (e) {
      String errorMessage = e.message ?? 'An error occurred while approving the request.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered.';
      }
      _showFloatingSnackBar(context, errorMessage, Colors.redAccent);
    } catch (e) {
      print('updateStatus error: $e');
      _showFloatingSnackBar(context, '⚠️ Failed to update request.', Colors.redAccent);
    }
  }

  void _showFloatingSnackBar(BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        elevation: 4,
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _applyFilterAndSearch(
      List<QueryDocumentSnapshot> docs) async {
    final query = _searchController.text.toLowerCase();
    final filter = _selectedFilter.toLowerCase();

    // If no search query and filter is 'all', return all docs
    if (query.isEmpty && filter == 'all') {
      return docs;
    }

    List<QueryDocumentSnapshot> filtered = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      final reason = (data['reason'] ?? '').toString().toLowerCase();
      
      // Decrypt email for search
      String email = '';
      if (data['email'] != null) {
        final decrypted = await _decryptValue(data['email']);
        email = (decrypted ?? '').toLowerCase();
      }

      final matchesQuery = query.isEmpty || email.contains(query) || reason.contains(query);
      final matchesFilter = filter == 'all' ||
          (filter == 'pending' && status == 'pending') ||
          (filter == 'approved' && status == 'approved') ||
          (filter == 'denied' && status == 'denied');

      if (matchesQuery && matchesFilter) {
        filtered.add(doc);
      }
    }

    return filtered;
  }

  Widget _buildTableHeader({bool compact = false}) {
    final textStyle = GoogleFonts.poppins(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: Colors.white,
    );

    if (!compact) {
      final headerRow = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Center(child: Text('Email', style: textStyle)),
            ),
            Expanded(
              flex: 3,
              child: Center(child: Text('Reason', style: textStyle)),
            ),
            Expanded(
              flex: 2,
              child: Center(child: Text('Timestamp', style: textStyle)),
            ),
            Expanded(
              flex: 1,
              child: Center(child: Text('Status', style: textStyle)),
            ),
            Expanded(
              flex: 2,
              child: Center(child: Text('Action', style: textStyle)),
            ),
          ],
        ),
      );

      return Card(
        color: primarycolordark,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: headerRow,
      );
    } else {
      return Card(
        color: primarycolordark,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 2, child: Center(child: Text('Email', style: textStyle.copyWith(fontSize: 12)))),
                  Expanded(flex: 3, child: Center(child: Text('Reason', style: textStyle.copyWith(fontSize: 12)))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(flex: 2, child: Center(child: Text('Timestamp', style: textStyle.copyWith(fontSize: 12)))),
                  Expanded(flex: 1, child: Center(child: Text('Status', style: textStyle.copyWith(fontSize: 12)))),
                  Expanded(flex: 2, child: Center(child: Text('Action', style: textStyle.copyWith(fontSize: 12)))),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildStatCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth > 800 ? 4 : 1;
        double spacing = 12;
        double totalSpacing = (columns - 1) * spacing;
        double width = (constraints.maxWidth - totalSpacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            StatCard(title: 'Total Requests', value: totalRequests.toString(), color: primarycolordark, width: width),
            StatCard(title: 'Pending', value: pendingRequests.toString(), color: primarycolor, width: width),
            StatCard(title: 'Approved', value: approvedRequests.toString(), color: Colors.green[700]!, width: width),
            StatCard(title: 'Denied', value: deniedRequests.toString(), color: Colors.red[700]!, width: width),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.white,
        drawer: NavigationDrawer(applicationLogoUrl: _applicationLogoUrl, activePage: 'Emergency Requests'),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          iconTheme: const IconThemeData(color: primarycolordark),
          title: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Emergency Requests',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ProfileButton(
                imageUrl: profilePictureUrl,
                name: fullName.trim().isNotEmpty ? fullName : "Loading...",
                role: "Super Admin",
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfilePage()));
                },
              ),
            ),
          ],
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatCards(context),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(flex: 3, child: _SearchBar(controller: _searchController)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: _FilterDropdown(
                        selectedFilter: _selectedFilter,
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value ?? 'All';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isWide) _buildTableHeader(compact: false),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('EmergencyAccessRequests')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return SizedBox(
                        height: 360,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset("assets/images/web-search.png", width: 240, height: 240),
                              const SizedBox(height: 12),
                              Text("No emergency requests found.", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      );
                    }

                    return FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: _applyFilterAndSearch(docs),
                      builder: (context, filterSnapshot) {
                        if (filterSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final filtered = filterSnapshot.data ?? [];

                        if (filtered.isEmpty) {
                          return SizedBox(
                            height: 200,
                            child: Center(child: Text('No requests match your filters.', style: GoogleFonts.poppins())),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: filtered.map<Widget>((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final id = doc.id;
                            final reason = (data['reason'] ?? '').toString();
                            final timestamp = data['timestamp'] != null
                                ? DateFormat('MMM d, yyyy h:mm a').format((data['timestamp'] as Timestamp).toDate())
                                : '';
                            final status = (data['status'] ?? 'pending').toString().toLowerCase();

                            // Get cached email or decrypt
                            final encryptedEmail = data['email'];
                            final email = _emailCache[encryptedEmail] ?? 'Loading...';
                            
                            // Decrypt in background if not cached
                            if (!_emailCache.containsKey(encryptedEmail) && encryptedEmail != null) {
                              _decryptValue(encryptedEmail).then((decrypted) {
                                if (mounted && decrypted != null) {
                                  setState(() {});
                                }
                              });
                            }

                            if (MediaQuery.of(context).size.width >= 900) {
                              return Card(
                                color: Colors.white,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Center(child: Text(email, style: GoogleFonts.poppins(color: dark))),
                                      ),
                                      Expanded(flex: 3, child: Center(child: Text(reason, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: dark)))),
                                      Expanded(flex: 2, child: Center(child: Text(timestamp, style: GoogleFonts.poppins(color: dark)))),
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: status == 'approved' ? Colors.green[100] : status == 'denied' ? Colors.red[100] : Colors.orange[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(status.toUpperCase(),
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  color: status == 'approved' ? Colors.green[800] : status == 'denied' ? Colors.red[800] : Colors.orange[800],
                                                )),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: status == 'pending'
                                                    ? () async {
                                                        await _updateStatus(id, 'approved', email: email);
                                                      }
                                                    : null,
                                                icon: const Icon(Icons.check_circle, size: 16),
                                                label: Text('Approve', style: GoogleFonts.poppins()),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green[700],
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: status == 'pending'
                                                    ? () async {
                                                        await _updateStatus(id, 'denied', email: email);
                                                      }
                                                    : null,
                                                icon: const Icon(Icons.cancel, size: 16),
                                                label: Text('Deny', style: GoogleFonts.poppins()),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.redAccent,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                            } else {
                              final double avatarRadius = 22.0;
                              return Card(
                                color: Colors.white,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              CircleAvatar(
                                                radius: avatarRadius,
                                                backgroundColor: secondarycolor,
                                                child: Text(
                                                  email.isNotEmpty ? email[0].toUpperCase() : '?',
                                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(email, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          if (reason.isNotEmpty)
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(text: 'Reason: ', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textdark)),
                                                  TextSpan(text: reason, style: GoogleFonts.poppins(color: textdark)),
                                                ],
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 10),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(text: 'Date: ', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textdark, fontSize: 12)),
                                                TextSpan(text: timestamp, style: GoogleFonts.poppins(color: textdark, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: status == 'pending'
                                                      ? () async {
                                                          await _updateStatus(id, 'approved', email: email);
                                                        }
                                                      : null,
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: Text('Approve', style: GoogleFonts.poppins()),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green[700],
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: status == 'pending'
                                                      ? () async {
                                                          await _updateStatus(id, 'denied', email: email);
                                                        }
                                                      : null,
                                                  icon: const Icon(Icons.cancel, size: 16),
                                                  label: Text('Deny', style: GoogleFonts.poppins()),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.redAccent,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: status == 'approved' ? Colors.green[100] : status == 'denied' ? Colors.red[100] : Colors.orange[100],
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(status.toUpperCase(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: status == 'approved' ? Colors.green[800] : status == 'denied' ? Colors.red[800] : Colors.orange[800],
                                              )),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }),
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: dark),
      decoration: InputDecoration(
        hintText: 'Search by email or reason...',
        hintStyle: GoogleFonts.poppins(color: dark),
        prefixIcon: const Icon(Icons.search, color: primarycolor),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primarycolordark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dark),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({Key? key, required this.selectedFilter, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: dark, width: 1.0), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFilter,
          onChanged: onChanged,
          icon: const Icon(Icons.filter_list, color: primarycolordark),
          items: ['All', 'Pending', 'Approved', 'Denied'].map((f) {
            return DropdownMenuItem(
              value: f,
              child: Text(f, style: GoogleFonts.poppins(color: dark)),
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
          _drawerItem(
            context,
            Icons.warning_amber_rounded,
            "Emergency Requests",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmergencyRequestsPage()),
              );
            },
          ),
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