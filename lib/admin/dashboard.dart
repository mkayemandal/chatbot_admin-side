import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/feedbacks.dart';
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
const white = Color(0xFFFFFFFF);
const textdark = Color(0xFF343a40);
const lightBackground = Color(0xFFFEFEFE);

final List<String> foulWords = [
  'fuck', 'shit', 'asshole', 'bitch', 'mother fucker', 'damn',
  'bastard', 'jerk', 'dick', 'pussy', 'slut', 'whore',
  'moron', 'idiot', 'stupid',
  'putang ina', 'tangina', 'gago', 'ulol', 'tarantado', 'gaga',
  'bobo', 'tanga', 'tanginamo', 'lintik', 'hayop ka', 'bwisit',
  'sira ulo', 'walang hiya', 'tamad', 'peste', 'sira ulo mu', 'ulul ka', 'alang hiya',
  'buri mu', 'pota', 'yamu', 'atsaka mu', 'buri ku', 'e tamu manyira', 'loko ka'
];

String capitalizeEachWord(String text) {
  if (text.isEmpty) return '';
  final words = text.trim().split(RegExp(r'\s+'));
  return words.map((w) {
    if (w.toUpperCase() == w && w.length <= 4) return w.toUpperCase();
    final lowered = w.toLowerCase();
    return lowered[0].toUpperCase() + (lowered.length > 1 ? lowered.substring(1) : '');
  }).join(' ');
}

// Department mapping: Admin department name -> Short code for chats/feedback
final Map<String, String> _departmentToShortCode = {
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

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isLoading = true;
  bool _recentChatsLoaded = false;
  bool _feedbacksLoaded = false;
  bool _barChartLoaded = false;

  Map<String, dynamic>? _dashboardStats;
  String firstName = "";
  String lastName = "";
  String? adminDepartment;
  String? adminDepartmentShortCode;

  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  List<Map<String, dynamic>> recentChatLogs = [];
  List<Map<String, dynamic>> latestFeedbacks = [];
  List<BarChartGroupData> barGroups = [];

  Map<String, int> _userChatCounts = {};

  String _normDept(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool get _allDataLoaded =>
      !_isLoading && _recentChatsLoaded && _feedbacksLoaded && _barChartLoaded && _logoLoaded;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  String _formatTimestampForDisplay(dynamic ts) {
    try {
      if (ts == null) return '';
      if (ts is Timestamp) {
        return DateFormat('MM-dd-yyyy h:mm a').format(ts.toDate());
      } else if (ts is int) {
        return DateFormat('MM-dd-yyyy h:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(ts));
      } else if (ts is DateTime) {
        return DateFormat('MM-dd-yyyy h:mm a').format(ts);
      } else {
        return ts.toString();
      }
    } catch (e) {
      print('Timestamp formatting error: $e');
      return ts?.toString() ?? '';
    }
  }

  Future<void> _initializeDashboard() async {
    try {
      await _loadAdminInfo();
      await _loadApplicationLogo();

      _dashboardStats = await fetchStatCounts();

      await Future.wait([
        _fetchRecentChats(),
        _fetchLatestFeedbacks(),
        _fetchMonthlyChatCounts(),
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
      if (adminDepartment == null || adminDepartment!.trim().isEmpty) {
        print('⚠️ No admin department found - returning zeros');
        return {
          'registeredInfo': 0,
          'totalFeedback': 0,
          'userSatisfaction': '0.0/5',
        };
      }

      final csvDocId = adminDepartment!; // Use full name for CSV
      final shortCode = adminDepartmentShortCode ?? adminDepartment!;

      print('📊 Fetching stats for CSV doc: "$csvDocId", Short code: "$shortCode"');

      // 1️⃣ Count registered info from CsvData collection
      int registeredInfoCount = 0;
      try {
        final csvDoc = await firestore.collection('CsvData').doc(csvDocId).get();
        if (csvDoc.exists) {
          final data = csvDoc.data()!;
          if (data.containsKey('data') && data['data'] is List) {
            registeredInfoCount = (data['data'] as List).length;
            print('✅ Found ${registeredInfoCount} entries in CsvData/$csvDocId');
          }
        } else {
          print('⚠️ CsvData document "$csvDocId" not found');
        }
      } catch (e) {
        print('❌ Error fetching CsvData: $e');
      }

      // 2️⃣ Count feedbacks using short code
      final feedbackSnapshot = await firestore.collection('feedback').get();
      final filteredFeedbacks = feedbackSnapshot.docs.where((doc) {
        final data = doc.data();
        final deptField = data['department'] ?? data['Department'] ?? '';
        
        if (deptField is String) {
          return deptField.trim() == shortCode;
        } else if (deptField is List) {
          return (deptField as List).any((d) => d.toString().trim() == shortCode);
        }
        return false;
      }).toList();

      final totalFeedbackCount = filteredFeedbacks.length;
      final positiveFeedbackCount = filteredFeedbacks.where((doc) {
        final data = doc.data();
        final val = data['is_positive'] ?? data['isPositive'] ?? false;
        return val == true;
      }).length;

      // 3️⃣ Calculate satisfaction score
      final satisfactionScore = totalFeedbackCount == 0
          ? 0.0
          : (positiveFeedbackCount / totalFeedbackCount) * 5;

      print('✅ Stats: Info=$registeredInfoCount, Feedback=$totalFeedbackCount, Positive=$positiveFeedbackCount');

      return {
        'registeredInfo': registeredInfoCount,
        'totalFeedback': totalFeedbackCount,
        'userSatisfaction': '${satisfactionScore.toStringAsFixed(1)}/5',
      };
    } catch (e, st) {
      print('❌ Error fetching stats: $e\n$st');
      return {
        'registeredInfo': 0,
        'totalFeedback': 0,
        'userSatisfaction': '0.0/5',
      };
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
          final rawDept = (data['department'] ?? 'No Department').toString().trim();
          
          setState(() {
            firstName = capitalizeEachWord(data['firstName'] ?? '');
            lastName = capitalizeEachWord(data['lastName'] ?? '');
            adminDepartment = rawDept;
            
            // Map to short code for chats/feedback
            adminDepartmentShortCode = _departmentToShortCode[adminDepartment] ?? adminDepartment;
          });

          print('✅ Admin loaded: $firstName $lastName, Dept: $adminDepartment (Short: $adminDepartmentShortCode)');
        }
      }
    } catch (e) {
      print('❌ Error loading admin info: $e');
    }
  }

  Future<void> _fetchRecentChats() async {
    try {
      if (adminDepartmentShortCode == null || adminDepartmentShortCode!.isEmpty) {
        print("⚠️ No department short code - skipping recent chats");
        setState(() => _recentChatsLoaded = true);
        return;
      }

      final targetShortCode = adminDepartmentShortCode!;
      final targetNorm = _normDept(targetShortCode);
      final fullDeptNorm = _normDept(adminDepartment!); // Normalize full department name for fallback matching
      print("🔍 Fetching chats for department: $targetShortCode (normalized: $targetNorm, full: $fullDeptNorm)");

      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      List<Map<String, dynamic>> allChats = [];

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final userName = capitalizeEachWord(
            (userData['name'] ?? userData['displayName'] ?? userId).toString());

        // Get all conversations for this user, ordered by lastTimestamp descending, limit to 50 for performance
        final conversationsSnapshot = await userDoc.reference
            .collection('conversations')
            .orderBy('lastTimestamp', descending: true)
            .limit(50)  // Added limit to improve performance
            .get();

        for (var convoDoc in conversationsSnapshot.docs) {
          final convoData = convoDoc.data();
          
          // Check if any message in this conversation has the target department
          bool hasMatchingMessage = false;
          final messagesSnapshot = await convoDoc.reference.collection('messages').get();
          for (var msgDoc in messagesSnapshot.docs) {
            final msgData = msgDoc.data();
            final msgDept = msgData['department'];
            if (msgDept is String) {
              final msgDeptNorm = _normDept(msgDept.trim());
              if (msgDeptNorm == targetNorm || msgDeptNorm == fullDeptNorm) { // Check both short code and full name
                hasMatchingMessage = true;
                break;
              }
            }
          }

          // Skip if no message matches the department
          if (!hasMatchingMessage) continue;

          // Get timestamp
          final lastTimestamp = convoData['lastTimestamp'];
          Timestamp? lastTs;
          
          if (lastTimestamp is Timestamp) {
            lastTs = lastTimestamp;
          } else if (lastTimestamp is int) {
            lastTs = Timestamp.fromMillisecondsSinceEpoch(lastTimestamp);
          } else if (lastTimestamp is String) {
            final parsed = DateTime.tryParse(lastTimestamp);
            if (parsed != null) lastTs = Timestamp.fromDate(parsed);
          }

          if (lastTs == null) continue;

          allChats.add({
            'user': userName,
            'message': convoData['title'] ?? '(No message)',
            'timestamp': lastTs,
            'conversationId': convoDoc.id,
          });
        }
      }

      // Sort by timestamp (most recent first)
      allChats.sort((a, b) => 
          (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

      setState(() {
        recentChatLogs = allChats.take(5).toList();
        _recentChatsLoaded = true;
      });

      print("✅ Loaded ${recentChatLogs.length} recent chats for $targetShortCode");
    } catch (e, st) {
      print('❌ Error fetching recent chats: $e\n$st');
      setState(() => _recentChatsLoaded = true);
    }
  }
  
  Future<void> _fetchLatestFeedbacks() async {
    try {
      if (adminDepartmentShortCode == null || adminDepartmentShortCode!.isEmpty) {
        print("⚠️ No department short code - skipping feedbacks");
        setState(() {
          latestFeedbacks = [];
          _feedbacksLoaded = true;
        });
        return;
      }

      final targetShortCode = adminDepartmentShortCode!;
      print('🔍 Fetching feedbacks for: $targetShortCode');

      final feedbackSnapshot = await FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final filtered = feedbackSnapshot.docs.where((doc) {
        final data = doc.data();
        final deptField = data['department'] ?? data['Department'];
        
        if (deptField is String) {
          return deptField.trim() == targetShortCode;
        } else if (deptField is List) {
          return (deptField as List).any((d) => d.toString().trim() == targetShortCode);
        }
        return false;
      }).take(5);

      final result = <Map<String, dynamic>>[];

      for (final doc in filtered) {
        final data = doc.data();

        final uid = (data['uid'] ?? data['userId'] ?? '').toString();
        final isGuestFlag = data['isGuest'] ?? data['is_guest'] ?? false;
        final rawName = (data['user_name'] ?? data['userName'] ?? data['user'] ?? '').toString();
        final rawEmail = (data['user_email'] ?? data['userEmail'] ?? data['email'] ?? '').toString();

        final bool isGuest = (isGuestFlag == true) ||
            uid.startsWith('guest_') ||
            rawEmail.trim().isEmpty;

        final displayName = isGuest
            ? 'Guest User'
            : capitalizeEachWord(rawName.isNotEmpty ? rawName : rawEmail.split('@').first);
        
        final displayEmail = isGuest ? '' : rawEmail;
        final timestampDisplay = _formatTimestampForDisplay(data['timestamp']);
        final feedbackText = (data['feedbackComment'] ??
                data['feedback_comment'] ??
                data['message'] ??
                data['feedback'] ?? '')
            .toString();

        final sentiment = (data['isPositive'] == true || data['is_positive'] == true)
            ? 'positive'
            : 'negative';

        result.add({
          'user': displayName,
          'email': displayEmail,
          'message': feedbackText,
          'sentiment': sentiment,
          'timestamp': timestampDisplay,
          'isGuest': isGuest,
          'docId': doc.id,
        });
      }

      setState(() {
        latestFeedbacks = result;
        _feedbacksLoaded = true;
      });

      print('✅ Loaded ${result.length} feedbacks for $targetShortCode');
    } catch (e, st) {
      print("❌ Error fetching feedbacks: $e\n$st");
      setState(() {
        latestFeedbacks = [];
        _feedbacksLoaded = true;
      });
    }
  }

  Future<void> _fetchMonthlyChatCounts() async {
    try {
      final Map<int, int> monthlyCounts = {for (int i = 1; i <= 12; i++) i: 0};

      if (adminDepartmentShortCode == null || adminDepartmentShortCode!.isEmpty) {
        print('⚠️ No department short code for chat counts');
        setState(() => _barChartLoaded = true);
        return;
      }

      final targetShortCode = adminDepartmentShortCode!;
      final targetNorm = _normDept(targetShortCode);
      final fullDeptNorm = _normDept(adminDepartment!); // Normalize full department name for fallback matching
      print('📊 Fetching user messages for: $targetShortCode (normalized: $targetNorm, full: $fullDeptNorm, with foul word filter)');

      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final Map<String, int> userCounts = {};

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final userName = capitalizeEachWord(
            (userData['name'] ?? userData['displayName'] ?? userId).toString());

        int userTotal = 0;
        final convosSnapshot = await userDoc.reference.collection('conversations').get();

        for (final convoDoc in convosSnapshot.docs) {
          final convoData = convoDoc.data();
          
          final messagesSnapshot = await convoDoc.reference
              .collection('messages')
              .where('role', isEqualTo: 'user')
              .get();

          for (final msg in messagesSnapshot.docs) {
            final msgData = msg.data();

            // Check department match with normalized exact matching (both short code and full name)
            final msgDept = msgData['departments'] ?? msgData['department'];
            bool msgMatches = false;

            if (msgDept is List) {
              msgMatches = (msgDept as List).any((d) {
                final dNorm = _normDept(d.toString().trim());
                return dNorm == targetNorm || dNorm == fullDeptNorm;
              });
            } else if (msgDept is String && msgDept.trim().isNotEmpty) {
              final msgDeptNorm = _normDept(msgDept.trim());
              msgMatches = msgDeptNorm == targetNorm || msgDeptNorm == fullDeptNorm;
            } else {
              // Fallback to conversation-level department
              final convoDept = convoData['departments'] ?? convoData['department'];
              if (convoDept is List) {
                msgMatches = (convoDept as List).any((d) {
                  final dNorm = _normDept(d.toString().trim());
                  return dNorm == targetNorm || dNorm == fullDeptNorm;
                });
              } else if (convoDept is String) {
                final convoDeptNorm = _normDept(convoDept.trim());
                msgMatches = convoDeptNorm == targetNorm || convoDeptNorm == fullDeptNorm;
              }
            }

            if (!msgMatches) continue;

            // Extract and validate message text
            final rawText = (msgData['message'] ??
                    msgData['text'] ??
                    msgData['original_question'] ??
                    msgData['content'] ?? '')
                .toString()
                .trim();
            
            if (rawText.isEmpty) continue;

            // Filter foul words
            final normalizedText = rawText.toLowerCase();
            final containsFoul = foulWords.any((w) {
              final wNorm = w.toLowerCase().trim();
              return wNorm.isNotEmpty && normalizedText.contains(wNorm);
            });
            
            if (containsFoul) continue;

            // Count this message
            userTotal++;

            // Add to monthly count
            DateTime? date;
            final ts = msgData['timestamp'];
            if (ts is Timestamp) {
              date = ts.toDate();
            } else if (ts is int) {
              date = DateTime.fromMillisecondsSinceEpoch(ts);
            }

            if (date != null) {
              monthlyCounts[date.month] = (monthlyCounts[date.month] ?? 0) + 1;
            }
          }
        }

        if (userTotal > 0) {
          userCounts[userName] = userTotal;
        }
      }

      // Build bar chart groups
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
        _userChatCounts = userCounts;
        _barChartLoaded = true;
      });

      print('✅ Monthly counts computed for $targetShortCode (foul-word filtered)');
      print('📊 Top users: ${userCounts.entries.take(3).map((e) => '${e.key}: ${e.value}').join(', ')}');
    } catch (e, st) {
      print("❌ Error fetching monthly chat counts: $e\n$st");
      setState(() => _barChartLoaded = true);
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

    final poppinsTextTheme =
        GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
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
              Flexible(
                child: Text(
                  "Dashboard",
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
                              ? 3
                              : constraints.maxWidth > 600
                                  ? 2
                                  : 1;

                          double spacing = 16;
                          double totalSpacing = (columns - 1) * spacing;
                          double cardWidth =
                              (constraints.maxWidth - totalSpacing) / columns;

                          if (_dashboardStats == null) {
                            return Center(
                                child: Text('No data available',
                                    style: GoogleFonts.poppins()));
                          }

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              StatCard(
                                title: 'Registered Information',
                                value: '${_dashboardStats!['registeredInfo']}',
                                subtitle: 'Information',
                                icon: Icons.insert_drive_file,
                                backgroundColor: const Color(0xFFFFB300),
                                width: cardWidth,
                              ),
                              StatCard(
                                title: 'Total Feedback',
                                value: '${_dashboardStats!['totalFeedback']}',
                                subtitle: 'Feedback',
                                icon: Icons.message,
                                backgroundColor: const Color(0xFFCDDC39),
                                width: cardWidth,
                              ),
                              StatCard(
                                title: 'User Satisfaction',
                                value: '${_dashboardStats!['userSatisfaction']}',
                                subtitle: 'Ratings',
                                icon: Icons.emoji_emotions,
                                backgroundColor: const Color(0xFFFFB300),
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
                            return SizedBox(
                              height: 435,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: RecentChatLogsCard(
                                      logs: recentChatLogs.take(5).toList(),
                                      fixedHeight: 450,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 1,
                                    child: UserFeedbackCard(
                                      feedbacks: latestFeedbacks.take(5).toList(),
                                      fixedHeight: 450,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RecentChatLogsCard(logs: recentChatLogs),
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

/* ----------------- UI Components ----------------- */

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
                'Welcome to your Admin dashboard',
                style: GoogleFonts.poppins(color: primarycolordark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecentChatLogsCard extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final double? fixedHeight;
  const RecentChatLogsCard({super.key, required this.logs, this.fixedHeight});

  int _maxItemsForHeight(double height) {
    const headerAndPadding = 20 + 20 + 36 + 12;
    const tileHeight = 68;
    final available = height - headerAndPadding;
    return available ~/ tileHeight;
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> itemsToShow = logs;
    if (fixedHeight != null) {
      final maxItems = _maxItemsForHeight(fixedHeight!);
      itemsToShow = logs.take(maxItems).toList();
    } else {
      itemsToShow = logs.take(5).toList();
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey, width: 0.5),
      ),
      elevation: 2,
      child: Container(
        height: fixedHeight,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Chat Logs",
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
                      MaterialPageRoute(builder: (_) => const ChatsPage()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            itemsToShow.isEmpty
                ? Expanded(
                    child: Center(
                      child: Text(
                        "No recent chats found.",
                        style: GoogleFonts.poppins(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: itemsToShow.map((log) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: primarycolordark,
                          child: Text(
                            log['user']!.isNotEmpty
                                ? log['user']![0].toUpperCase()
                                : 'U',
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
                              log['user'] ?? '',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: dark,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              log['message'] ?? '',
                              style: GoogleFonts.poppins(
                                color: dark,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
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
        side: BorderSide(color: Colors.grey, width: 0.5),
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
                        if (feedback['sentiment'].toString().toLowerCase() ==
                            'negative') {
                          sentimentIcon = Icons.warning_amber_rounded;
                          iconColor = secondarycolor;
                        }
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: primarycolordark,
                            child: Text(
                              feedback['user']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
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
                                  Icon(sentimentIcon,
                                      color: iconColor, size: 22),
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
            color: isHovered
                ? primarycolor.withOpacity(0.85)
                : primarycolor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                        color: primarycolordark.withOpacity(0.15),
                        blurRadius: 6,
                        offset: Offset(0, 2))
                  ]
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

class UserChatsBarChart extends StatelessWidget {
  final List<BarChartGroupData> barGroups;
  const UserChatsBarChart({super.key, required this.barGroups});

  @override
  Widget build(BuildContext context) {
    double maxY = barGroups.isNotEmpty
        ? barGroups
            .map((e) => e.barRods.first.toY)
            .reduce((a, b) => a > b ? a : b)
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
        side: BorderSide(color: Colors.grey.shade300, width: 0.5),
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
                                final label = (idx >= 0 && idx < 12) ? months[idx] : '';
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

  const HoverButton({
    Key? key,
    required this.onPressed,
    this.child,
    this.isLogout = false,
    this.icon,
    this.label,
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
            color: isHovered
                ? (widget.isLogout
                    ? primarycolor.withOpacity(0.13)
                    : primarycolor.withOpacity(0.09))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: Icon(
              widget.icon,
              color: widget.isLogout ? Colors.red : primarycolordark,
            ),
            title: Text(
              widget.label ?? '',
              style: GoogleFonts.poppins(
                color: widget.isLogout ? Colors.red : primarycolordark,
                fontWeight: FontWeight.w600,
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
          }, isActive: activePage == "Dashboard"),
          _drawerItem(context, Icons.analytics_outlined, "Statistics", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotStatisticsPage()),
            );
          }, isActive: activePage == "Statistics"),
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
              : (isHovered ? primarycolor.withOpacity(0.10) : Colors.transparent),
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