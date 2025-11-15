import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatbot/admin/dashboard.dart';
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
const textdark = Color(0xFF343a40);
const lightBackground = Color(0xFFFEFEFE);

// foul words list unchanged
final List<String> foulWords = [
  'fuck', 'shit', 'asshole', 'bitch', 'mother fucker', 'damn',
  'bastard', 'jerk', 'dick', 'pussy', 'slut', 'whore',
  'moron', 'idiot', 'stupid',
  'putang ina', 'tangina', 'gago', 'ulol', 'tarantado', 'gaga',
  'bobo', 'tanga', 'tanginamo', 'lintik', 'hayop ka', 'bwisit',
  'sira ulo', 'walang hiya', 'tamad', 'peste', 'sira ulo mu', 'ulul ka', 'alang hiya',
  'buri mu', 'pota', 'yamu', 'atsaka mu', 'buri ku', 'e tamu manyira', 'loko ka'
];

// Improved capitalization that preserves short acronyms (MIS, OCA, COOP)
String capitalizeEachWord(String text) {
  if (text.trim().isEmpty) return '';
  final words = text.trim().split(RegExp(r'\s+'));
  return words.map((w) {
    // preserve acronyms (all uppercase and short)
    if (w.toUpperCase() == w && w.length <= 4) return w.toUpperCase();
    final lower = w.toLowerCase();
    return lower[0].toUpperCase() + (lower.length > 1 ? lower.substring(1) : '');
  }).join(' ');
}

// Normalize strings for fuzzy matching (remove non-alnum, lowercase)
String _normalize(String s) => s.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

// Map of display names -> Firestore short codes (kept for reference and mapping)
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

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> allChats = [];
  String _selectedFilter = 'All';

  String fullName = '';
  String? adminDepartment;
  List<Map<String, dynamic>> chatData = [];
  bool _adminInfoLoaded = false;
  bool _chatDataLoaded = false;

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  bool get _allDataLoaded => _adminInfoLoaded && _chatDataLoaded && _logoLoaded;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _loadAdminInfo(),
      _loadApplicationLogo(),
    ]);
    // After admin info & logo loaded, fetch chats (so we have adminDepartment)
    await _fetchChatData();
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

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('Admin').doc(user.uid).get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;

          final fetchedFirstName = (data['firstName'] ?? '').toString();
          final fetchedLastName = (data['lastName'] ?? '').toString();
          final fetchedDepartment = (data['department'] ?? 'No Department').toString();

          setState(() {
            fullName = capitalizeEachWord('$fetchedFirstName $fetchedLastName');
            // keep human-friendly department (used for doc ids), but we'll map to codes when matching
            adminDepartment = fetchedDepartment;
            _adminInfoLoaded = true;
          });
        } else {
          setState(() => _adminInfoLoaded = true);
        }
      } else {
        setState(() => _adminInfoLoaded = true);
      }
    } catch (e, st) {
      print('Error loading admin info: $e\n$st');
      setState(() => _adminInfoLoaded = true);
    }
  }

  // Map admin-facing label to a short code used in stored conversations/feedbacks
  String _mapAdminDeptToShort(String raw) {
    if (raw.trim().isEmpty) return raw;
    final norm = _normalize(raw);

    // Try normalized direct matches against keys in _departmentMap
    for (final entry in _departmentMap.entries) {
      if (_normalize(entry.key) == norm) return entry.value;
    }

    // keyword-based mapping (handles "Office of Admission", "Admission Office", typos etc.)
    if (norm.contains('admission') || norm.contains('admit')) return 'Admission';
    if (norm.contains('registr') || norm.contains('registar')) return 'Registrar';
    if (norm.contains('multipurpose') || norm.contains('cooperative') || norm.contains('coop')) return 'COOP';
    if (norm.contains('managementinformationsystems') || norm.contains('managementinformation') || norm.contains('mis')) return 'MIS';
    if (norm.contains('culture') || norm.contains('arts') || norm.contains('oca')) return 'OCA';
    if (norm.contains('studentaffairs') || norm.contains('osa')) return 'OSA';
    if (norm.contains('studentwelfare') || norm.contains('welfare') || norm.contains('formation') || norm.contains('oswf')) return 'OSWF';
    if (norm.contains('aboutpsu') || norm.contains('about') || norm.contains('psu')) return 'AboutPSU';
    if (norm.contains('accredited') || norm.contains('rso')) return 'RSO';
    if (norm.contains('administrative') || norm.contains('administration') || norm.contains('admin')) return 'Administrative';

    // fallback: return title-cased without extra spaces
    return capitalizeEachWord(raw).replaceAll(RegExp(r'\s+'), ' ');
  }

  // extractor helpers
  String? _extractMessageText(Map<String, dynamic> data) {
    final candidateKeys = ['text', 'message', 'original_question', 'content', 'body', 'question'];
    for (final k in candidateKeys) {
      if (data.containsKey(k) && data[k] != null) {
        final s = data[k].toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  DateTime? _extractTimestamp(Map<String, dynamic> data) {
    final timeKeys = ['timestamp', 'createdAt', 'created_at', 'time'];
    for (final k in timeKeys) {
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

  Future<void> _fetchChatData() async {
    try {
      // Ensure admin info loaded
      while (!_adminInfoLoaded) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (adminDepartment == null || adminDepartment!.trim().isEmpty) {
        print("⚠️ Admin department not set. Skipping department filtering.");
        setState(() => _chatDataLoaded = true);
        return;
      }

      final mappedShort = _mapAdminDeptToShort(adminDepartment!);
      final mappedNorm = _normalize(mappedShort);

      print("🔍 Fetching chats for admin department (short): $mappedShort (norm: $mappedNorm)");

      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      List<Map<String, dynamic>> loadedChats = [];

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final userName = capitalizeEachWord((userData['name'] ?? userData['displayName'] ?? userId).toString());

        // Get all conversations for this user
        final convosSnapshot = await userDoc.reference.collection('conversations').orderBy('lastTimestamp', descending: true).get();

        for (final convoDoc in convosSnapshot.docs) {
          final convoData = convoDoc.data() as Map<String, dynamic>? ?? {};

          // Fetch messages for this conversation (ordered ascending for display)
          final messagesSnapshot = await convoDoc.reference.collection('messages').orderBy('timestamp', descending: false).get();

          // Check if any message in this conversation has a matching department
          bool hasMatchingDept = false;
          for (final msgDoc in messagesSnapshot.docs) {
            final msgData = msgDoc.data() as Map<String, dynamic>;
            final dept = msgData['department'] ?? msgData['departments'];
            if (dept is String && dept.trim() == mappedShort) {
              hasMatchingDept = true;
              break;
            } else if (dept is List) {
              if ((dept as List).any((d) => d.toString().trim() == mappedShort)) {
                hasMatchingDept = true;
                break;
              }
            }
          }

          // Skip if no message matches the department
          if (!hasMatchingDept) continue;

          // Now process the messages for display
          final messages = <Map<String, dynamic>>[];
          Timestamp? lastMessageTs;

          for (final msgDoc in messagesSnapshot.docs) {
            final msgData = msgDoc.data() as Map<String, dynamic>;
            final text = _extractMessageText(msgData) ?? '';
            final ts = msgData['timestamp'];
            Timestamp? tsObj;
            if (ts is Timestamp) tsObj = ts;
            else if (ts is int) {
              try {
                tsObj = Timestamp.fromMillisecondsSinceEpoch(ts);
              } catch (_) {}
            } else if (ts is String) {
              final parsed = DateTime.tryParse(ts);
              if (parsed != null) tsObj = Timestamp.fromDate(parsed);
            }

            // Ignore empty messages or foul messages
            if (text.trim().isEmpty) continue;
            final textLower = text.toLowerCase();
            final containsFoul = foulWords.any((w) => w.isNotEmpty && textLower.contains(w.toLowerCase()));
            if (containsFoul) continue;

            if (tsObj != null) lastMessageTs = tsObj;

            messages.add({
              'role': (msgData['role'] ?? '').toString(),
              'text': text,
              'timestamp': tsObj,
              // Include raw department fields for debugging if needed
              'departments': msgData['departments'] ?? msgData['department'],
            });
          }

          if (messages.isEmpty) continue;

          // lastTimestamp prefer convoData['lastTimestamp'] else last message ts
          Timestamp? lastTimestamp;
          final convoLast = convoData['lastTimestamp'];
          if (convoLast is Timestamp) lastTimestamp = convoLast;
          else if (convoLast is int) {
            try {
              lastTimestamp = Timestamp.fromMillisecondsSinceEpoch(convoLast);
            } catch (_) {}
          } else if (convoLast is String) {
            final parsed = DateTime.tryParse(convoLast);
            if (parsed != null) lastTimestamp = Timestamp.fromDate(parsed);
          } else {
            lastTimestamp = lastMessageTs;
          }

          if (lastTimestamp == null) continue;

          final titleText = convoData['title'] ?? messages.last['text'] ?? '';

          loadedChats.add({
            'user': userName,
            'title': titleText.toString(),
            'timestamp': _formatTimestamp(lastTimestamp.toDate()),
            'rawTimestamp': lastTimestamp,
            'messages': messages,
            'departments': [], // Not used anymore, but kept for compatibility
            'convoId': convoDoc.id,
            'userId': userId,
          });
        } // end convos loop
      } // end users loop

      // Sort by rawTimestamp desc
      loadedChats.sort((a, b) {
        final aTs = a['rawTimestamp'] as Timestamp;
        final bTs = b['rawTimestamp'] as Timestamp;
        return bTs.compareTo(aTs);
      });

      setState(() {
        allChats = loadedChats;
        chatData = loadedChats;
        _chatDataLoaded = true;
      });

      print("✅ Loaded ${loadedChats.length} chats for department: $mappedShort");
    } catch (e, st) {
      print("❌ Error fetching chat data: $e\n$st");
      setState(() => _chatDataLoaded = true);
    }
  }
  
  void _applySearchFilter(String keyword) {
    if (keyword.trim().isEmpty) {
      setState(() => chatData = allChats);
      return;
    }

    final filtered = allChats.where((chat) {
      final name = chat['user'].toString().toLowerCase();
      final title = chat['title'].toString().toLowerCase();
      final kw = keyword.toLowerCase();
      return name.contains(kw) || title.contains(kw);
    }).toList();

    setState(() {
      chatData = filtered;
    });
  }

  void _applyFilter(String selected) {
    DateTime now = DateTime.now();
    List<Map<String, dynamic>> filtered = [];

    if (selected == 'All') {
      filtered = allChats;
    } else if (selected == 'Today') {
      filtered = allChats.where((chat) {
        final ts = (chat['rawTimestamp'] as Timestamp).toDate();
        return ts.year == now.year && ts.month == now.month && ts.day == now.day;
      }).toList();
    } else if (selected == 'This Week') {
      DateTime weekAgo = now.subtract(const Duration(days: 7));
      filtered = allChats.where((chat) {
        final ts = (chat['rawTimestamp'] as Timestamp).toDate();
        return ts.isAfter(weekAgo);
      }).toList();
    } else if (selected == 'This Month') {
      filtered = allChats.where((chat) {
        final ts = (chat['rawTimestamp'] as Timestamp).toDate();
        return ts.year == now.year && ts.month == now.month;
      }).toList();
    }

    setState(() {
      _selectedFilter = selected;
      chatData = filtered;
    });
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';

    return '${time.month}/${time.day}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_allDataLoaded) {
      return Scaffold(
        backgroundColor: lightBackground,
        body: Center(
          child: Lottie.asset('assets/animations/Live chatbot.json', width: 200, height: 200),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightBackground,
      drawer: NavigationDrawer(applicationLogoUrl: _applicationLogoUrl, activePage: "Chat Logs"),
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
                "Chat Logs",
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfilePage()));
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                int columns = constraints.maxWidth > 800 ? 2 : 1;
                double spacing = 12;
                double totalSpacing = (columns - 1) * spacing;
                double cardWidth = (constraints.maxWidth - totalSpacing) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    StatCard(
                      title: "Total Chats",
                      value: "${chatData.length}",
                      color: primarycolordark,
                      width: cardWidth,
                    ),
                    StatCard(
                      title: "Today Chats",
                      value: "${chatData.where((c) {
                        final ts = c['rawTimestamp'] as Timestamp;
                        final dt = ts.toDate();
                        final now = DateTime.now();
                        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
                      }).length}",
                      color: primarycolor,
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
                  child: SearchBar(controller: _searchController, onChanged: _applySearchFilter),
                ),
                const SizedBox(width: 12),
                FilterDropdown(selectedFilter: _selectedFilter, onChanged: (value) {
                  if (value != null) _applyFilter(value);
                }),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: chatData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/web-search.png', width: 240, height: 240, fit: BoxFit.contain),
                          const SizedBox(height: 24),
                          Text("No chats to show.", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: chatData.length,
                      itemBuilder: (context, index) {
                        final chat = chatData[index];
                        return Card(
                          color: Colors.white,
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: secondarycolor,
                              child: Text(
                                chat['user'].toString().isNotEmpty ? chat['user'].toString()[0].toUpperCase() : 'U',
                                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              chat['user'],
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: primarycolordark),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                chat['title'],
                                style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(chat['timestamp'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                const Icon(Icons.chevron_right, color: primarycolor),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatHistoryPage(user: chat['user'], messages: List<Map<String, dynamic>>.from(chat['messages']))));
                            },
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

class ChatHistoryPage extends StatelessWidget {
  final String user;
  final List<Map<String, dynamic>> messages;

  const ChatHistoryPage({super.key, required this.user, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        title: Text(user, style: GoogleFonts.poppins(color: primarycolordark, fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: primarycolordark),
        elevation: 1,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final role = (message['role'] ?? '').toString();
          final isUser = role.toLowerCase() == 'user';

          final timestamp = message['timestamp'];
          final displayTime = timestamp is Timestamp ? _formatTimestamp(timestamp.toDate()) : timestamp?.toString() ?? '';

          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isUser ? primarycolordark.withOpacity(0.95) : primarycolor.withOpacity(0.9),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isUser ? 12 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 12),
                    ),
                  ),
                  child: Text(message['text'] ?? '', style: GoogleFonts.poppins(fontSize: 15, color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(displayTime, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}';
  }
}

/* UI components reused from original file (unchanged) */

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final Color color;
  final double width;

  const StatCard({super.key, required this.title, required this.value, required this.color, required this.width});

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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(isHovered ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.color.withOpacity(isHovered ? 0.54 : 0.31), width: 1.5),
          boxShadow: isHovered ? [BoxShadow(color: widget.color.withOpacity(0.13), blurRadius: 14, offset: const Offset(0, 6))] : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: widget.color)),
          const SizedBox(height: 4),
          Text(widget.title, style: GoogleFonts.poppins(fontSize: 14, color: widget.color.withOpacity(0.9))),
        ]),
      ),
    );
  }
}

class AnimatedHoverCard extends StatefulWidget {
  final Widget child;
  const AnimatedHoverCard({super.key, required this.child});

  @override
  State<AnimatedHoverCard> createState() => _AnimatedHoverCardState();
}

class _AnimatedHoverCardState extends State<AnimatedHoverCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedScale(scale: isHovered ? 1.015 : 1.0, duration: const Duration(milliseconds: 120), child: widget.child),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const SearchBar({super.key, required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.poppins(color: dark),
      decoration: InputDecoration(
        hintText: 'Search user...',
        hintStyle: GoogleFonts.poppins(color: dark),
        prefixIcon: const Icon(Icons.search, color: primarycolor),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primarycolordark, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: dark)),
      ),
    );
  }
}

class FilterDropdown extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({super.key, required this.selectedFilter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const List<String> filters = ['All', 'Today', 'This Week', 'This Month'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: dark, width: 1.2), borderRadius: BorderRadius.circular(14)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFilter,
          onChanged: onChanged,
          dropdownColor: lightBackground,
          style: GoogleFonts.poppins(color: dark),
          icon: const Icon(Icons.filter_list, color: primarycolordark),
          items: filters.map((filter) {
            return DropdownMenuItem<String>(
              value: filter,
              child: MouseRegion(cursor: SystemMouseCursors.click, child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text(filter, style: GoogleFonts.poppins(color: dark)))),
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
  const NavigationDrawer({super.key, this.applicationLogoUrl, required this.activePage});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: lightBackground),
          child: Center(
            child: applicationLogoUrl != null && applicationLogoUrl!.isNotEmpty
                ? Image.network(applicationLogoUrl!, height: double.infinity, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/dhvbot.png', height: double.infinity, fit: BoxFit.contain))
                : Image.asset('assets/images/dhvbot.png', height: double.infinity, fit: BoxFit.contain),
          ),
        ),
        _drawerItem(context, Icons.dashboard_outlined, "Dashboard", () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage()));
        }, isActive: activePage == "Dashboard"),
        _drawerItem(context, Icons.analytics_outlined, "Statistics", () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotStatisticsPage()));
        }, isActive: activePage == "Statistics"),
        _drawerItem(context, Icons.chat_outlined, "Chat Logs", () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsPage()));
        }, isActive: activePage == "Chat Logs"),
        _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbacksPage()));
        }, isActive: activePage == "Feedbacks"),
        _drawerItem(context, Icons.receipt_long_outlined, "Chatbot Data", () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotDataPage()));
        }, isActive: activePage == "Chatbot Data"),
        _drawerItem(context, Icons.folder_open_outlined, "Chatbot Files", () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotFilesPage()));
        }, isActive: activePage == "Chatbot Files"),
        const Spacer(),
        _drawerItem(context, Icons.logout, "Logout", () async {
          try {
            await FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AdminLoginPage()), (route) => false);
          } catch (e) {
            print("Logout error: $e");
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Logout failed. Please try again.", style: GoogleFonts.poppins())));
          }
        }, isLogout: true, isActive: false),
      ]),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isLogout = false, required bool isActive}) {
    return _DrawerHoverButton(icon: icon, title: title, onTap: onTap, isLogout: isLogout, isActive: isActive);
  }
}

class _DrawerHoverButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLogout;
  final bool isActive;

  const _DrawerHoverButton({Key? key, required this.icon, required this.title, required this.onTap, this.isLogout = false, this.isActive = false}) : super(key: key);

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
          color: widget.isActive ? primarycolor.withOpacity(0.25) : (isHovered ? primarycolor.withOpacity(0.10) : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Icon(widget.icon, color: (widget.isLogout ? Colors.red : primarycolordark)),
          title: Text(widget.title, style: GoogleFonts.poppins(color: (widget.isLogout ? Colors.red : primarycolordark), fontWeight: FontWeight.w600)),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}