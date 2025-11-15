import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/auditlogs.dart';
import 'package:chatbot/superadmin/chatlogs.dart';
import 'package:chatbot/superadmin/feedbacks.dart';
import 'package:chatbot/superadmin/settings.dart';
import 'package:chatbot/superadmin/profile.dart';
import 'package:chatbot/superadmin/emergencypage.dart';
import 'package:chatbot/services/encryption_service.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

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

class ManualEmailFix extends StatefulWidget {
  const ManualEmailFix({super.key});

  @override
  State<ManualEmailFix> createState() => _ManualEmailFixState();
}

class _ManualEmailFixState extends State<ManualEmailFix> {
  final _encryptionService = EncryptionService();
  List<Map<String, dynamic>> _problematicUsers = [];
  bool _isLoading = false;
  bool _isFixing = false;

  @override
  void initState() {
    super.initState();
    _loadProblematicUsers();
  }

  Future<void> _loadProblematicUsers() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      List<Map<String, dynamic>> problems = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final emailField = data['email'] as String?;
        
        if (emailField == null || emailField.isEmpty) continue;

        // Skip if already plain text (already fixed)
        if (emailField.contains('@')) continue;

        // Try to decrypt
        bool canDecrypt = false;
        try {
          await _encryptionService.decryptValue(emailField);
          canDecrypt = true;
        } catch (e) {
          canDecrypt = false;
        }

        if (!canDecrypt) {
          // This user needs manual fix
          problems.add({
            'docId': doc.id,
            'name': data['name'] ?? 'Unknown',
            'username': data['username'] ?? '',
            'encryptedEmail': emailField,
            'studentType': data['studentType'] ?? 'Unknown',
          });
        }
      }

      setState(() {
        _problematicUsers = problems;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fixUserEmail(String docId, String plainEmail) async {
    if (plainEmail.isEmpty || !plainEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid email format', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isFixing = true);

    try {
      // Encrypt with the centralized key
      final encrypted = await _encryptionService.encryptValue(plainEmail.toLowerCase());

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .update({
        'email': encrypted,
        'email_fixed_at': FieldValue.serverTimestamp(),
      });

      // Reload list
      await _loadProblematicUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Email fixed successfully!', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isFixing = false);
    }
  }

  void _showFixDialog(Map<String, dynamic> user) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Fix Email for ${user['name']}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Username: ${user['username']}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            Text(
              'Type: ${user['studentType']}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter the correct email address:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: 'user@example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact the user to verify their email',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              Navigator.pop(context);
              _fixUserEmail(user['docId'], email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Fix Email', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Color(0xFF550100)),
                const SizedBox(width: 8),
                Text(
                  'Manual Email Fix Tool',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF550100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Users with emails encrypted by old keys need manual fixing.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_problematicUsers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '✅ All users have valid emails!',
                        style: GoogleFonts.poppins(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_problematicUsers.length} users need email fixes',
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _problematicUsers.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final user = _problematicUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Text(
                        user['name'].toString()[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      user['name'],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Username: ${user['username']} • Type: ${user['studentType']}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: _isFixing ? null : () => _showFixDialog(user),
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text('Fix', style: GoogleFonts.poppins(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFffc803),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadProblematicUsers,
                icon: const Icon(Icons.refresh),
                label: Text('Refresh List', style: GoogleFonts.poppins()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF550100)),
                  foregroundColor: const Color(0xFF550100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserinfoPage extends StatefulWidget {
  const UserinfoPage({super.key});

  @override
  State<UserinfoPage> createState() => _UserinfoPageState();
}

class _UserinfoPageState extends State<UserinfoPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> guestUsers = [];
  bool _guestDataLoaded = false;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String firstName = "";
  String lastName = "";
  String profilePictureUrl = "assets/images/defaultDP.jpg";
  bool _adminInfoLoaded = false;
  bool _userDataLoaded = false;

  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  List<Map<String, dynamic>> users = [];
  late AnimationController _controller;

  final _encryptionService = EncryptionService();

  bool get _allDataLoaded =>
      _adminInfoLoaded && _userDataLoaded && _logoLoaded && _guestDataLoaded;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _searchController.addListener(() => setState(() {}));
    _initializePage();
    _controller.forward();
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _loadAdminInfo(),
      _loadUserDataList(),
      _loadApplicationLogo(),
      _loadGuestUsers(),
    ]);
  }

  Future<void> _loadGuestUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('guest_conversations')
          .get();

      setState(() {
        guestUsers = snapshot.docs.map((doc) => doc.data()).toList();
        _guestDataLoaded = true;
      });
    } catch (e) {
      print('Error loading guest users: $e');
      setState(() => _guestDataLoaded = true);
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

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void showCustomSnackBar(
    BuildContext context,
    String message, {
    Color backgroundColor = primarycolor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showRecoverConfirmation(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Recover Account?',
          style: GoogleFonts.poppins(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to recover ${user['name']}\'s account? This will restore their access.',
          style: GoogleFonts.poppins(color: dark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: primarycolordark,
              textStyle: GoogleFonts.poppins(),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _recoverAccount(user);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text(
              'Confirm Recover',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FIXED _recoverAccount method with proper null handling
  void _recoverAccount(Map user) async {
    try {
      final userEmail = user['email']; // Already decrypted
      final encryptedEmail = user['email_encrypted']; // Get encrypted version

      // Validate email exists
      if (userEmail == null || userEmail.isEmpty) {
        showCustomSnackBar(
          context,
          'Invalid user email.',
          backgroundColor: Colors.red,
        );
        return;
      }

      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      String? foundDocId;
      if (userDoc.docs.isEmpty && encryptedEmail != null) {
        print('🔍 Searching for user by encrypted email...');
        final allUsers = await FirebaseFirestore.instance
            .collection('users')
            .get();

        for (var doc in allUsers.docs) {
          final data = doc.data();
          final storedEmail = data['email'] as String?;
          
          if (storedEmail != null && storedEmail.isNotEmpty) {
            try {
              String checkEmail;
              if (storedEmail.contains('@')) {
                checkEmail = storedEmail;
              } else {
                checkEmail = await _encryptionService.decryptValue(storedEmail);
              }

              if (checkEmail.toLowerCase() == userEmail.toLowerCase()) {
                foundDocId = doc.id;
                print('✅ Found user by decrypted email match');
                break;
              }
            } catch (e) {
              continue;
            }
          }
        }
      }

      final docId = userDoc.docs.isNotEmpty ? userDoc.docs.first.id : foundDocId;
      
      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .update({
          'blocked': false,
          'blockedReason': FieldValue.delete(), 
        });

        String notificationEmail = encryptedEmail ?? '';
        
        if (notificationEmail.isEmpty && userEmail.isNotEmpty) {
          try {
            notificationEmail = await _encryptionService.encryptValue(userEmail);
          } catch (e) {
            print('⚠️ Failed to encrypt email for notification: $e');
            notificationEmail = userEmail; 
          }
        }

        await FirebaseFirestore.instance.collection('Notifications').add({
          'userId': docId,
          'email': notificationEmail,
          'message': 'Your account has been recovered and access has been restored.',
          'status': 'unread',
          'title': 'Notice',
          'timestamp': Timestamp.now(),
        });

        await _loadUserDataList();

        if (mounted) {
          showCustomSnackBar(context, 'Account recovered successfully.');
        }
      } else {
        showCustomSnackBar(
          context,
          'User not found.',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      debugPrint('Error recovering account: $e');
      showCustomSnackBar(
        context,
        'Failed to recover account.',
        backgroundColor: Colors.red,
      );
    }
  }

  void _showBlockConfirmation(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Block User?',
          style: GoogleFonts.poppins(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to block ${user['name']}? This will restrict their access due to violations.',
          style: GoogleFonts.poppins(color: dark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: primarycolordark,
              textStyle: GoogleFonts.poppins(),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser(user);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text(
              'Confirm Block',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(Map<String, dynamic> user) async {
    try {
      final userEmail = user['email']; 
      final encryptedEmail = user['email_encrypted']; 


      if (userEmail == null || userEmail.isEmpty) {
        showCustomSnackBar(
          context,
          'Invalid user email.',
          backgroundColor: Colors.red,
        );
        return;
      }


      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();


      String? foundDocId;
      if (snapshot.docs.isEmpty && encryptedEmail != null) {
        print('🔍 Searching for user by encrypted email...');
        final allUsers = await FirebaseFirestore.instance
            .collection('users')
            .get();

        for (var doc in allUsers.docs) {
          final data = doc.data();
          final storedEmail = data['email'] as String?;
          
          if (storedEmail != null && storedEmail.isNotEmpty) {
            try {
              String checkEmail;
              if (storedEmail.contains('@')) {
                checkEmail = storedEmail;
              } else {
                checkEmail = await _encryptionService.decryptValue(storedEmail);
              }

              if (checkEmail.toLowerCase() == userEmail.toLowerCase()) {
                foundDocId = doc.id;
                print('✅ Found user by decrypted email match');
                break;
              }
            } catch (e) {
              continue;
            }
          }
        }
      }

      final docId = snapshot.docs.isNotEmpty ? snapshot.docs.first.id : foundDocId;
      
      if (docId != null) {

        await FirebaseFirestore.instance.collection('users').doc(docId).update({
          'blocked': true,
          'blockedReason': 'Blocked by administrator',
        });

        String notificationEmail = encryptedEmail ?? '';
        
        if (notificationEmail.isEmpty && userEmail.isNotEmpty) {
          try {
            notificationEmail = await _encryptionService.encryptValue(userEmail);
          } catch (e) {
            print('⚠️ Failed to encrypt email for notification: $e');
            notificationEmail = userEmail; 
          }
        }

        await FirebaseFirestore.instance.collection('Notifications').add({
          'userId': docId,
          'email': notificationEmail, 
          'message': 'Your account has been blocked due to violations.',
          'status': 'unread',
          'title': 'Notice',
          'timestamp': Timestamp.now(),
        });

        // Reload user list
        await _loadUserDataList();

        if (mounted) {
          showCustomSnackBar(context, 'User has been blocked.');
        }
      } else {
        showCustomSnackBar(
          context,
          'User not found.',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      debugPrint('Error blocking user: $e');
      showCustomSnackBar(
        context,
        'Failed to block user.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _sendWarningNotification(Map<String, dynamic> user) async {
    try {
      final userEmail = user['email']; 
      final encryptedEmail = user['email_encrypted']; 

      if (userEmail == null || userEmail.isEmpty) {
        showCustomSnackBar(
          context,
          'Invalid user email.',
          backgroundColor: Colors.red,
        );
        return;
      }

      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      String? foundDocId;
      if (snapshot.docs.isEmpty && encryptedEmail != null) {
        print('🔍 Searching for user by encrypted email...');
        final allUsers = await FirebaseFirestore.instance
            .collection('users')
            .get();

        for (var doc in allUsers.docs) {
          final data = doc.data();
          final storedEmail = data['email'] as String?;
          
          if (storedEmail != null && storedEmail.isNotEmpty) {
            try {
              String checkEmail;
              if (storedEmail.contains('@')) {
                checkEmail = storedEmail;
              } else {
                checkEmail = await _encryptionService.decryptValue(storedEmail);
              }

              if (checkEmail.toLowerCase() == userEmail.toLowerCase()) {
                foundDocId = doc.id;
                print('✅ Found user by decrypted email match');
                break;
              }
            } catch (e) {
              continue;
            }
          }
        }
      }

      final docId = snapshot.docs.isNotEmpty ? snapshot.docs.first.id : foundDocId;

      if (docId != null) {

        String notificationEmail = encryptedEmail ?? '';
        
        if (notificationEmail.isEmpty && userEmail.isNotEmpty) {
          try {
            notificationEmail = await _encryptionService.encryptValue(userEmail);
          } catch (e) {
            print('⚠️ Failed to encrypt email for notification: $e');
            notificationEmail = userEmail; 
          }
        }

        await FirebaseFirestore.instance.collection('Notifications').add({
          'userId': docId,
          'email': notificationEmail, 
          'title': 'Warning',
          'message': 'You will be blocked if you continue using foul language.',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'unread',
          'sentBy': FirebaseAuth.instance.currentUser?.email ?? 'Super Admin',
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Warning notification sent.",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: primarycolor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        showCustomSnackBar(
          context, 
          'User not found in database.',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      print('Error sending warning notification: $e');
      showCustomSnackBar(
        context, 
        'Failed to send warning notification.',
        backgroundColor: Colors.red,
      );
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
          setState(() {
            firstName = capitalizeEachWord(doc['firstName'] ?? '');
            lastName = capitalizeEachWord(doc['lastName'] ?? '');
            profilePictureUrl =
                doc['profilePicture'] ?? "assets/images/defaultDP.jpg";
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

  Future<void> _loadUserDataList() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      final fetchedUsers = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data();
          final timestamp = data['createdAt'];
          String formattedDate = '';

          if (timestamp != null) {
            final date = timestamp.toDate();
            formattedDate = DateFormat('MMMM dd, yyyy').format(date);
          }

          final encryptedEmail = data['email'] as String?;
          String decryptedEmail = '';
          
          if (encryptedEmail != null && encryptedEmail.isNotEmpty) {
            try {
              if (encryptedEmail.contains('@')) {
                decryptedEmail = encryptedEmail;
                print('📧 Email already plain text: $decryptedEmail');
              } else {
                decryptedEmail = await _encryptionService.decryptValue(encryptedEmail);
                print('🔓 Decrypted email for ${data['name']}: $decryptedEmail');
              }
            } catch (e) {
              print('⚠️ Failed to decrypt email for ${doc.id}: $e');
              decryptedEmail = '[Encrypted]'; 
            }
          }

          final int foulCount = data['strikes'] ?? 0;
          final bool isBlocked = data['blocked'] ?? false;
          const int foulThreshold = 20;

          if (foulCount >= foulThreshold && !isBlocked) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(doc.id)
                .update({
              'blocked': true,
              'blockedReason': 'Exceeded foul word limit',
            });
            print('User $decryptedEmail automatically blocked (strikes: $foulCount)');
          }

          return {
            'name': capitalizeEachWord(data['name'] ?? ''),
            'email': decryptedEmail,
            'email_encrypted': encryptedEmail,
            'username': data['username'] ?? '',
            'position': data['studentType'] ?? 'Prospective',
            'date': formattedDate,
            'foulWords': foulCount,
            'blocked': foulCount >= foulThreshold || isBlocked,
            'phoneNumber': data['phoneNumber'] ?? null,
          };
        }).toList(),
      );

      setState(() {
        users = fetchedUsers;
        _userDataLoaded = true;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _userDataLoaded = true);
    }
  }

  int get totalusersCount => users.length + guestUsers.length;
  int get blockedCount => users.where((c) => c['blocked'] == true).length;

  Widget _buildProfileRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: dark,
            ),
          ),
          Flexible(
            child: Text(
              value?.toString() ?? 'N/A',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: textdark),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(BuildContext context, Map<String, dynamic> c) {
    final fullName = (c['name'] ?? '').toString().trim();
    final nameParts = fullName.split(' ');

    final lastName = nameParts.isNotEmpty ? nameParts.last : '';
    final firstName = nameParts.length > 1
        ? nameParts.sublist(0, nameParts.length - 1).join(' ')
        : '';
    final phoneNumber = (c['phoneNumber'] != null && (c['phoneNumber'] as String).isNotEmpty)
        ? c['phoneNumber']
        : 'Not set';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                _maskEmail(c['email'] ?? ''),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: textdark,
                ),
              ),
              const Divider(height: 30),
              _buildProfileRow("First Name", firstName),
              _buildProfileRow("Last Name", lastName),
              _buildProfileRow("Username", c['username']),
              _buildProfileRow("Phone Number", phoneNumber),
              _buildProfileRow("Date Created", c['date']),
              _buildProfileRow("Foul Words Count", c['foulWords']),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.toLowerCase();
    final filter = _selectedFilter.toLowerCase();

    return users.where((item) {
      final name = item['name'].toString().toLowerCase();
      final position = item['position'].toString().toLowerCase();
      final matchesQuery = name.contains(query);
      final matchesFilter = filter == 'all' || position == filter;
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = capitalizeEachWord('$firstName $lastName');

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
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Users Info",
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
              Text(
                "Users Info",
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int columns = constraints.maxWidth > 1000
                      ? 4
                      : (constraints.maxWidth > 800 ? 2 : 1);
                  double spacing = 12;
                  double totalSpacing = (columns - 1) * spacing;
                  double cardWidth =
                      (constraints.maxWidth - totalSpacing) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      StatCard(
                        title: "Registered Users",
                        value: users.length.toString(),
                        color: primarycolordark,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Guest Users",
                        value: guestUsers.length.toString(),
                        color: primarycolor,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Total User",
                        value: totalusersCount.toString(),
                        color: primarycolordark,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Blocked User",
                        value: blockedCount.toString(),
                        color: primarycolor,
                        width: cardWidth,
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: SearchBar(controller: _searchController)),
                  const SizedBox(width: 10),
                  FilterDropdown(
                    selectedFilter: _selectedFilter,
                    onChanged: (value) =>
                        setState(() => _selectedFilter = value ?? 'All'),
                  ),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Card(
                    color: primarycolordark,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 40),
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
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Joined',
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
                                'Foul Words Count',
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
            const SizedBox(height: 4),
            Expanded(
              child: _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/images/web-search.png",
                            width: 240,
                            height: 240,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "No user to show.",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final c = _filteredUsers[index];
                        final fullName = c['name'] ?? '';
                        final joinedDate = c['date'] ?? '';
                        final isBlocked = c['blocked'] == true;

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            bool isSmallScreen = constraints.maxWidth < 600;
                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor:
                                                        secondarycolor,
                                                    child: Text(
                                                      fullName.isNotEmpty
                                                          ? fullName[0]
                                                          : '?',
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                fullName,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: GoogleFonts.poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: dark,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Text(
                                                          _maskEmail(
                                                            c['email'],
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 13,
                                                            color: textdark,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Joined: $joinedDate',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: textdark,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Foul Words: ${c['foulWords'] ?? 0}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: textdark,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: () =>
                                                          _showUserDetailsDialog(
                                                            context,
                                                            c,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.visibility,
                                                        size: 16,
                                                      ),
                                                      label: Text(
                                                        'View',
                                                        style: GoogleFonts.poppins(),
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFFD88C1B,
                                                            ),
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 14,
                                                            ),
                                                        textStyle: GoogleFonts.poppins(),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: isBlocked
                                                        ? ElevatedButton.icon(
                                                            onPressed: () =>
                                                                _showRecoverConfirmation(
                                                                  context,
                                                                  c,
                                                                ),
                                                            icon: const Icon(
                                                              Icons.lock_open,
                                                              size: 16,
                                                            ),
                                                            label: Text(
                                                              'Recover',
                                                              style: GoogleFonts.poppins(),
                                                            ),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.green,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              textStyle: GoogleFonts.poppins(),
                                                            ),
                                                          )
                                                        : ElevatedButton.icon(
                                                            onPressed: () =>
                                                                _sendWarningNotification(
                                                                  c,
                                                                ),
                                                            icon: const Icon(
                                                              Icons
                                                                  .warning_amber,
                                                              size: 16,
                                                            ),
                                                            label: Text(
                                                              'Warning',
                                                              style: GoogleFonts.poppins(),
                                                            ),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors
                                                                      .orange
                                                                      .shade700,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              textStyle: GoogleFonts.poppins(),
                                                            ),
                                                          ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (!isBlocked)
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () =>
                                                            _showBlockConfirmation(
                                                              context,
                                                              c,
                                                            ),
                                                        icon: const Icon(
                                                          Icons.block,
                                                          size: 16,
                                                        ),
                                                        label: Text(
                                                          'Block',
                                                          style: GoogleFonts.poppins(),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                0xFF6C3C00,
                                                              ),
                                                          foregroundColor:
                                                              Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 14,
                                                              ),
                                                          textStyle: GoogleFonts.poppins(),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: _badge(
                                              c['blocked'] == true
                                                  ? 'Blocked'
                                                  : (c['position'] ?? ''),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 40,
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor:
                                                        secondarycolor,
                                                    child: Text(
                                                      fullName.isNotEmpty
                                                          ? fullName[0]
                                                          : '?',
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            fullName,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                            maxLines: 1,
                                                            style: GoogleFonts.poppins(
                                                              color: dark,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
                                                _maskEmail(c['email']),
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  color: textdark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: _badge(
                                                c['blocked'] == true
                                                    ? 'Blocked'
                                                    : (c['position'] ?? ''),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                joinedDate,
                                                style: GoogleFonts.poppins(
                                                  color: dark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                '${c['foulWords'] ?? 0}',
                                                style: GoogleFonts.poppins(
                                                  color: textdark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Tooltip(
                                                    message:
                                                        'View User Details',
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFD88C1B,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: SizedBox(
                                                        width: 35,
                                                        height: 35,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.visibility,
                                                            size: 20,
                                                          ),
                                                          color: Colors.white,
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints.tightFor(
                                                                width: 40,
                                                                height: 40,
                                                              ),
                                                          onPressed: () =>
                                                              _showUserDetailsDialog(
                                                                context,
                                                                c,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  isBlocked
                                                      ? Tooltip(
                                                          message:
                                                              'Recover Account',
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .green,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                            child: SizedBox(
                                                              width: 35,
                                                              height: 35,
                                                              child: IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .lock_open,
                                                                  size: 20,
                                                                ),
                                                                color: Colors
                                                                    .white,
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints.tightFor(
                                                                      width: 40,
                                                                      height:
                                                                          40,
                                                                    ),
                                                                onPressed: () =>
                                                                    _showRecoverConfirmation(
                                                                      context,
                                                                      c,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      : Row(
                                                          children: [
                                                            Tooltip(
                                                              message:
                                                                  'Send Warning',
                                                              child: Container(
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .orange
                                                                      .shade700,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                                child: SizedBox(
                                                                  width: 35,
                                                                  height: 35,
                                                                  child: IconButton(
                                                                    icon: const Icon(
                                                                      Icons
                                                                          .warning_amber,
                                                                      size: 20,
                                                                    ),
                                                                    color: Colors
                                                                        .white,
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    constraints:
                                                                        const BoxConstraints.tightFor(
                                                                          width:
                                                                              40,
                                                                          height:
                                                                              40,
                                                                        ),
                                                                    onPressed: () =>
                                                                        _sendWarningNotification(
                                                                          c,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Tooltip(
                                                              message:
                                                                  'Block User',
                                                              child: Container(
                                                                decoration: BoxDecoration(
                                                                  color: const Color(
                                                                    0xFF6C3C00,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                                child: SizedBox(
                                                                  width: 35,
                                                                  height: 35,
                                                                  child: IconButton(
                                                                    icon: const Icon(
                                                                      Icons
                                                                          .block,
                                                                      size: 20,
                                                                    ),
                                                                    color: Colors
                                                                        .white,
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    constraints:
                                                                        const BoxConstraints.tightFor(
                                                                          width:
                                                                              40,
                                                                          height:
                                                                              40,
                                                                        ),
                                                                    onPressed: () =>
                                                                        _showBlockConfirmation(
                                                                          context,
                                                                          c,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                ],
                                              ),
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

  Widget _badge(String text) {
    Color badgeColor;

    if (text == 'Blocked') {
      badgeColor = Colors.red;
    } else if (text.contains('Prospective')) {
      badgeColor = primarycolor;
    } else if (text.contains('Enrolled')) {
      badgeColor = primarycolordark;
    } else {
      badgeColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    // Don't mask [Encrypted] text
    if (email == '[Encrypted]') {
      return email;
    }
    
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    String masked = name.length <= 2
        ? name[0] + '*'
        : name[0] + '*' * (name.length - 2) + name[name.length - 1];
    return '$masked@$domain';
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: widget.width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(isHovered ? 0.16 : 0.10),
          border: Border.all(
            color: isHovered
                ? widget.color.withOpacity(0.54)
                : widget.color.withOpacity(0.31),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
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

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const SearchBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins( color: dark),
      decoration: InputDecoration(
        hintText: 'Search user...',
        hintStyle: GoogleFonts.poppins(color: textdark),
        prefixIcon: const Icon(Icons.search, color: primarycolor),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primarycolordark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: textdark),
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
        border: Border.all(color: textdark, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFilter,
          onChanged: onChanged,
          dropdownColor: lightBackground,
          style: GoogleFonts.poppins(color: dark),
          icon: const Icon(Icons.filter_list, color: primarycolordark),
          items: ['All', 'Prospective', 'Enrolled'].map((filter) {
            return DropdownMenuItem<String>(
              value: filter,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Text(
                    filter,
                    style: GoogleFonts.poppins(color: dark),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class AnimatedUserCard extends StatefulWidget {
  final Widget child;
  const AnimatedUserCard({super.key, required this.child});

  @override
  State<AnimatedUserCard> createState() => _AnimatedUserCardState();
}

class _AnimatedUserCardState extends State<AnimatedUserCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedScale(
        scale: isHovered ? 1.018 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: widget.child,
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