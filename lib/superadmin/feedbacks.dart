import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/auditlogs.dart';
import 'package:chatbot/superadmin/chatlogs.dart';
import 'package:chatbot/superadmin/settings.dart';
import 'package:chatbot/superadmin/userinfo.dart';
import 'package:chatbot/superadmin/profile.dart';
import 'package:chatbot/superadmin/emergencypage.dart';
import 'package:chatbot/services/encryption_service.dart'; 

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
  String profilePictureUrl = "assets/images/defaultDP.jpg";

  bool _adminInfoLoaded = false;
  bool _feedbacksLoaded = false;

  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  final _encryptionService = EncryptionService(); 

  bool get _allDataLoaded => _adminInfoLoaded && _feedbacksLoaded && _logoLoaded;

  @override
  void initState() {
    super.initState();
    _initializePage();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _loadAdminInfo(),
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
            .collection('SuperAdmin')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final firstName = data?['firstName'] ?? '';
          final lastName = data?['lastName'] ?? '';
          setState(() {
            fullName = capitalizeEachWord('$firstName $lastName');
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

  Future<void> _loadFeedbacks() async {
    try {
      print('Fetching feedbacks for department: admin');

      final snapshot = await FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('timestamp', descending: false)
          .get();

      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dept = (data['department'] ?? '').toString().trim().toLowerCase();
        return dept == 'admin';
      }).toList();

      print('Fetched ${filteredDocs.length} admin feedbacks.');

      // ✅ DECRYPT EMAILS WHILE MAPPING
      final List<Map<String, dynamic>> loadedFeedbacks = [];

      for (var doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>;

        final rawName = (data['user_name'] ?? data['userName'] ?? data['user'] ?? '')
            .toString()
            .trim();
        final rawEmailEncrypted =
            (data['user_email'] ?? data['userEmail'] ?? data['email'] ?? '')
                .toString()
                .trim();
        final uidRaw = (data['uid'] ?? data['userId'] ?? '').toString().trim();

        String decryptedEmail = '';
        if (rawEmailEncrypted.isNotEmpty) {
          try {
            if (rawEmailEncrypted.contains('@')) {
              decryptedEmail = rawEmailEncrypted; 
              print('📧 Email already plain text: $decryptedEmail');
            } else {
              decryptedEmail = await _encryptionService.decryptValue(rawEmailEncrypted);
              print('🔓 Decrypted email: $decryptedEmail');
            }
          } catch (e) {
            print('⚠️ Failed to decrypt email for doc ${doc.id}: $e');
            decryptedEmail = '[Encrypted]';
          }
        }

        String displayUser;
        if (rawName.isNotEmpty) {
          displayUser = capitalizeEachWord(rawName);
        } else if (decryptedEmail.isNotEmpty && decryptedEmail != '[Encrypted]') {
          displayUser = decryptedEmail.split('@').first;
        } else if (uidRaw.isNotEmpty) {
          displayUser = uidRaw;
        } else {
          displayUser = 'Unknown User';
        }

        final isPositiveRaw = data['isPositive'] ?? data['is_positive'] ?? false;
        final sentiment =
            (isPositiveRaw == true || isPositiveRaw.toString().toLowerCase() == 'true')
                ? 'positive'
                : 'negative';

        final timestampDisplay = data['timestamp'] != null
            ? (data['timestamp'] is Timestamp
                ? DateFormat('MM-dd-yyyy h:mm a')
                    .format((data['timestamp'] as Timestamp).toDate())
                : data['timestamp'].toString())
            : '';

        final statusValue = (data['status'] ?? 'new').toString();

        loadedFeedbacks.add({
          'docId': doc.id,
          'feedback': (data['feedback_comment'] ??
                  data['feedbackComment'] ??
                  data['message'] ??
                  data['feedback'] ??
                  '')
              .toString(),
          'sentiment': sentiment,
          'user_name': rawName,
          'user_email': decryptedEmail, 
          'user_email_encrypted': rawEmailEncrypted,
          'user': displayUser,
          'email': decryptedEmail,
          'uid': uidRaw,
          'timestamp': timestampDisplay,
          'status': statusValue,
          'question': data['question'] ?? '',
          'answer': data['answer'] ?? '',
          'department': data['department'] ?? '',
          '_raw': data,
        });
      }

      setState(() {
        feedbackList = loadedFeedbacks;
        _feedbacksLoaded = true;
      });
    } catch (e, st) {
      print('Error loading admin feedbacks: $e\n$st');
      setState(() => _feedbacksLoaded = true);
    }
  }

  List<Map<String, dynamic>> _getFeedbacksByStatus(String status) {
    final query = _searchController.text.toLowerCase();
    final filter = _selectedFilter.toLowerCase();

    return feedbackList.where((item) {
      final matchesStatus = item['status'] == status;
      
      final searchableText = '${item['feedback'] ?? ''} ${item['user'] ?? ''} ${item['user_name'] ?? ''} ${item['user_email'] ?? ''}'.toLowerCase();
      
      final matchesQuery = searchableText.contains(query);
      final matchesFilter =
          filter == 'all' || item['sentiment'].toLowerCase() == filter;
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
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      final feedbackText = (item['feedback'] ?? '').toString().trim();

      final snapshot = await firestore
          .collection('feedback')
          .where('feedback_comment', isEqualTo: feedbackText)
          .limit(1)
          .get();

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
            margin: const EdgeInsets.all(16),
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
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
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
    final transferredCount =
        feedbackList.where((f) => f['status'] == 'transferred').length;
    final archivedCount =
        feedbackList.where((f) => f['status'] == 'archived').length;

    final poppinsTextTheme =
        GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
            .apply(bodyColor: dark, displayColor: dark);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: poppinsTextTheme,
        primaryTextTheme: poppinsTextTheme,
      ),
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
              Text(
                "Feedbacks",
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
                    MaterialPageRoute(
                        builder: (_) => const AdminProfilePage()),
                  );
                },
              ),
            ),
          ],
        ),
        backgroundColor: lightBackground,
        body: DefaultTabController(
          length: 2, 
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
                        double cardWidth =
                            (constraints.maxWidth - totalSpacing) / columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            StatCard(
                              title: "Total Feedback",
                              value: "${feedbackList.length}",
                              color: primarycolordark,
                              width: cardWidth,
                            ),
                            StatCard(
                              title: "Positive Feedback",
                              value:
                                  "${feedbackList.where((f) => f['sentiment'] == 'positive').length}",
                              color: primarycolor,
                              width: cardWidth,
                            ),
                            StatCard(
                              title: "Negative Feedback",
                              value:
                                  "${feedbackList.where((f) => f['sentiment'] == 'negative').length}",
                              color: secondarycolor,
                              width: cardWidth,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                            child: SearchBar(controller: _searchController)),
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
                indicatorPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 14),
                tabs: [
                  Tab(text: 'New ($newCount)'),
                  Tab(text: 'Archived ($archivedCount)'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildFeedbackList('new'),
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
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;
  final Future<void> Function() onRefresh;

  const FeedbackCard({
    super.key,
    required this.feedback,
    required this.getIcon,
    required this.currentStatus,
    required this.onArchive,
    required this.onUnarchive,
    required this.onRefresh,
  });

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

    final rawName = (feedback['user_name'] ?? '').toString().trim();
    final decryptedEmail = (feedback['user_email'] ?? feedback['email'] ?? '')
        .toString()
        .trim(); 
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

    final displayEmail = isGuest ? '' : decryptedEmail;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayUser,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        legacyIsGuest
                            ? "Guest ID: ${feedback['docId'] ?? 'n/a'}"
                            : "Email: ${displayEmail.isNotEmpty && displayEmail != '[Encrypted]' ? displayEmail : 'n/a'}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            if ((feedback['answer'] ?? '').isNotEmpty)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    feedback['feedback'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: dark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentStatus == 'new') ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = (constraints.maxWidth - 16) / 2;
                  return Row(
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: _SendToAdminModalButton(
                          feedback: feedback,
                          onRefresh: onRefresh,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
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
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
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

class _SendToAdminModalButton extends StatefulWidget {
  final Map<String, dynamic> feedback;
  final Future<void> Function() onRefresh;

  const _SendToAdminModalButton({
    required this.feedback,
    required this.onRefresh,
  });

  @override
  State<_SendToAdminModalButton> createState() =>
      _SendToAdminModalButtonState();
}

class _SendToAdminModalButtonState extends State<_SendToAdminModalButton> {
  bool isLoading = false;

  Future<void> _showDepartmentDialog(BuildContext context) async {
    String? selectedDepartment;

    final Map<String, String> deptMap = {
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

    final List<String> departmentList = deptMap.keys.toList();
    final feedbackDeptRaw = widget.feedback['department']?.toString().trim();

    if (feedbackDeptRaw != null && feedbackDeptRaw.isNotEmpty) {
      if (departmentList.contains(feedbackDeptRaw)) {
        selectedDepartment = feedbackDeptRaw;
      } else {
        final matchedEntry = deptMap.entries.firstWhere(
          (e) => e.value.toLowerCase() == feedbackDeptRaw.toLowerCase(),
          orElse: () =>
              MapEntry(departmentList.first, deptMap[departmentList.first]!),
        );
        selectedDepartment = matchedEntry.key;
      }
    } else {
      selectedDepartment = departmentList.first;
    }

    bool modalLoading = false;
    await showDialog(
      context: context,
      barrierDismissible: !modalLoading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
            return AlertDialog(
              backgroundColor: lightBackground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Choose Department",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: primarycolordark,
                ),
              ),
              content: DropdownButtonFormField<String>(
                value: selectedDepartment,
                decoration: InputDecoration(
                  labelText: "Department",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: departmentList
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d, style: GoogleFonts.poppins()),
                        ))
                    .toList(),
                onChanged: modalLoading
                    ? null
                    : (val) => setInnerState(() => selectedDepartment = val),
              ),
              actions: [
                TextButton(
                  onPressed:
                      modalLoading ? null : () => Navigator.pop(innerContext),
                  child:
                      Text("Cancel", style: GoogleFonts.poppins(color: dark)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primarycolor,
                    foregroundColor: Colors.white,
                    textStyle:
                        GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed:
                      (selectedDepartment == null || modalLoading)
                          ? null
                          : () async {
                              setInnerState(() => modalLoading = true);

                              try {
                                final feedbackDocId =
                                    widget.feedback['docId']?.toString() ?? '';
                                final displayDept = selectedDepartment!.trim();

                                if (feedbackDocId.isEmpty) {
                                  throw Exception(
                                      "Invalid feedback document ID.");
                                }

                                final storedDept = deptMap[displayDept] ??
                                    displayDept
                                        .toLowerCase()
                                        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');

                                await FirebaseFirestore.instance
                                    .collection('feedback')
                                    .doc(feedbackDocId)
                                    .update({
                                  'department': storedDept,
                                  'status': 'transferred',
                                  'transferredAt': FieldValue.serverTimestamp(),
                                });

                                await widget.onRefresh();

                                if (mounted) {
                                  Navigator.pop(innerContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Department changed to $displayDept.",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white),
                                      ),
                                      backgroundColor: primarycolor,
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.all(16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Failed to update department: $e",
                                      style: GoogleFonts.poppins(
                                          color: Colors.white),
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } finally {
                                setInnerState(() => modalLoading = false);
                              }
                            },
                  child: modalLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text("Change Department"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading
          ? null
          : () async {
              setState(() => isLoading = true);
              await _showDepartmentDialog(context);
              setState(() => isLoading = false);
            },
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.send, size: 16),
      label: Text("Send to Admin", style: GoogleFonts.poppins(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primarycolor,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
        hintText: 'Search feedback or user...',
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
          items: ['All', 'Positive', 'Negative'].map((filter) {
            return DropdownMenuItem<String>(
              value: filter,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child:
                      Text(filter, style: GoogleFonts.poppins(color: dark)),
                ),
              ),
            );
          }).toList(),
        ),
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
                fontWeight:
                    widget.isActive ? FontWeight.bold : FontWeight.w600,
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
          transform: isHovered
              ? (Matrix4.identity()..scale(1.07))
              : Matrix4.identity(),
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
              child: applicationLogoUrl != null &&
                      applicationLogoUrl!.isNotEmpty
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
          // _drawerItem(
          //     context, Icons.warning_amber_rounded, "Emergency Requests", () {
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
                      content: Text("Logout failed. Please try again.",
                          style: GoogleFonts.poppins())),
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