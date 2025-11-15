import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:chatbot/admin/profile.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/chatbotfiles.dart';
import 'package:chatbot/admin/chatbotdata.dart';
import 'package:chatbot/admin/feedbacks.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:firebase_auth/firebase_auth.dart';

final List<String> foulWords = [
  'fuck', 'shit', 'asshole', 'bitch', 'mother fucker', 'damn',
  'bastard', 'jerk', 'dick', 'pussy', 'slut', 'whore',
  'moron', 'idiot', 'stupid',
  'putang ina', 'tangina', 'gago', 'ulol', 'tarantado', 'gaga',
  'bobo', 'tanga', 'tanginamo', 'lintik', 'hayop ka', 'bwisit',
  'sira ulo', 'walang hiya', 'tamad', 'peste', 'sira ulo mu', 'ulul ka', 'alang hiya',
  'buri mu', 'pota', 'yamu', 'atsaka mu', 'buri ku', 'e tamu manyira', 'loko ka'
];

const primarycolor = Color(0xFFffc803);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFF800000);
const dark = Color(0xFF17110d);
const white = Color(0xFFFFFFFF);
const textdark = Color(0xFF343a40);
const lightBackground = Color(0xFFFEFEFE);

// Improved normalization helper used by mapping logic
String _normalizeForKey(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

// Raw fallback mapping (human readable -> firestore key)
final Map<String, String> _rawFallback = {
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

// Normalized fallback map keyed by normalized human-readable names
final Map<String, String> _normalizedFallback = {
  for (final entry in _rawFallback.entries) _normalizeForKey(entry.key): entry.value
};

String capitalizeEachWord(String text) {
  if (text.trim().isEmpty) return '';
  final words = text.trim().split(RegExp(r'\s+'));
  return words.map((w) {
    // Preserve existing acronyms like "MIS", "OCA", "COOP" (all-caps, short)
    if (w.toUpperCase() == w && w.length <= 4) return w.toUpperCase();
    final lowered = w.toLowerCase();
    return lowered[0].toUpperCase() + (lowered.length > 1 ? lowered.substring(1) : '');
  }).join(' ');
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

class ChatbotStatisticsPage extends StatefulWidget {
  const ChatbotStatisticsPage({super.key});

  @override
  State<ChatbotStatisticsPage> createState() => _ChatbotStatisticsPageState();
}

class _ChatbotStatisticsPageState extends State<ChatbotStatisticsPage> {
  bool _dataLoaded = false;
  bool _barChartLoaded = false;
  List<BarChartGroupData> barGroups = [];
  List<Map<String, dynamic>> _topQuestions = [];
  List<Map<String, dynamic>> _topUserQuestions = [];
  List<Map<String, dynamic>> _topGuestQuestions = [];
  int totalQuestions = 0;
  int uniqueQuestions = 0;

  double weeklyChange = 0.0;
  String peakHour = "N/A";
  double positiveFeedbackPercent = 0.0;
  List<FlSpot> weeklyTrend = [];

  String fullName = '';
  String? adminDepartment;
  String? _applicationLogoUrl;

  Map<String, int> _userWeeklyCounts = {};
  Map<String, int> _guestWeeklyCounts = {};

  // NEW: per-user chat counts and top users
  Map<String, int> _userChatCounts = {};
  List<Map<String, dynamic>> _topUsersByCount = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadAdminInfo();
      await _loadApplicationLogo();

      if (adminDepartment != null && adminDepartment!.trim().isNotEmpty) {
        await _fetchChatStatistics();
      } else {
        debugPrint("⚠️ Admin department not found or empty, skipping stats fetch.");
      }

      if (mounted) {
        setState(() => _dataLoaded = true);
      }
    } catch (e, stack) {
      debugPrint("❌ Error during initialization: $e");
      debugPrint(stack.toString());
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  Future<void> _loadApplicationLogo() async {
    final doc = await FirebaseFirestore.instance.collection('SystemSettings').doc('global').get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['applicationLogoUrl'] != null) {
        setState(() => _applicationLogoUrl = data['applicationLogoUrl'].toString());
      }
    }
  }

  Future<void> _loadAdminInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('Admin').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final first = (data['firstName'] ?? '').toString();
        final last = (data['lastName'] ?? '').toString();
        final deptRaw = (data['department'] ?? '').toString();

        setState(() {
          fullName = "${capitalizeEachWord(first)} ${capitalizeEachWord(last)}".trim();
          adminDepartment = deptRaw.trim();
        });

        debugPrint('Loaded admin: $fullName, department(raw): "$adminDepartment"');
      }
    }
  }

  // Robust mapping helper: maps many variants ("Office of Admission", "Office Of Registar", "Admission", "Admission Office", "admission", "ADMISSION") to the correct Firestore department key.
  String _mapAdminDeptToFirestoreDept(String rawDept) {
    final norm = _normalizeForKey(rawDept);
    if (norm.isEmpty) return rawDept;

    // Try direct normalized fallback first
    if (_normalizedFallback.containsKey(norm)) return _normalizedFallback[norm]!;

    // Keyword-based mapping and handling common misspellings / abbreviations
    if (norm.contains('admission') || norm.contains('admit')) return 'Admission';
    if (norm.contains('registr') || norm.contains('registar')) return 'Registrar';
    if (norm.contains('multipurpose') || norm.contains('cooperative') || norm.contains('coop')) return 'COOP';
    if (norm.contains('managementinformationsystems') || norm.contains('managementinformation') || norm.contains('mis')) return 'MIS';
    if (norm.contains('culture') || norm.contains('arts') || norm.contains('oca')) return 'OCA';
    if (norm.contains('studentaffairs') || norm.contains('studentaffair') || norm.contains('osa')) return 'OSA';
    if (norm.contains('studentwelfare') || norm.contains('welfare') || norm.contains('formation') || norm.contains('oswf')) return 'OSWF';
    if (norm.contains('aboutpsu') || norm.contains('about') || norm.contains('psu')) return 'AboutPSU';
    if (norm.contains('accredited') || norm.contains('rso')) return 'RSO';
    if (norm.contains('administrative') || norm.contains('administration') || norm.contains('admin')) return 'Administrative';

    // final fallback: return a cleaned title-cased string without spaces (best-effort)
    return capitalizeEachWord(rawDept).replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _fetchChatStatistics() async {
  try {
    if (adminDepartment == null || adminDepartment!.trim().isEmpty) {
      debugPrint("⚠️ Cannot fetch stats — adminDepartment is null or empty.");
      return;
    }

    final firestoreDept = _mapAdminDeptToFirestoreDept(adminDepartment!);
    debugPrint("📊 Fetching statistics for department (mapped): $firestoreDept (from '${adminDepartment!}')");

    // NEW: Add normalization helper to match dashboard.dart
    String _normDept(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final firestoreDeptNorm = _normDept(firestoreDept);

    // Robust extractors (unchanged)
    String? _extractText(Map<String, dynamic> data) {
      final possibleKeys = ['text', 'message', 'messageText', 'content', 'body', 'question'];
      for (var k in possibleKeys) {
        if (data.containsKey(k) && data[k] != null) {
          final val = data[k].toString().trim();
          if (val.isNotEmpty) return val;
        }
      }
      return null;
    }

    // guest-specific extractor that prefers original_question (unchanged)
    String? _extractGuestText(Map<String, dynamic> data) {
      if (data.containsKey('original_question') && data['original_question'] != null) {
        final v = data['original_question'].toString().trim();
        if (v.isNotEmpty) return v;
      }
      return _extractText(data);
    }

    DateTime? _extractTimestamp(Map<String, dynamic> data) {
      final timeKeys = ['timestamp', 'createdAt', 'created_at', 'time'];
      for (var k in timeKeys) {
        if (!data.containsKey(k) || data[k] == null) continue;
        final v = data[k];
        if (v is Timestamp) return v.toDate();
        if (v is int) {
          try {
            return DateTime.fromMillisecondsSinceEpoch(v);
          } catch (_) {}
        }
        if (v is String) {
          try {
            return DateTime.parse(v);
          } catch (_) {}
        }
      }
      return null;
    }

    // Counters (unchanged)
    final Map<String, int> userQuestionCounts = {};
    final Map<String, int> guestQuestionCounts = {};
    final Map<int, int> userMonthlyCounts = {for (int i = 1; i <= 12; i++) i: 0};
    final Map<int, int> guestMonthlyCounts = {for (int i = 1; i <= 12; i++) i: 0};

    int totalUserMessagesFetched = 0;
    int totalUserWithTextAndTs = 0;
    int totalUserMatchedDept = 0;
    int totalUserAfterFoulFilter = 0;

    int totalGuestMessagesFetched = 0;
    int totalGuestWithTextAndTs = 0;
    int totalGuestMatchedDept = 0;
    int totalGuestAfterFoulFilter = 0;

    void _incrementQuestion(Map<String, int> map, String normalized) {
      final matchedKey = _findSimilarQuestion(normalized, map.keys.toList());
      if (matchedKey != null) {
        map[matchedKey] = map[matchedKey]! + 1;
      } else {
        map[normalized] = (map[normalized] ?? 0) + 1;
      }
    }

    // ---------- Users ----------
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      debugPrint('Total user docs: ${usersSnapshot.size}');

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final convosSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .get();

        for (var convo in convosSnapshot.docs) {
          final convoData = convo.data() as Map<String, dynamic>? ?? {};
          final convoDept = (convoData['department'] as String?)?.trim();

          // fetch messages and filter client-side for department
          final messagesSnapshot = await convo.reference
              .collection('messages')
              .where('role', isEqualTo: 'user') // only user-role messages
              .get();

          debugPrint("User ${userId} - convo ${convo.id} fetched ${messagesSnapshot.size} messages (role=user)");

          for (var msgDoc in messagesSnapshot.docs) {
            totalUserMessagesFetched++;
            final msgData = msgDoc.data() as Map<String, dynamic>;

            final text = _extractText(msgData);
            final timestamp = _extractTimestamp(msgData);

            if (text == null || text.isEmpty || timestamp == null) continue;
            totalUserWithTextAndTs++;

            String? messageDept = (msgData['department'] as String?)?.trim();
            if (messageDept == null || messageDept.isEmpty) messageDept = convoDept;
            if (messageDept == null || messageDept.isEmpty) continue;

            // UPDATED: Use exact normalized matching to prevent cross-department fetching
            final msgDeptNorm = _normDept(messageDept);
            final matchesDept = msgDeptNorm == firestoreDeptNorm;

            if (!matchesDept) continue;
            totalUserMatchedDept++;

            final normalized = _normalizeQuestion(text);
            final containsFoul = foulWords.any((w) => normalized.contains(w));
            if (containsFoul) continue;
            totalUserAfterFoulFilter++;

            _incrementQuestion(userQuestionCounts, normalized);
            userMonthlyCounts[timestamp.month] = (userMonthlyCounts[timestamp.month] ?? 0) + 1;
          }
        }
      }
    // ---------- Guests ----------
    final guestSnapshot = await FirebaseFirestore.instance.collection('guest_conversations').get();
    debugPrint('Total guest conversation docs: ${guestSnapshot.size}');

    for (var guestDoc in guestSnapshot.docs) {
      final guestData = guestDoc.data() as Map<String, dynamic>? ?? {};
      final guestConvoDept = (guestData['department'] as String?)?.trim();

      final messagesSnapshot = await guestDoc.reference
          .collection('messages')
          .where('role', isEqualTo: 'user') // only user-role messages from guest conversations
          .get();

      debugPrint("Guest convo ${guestDoc.id} fetched ${messagesSnapshot.size} messages (role=user)");

      for (var msgDoc in messagesSnapshot.docs) {
        totalGuestMessagesFetched++;
        final msgData = msgDoc.data() as Map<String, dynamic>;

        // IMPORTANT: use original_question for guest messages if available
        final text = _extractGuestText(msgData);
        final timestamp = _extractTimestamp(msgData);

        if (text == null || text.isEmpty || timestamp == null) continue;
        totalGuestWithTextAndTs++;

        String? messageDept = (msgData['department'] as String?)?.trim();
        if (messageDept == null || messageDept.isEmpty) messageDept = guestConvoDept;
        if (messageDept == null || messageDept.isEmpty) continue;

        // UPDATED: Use exact normalized matching to prevent cross-department fetching
        final msgDeptNorm = _normDept(messageDept);
        final matchesDept = msgDeptNorm == firestoreDeptNorm;

        if (!matchesDept) continue;
        totalGuestMatchedDept++;

        final normalized = _normalizeQuestion(text);
        final containsFoul = foulWords.any((w) => normalized.contains(w));
        if (containsFoul) continue;
        totalGuestAfterFoulFilter++;

        _incrementQuestion(guestQuestionCounts, normalized);
        guestMonthlyCounts[timestamp.month] = (guestMonthlyCounts[timestamp.month] ?? 0) + 1;
      }
    }

    // Diagnostics logs (unchanged)
    debugPrint('--- Diagnostics summary for dept: $firestoreDept ---');
    debugPrint('User messages fetched: $totalUserMessagesFetched');
    debugPrint('User messages with text+ts: $totalUserWithTextAndTs');
    debugPrint('User messages matched dept: $totalUserMatchedDept');
    debugPrint('User messages after foul-word filter: $totalUserAfterFoulFilter');
    debugPrint('Guest messages fetched: $totalGuestMessagesFetched');
    debugPrint('Guest messages with text+ts: $totalGuestWithTextAndTs');
    debugPrint('Guest messages matched dept: $totalGuestMatchedDept');
    debugPrint('Guest messages after foul-word filter: $totalGuestAfterFoulFilter');

    // Build combined monthly groups (unchanged)
    final List<BarChartGroupData> groups = [];
    for (int i = 1; i <= 12; i++) {
      final count = (userMonthlyCounts[i] ?? 0) + (guestMonthlyCounts[i] ?? 0);
      groups.add(
        BarChartGroupData(
          x: i, // 1-12
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              width: 18,
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

    // Top lists (unchanged)
    final userList = userQuestionCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final guestList = guestQuestionCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final combinedCounts = {...userQuestionCounts};
    guestQuestionCounts.forEach((k, v) => combinedCounts[k] = (combinedCounts[k] ?? 0) + v);
    final combinedList = combinedCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final topUser = userList.take(5).map((e) => {"question": e.key, "count": e.value}).toList();
    final topGuest = guestList.take(5).map((e) => {"question": e.key, "count": e.value}).toList();
    final topCombined = combinedList.take(5).map((e) => {"question": e.key, "count": e.value}).toList();

    // -------------------- Per-user chat counts --------------------
    try {
      debugPrint('🔍 Computing per-user and guest chat counts for dept: $firestoreDept');
      final Map<String, int> combinedChatCounts = {};

      // Users
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final userName = capitalizeEachWord((userData['name'] ?? userData['displayName'] ?? userId).toString());
        int userTotal = 0;

        final convos = await userDoc.reference.collection('conversations').get();
        for (var convoDoc in convos.docs) {
          // Fetch user messages then filter by department client-side
          final msgs = await convoDoc.reference
              .collection('messages')
              .where('role', isEqualTo: 'user')
              .get();

          for (var m in msgs.docs) {
            final md = m.data() as Map<String, dynamic>;
            
            // Extract and validate message text
            final rawText = (md['message'] ??
                    md['text'] ??
                    md['original_question'] ??
                    md['content'] ?? '')
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

            // UPDATED: Check department with exact normalized matching
            String? messageDept = (md['department'] as String?)?.trim();
            bool msgMatches = false;

            if (messageDept != null && messageDept.isNotEmpty) {
              final msgDeptNorm = _normDept(messageDept);
              msgMatches = msgDeptNorm == firestoreDeptNorm;
            } else {
              // Fallback to conversation-level department
              final convoData = convoDoc.data() as Map<String, dynamic>? ?? {};
              final convoDept = convoData['department'];
              if (convoDept is List) {
                msgMatches = (convoDept as List).any((d) => _normDept(d.toString().trim()) == firestoreDeptNorm);
              } else if (convoDept is String) {
                final convoDeptNorm = _normDept(convoDept);
                msgMatches = convoDeptNorm == firestoreDeptNorm;
              }
            }

            if (msgMatches) {
              userTotal += 1;
            }
          }
        }

        combinedChatCounts[userName] = userTotal;
      }

      // Guests
      for (var guestDoc in guestSnapshot.docs) {
        final guestData = guestDoc.data() as Map<String, dynamic>? ?? {};
        final guestName = 'Guest User';
        int guestTotal = 0;

        final msgs = await guestDoc.reference
            .collection('messages')
            .where('role', isEqualTo: 'user')
            .get();

        for (var m in msgs.docs) {
          final md = m.data() as Map<String, dynamic>;
          
          // Extract and validate message text (use _extractGuestText for guests)
          final rawText = _extractGuestText(md)?.trim() ?? '';
          
          if (rawText.isEmpty) continue;

          // Filter foul words
          final normalizedText = rawText.toLowerCase();
          final containsFoul = foulWords.any((w) {
            final wNorm = w.toLowerCase().trim();
            return wNorm.isNotEmpty && normalizedText.contains(wNorm);
          });
          
          if (containsFoul) continue;

          // UPDATED: Check department with exact normalized matching
          String? messageDept = (md['department'] as String?)?.trim();
          bool msgMatches = false;

          if (messageDept != null && messageDept.isNotEmpty) {
            final msgDeptNorm = _normDept(messageDept);
            msgMatches = msgDeptNorm == firestoreDeptNorm;
          } else {
            // Fallback to guest convo-level department
            final convoDept = guestData['department'];
            if (convoDept is List) {
              msgMatches = (convoDept as List).any((d) => _normDept(d.toString().trim()) == firestoreDeptNorm);
            } else if (convoDept is String) {
              final convoDeptNorm = _normDept(convoDept);
              msgMatches = convoDeptNorm == firestoreDeptNorm;
            }
          }

          if (msgMatches) {
            guestTotal += 1;
          }
        }

        // Aggregate guest counts
        combinedChatCounts[guestName] = (combinedChatCounts[guestName] ?? 0) + guestTotal;
      }

      final topUsersList = combinedChatCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topUsersMapList = topUsersList.take(5).map((e) => {"user": e.key, "count": e.value}).toList();

      setState(() {
        _userChatCounts = combinedChatCounts;
        _topUsersByCount = topUsersMapList;
      });

      debugPrint('✅ Per-user and guest chat counts computed. Top users/guests: ${_topUsersByCount}');
    } catch (e, st) {
      debugPrint('❌ Error computing per-user and guest chat counts: $e\n$st');
    }
    // -----------------------------------------------------------------------

    setState(() {
      barGroups = groups;
      totalQuestions = combinedCounts.values.fold(0, (a, b) => a + b);
      uniqueQuestions = combinedCounts.keys.length;
      _topQuestions = topCombined;
      _topUserQuestions = topUser;
      _topGuestQuestions = topGuest;

      _userWeeklyCounts = {
        for (var e in userMonthlyCounts.entries) e.key.toString(): e.value
      };
      _guestWeeklyCounts = {
        for (var e in guestMonthlyCounts.entries) e.key.toString(): e.value
      };

      _barChartLoaded = true;
    });

    debugPrint("✅ Chat statistics updated for department: $firestoreDept");
  } catch (e, stack) {
    debugPrint("❌ Error fetching chat statistics: $e");
    debugPrint(stack.toString());
    setState(() {
      _barChartLoaded = true;
    });
  }
}

  String _getWeekIdentifier(DateTime date) {
    final weekOfYear = int.parse(DateFormat('w').format(date));
    final year = date.year;
    return '$year-W${weekOfYear.toString().padLeft(2, '0')}';
  }

  String _normalizeQuestion(String text) {
    text = text.toLowerCase();
    text = text.replaceAll(RegExp(r'[^\w\s]'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  String? _findSimilarQuestion(String newQ, List<String> existing) {
    for (var oldQ in existing) {
      if (_areQuestionsSimilar(newQ, oldQ)) return oldQ;
    }
    return null;
  }

  bool _areQuestionsSimilar(String q1, String q2) {
    final words1 = q1.split(' ').toSet();
    final words2 = q2.split(' ').toSet();
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    if (union == 0) return false;
    final similarity = intersection / union;
    return similarity >= 0.6;
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      return Scaffold(
        backgroundColor: lightBackground,
        body: Center(child: Lottie.asset('assets/animations/Live chatbot.json', width: 180)),
      );
    }

    final isLargeScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: lightBackground,
      drawer: NavigationDrawer(applicationLogoUrl: _applicationLogoUrl, activePage: "Statistics"),
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
                "Statistics",
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _topQuestions.isEmpty
            ? _buildEmptyState()
            : isLargeScreen
                ? _buildLargeScreenLayout()
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatCardsSmallScreen(),
                        const SizedBox(height: 24),
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey, width: 0.5),
                          ),
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("User and Guest Question Trend",
                                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                SizedBox(height: 240, child: _buildCombinedTrendChart(_userWeeklyCounts, _guestWeeklyCounts)),
                              ],
                            ),
                          ),
                        ),
                        // Top 5 FAQs
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey, width: 0.5),
                          ),
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Top 5 Frequently Asked Questions",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: primarycolordark,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildTopQuestionsContent(),
                              ],
                            ),
                          ),
                        ),
                        // NEW: Top users card (shows users with most chats)
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey, width: 0.5),
                          ),
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Top Users by Chat Count",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: primarycolordark,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildTopUsersContent(),
                              ],
                            ),
                          ),
                        ),
                        // Pie Chart
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey, width: 0.5),
                          ),
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Top 5 Distribution",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: primarycolordark,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AspectRatio(
                                  aspectRatio: 1.3,
                                  child: _buildPieChart(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildTopUsersContent() {
    if (_topUsersByCount.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text("No user chat counts available", style: GoogleFonts.poppins(color: Colors.grey)),
      );
    }

    return Column(
      children: _topUsersByCount.asMap().entries.map((entry) {
        final i = entry.key;
        final u = entry.value;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: primarycolor,
              child: Text("${i + 1}",
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(u["user"] ?? '', style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500)),
            trailing: Text("${u["count"]} chats", style: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCombinedTrendChart(Map<String, int> userData, Map<String, int> guestData) {
    final allKeys = <String>{}..addAll(userData.keys)..addAll(guestData.keys);
    if (allKeys.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    final keys = allKeys.toList();
    final allNumeric = keys.every((k) => int.tryParse(k) != null);
    if (allNumeric) {
      keys.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    } else {
      keys.sort();
    }

    // Build spots using consistent indices
    final userSpots = <FlSpot>[];
    final guestSpots = <FlSpot>[];

    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      final ux = (userData[k] ?? 0).toDouble();
      final gx = (guestData[k] ?? 0).toDouble();

      userSpots.add(FlSpot(i.toDouble(), ux));
      guestSpots.add(FlSpot(i.toDouble(), gx));
    }

    const goldColor = Color(0xFFFFC803);
    const maroonColor = Color(0xFF550100);

    final maxUser = userSpots.isNotEmpty ? userSpots.map((e) => e.y).reduce(max) : 0.0;
    final maxGuest = guestSpots.isNotEmpty ? guestSpots.map((e) => e.y).reduce(max) : 0.0;

    final rawMax = max(maxUser, maxGuest);
    final adjustedMaxY = rawMax == 0 ? 1.0 : (rawMax + (rawMax * 0.3)).ceilToDouble();

    Widget bottomTitle(double value, TitleMeta meta) {
      final idx = value.round();
      if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
      final label = keys[idx];
      if (allNumeric) {
        final monthNum = int.tryParse(label) ?? 1;
        final monthName = DateFormat.MMM().format(DateTime(2020, monthNum));
        return Text(
          monthName,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        );
      }
      return Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: adjustedMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.15),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: bottomTitle,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  final interval = adjustedMaxY <= 10 ? 1.0 : 5.0;
                  if (value % interval != 0) return const SizedBox.shrink();
                  return Text(
                    '${value.toInt()} chats',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.25), width: 1),
              left: BorderSide(color: Colors.grey.withOpacity(0.25), width: 1),
              right: const BorderSide(color: Colors.transparent),
              top: const BorderSide(color: Colors.transparent),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: primarycolor,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                if (touchedSpots.isEmpty) return [];

                final userSpot = touchedSpots.firstWhere(
                  (e) => e.barIndex == 1,
                  orElse: () => touchedSpots.first,
                );
                final guestSpot = touchedSpots.firstWhere(
                  (e) => e.barIndex == 0,
                  orElse: () => touchedSpots.first,
                );

                final userValue = userSpot.y.toInt();
                final guestValue = guestSpot.y.toInt();

                return [
                  LineTooltipItem(
                    'User: $userValue\n',
                    GoogleFonts.poppins(
                      color: maroonColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  LineTooltipItem(
                    'Guest: $guestValue',
                    GoogleFonts.poppins(
                      color: maroonColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ];
              },
            ),
          ),
          lineBarsData: [
            // Guest Line (Gold)
            LineChartBarData(
              spots: guestSpots,
              isCurved: true,
              curveSmoothness: 0.4,
              gradient: const LinearGradient(
                colors: [goldColor, maroonColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [goldColor.withOpacity(0.3), maroonColor.withOpacity(0.05)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // User Line (Maroon)
            LineChartBarData(
              spots: userSpots,
              isCurved: true,
              curveSmoothness: 0.4,
              gradient: const LinearGradient(
                colors: [maroonColor, goldColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [maroonColor.withOpacity(0.3), goldColor.withOpacity(0.05)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardsSmallScreen() {
    final statCardWidth = double.infinity;
    return Column(
      children: [
        StatCard(
          title: "Total Questions",
          value: "$totalQuestions",
          subtitle: "Questions",
          icon: Icons.question_answer,
          backgroundColor: const Color(0xFFFFB300),
          width: statCardWidth,
        ),
        const SizedBox(height: 10),
        StatCard(
          title: "Unique Questions",
          value: "$uniqueQuestions",
          subtitle: "Unique",
          icon: Icons.lightbulb_outline,
          backgroundColor: const Color(0xFFCDDC39),
          width: statCardWidth,
        ),
        const SizedBox(height: 10),
        StatCard(
          title: "Peak Hour",
          value: peakHour,
          subtitle: "Peak",
          icon: Icons.access_time,
          backgroundColor: const Color(0xFFFFB300),
          width: statCardWidth,
        ),
      ],
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/web-search.png", width: 200),
            const SizedBox(height: 20),
            Text("No chat data available yet.", style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );

  Widget _buildLargeScreenLayout() {
    final statCardCount = 3;
    final statCardSpacing = 16.0;
    final totalSpacing = (statCardCount - 1) * statCardSpacing;
    final pageWidth = MediaQuery.of(context).size.width - 48;
    final statCardWidth = (pageWidth - totalSpacing) / statCardCount;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatCard(
                title: "Total Questions",
                value: "$totalQuestions",
                subtitle: "Questions",
                icon: Icons.question_answer,
                backgroundColor: const Color(0xFFFFB300),
                width: statCardWidth,
              ),
              SizedBox(width: statCardSpacing),
              StatCard(
                title: "Unique Questions",
                value: "$uniqueQuestions",
                subtitle: "Unique",
                icon: Icons.lightbulb_outline,
                backgroundColor: const Color(0xFFCDDC39),
                width: statCardWidth,
              ),
              SizedBox(width: statCardSpacing),
              StatCard(
                title: "Peak Hour",
                value: peakHour,
                subtitle: "Peak",
                icon: Icons.access_time,
                backgroundColor: const Color(0xFFFFB300),
                width: statCardWidth,
              ),
            ],
          ),

          const SizedBox(height: 24),

          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey, width: 0.5),
            ),
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("User and Guest Question Trend",
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(height: 240, child: _buildCombinedTrendChart(_userWeeklyCounts, _guestWeeklyCounts)),
                ],
              ),
            ),
          ),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                    elevation: 2,
                    margin: const EdgeInsets.only(right: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Top 5 Frequently Asked Questions",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: primarycolordark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildTopQuestionsContent(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  flex: 1,
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                    elevation: 2,
                    margin: const EdgeInsets.only(left: 0),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Top 5 Distribution",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: primarycolordark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Center(
                              child: SizedBox(
                                width: 350,
                                height: 300,
                                child: _buildPieChart(),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildTopQuestionsContent() {
    final List<Color> cardColors = [
      const Color(0xFFFFF3E0), // soft orange
      const Color(0xFFFFF8E1), // soft yellow
      const Color(0xFFE3F2FD), // light blue
      const Color(0xFFE8F5E9), // light green
      const Color(0xFFF3E5F5), // light purple
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _topQuestions.asMap().entries.map((entry) {
        final i = entry.key;
        final q = entry.value;
        final bgColor = cardColors[i % cardColors.length];

        return Card(
          color: bgColor,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: primarycolor.withOpacity(0.3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {},
              hoverColor: primarycolor.withOpacity(0.1),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primarycolor,
                      radius: 20,
                      child: Text(
                        "${i + 1}",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        q["question"] ?? '',
                        style: GoogleFonts.poppins(
                          color: dark,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "${q["count"]}x",
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
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieChart() {
    int touchedIndex = -1;
    Offset? touchPosition;
    Size? chartSize;

    return StatefulBuilder(
      builder: (context, setState) {
        final total = _topQuestions.fold<int>(0, (sum, item) => sum + ((item['count'] as num?)?.toInt() ?? 0));
        if (total == 0) {
          return const Center(child: Text("No data"));
        }

        final overlayMaxWidth = min(MediaQuery.of(context).size.width * 0.6, 520.0);

        final List<PieChartSectionData> sections = List.generate(_topQuestions.length, (i) {
          final q = _topQuestions[i];
          final qCount = (q['count'] as num?)?.toDouble() ?? 0.0;
          final percentageNum = (qCount / total) * 100;
          final percentageStr = percentageNum.toStringAsFixed(1);
          final isTouched = i == touchedIndex;
          final double radius = isTouched ? 90 : 70;

          return PieChartSectionData(
            value: qCount,
            title: "$percentageStr%",
            color: primarycolor.withOpacity(0.3 + ((qCount / total).clamp(0.0, 0.7))),
            radius: radius,
            titleStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: isTouched ? 13 : 14,
              color: isTouched ? primarycolordark : Colors.white,
            ),
            titlePositionPercentageOffset: 0.6,
          );
        });

        return LayoutBuilder(builder: (context, constraints) {
          chartSize = Size(constraints.maxWidth, constraints.maxHeight);

          final overlayWidth = min(chartSize!.width * 0.5, overlayMaxWidth);
          final estimatedOverlayHeight = 90.0;

          double computeLeft(double dx) {
            final half = chartSize!.width / 2;
            double left;
            if (dx <= half) {
              left = dx + 12;
              if (left + overlayWidth > chartSize!.width) left = chartSize!.width - overlayWidth - 6;
            } else {
              left = dx - overlayWidth - 12;
              if (left < 6) left = 6;
            }
            return left.clamp(6.0, chartSize!.width - overlayWidth - 6.0);
          }

          double computeTop(double dy) {
            final top = dy - estimatedOverlayHeight / 2;
            final maxTop = chartSize!.height - estimatedOverlayHeight - 6;
            return top.clamp(6.0, maxTop.isFinite ? maxTop : 6.0);
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        // Reset when there's no interaction or no section touched
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          setState(() {
                            touchedIndex = -1;
                            touchPosition = null;
                          });
                          return;
                        }

                        // Prefer event.localPosition (works for fl_chart FlTouchEvent)
                        Offset local = Offset(chartSize!.width / 2, chartSize!.height / 2);
                        try {
                          final maybePos = event.localPosition;
                          if (maybePos != null) local = maybePos;
                        } catch (_) {
                          local = Offset(chartSize!.width / 2, chartSize!.height / 2);
                        }

                        setState(() {
                          touchedIndex = response.touchedSection!.touchedSectionIndex;
                          touchPosition = local;
                        });
                      },
                    ),
                  ),
                ),
              ),

              if (touchedIndex != -1 && touchPosition != null && chartSize != null)
                Positioned(
                  left: computeLeft(touchPosition!.dx),
                  top: computeTop(touchPosition!.dy),
                  child: IgnorePointer(
                    ignoring: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: overlayWidth),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.withOpacity(0.12)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _topQuestions[touchedIndex]['question'] ?? '',
                              textAlign: TextAlign.left,
                              style: GoogleFonts.poppins(
                                color: dark,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Builder(builder: (_) {
                              final qCount = (_topQuestions[touchedIndex]['count'] as num?)?.toDouble() ?? 0.0;
                              final percentageNum = (qCount / total) * 100;
                              final percentageStr = percentageNum.toStringAsFixed(1);
                              return Text(
                                "${qCount.toInt()} • $percentageStr%",
                                style: GoogleFonts.poppins(
                                  color: primarycolordark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        });
      },
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
          _drawerItem(context, Icons.people_outline, "Statistics", () {
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
          }, isActive: activePage == "Feedbacks",),
          _drawerItem(context, Icons.receipt_long_outlined, "Chatbot Data", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotDataPage()),
            );
          }, isActive: activePage == "Chatbot Data",),
          _drawerItem(context, Icons.folder_open_outlined, "Chatbot Files", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotFilesPage()),
            );
          }, isActive: activePage == "Chatbot Files",),
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