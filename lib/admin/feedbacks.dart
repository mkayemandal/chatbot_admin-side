import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatbot/services/encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/chatbotdata.dart';
import 'package:chatbot/admin/profile.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/admin/chatbotfiles.dart';
import 'package:chatbot/admin/usersinfo.dart';
import 'package:chatbot/admin/statistics.dart';

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

class FeedbacksPage extends StatefulWidget {
  const FeedbacksPage({super.key});

  @override
  State<FeedbacksPage> createState() => _FeedbacksPageState();
}

class _FeedbacksPageState extends State<FeedbacksPage> {
  List<Map<String, dynamic>> feedbackList = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String fullName = '';
  String? adminDepartment;
  bool _adminInfoLoaded = false;
  bool _feedbacksLoaded = false;

  final _encryptionService = EncryptionService();

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  // Department map (admin display -> stored value)
  final Map<String, String> _departmentMap = {
    'About PSU': 'AboutPSU',
    'Academic Honors': 'AcademicHonors',
    'Accredited RSO': 'RSO',
    'Administrative': 'Administrative',
    'College of Arts and Sciences': 'CAS',
    'College of Business Administration and Accountancy': 'CBAA',
    'College of Computing Studies': 'CCS',
    'College of Education': 'COE',
    'College of Engineering and Architecture': 'CEA',
    'College of Hospitality and Tourism Management': 'CHTM',
    'College of Industrial Technology': 'CIT',
    'Management Information Systems Office': 'MIS',
    'Multipurpose Cooperative Office': 'COOP',
    'Office of Admission': 'Admission',
    'Office of Culture and the Arts': 'OCA',
    'Office of Registrar': 'Registrar',
    'Office of Student Affairs and Development': 'OSA',
    'Office of Student Welfare and Formation': 'OSWF',
  };

  bool get _allDataLoaded => _adminInfoLoaded && _feedbacksLoaded && _logoLoaded;

  @override
  void initState() {
    super.initState();
    _initializePage();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _initializePage() async {
    await _loadAdminInfo();

    await Future.wait([
      _loadFeedbacks(),
      _loadApplicationLogo(),
    ]);
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

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('Admin')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;

          final fetchedFirstName = data['firstName'] ?? '';
          final fetchedLastName = data['lastName'] ?? '';
          final fetchedDepartment = data['department'] ?? 'No Department';

          setState(() {
            fullName = capitalizeEachWord('$fetchedFirstName $fetchedLastName');
            adminDepartment = fetchedDepartment;
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

  // Helper: map adminDepartment to stored feedback department
  String _mapAdminDepartmentToFeedback(String adminDept) {
    final adminLower = adminDept.trim().toLowerCase();

    // exact key match
    final exactKey = _departmentMap.keys.firstWhere(
      (k) => k.toLowerCase() == adminLower,
      orElse: () => '',
    );
    if (exactKey.isNotEmpty) return _departmentMap[exactKey]!;

    // partial / token match
    for (final entry in _departmentMap.entries) {
      final keyLower = entry.key.toLowerCase();
      if (adminLower.contains(keyLower) || keyLower.contains(adminLower)) {
        return entry.value;
      }
      final adminTokens = adminLower.split(RegExp(r'\s+'));
      final keyTokens = keyLower.split(RegExp(r'\s+'));
      if (adminTokens.any((t) => keyTokens.contains(t)) || keyTokens.any((t) => adminTokens.contains(t))) {
        return entry.value;
      }
    }

    // fallback: remove "office" / "of"
    var cleaned = adminDept.replaceAll(RegExp(r'\boffice\b|\bof\b', caseSensitive: false), '').trim();
    if (cleaned.isEmpty) return capitalizeEachWord(adminDept);
    return capitalizeEachWord(cleaned);
  }

  // Helper to format various timestamp types
  String _formatTimestamp(dynamic ts) {
    try {
      if (ts == null) return '';
      if (ts is Timestamp) {
        return DateFormat('MM-dd-yyyy h:mm a').format(ts.toDate());
      } else if (ts is int) {
        return DateFormat('MM-dd-yyyy h:mm a').format(DateTime.fromMillisecondsSinceEpoch(ts));
      } else if (ts is DateTime) {
        return DateFormat('MM-dd-yyyy h:mm a').format(ts);
      } else {
        return ts.toString();
      }
    } catch (e) {
      print('Timestamp format error: $e');
      return ts?.toString() ?? '';
    }
  }

  Future<String?> _findUserIdByEmail(String email) async {
    if (email.isEmpty) return null;

    try {
      // Step 1: Try to find by plain email first (backwards compatibility)
      var userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        print('✅ Found user by plain email');
        return userSnapshot.docs.first.id;
      }

      // Step 2: If not found, search through all users and decrypt emails
      print('🔍 Searching for user with encrypted email...');
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var doc in allUsersSnapshot.docs) {
        final data = doc.data();
        final encryptedEmail = data['email'] as String?;

        if (encryptedEmail != null && encryptedEmail.isNotEmpty) {
          try {
            // Check if it's already plain text (contains @)
            if (encryptedEmail.contains('@')) {
              if (encryptedEmail.toLowerCase() == email.toLowerCase()) {
                print('✅ Found user by plain email in doc');
                return doc.id;
              }
            } else {
              // Try to decrypt
              final decryptedEmail = await _encryptionService.decryptValue(encryptedEmail);
              if (decryptedEmail.toLowerCase() == email.toLowerCase()) {
                print('✅ Found user by decrypted email');
                return doc.id;
              }
            }
          } catch (e) {
            // Skip this document if decryption fails
            continue;
          }
        }
      }

      print('⚠️ User not found with email: $email');
      return null;
    } catch (e) {
      print('❌ Error finding user by email: $e');
      return null;
    }
  }

  Future<void> _loadFeedbacks() async {
    try {
      if (adminDepartment == null || adminDepartment!.isEmpty) {
        print('Admin department not loaded yet.');
        setState(() => _feedbacksLoaded = true);
        return;
      }

      final mappedDepartment = _mapAdminDepartmentToFeedback(adminDepartment!);
      final normalizedDepartment = mappedDepartment.trim().toLowerCase();

      print(
          'Fetching feedbacks for admin department: "$adminDepartment" -> filtering by: "$mappedDepartment" (normalized: $normalizedDepartment)');

      final snapshot = await FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('timestamp', descending: false)
          .get();

      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final deptRaw =
            (data['department'] ?? data['Department'] ?? '').toString().trim().toLowerCase();
        return deptRaw == normalizedDepartment;
      }).toList();

      print('Fetched ${filteredDocs.length} feedbacks after department mapping/filtering.');

      // ✅ DECRYPT EMAILS WHILE MAPPING
      final List<Map<String, dynamic>> loadedFeedbacks = [];
      
      for (var doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>;

        final feedbackText = (data['feedbackComment'] ??
                data['feedback_comment'] ??
                data['message'] ??
                data['feedback'] ??
                '')
            .toString();

        final isPositiveRaw = data['isPositive'] ?? data['is_positive'] ?? false;
        final sentiment = (isPositiveRaw == true ||
                isPositiveRaw.toString().toLowerCase() == 'true')
            ? 'positive'
            : 'negative';

        final userNameRaw =
            (data['user_name'] ?? data['userName'] ?? data['user'] ?? '').toString().trim();
        
        // ✅ DECRYPT EMAIL HERE
        final userEmailRaw =
            (data['user_email'] ?? data['userEmail'] ?? data['email'] ?? '').toString().trim();
        
        String decryptedEmail = '';
        if (userEmailRaw.isNotEmpty) {
          try {
            // Check if email is already plain text (contains @)
            if (userEmailRaw.contains('@')) {
              decryptedEmail = userEmailRaw;
              print('📧 Email already plain text: $decryptedEmail');
            } else {
              // Decrypt encrypted email
              decryptedEmail = await _encryptionService.decryptValue(userEmailRaw);
              print('🔓 Decrypted email: $decryptedEmail');
            }
          } catch (e) {
            print('⚠️ Failed to decrypt email for doc ${doc.id}: $e');
            decryptedEmail = '[Encrypted]'; // Fallback display
          }
        }
        
        final uidRaw = (data['uid'] ?? data['userId'] ?? '').toString().trim();
        final timestampDisplay = _formatTimestamp(data['timestamp']);
        final statusValue = (data['status'] ?? 'new').toString();

        loadedFeedbacks.add({
          'docId': doc.id,
          'feedback': feedbackText,
          'sentiment': sentiment,
          'user_name': userNameRaw.isNotEmpty ? userNameRaw : '',
          'user_email': decryptedEmail, // ✅ Store decrypted email
          'user_email_encrypted': userEmailRaw, // ✅ Keep encrypted for later use
          'user': userNameRaw.isNotEmpty
              ? capitalizeEachWord(userNameRaw)
              : (decryptedEmail.isNotEmpty
                  ? decryptedEmail.split('@').first
                  : (uidRaw.isNotEmpty ? uidRaw : 'Unknown User')),
          'email': decryptedEmail, // ✅ Decrypted email
          'uid': uidRaw,
          'timestamp': timestampDisplay,
          'status': statusValue,
          'question': data['question'] ?? '',
          'answer': data['answer'] ?? '',
          'department': data['department'] ?? data['Department'] ?? '',
          '_raw': data,
        });
      }

      // Sort by timestamp
      DateTime? _parseRawTs(dynamic raw) {
        if (raw == null) return null;
        if (raw is Timestamp) return raw.toDate();
        if (raw is DateTime) return raw;
        if (raw is String) return DateTime.tryParse(raw);
        return null;
      }

      loadedFeedbacks.sort((a, b) {
        final aDate = _parseRawTs(a['_raw']?['timestamp']);
        final bDate = _parseRawTs(b['_raw']?['timestamp']);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

      setState(() {
        feedbackList = loadedFeedbacks;
        _feedbacksLoaded = true;
      });
    } catch (e, st) {
      print('Error loading feedbacks: $e\n$st');
      setState(() => _feedbacksLoaded = true);
    }
  }

  List<Map<String, dynamic>> _getFeedbacksByStatus(String status) {
    final query = _searchController.text.toLowerCase();
    final filter = _selectedFilter.toLowerCase();

    final matchesNewTab = (item) =>
        (item['status'] == 'new' || item['status'] == 'transferred');

    return feedbackList.where((item) {
      final matchesStatus = (status == 'new') ? matchesNewTab(item) : (item['status'] == status);

      // combine user-name/email/uid for searching
      final userFieldsCombined = '${(item['user_name'] ?? '')} ${(item['user'] ?? '')} ${(item['user_email'] ?? '')} ${(item['email'] ?? '')}'.toLowerCase();

      final matchesQuery = (item['feedback'] ?? '').toString().toLowerCase().contains(query) || userFieldsCombined.contains(query);
      final matchesFilter = filter == 'all' || (item['sentiment'] ?? '').toString().toLowerCase() == filter;
      return matchesStatus && matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _updateFeedbackStatus(
    BuildContext context,
    Map<String, dynamic> item,
    String newStatus,
    Future<void> Function() refresh,
    String successMessage,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Prefer updating by docId (safer)
      final docId = item['docId'] as String?;
      if (docId != null && docId.isNotEmpty) {
        final docRef = firestore.collection('feedback').doc(docId);
        await docRef.update({'status': newStatus});
        print('Updated feedback $docId → $newStatus (by docId)');
        await Future.delayed(const Duration(milliseconds: 200));
        await refresh();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: primarycolor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      // Fallback: try matching by fields (legacy)
      final feedbackText = (item['feedback'] ?? '').toString().trim();
      final userEmail = (item['email'] ?? '').toString().trim();

      QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
          .collection('feedback')
          .where('feedback_comment', isEqualTo: feedbackText)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        snapshot = await firestore
            .collection('feedback')
            .where('feedbackComment', isEqualTo: feedbackText)
            .limit(1)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        final docRef = snapshot.docs.first.reference;
        await docRef.update({'status': newStatus});
        print('Updated feedback ${docRef.id} → $newStatus (fallback match)');
        await Future.delayed(const Duration(milliseconds: 200));
        await refresh();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: primarycolor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        print("⚠️ No matching feedback found for update.");
      }
    } catch (e, st) {
      print('Error updating feedback status: $e\n$st');
    }
  }

  Widget _buildFeedbackList(String status) {
    final list = _getFeedbacksByStatus(status);

    if (list.isEmpty) {
      // Centered illustration with text when empty
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/web-search.png",
              width: 240,
              height: 240,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              "No item to show.",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final feedback = list[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FeedbackCard(
            feedback: feedback,
            getIcon: _getIcon,
            currentStatus: status,
            onMarkReviewed: () => _updateFeedbackStatus(
              context,
              feedback,
              'reviewed',
              _loadFeedbacks,
              "Marked as reviewed!",
            ),
            onArchive: () => _updateFeedbackStatus(
              context,
              feedback,
              'archived',
              _loadFeedbacks,
              "Feedback archived!",
            ),
            onUnarchive: () => _updateFeedbackStatus(
              context,
              feedback,
              'new',
              _loadFeedbacks,
              "Feedback unarchived!",
            ),
            onRefresh: _loadFeedbacks,
          ),
        );
      },
    );
  }

  Icon _getIcon(String sentiment) {
    switch (sentiment) {
      case 'positive':
        return const Icon(Icons.thumb_up, color: Colors.green);
      case 'negative':
        return const Icon(Icons.thumb_down, color: Colors.red);
      default:
        return const Icon(Icons.feedback, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loader screen covers everything until _allDataLoaded
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

    final newCount = feedbackList.where((f) => f['status'] == 'new').length;
    final reviewedCount = feedbackList.where((f) => f['status'] == 'reviewed').length;
    final archivedCount = feedbackList.where((f) => f['status'] == 'archived').length;

    // apply Poppins theme locally
    final poppinsTextTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
        .apply(bodyColor: dark, displayColor: dark);

    return Theme(
      data: Theme.of(context).copyWith(textTheme: poppinsTextTheme, primaryTextTheme: poppinsTextTheme),
      child: Scaffold(
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Feedbacks",
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
                  "Feedbacks",
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
        backgroundColor: lightBackground,
        body: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int columns = constraints.maxWidth > 800 ? 3 : 1;
                        double spacing = 12;
                        double totalSpacing = (columns - 1) * spacing;
                        double cardWidth = (constraints.maxWidth - totalSpacing) / columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            StatCard(title: "Total Feedback", value: "${feedbackList.length}", color: primarycolordark, width: cardWidth),
                            StatCard(title: "Positive Feedback", value: "${feedbackList.where((f) => f['sentiment'] == 'positive').length}", color: primarycolor, width: cardWidth),
                            StatCard(title: "Negative Feedback", value: "${feedbackList.where((f) => f['sentiment'] == 'negative').length}", color: secondarycolor, width: cardWidth),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: SearchBar(controller: _searchController)),
                        const SizedBox(width: 12),
                        FilterDropdown(
                          selectedFilter: _selectedFilter,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedFilter = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TabBar(
                labelColor: primarycolor,
                unselectedLabelColor: dark,
                indicatorColor: primarycolor,
                indicatorWeight: 3,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: [
                  Tab(text: 'New ($newCount)'),
                  Tab(text: 'Reviewed ($reviewedCount)'),
                  Tab(text: 'Archived ($archivedCount)'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildFeedbackList('new'),
                    _buildFeedbackList('reviewed'),
                    _buildFeedbackList('archived'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> feedback;
  final Icon Function(String) getIcon;
  final String currentStatus;
  final VoidCallback onMarkReviewed;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;
  final Future<void> Function() onRefresh;

  const FeedbackCard({
    super.key,
    required this.feedback,
    required this.getIcon,
    required this.currentStatus,
    required this.onMarkReviewed,
    required this.onArchive,
    required this.onUnarchive,
    required this.onRefresh,
  });

  // Only treat as guest when explicitly flagged in the raw document
  bool isGuestFeedback(Map<String, dynamic> feedback) {
    final raw = feedback['_raw'] as Map<String, dynamic>?;
    if (raw != null) {
      if (raw['isGuest'] == true || raw['is_guest'] == true) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = (feedback['sentiment'] ?? '').toString() == 'positive';
    final sentimentLabel = isPositive ? "Positive" : "Negative";
    final sentimentColor = isPositive ? Colors.green : Colors.red;

    final bool isGuest = isGuestFeedback(feedback);

    // Get values
    final rawName = (feedback['user_name'] ?? '').toString().trim();
    final decryptedEmail = (feedback['user_email'] ?? feedback['email'] ?? '').toString().trim(); // ✅ Already decrypted
    final rawUid = (feedback['uid'] ?? feedback['user'] ?? '').toString().trim();

    String displayUser;
    if (isGuest) {
      displayUser = 'Guest User';
    } else if (rawName.isNotEmpty) {
      displayUser = capitalizeEachWord(rawName);
    } else if (decryptedEmail.isNotEmpty && decryptedEmail != '[Encrypted]') {
      displayUser = decryptedEmail.split('@').first;
    } else if (rawUid.isNotEmpty) {
      displayUser = rawUid;
    } else {
      displayUser = 'Unknown User';
    }

    final displayEmail = isGuest ? '' : decryptedEmail; // ✅ Use decrypted email

    final hasEmail = decryptedEmail.isNotEmpty && decryptedEmail != '[Encrypted]';
    final hasUserName = rawName.isNotEmpty;
    final bool legacyIsGuest = isGuest || !(hasEmail || hasUserName);

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ User Info & Timestamp - UPDATED
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayUser,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // ✅ SHOW DECRYPTED EMAIL
                      Text(
                        legacyIsGuest
                            ? "Guest ID: ${feedback['docId'] ?? 'n/a'}"
                            : "Email: ${displayEmail.isNotEmpty && displayEmail != '[Encrypted]' ? displayEmail : 'n/a'}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: displayEmail == '[Encrypted]' ? Colors.red : dark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  feedback['timestamp'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: dark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bot Response
            if ((feedback['answer'] ?? '').toString().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${feedback['answer']}",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: dark,
                  ),
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sentimentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sentimentLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: sentimentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    feedback['feedback'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: dark,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ✅ UPDATED BUTTON SECTION - Use decrypted email
            if (currentStatus == 'new') ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = legacyIsGuest
                      ? (constraints.maxWidth - 8) / 2
                      : (constraints.maxWidth - 16) / 3;

                  return Row(
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          onPressed: onMarkReviewed,
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text("Mark as Reviewed", style: GoogleFonts.poppins()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primarycolor,
                            side: const BorderSide(color: primarycolor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            textStyle: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!legacyIsGuest) ...[
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // ✅ USE DECRYPTED EMAIL (already available)
                              final email = decryptedEmail;
                              final name = feedback['user_name'] ?? feedback['user'] ?? '';
                              final currentUser = FirebaseAuth.instance.currentUser;

                              if (email.isEmpty || email == '[Encrypted]') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Cannot find user email.",
                                      style: GoogleFonts.poppins(color: Colors.white),
                                    ),
                                  ),
                                );
                                return;
                              }

                              try {
                                // ✅ Find user by DECRYPTED email
                                String? userId;

                                // Try direct query first
                                var userSnapshot = await FirebaseFirestore.instance
                                    .collection('users')
                                    .where('email', isEqualTo: email)
                                    .limit(1)
                                    .get();

                                if (userSnapshot.docs.isNotEmpty) {
                                  userId = userSnapshot.docs.first.id;
                                  print('✅ Found user by direct email query');
                                } else {
                                  // Search all users and decrypt
                                  print('🔍 Searching all users with decryption...');
                                  final allUsers = await FirebaseFirestore.instance
                                      .collection('users')
                                      .get();

                                  for (var doc in allUsers.docs) {
                                    final userData = doc.data();
                                    final userEncryptedEmail = userData['email'] as String?;

                                    if (userEncryptedEmail != null && userEncryptedEmail.isNotEmpty) {
                                      try {
                                        String userEmail;
                                        if (userEncryptedEmail.contains('@')) {
                                          userEmail = userEncryptedEmail;
                                        } else {
                                          userEmail = await EncryptionService()
                                              .decryptValue(userEncryptedEmail);
                                        }

                                        if (userEmail.toLowerCase() == email.toLowerCase()) {
                                          userId = doc.id;
                                          print('✅ Found user by decrypted email match');
                                          break;
                                        }
                                      } catch (e) {
                                        continue;
                                      }
                                    }
                                  }
                                }

                                if (userId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "User not found in system.",
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (isPositive) {
                                  final encryptedEmailForNotification = await EncryptionService()
                                    .encryptValue(decryptedEmail);
                                  // Send thank-you notification
                                  await FirebaseFirestore.instance
                                      .collection('Notifications')
                                      .add({
                                    'userId': userId,
                                    'email': encryptedEmailForNotification, 
                                    'title': 'Thank You',
                                    'message':
                                        "Thank you ${name.isNotEmpty ? name : ''} for your kind words. We're glad you're satisfied!",
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'status': 'unread',
                                    // 'sentBy': currentUser?.email ?? 'admin',
                                  });

                                  onMarkReviewed();
                                  await onRefresh();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Thank you message sent!",
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: primarycolor,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                } else {
                                  // Respond directly dialog
                                  final String userName = feedback['user'] ?? 'User';
                                  final TextEditingController responseController =
                                      TextEditingController();

                                  await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: lightBackground,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Text(
                                        'Respond to Users Feedback',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: primarycolordark,
                                        ),
                                      ),
                                      content: SizedBox(
                                        width: 400,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Your response will be sent to $userName.',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: dark,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller: responseController,
                                              maxLines: 5,
                                              decoration: InputDecoration(
                                                hintText: 'Type your response here...',
                                                hintStyle: GoogleFonts.poppins(color: dark),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFFCCCCCC),
                                                  ),
                                                ),
                                                contentPadding: const EdgeInsets.all(12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actionsPadding: const EdgeInsets.only(
                                        right: 16,
                                        bottom: 8,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text(
                                            'Cancel',
                                            style: GoogleFonts.poppins(color: dark),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primarycolor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () async {
                                            final responseText =
                                                responseController.text.trim();

                                            if (responseText.isNotEmpty) {
                                              Navigator.pop(context);

                                              try {
                                                final fullMessage =
                                                    "$responseText\n\nIf you have further concerns, feel free to contact us at support@dhvsu.edu.ph or call (045) 123-4567.";

                                                final encryptedEmailForNotification = await EncryptionService()
                                                 .encryptValue(decryptedEmail);    

                                                await FirebaseFirestore.instance
                                                    .collection('Notifications')
                                                    .add({
                                                  'userId': userId,
                                                  'email': encryptedEmailForNotification,
                                                  'title': 'Feedback Response',
                                                  'message': fullMessage,
                                                  'timestamp':
                                                      FieldValue.serverTimestamp(),
                                                  'status': 'unread',
                                                  // 'sentBy':
                                                  //     currentUser?.email ?? 'super admin',
                                                });

                                                onMarkReviewed();
                                                await onRefresh();

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Response sent and saved!",
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    duration: const Duration(seconds: 2),
                                                    backgroundColor: primarycolor,
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                print('Error sending response: $e');
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Failed to send response",
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    duration: const Duration(seconds: 2),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: Text(
                                            'Send',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 25),
                                      ],
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('Error processing feedback: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Unexpected error",
                                      style: GoogleFonts.poppins(color: Colors.white),
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              isPositive ? Icons.thumb_up_alt : Icons.reply,
                              size: 16,
                            ),
                            label: Text(
                              isPositive ? "Send Thanks" : "Respond Directly",
                              style: GoogleFonts.poppins(),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primarycolor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              textStyle: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      SizedBox(
                        width: buttonWidth,
                        child: ElevatedButton.icon(
                          onPressed: onArchive,
                          icon: const Icon(Icons.archive_outlined, size: 16),
                          label: Text("Archive", style: GoogleFonts.poppins()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: secondarycolor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            textStyle: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ] else if (currentStatus == 'archived') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: onUnarchive,
                    icon: const Icon(Icons.unarchive),
                    label: Text("Unarchive", style: GoogleFonts.poppins()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primarycolor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      textStyle: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
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
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        width: widget.width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(isHovered ? 0.17 : 0.12),
          border: Border.all(
            color: widget.color.withOpacity(isHovered ? 0.9 : 0.6),
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
      style: GoogleFonts.poppins(color: dark),
      decoration: InputDecoration(
        hintText: 'Search user...',
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
          items: ['All', 'Positive', 'Negative'].map((filter) {
            return DropdownMenuItem<String>(
              value: filter,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
          },
          isActive: activePage == "Dashboard",),
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
          // },
          // isActive: activePage == "Users Info",),
          _drawerItem(context, Icons.chat_outlined, "Chat Logs", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatsPage()),
            );
          },
          isActive: activePage == "Chat Logs",),
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