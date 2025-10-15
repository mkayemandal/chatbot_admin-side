import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/feedbacks.dart';
import 'package:chatbot/admin/chatbotdata.dart';
import 'package:chatbot/admin/profile.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/admin/chatbotfiles.dart';
import 'package:chatbot/admin/usersinfo.dart';

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: AssetImage(widget.imageUrl),
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    widget.role,
                    style: const TextStyle(
                      fontSize: 12,
                      color: dark,
                      fontFamily: 'Poppins',
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

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isLoading = true;
  bool _recentChatsLoaded = false;
  bool _feedbacksLoaded = false;
  bool _barChartLoaded = false;

  Map<String, dynamic>? _dashboardStats;
  String firstName = "";
  String lastName = "";

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  // Data for child widgets (so they're not fetched separately)
  List<Map<String, dynamic>> recentChatLogs = [];
  List<Map<String, dynamic>> latestFeedbacks = [];
  List<BarChartGroupData> barGroups = [];

  bool get _allDataLoaded =>
      !_isLoading &&
      _recentChatsLoaded &&
      _feedbacksLoaded &&
      _barChartLoaded &&
      _logoLoaded;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
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

    final usersSnapshot = await firestore.collection('users').get();
    int registeredUsersCount = usersSnapshot.docs.length;

    final csvSnapshot = await firestore.collection('CsvData').get();
    int registeredInfoCount = 0;
    for (var doc in csvSnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('data') && data['data'] is List) {
        registeredInfoCount += (data['data'] as List).length;
      }
    }

    final feedbackSnapshot = await firestore.collection('Feedbacks').get();
    int totalFeedbackCount = feedbackSnapshot.docs.length;
    int positiveFeedbackCount = feedbackSnapshot.docs.where((doc) {
      final sentiment = doc.data()['sentiment']?.toString().toLowerCase();
      return sentiment == 'positive';
    }).length;

    double satisfactionScore = totalFeedbackCount == 0
        ? 0.0
        : (positiveFeedbackCount / totalFeedbackCount) * 5;

    return {
      'registeredUsers': registeredUsersCount,
      'registeredInfo': registeredInfoCount,
      'totalFeedback': totalFeedbackCount,
      'userSatisfaction': '${satisfactionScore.toStringAsFixed(1)}/5',
    };
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
          setState(() {
            firstName = capitalizeEachWord(doc['firstName'] ?? '');
            lastName = capitalizeEachWord(doc['lastName'] ?? '');
          });
        }
      }
    } catch (e) {
      print('Error loading admin info: $e');
    }
  }

  Future<void> _fetchRecentChats() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

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

  Future<void> _fetchLatestFeedbacks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Feedbacks')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      setState(() {
        latestFeedbacks = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'user': capitalizeEachWord(data['name'] ?? 'Unknown'),
            'message': data['message'] ?? '',
            'sentiment': data['sentiment'] ?? 'positive',
          };
        }).toList();
        _feedbacksLoaded = true;
      });
    } catch (e) {
      print("Error fetching feedbacks: $e");
      setState(() {
        _feedbacksLoaded = true;
      });
    }
  }

  Future<void> _fetchMonthlyChatCounts() async {
    try {
      final Map<int, int> monthlyCounts = {for (int i = 1; i <= 12; i++) i: 0};

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final convosSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .get();

        for (var convoDoc in convosSnapshot.docs) {
          final data = convoDoc.data();
          final timestamp = data['lastTimestamp'];
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            final month = date.month;
            monthlyCounts[month] = (monthlyCounts[month] ?? 0) + 1;
          }
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
    } catch (e) {
      print("Error fetching monthly chat logs: $e");
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
            // 'assets/animations/Loading Dots Blue.json',
            // 'assets/animations/Loading Lottie animation.json',
            // 'assets/animations/Loading Spinner (Dots).json',
            width: 200,
            height: 200,
          ),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Poppins',
          bodyColor: dark,
          displayColor: dark,
        ),
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
            children: const [
              SizedBox(width: 12),
              Text(
                "Dashboard",
                style: TextStyle(
                  color: primarycolordark,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
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
                role: "Admin",
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
                              ? 4
                              : constraints.maxWidth > 600
                                  ? 2
                                  : 1;

                          double spacing = 12;
                          double totalSpacing = (columns - 1) * spacing;
                          double cardWidth = (constraints.maxWidth - totalSpacing) / columns;

                          if (_dashboardStats == null) {
                            return const Center(child: Text('No data available'));
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
                                title: 'Total Feedback',
                                value: '${_dashboardStats!['totalFeedback']}',
                                subtitle: 'Feedback',
                                icon: Icons.message,
                                backgroundColor: const Color(0xFFFFB300),
                                width: cardWidth,
                              ),
                              StatCard(
                                title: 'User Satisfaction',
                                value: '${_dashboardStats!['userSatisfaction']}',
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
                            // Large screen: Fixed height, no scroll, show only top 5 items
                            return SizedBox(
                              height: 435,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: RecentChatLogsCard(
                                      logs: recentChatLogs.take(5).toList(), // ensure max 5
                                      fixedHeight: 450, // You can add this param to style inner padding if needed
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primarycolordark,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Welcome to your Admin dashboard',
                style: TextStyle(
                  color: primarycolordark,
                  fontFamily: 'Poppins',
                ),
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
        side: BorderSide(
          color: Colors.grey,
          width: 0.5,
        ),
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
                const Text(
                  "Recent Chat Logs",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: primarycolordark,
                    fontFamily: 'Poppins',
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
                        style: TextStyle(fontSize: 18),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                                color: dark,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              log['message'] ?? '',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
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
                const Text(
                  "User Feedbacks",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: primarycolordark,
                    fontFamily: 'Poppins',
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
                  ? const Center(
                      child: Text(
                        "No recent feedbacks found.",
                        style: TextStyle(fontSize: 18),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
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
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
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
            style: const TextStyle(
              color: dark,
              fontFamily: 'Poppins',
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
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
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: primarycolor, 
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      fontFamily: 'Poppins',
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
      title: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}

class UserChatsBarChart extends StatelessWidget {
  final List<BarChartGroupData> barGroups;
  const UserChatsBarChart({super.key, required this.barGroups});

  @override
  Widget build(BuildContext context) {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "User Chats Over Time",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Poppins',
                color: primarycolordark,
              ),
            ),
            const SizedBox(height: 16),
            barGroups.isEmpty
                ? const Center(child: Text("No chat data found."))
                : SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        maxY: barGroups.map((e) => e.barRods.first.toY).reduce((a, b) => a > b ? a : b) + 20,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: primarycolor,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.toInt()} chats',
                                const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: barGroups,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 8,
                                  child: Text(
                                    '${value.toInt()} chats',
                                    style: const TextStyle(
                                      color: dark,
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                              interval: 50,
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
                                return Text(
                                  months[value.toInt()],
                                  style: const TextStyle(
                                    color: dark,
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              style: TextStyle(
                color: widget.isLogout ? Colors.red : primarycolordark,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
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
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
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
          _drawerItem(context, Icons.people_outline, "Users Info", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserinfoPage()),
            );
          },
          isActive: activePage == "Users Info",),
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
          _drawerItem(context, Icons.logout, "Logout", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            );
          },
          isLogout: true,
          isActive: false
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
            style: TextStyle(
              color: (widget.isLogout ? Colors.red : primarycolordark), 
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}