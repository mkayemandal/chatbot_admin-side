import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/auditlogs.dart';
import 'package:chatbot/superadmin/chatlogs.dart';
import 'package:chatbot/superadmin/feedbacks.dart';
import 'package:chatbot/superadmin/settings.dart';
import 'package:chatbot/superadmin/userinfo.dart';
import 'package:chatbot/superadmin/profile.dart';
import 'package:chatbot/superadmin/emergencypage.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:google_fonts/google_fonts.dart';

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

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  bool _isLoading = true;
  bool _recentChatsLoaded = false;
  bool _feedbacksLoaded = false;
  bool _barChartLoaded = false;

  Map<String, dynamic>? _dashboardStats;
  String firstName = "";
  String lastName = "";
  String profilePictureUrl = "assets/images/defaultDP.jpg";

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  // Data for child widgets (so they're not fetched separately)
  List<Map<String, dynamic>> recentChatLogs = [];
  List<Map<String, dynamic>> latestFeedbacks = [];
  List<BarChartGroupData> barGroups = [];

  bool _topOfficesLoaded = false;
  List<Map<String, dynamic>> topOfficeChats = [];

  bool get _allDataLoaded =>
      !_isLoading &&
      _recentChatsLoaded &&
      _feedbacksLoaded &&
      _barChartLoaded &&
      _logoLoaded &&
      _topOfficesLoaded;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      await _loadSuperAdminInfo();
      await _loadApplicationLogo();
      _dashboardStats = await fetchStatCounts();

      await Future.wait([
        _fetchRecentChats(),
        _fetchLatestFeedbacks(),
        _fetchMonthlyChatCounts(),
        _fetchTopOfficesByChatCounts(),
      ]);
    } catch (e) {
      print("Error loading dashboard data: $e");
    } finally {
      setState(() {
        _isLoading = false;
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

  Future<Map<String, dynamic>> fetchStatCounts() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Registered users
      final usersSnapshot = await firestore.collection('users').get();
      int registeredUsersCount = usersSnapshot.docs.length;

      // Registered information (CsvData)
      final csvSnapshot = await firestore.collection('CsvData').get();
      int registeredInfoCount = 0;
      for (var doc in csvSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('data') && data['data'] is List) {
          registeredInfoCount += (data['data'] as List).length;
        }
      }

      // Fetch all feedback documents (no department filtering here)
      final feedbackSnapshot = await firestore.collection('feedback').get();

      // Count only admin-department feedbacks for the 'totalFeedback' stat (preserve previous behavior)
      int totalFeedbackCount = feedbackSnapshot.docs.where((doc) {
        final dept = (doc.data()['department'] ?? '').toString().toLowerCase();
        return dept == 'admin';
      }).length;

      int totalPositiveFeedbackCount = 0;
      int totalAllFeedbackCount = feedbackSnapshot.docs.length;

      for (final doc in feedbackSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        bool isPositive = false;

        final dynamic isPos1 = data['isPositive'] ?? data['is_positive'];
        if (isPos1 == true) isPositive = true;

        if (!isPositive && data.containsKey('sentiment')) {
          final s = (data['sentiment'] ?? '').toString().toLowerCase();
          if (s.contains('positive') || s.contains('pos')) isPositive = true;
        }

        if (!isPositive) {
          final dynamic rating = data['rating'] ?? data['score'] ?? data['rating_value'];
          if (rating != null) {
            if (rating is num) {
              if (rating >= 4) isPositive = true;
            } else {
              // try parse string
              final parsed = double.tryParse(rating.toString());
              if (parsed != null && parsed >= 4) isPositive = true;
            }
          }
        }

        if (isPositive) totalPositiveFeedbackCount++;
      }

      double satisfactionScore = totalAllFeedbackCount == 0
          ? 0.0
          : (totalPositiveFeedbackCount / totalAllFeedbackCount) * 5;

      return {
        'registeredUsers': registeredUsersCount,
        'registeredInfo': registeredInfoCount,
        'totalFeedback': totalFeedbackCount,
        'userSatisfaction': '${satisfactionScore.toStringAsFixed(1)}/5',
      };
    } catch (e) {
      print('Error fetching stat counts: $e');
      return {
        'registeredUsers': 0,
        'registeredInfo': 0,
        'totalFeedback': 0,
        'userSatisfaction': '0.0/5',
      };
    }
  }

  Future<void> _loadSuperAdminInfo() async {
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
          });
        }
      }
    } catch (e) {
      print('Error loading super admin info: $e');
    }
  }

  Future<void> _fetchRecentChats() async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      List<Map<String, dynamic>> allChats = [];

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final userName = capitalizeEachWord(userData['name'] ?? 'Unknown');

        final conversationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .orderBy('lastTimestamp', descending: true)
            .get();

        for (var convoDoc in conversationsSnapshot.docs) {
          final convoData = convoDoc.data();
          final lastTimestamp = convoData['lastTimestamp'] as Timestamp?;
          if (lastTimestamp == null) continue;

          allChats.add({
            'user': userName,
            'message': convoData['title'],
            'timestamp': lastTimestamp,
          });
        }
      }

      allChats.sort(
        (a, b) => (b['timestamp'] as Timestamp).compareTo(
          a['timestamp'] as Timestamp,
        ),
      );
      final latestFive = allChats.take(5).toList();

      setState(() {
        recentChatLogs = latestFive;
        _recentChatsLoaded = true;
      });
    } catch (e) {
      print('Error fetching recent chat logs: $e');
      setState(() {
        _recentChatsLoaded = true;
      });
    }
  }

  String mapOfficeName(String raw) {
    final s = raw.toString().trim();
    if (s.isEmpty) return '';

    String norm(String input) =>
        input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final Map<String, String> mapping = {
      'AboutPSU': 'About PSU',
      'RSO': 'Accredited RSO',
      'Administrative': 'Administrative',
      'CAS':'College of Arts and Sciences',
      'CBAA':'College of Business Administration and Accountancy',
      'CCS':'College of Computing Studies',
      'COE':'College of Education',
      'CEA':'College of Engineering and Architecture',
      'CHTM':'College of Hospitality and Tourism Management',
      'CIT':'College of Industrial Technology',
      'MIS': 'Management Information Systems Office',
      'COOP': 'Multipurpose Cooperative Office',
      'Admission': 'Office Of Admission',
      'OCA': 'Office Of Culture And The Arts',
      'Registrar': 'Office Of Registrar',
      'OSA': 'Office Of Student Affairs And Developemnt',
      'OSWF': 'Office Of Student Welfare And Formation',
    };

    final Map<String, String> normMap = {
      for (final entry in mapping.entries) norm(entry.key): entry.value
    };

    for (final entry in mapping.entries) {
      normMap[norm(entry.value)] = entry.value;
    }

    final rawNorm = norm(s);

    if (normMap.containsKey(rawNorm)) return normMap[rawNorm]!;

    for (final key in normMap.keys) {
      if (key.isEmpty) continue;
      if (rawNorm.contains(key) || key.contains(rawNorm)) {
        return normMap[key]!;
      }
    }

    final tokens = s
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    for (final token in tokens) {
      final tNorm = norm(token);
      if (normMap.containsKey(tNorm)) return normMap[tNorm]!;
      for (final key in normMap.keys) {
        if (key.contains(tNorm) || tNorm.contains(key)) return normMap[key]!;
      }
    }

    var cleaned =
        s.replaceAll(RegExp(r'\boffice\b|\bof\b', caseSensitive: false), '')
            .trim();
    if (cleaned.isEmpty) cleaned = s;

    return capitalizeEachWord(cleaned);
  }

  Future<void> _fetchTopOfficesByChatCounts() async {
    try {
      final Map<String, int> officeChatCounts = {};

      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final conversationsSnapshot =
            await userDoc.reference.collection('conversations').get();

        for (var convoDoc in conversationsSnapshot.docs) {
          final messagesSnapshot = await convoDoc.reference
              .collection('messages')
              .where('role', isEqualTo: 'user')
              .get();

          for (var msgDoc in messagesSnapshot.docs) {
            final msgData = msgDoc.data();
            final rawDept =
                (msgData['office'] ?? msgData['department'] ?? '').toString().trim();
            final depRaw = rawDept.toLowerCase();

            if (depRaw.contains('admin') || depRaw.isEmpty) continue;

            final officeName = mapOfficeName(rawDept);

            if (officeName.isEmpty) continue;

            officeChatCounts[officeName] =
                (officeChatCounts[officeName] ?? 0) + 1;
          }
        }
      }

      final guestSnapshot = await FirebaseFirestore.instance
          .collection('guest_conversations')
          .get();

      for (var guestDoc in guestSnapshot.docs) {
        final messagesSnapshot = await guestDoc.reference
            .collection('messages')
            .where('role', isEqualTo: 'user')
            .get();
        for (var msgDoc in messagesSnapshot.docs) {
          final msgData = msgDoc.data();
          final rawDept =
              (msgData['office'] ?? msgData['department'] ?? '').toString().trim();
          final depRaw = rawDept.toLowerCase();

          if (depRaw.contains('admin') || depRaw.isEmpty) continue;

          final officeName = mapOfficeName(rawDept);

          if (officeName.isEmpty) continue;

          officeChatCounts[officeName] =
              (officeChatCounts[officeName] ?? 0) + 1;
        }
      }

      final sortedOffices = officeChatCounts.entries
          .where((e) => e.key.isNotEmpty)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        topOfficeChats = sortedOffices.take(5).map((entry) => {
              'office': entry.key,
              'chatCount': entry.value,
            }).toList();
        _topOfficesLoaded = true;
      });
    } catch (e, st) {
      debugPrint('Error fetching top offices by chats: $e\n$st');
      setState(() {
        _topOfficesLoaded = true;
        topOfficeChats = [];
      });
    }
  }

  Future<void> _fetchLatestFeedbacks() async {
    try {
      final firestore = FirebaseFirestore.instance;
      debugPrint('Fetching latest feedbacks (superadmin dashboard)');

      final feedbackSnapshot = await firestore
          .collection('feedback')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      String formatTimestamp(dynamic ts) {
        try {
          if (ts == null) return '';
          if (ts is Timestamp) return DateFormat('MM-dd-yyyy h:mm a').format(ts.toDate());
          if (ts is DateTime) return DateFormat('MM-dd-yyyy h:mm a').format(ts);
          if (ts is int) return DateFormat('MM-dd-yyyy h:mm a').format(DateTime.fromMillisecondsSinceEpoch(ts));
          return ts.toString();
        } catch (e) {
          return ts?.toString() ?? '';
        }
      }

      final List<Map<String, dynamic>> mapped = [];

      for (final doc in feedbackSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final deptRaw = (data['department'] ?? data['Department'] ?? '').toString().trim().toLowerCase();
        if (deptRaw != 'admin') continue;

        final rawName = (data['user_name'] ?? data['userName'] ?? data['user'] ?? '').toString().trim();
        final rawEmail = (data['user_email'] ?? data['userEmail'] ?? data['email'] ?? '').toString().trim();
        final uidRaw = (data['uid'] ?? data['userId'] ?? '').toString().trim();

        final raw = data;
        final explicitGuest = (raw['isGuest'] == true) || (raw['is_guest'] == true);
        final uidIsGuest = uidRaw.startsWith('guest_');
        final hasUserName = rawName.isNotEmpty;
        final hasEmail = rawEmail.isNotEmpty;
        final isGuest = explicitGuest || uidIsGuest || !(hasUserName || hasEmail || uidRaw.isNotEmpty);

        String displayName;
        if (isGuest) {
          displayName = 'Guest User';
        } else if (rawName.isNotEmpty) {
          displayName = capitalizeEachWord(rawName);
        } else if (rawEmail.isNotEmpty) {
          displayName = rawEmail.split('@').first;
        } else if (uidRaw.isNotEmpty) {
          displayName = uidRaw;
        } else {
          displayName = 'Unknown User';
        }

        final isPositiveRaw = data['isPositive'] ?? data['is_positive'] ?? false;
        final sentiment = (isPositiveRaw == true || isPositiveRaw.toString().toLowerCase() == 'true')
            ? 'positive'
            : 'negative';

        final message = (data['feedbackComment'] ??
                data['feedback_comment'] ??
                data['message'] ??
                data['feedback'] ??
                '')
            .toString();

        final timestampDisplay = formatTimestamp(data['timestamp']);

        mapped.add({
          'docId': doc.id,
          'user': displayName,
          'user_name': rawName,
          'user_email': rawEmail,
          'uid': uidRaw,
          'isGuest': isGuest,
          'message': message,
          'sentiment': sentiment,
          'timestamp': timestampDisplay,
          '_raw': data,
        });

        if (mapped.length >= 5) break;
      }

      setState(() {
        latestFeedbacks = mapped.take(5).toList();
        _feedbacksLoaded = true;
      });

      debugPrint('Loaded ${latestFeedbacks.length} latest admin feedback(s).');
    } catch (e, st) {
      debugPrint('Error fetching admin latest feedbacks: $e\n$st');
      setState(() {
        latestFeedbacks = [];
        _feedbacksLoaded = true;
      });
    }
  }

  Future<void> _fetchMonthlyChatCounts() async {
    try {
      final Map<int, int> monthlyCounts = {for (int i = 1; i <= 12; i++) i: 0};

      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;

        final convosSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .get();

        for (var convoDoc in convosSnapshot.docs) {
          final messagesSnapshot = await convoDoc.reference
              .collection('messages')
              .where('role', isEqualTo: 'user')
              .get();

          for (var msgDoc in messagesSnapshot.docs) {
            final msgData = msgDoc.data();
            final ts = msgData['timestamp'];
            DateTime? date;
            if (ts is Timestamp) date = ts.toDate();
            else if (ts is int) date = DateTime.fromMillisecondsSinceEpoch(ts);
            else if (ts is String) {
              try {
                date = DateTime.parse(ts);
              } catch (_) {}
            } else if (ts is DateTime) date = ts;

            if (date == null) continue;
            final month = date.month;
            monthlyCounts[month] = (monthlyCounts[month] ?? 0) + 1;
          }
        }
      }

      final guestSnapshot = await FirebaseFirestore.instance.collection('guest_conversations').get();
      for (var guestDoc in guestSnapshot.docs) {
        final messagesSnapshot = await guestDoc.reference
            .collection('messages')
            .where('role', isEqualTo: 'user')
            .get();

        for (var msgDoc in messagesSnapshot.docs) {
          final msgData = msgDoc.data();
          final ts = msgData['timestamp'];
          DateTime? date;
          if (ts is Timestamp) date = ts.toDate();
          else if (ts is int) date = DateTime.fromMillisecondsSinceEpoch(ts);
          else if (ts is String) {
            try {
              date = DateTime.parse(ts);
            } catch (_) {}
          } else if (ts is DateTime) date = ts;

          if (date == null) continue;
          final month = date.month;
          monthlyCounts[month] = (monthlyCounts[month] ?? 0) + 1;
        }
      }

      final List<BarChartGroupData> groups = [];
      for (int i = 0; i < 12; i++) {
        final count = monthlyCounts[i + 1] ?? 0;
        groups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                width: 20,
                gradient: const LinearGradient(
                  colors: [primarycolordark, primarycolor],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
        );
      }

      setState(() {
        barGroups = groups;
        _barChartLoaded = true;
      });
    } catch (e, st) {
      debugPrint('Error fetching monthly chat counts: $e\n$st');
      setState(() {
        _barChartLoaded = true;
      });
    }
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

    final poppinsTextTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    ).apply(bodyColor: dark, displayColor: dark);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: poppinsTextTheme,
        primaryTextTheme: poppinsTextTheme,
      ),
      child: Scaffold(
        backgroundColor: lightBackground,
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Dashboard",
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
                "Dashboard",
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
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminProfilePage()),
                  );
                  await _loadSuperAdminInfo();
                },
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            CustomHeader(firstName: firstName),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int columns = constraints.maxWidth > 1000
                              ? 4
                              : constraints.maxWidth > 600
                                  ? 2
                                  : 1;

                          double spacing = 12;
                          double totalSpacing = (columns - 1) * spacing;
                          double cardWidth =
                              (constraints.maxWidth - totalSpacing) / columns;

                          if (_dashboardStats == null) {
                            return const Center(
                              child: Text('No data available'),
                            );
                          }
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              StatCard(
                                title: 'Registered Users',
                                value: '${_dashboardStats!['registeredUsers']}',
                                subtitle: 'Users',
                                icon: Icons.person,
                                backgroundColor: const Color(0xFFFFB300),
                                width: cardWidth,
                              ),
                              StatCard(
                                title: 'Registered Information',
                                value: '${_dashboardStats!['registeredInfo']}',
                                subtitle: 'Information',
                                icon: Icons.insert_drive_file,
                                backgroundColor: const Color(0xFFCDDC39),
                                width: cardWidth,
                              ),
                              StatCard(
                                title: 'Unknown Feedback',
                                value: '${_dashboardStats!['totalFeedback']}',
                                subtitle: 'Feedback',
                                icon: Icons.message,
                                backgroundColor: const Color(0xFFFFB300),
                                width: cardWidth,
                              ),
                              StatCard(
                                title: 'User Satisfaction',
                                value:
                                    '${_dashboardStats!['userSatisfaction']}',
                                subtitle: 'Ratings',
                                icon: Icons.emoji_emotions,
                                backgroundColor: const Color(0xFFCDDC39),
                                width: cardWidth,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      UserChatsBarChart(barGroups: barGroups),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 800) {
                            const double panelHeight = 435;
                            return SizedBox(
                              height: panelHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: TopOfficeChatsCard(
                                      offices: topOfficeChats,
                                      fixedHeight: panelHeight,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 1,
                                    child: UserFeedbackCard(
                                      feedbacks: latestFeedbacks.take(5).toList(),
                                      fixedHeight: panelHeight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TopOfficeChatsCard(offices: topOfficeChats),
                                const SizedBox(height: 16),
                                UserFeedbackCard(feedbacks: latestFeedbacks),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopOfficeChatsCard extends StatelessWidget {
  final List<Map<String, dynamic>> offices;
  final double? fixedHeight;
  const TopOfficeChatsCard({super.key, required this.offices, this.fixedHeight});

  @override
  Widget build(BuildContext context) {
    final List<Color> cardColors = [
      const Color(0xFFFFF3E0),
      const Color(0xFFFFF8E1),
      const Color(0xFFE3F2FD),
      const Color(0xFFE8F5E9),
      const Color(0xFFF3E5F5),
    ];

    // Take only up to 5 items
    final itemsToShow = offices.take(5).toList();

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 0.5),
      ),
      elevation: 2,
      child: Container(
        height: fixedHeight ?? 435,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Top 5 Performing Offices",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primarycolordark,
              ),
            ),
            const SizedBox(height: 16),
            if (offices.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    "No office chat data found.",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    itemsToShow.length,
                    (index) {
                      final office = itemsToShow[index];
                      final bgColor = cardColors[index % cardColors.length];

                      return Card(
                        color: bgColor,
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: primarycolor.withOpacity(0.12)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {},
                          hoverColor: primarycolor.withOpacity(0.06),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: primarycolor,
                                  radius: 18,
                                  child: Text(
                                    "${index + 1}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    office["office"] ?? '',
                                    style: GoogleFonts.poppins(
                                      color: dark,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "${office["chatCount"]}x",
                                  style: GoogleFonts.poppins(
                                    color: primarycolordark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CustomHeader extends StatelessWidget {
  final String firstName;
  const CustomHeader({super.key, required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: lightBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${capitalizeEachWord(firstName.isNotEmpty ? firstName : 'there')}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primarycolordark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome to your Super Admin dashboard',
                style: GoogleFonts.poppins(
                  color: primarycolordark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UserFeedbackCard extends StatelessWidget {
  final List<Map<String, dynamic>> feedbacks;
  final double? fixedHeight;
  const UserFeedbackCard({super.key, required this.feedbacks, this.fixedHeight});

  @override
  Widget build(BuildContext context) {
    final itemsToShow = feedbacks.take(5).toList();

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey,
          width: 0.5,
        ),
      ),
      elevation: 2,
      child: Container(
        height: fixedHeight ?? 450,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Feedbacks",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: primarycolordark,
                  ),
                ),
                SeeAllButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbacksPage()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: itemsToShow.isEmpty
                  ? Center(
                      child: Text(
                        "No recent feedbacks found.",
                        style: GoogleFonts.poppins(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      itemCount: itemsToShow.length,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, idx) {
                        final feedback = itemsToShow[idx];
                        IconData sentimentIcon = Icons.thumb_up;
                        Color iconColor = secondarycolor;
                        if (feedback['sentiment'].toString().toLowerCase() == 'negative') {
                          sentimentIcon = Icons.warning_amber_rounded;
                          iconColor = secondarycolor;
                        }
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: primarycolordark,
                            child: Text(
                              feedback['user'].toString().substring(0, 1).toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feedback['user'],
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: dark,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(sentimentIcon, color: iconColor, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feedback['message'],
                                      style: GoogleFonts.poppins(
                                        color: dark,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
    );
  }
}

class SeeAllButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const SeeAllButton({super.key, required this.onTap, this.label = "See All"});

  @override
  State<SeeAllButton> createState() => _SeeAllButtonState();
}

class _SeeAllButtonState extends State<SeeAllButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isHovered ? primarycolor.withOpacity(0.85) : primarycolor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isHovered
                ? [BoxShadow(color: primarycolordark.withOpacity(0.15), blurRadius: 6, offset: Offset(0, 2))]
                : [],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.poppins(
              color: dark,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final double width;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 130,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: primarycolordark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: secondarycolor),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: secondarycolor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: primarycolor,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatItem extends StatelessWidget {
  final String message;
  const ChatItem({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.chat_bubble_outline, color: primarycolordark),
      title: Text(message, style: GoogleFonts.poppins()),
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}

class UserChatsBarChart extends StatelessWidget {
  final List<BarChartGroupData> barGroups;
  const UserChatsBarChart({super.key, required this.barGroups});

  @override
  Widget build(BuildContext context) {
    double maxY = barGroups.isNotEmpty
        ? barGroups.map((e) => e.barRods.first.toY).reduce((a, b) => a > b ? a : b)
        : 0;

    double adjustedMaxY = maxY + (maxY * 0.2);
    
    double interval;
    if (maxY <= 10) {
      interval = 2; 
    } else if (maxY <= 20) {
      interval = 5; 
    } else if (maxY <= 50) {
      interval = 10;
    } else if (maxY <= 100) {
      interval = 20; 
    } else if (maxY <= 200) {
      interval = 50;
    } else if (maxY <= 500) {
      interval = 100;
    } else {
      interval = 200;
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 0.5,
        ),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "User Chats Over Time",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primarycolordark,
              ),
            ),
            const SizedBox(height: 16),
            barGroups.isEmpty
                ? Center(
                    child: Text(
                      "No chat data found.",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        maxY: adjustedMaxY,
                        minY: 0,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: primarycolor,
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.toInt()} chats',
                                GoogleFonts.poppins(
                                  color: dark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            left: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withOpacity(0.15),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: barGroups,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 70, 
                              interval: interval,
                              getTitlesWidget: (value, meta) {
                                if (value == 0 || value % interval == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      '${value.toInt()} chats',
                                      style: GoogleFonts.poppins(
                                        color: dark,
                                        fontSize: 10, 
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                      ),
                                      textAlign: TextAlign.right,
                                      softWrap: false, 
                                      overflow: TextOverflow.fade, 
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const months = [
                                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                                ];
                                final idx = value.toInt();
                                final label = (idx >= 0 && idx < 12) 
                                    ? months[idx] 
                                    : '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    label,
                                    style: GoogleFonts.poppins(
                                      color: dark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
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