import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/chatbotdata.dart';
import 'package:chatbot/admin/profile.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/admin/chatbotfiles.dart';
import 'package:chatbot/admin/usersinfo.dart';

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

  bool _adminInfoLoaded = false;
  bool _feedbacksLoaded = false;

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

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
            .collection('Admin')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final firstName = data?['firstName'] ?? '';
          final lastName = data?['lastName'] ?? '';
          setState(() {
            fullName = capitalizeEachWord('$firstName $lastName');
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
      final snapshot = await FirebaseFirestore.instance
          .collection('Feedbacks')
          .orderBy('timestamp', descending: false)
          .get();

      final List<Map<String, dynamic>> loadedFeedbacks = snapshot.docs.map((
        doc,
      ) {
        final data = doc.data();
        return {
          'docId': doc.id,
          'feedback': data['message'] ?? '',
          'sentiment': data['sentiment'] ?? 'neutral',
          'user': capitalizeEachWord(data['name'] ?? 'Unknown'),
          'email': data['email'] ?? '',
          'timestamp': data['timestamp'] != null
              ? DateFormat(
                  'MM-dd-yyyy h:mm a',
                ).format((data['timestamp'] as Timestamp).toDate())
              : '',
          'status': data['status'] ?? 'new',
          'botResponse': data['botResponse'] ?? '',
        };
      }).toList();

      setState(() {
        feedbackList = loadedFeedbacks;
        _feedbacksLoaded = true;
      });
    } catch (e) {
      print('Error loading feedbacks: $e');
      setState(() => _feedbacksLoaded = true);
    }
  }

  List<Map<String, dynamic>> _getFeedbacksByStatus(String status) {
  final query = _searchController.text.toLowerCase();
  final filter = _selectedFilter.toLowerCase();

  return feedbackList.where((item) {
    final matchesStatus = item['status'] == status;
    final matchesQuery = item['feedback'].toLowerCase().contains(query) ||
                         item['user'].toLowerCase().contains(query); // <-- changed
    final matchesFilter = filter == 'all' || item['sentiment'].toLowerCase() == filter;
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
      final snapshot = await FirebaseFirestore.instance
          .collection('Feedbacks')
          .where('message', isEqualTo: item['feedback'])
          .where('email', isEqualTo: item['email'])
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({'status': newStatus});
        await Future.delayed(const Duration(milliseconds: 200));
        await refresh();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage, style: GoogleFonts.poppins(color: Colors.white)),
            duration: const Duration(seconds: 2),
            backgroundColor: primarycolor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      print('Error updating feedback status: $e');
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
            const Text(
              "No item to show.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Poppins',
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

    return Scaffold(
      drawer: NavigationDrawer(
        applicationLogoUrl: _applicationLogoUrl,
        activePage: "Feedbacks",
      ),
      appBar: AppBar(
        backgroundColor: lightBackground,
        iconTheme: const IconThemeData(color: primarycolordark),
        elevation: 0,
        titleSpacing: 0,
        title: const Row(
          children: [
            SizedBox(width: 12),
            Text("Feedbacks", style: TextStyle(color: primarycolordark, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
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
              labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14),
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

  // Helper to check guest
  bool isGuestFeedback(Map<String, dynamic> feedback) {
    final email = feedback['email'] ?? '';
    return email.startsWith('guest_') || email.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = feedback['sentiment'] == 'positive';
    final sentimentLabel = isPositive ? "Positive" : "Negative";
    final sentimentColor = isPositive ? Colors.green : Colors.red;
    final isGuest = isGuestFeedback(feedback);

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
            // User Info & Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback['user'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: dark,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isGuest
                          ? "Guest ID: ${feedback['docId'] ?? 'n/a'}"
                          : "Email: ${feedback['email'] ?? 'n/a'}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: dark,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  feedback['timestamp'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: dark,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bot Response
            if ((feedback['botResponse'] ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${feedback['botResponse']}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    color: dark,
                  ),
                ),
              ),

            // Feedback + Sentiment
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
                    style: TextStyle(
                      fontSize: 12,
                      color: sentimentColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    feedback['feedback'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: dark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Buttons
            if (currentStatus == 'new') ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = isGuest
                    ? (constraints.maxWidth - 8) / 2
                    : (constraints.maxWidth - 16) / 3;

                  return Row(
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          onPressed: onMarkReviewed,
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: const Text("Mark as Reviewed"),
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
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isGuest) ...[
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final email = feedback['email'];
                              final name = feedback['user'];
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;

                              try {
                                // Fetch the userId from 'users' collection based on email
                                final userSnapshot = await FirebaseFirestore
                                    .instance
                                    .collection('users')
                                    .where('email', isEqualTo: email)
                                    .limit(1)
                                    .get();

                                if (userSnapshot.docs.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("User not found."),
                                    ),
                                  );
                                  return;
                                }

                                final userId = userSnapshot.docs.first.id;

                                if (isPositive) {
                                  // Send thank-you notification
                                  await FirebaseFirestore.instance
                                      .collection('Notifications')
                                      .add({
                                        'userId': userId,
                                        'email': email,
                                        'title': 'Thank You',
                                        'message':
                                            "Thank you $name for your kind words. We're glad you're satisfied!",
                                        'timestamp': FieldValue.serverTimestamp(),
                                        'status': 'unread',
                                        'sentBy': currentUser?.email ?? 'admin',
                                      });

                                  // Update feedback status
                                  await FirebaseFirestore.instance
                                      .collection('Feedbacks')
                                      .where(
                                        'message',
                                        isEqualTo: feedback['feedback'],
                                      )
                                      .where('email', isEqualTo: email)
                                      .limit(1)
                                      .get()
                                      .then((snapshot) {
                                        if (snapshot.docs.isNotEmpty) {
                                          snapshot.docs.first.reference.update({
                                            'status': 'reviewed',
                                          });
                                        }
                                      });

                                  await onRefresh();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Thank you message sent!",
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
                                } else {
                                  // Respond directly (dialog)
                                  final String userName =
                                      feedback['user'] ?? 'User';
                                  final TextEditingController
                                  _responseController = TextEditingController();

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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              controller: _responseController,
                                              maxLines: 5,
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Type your response here...',
                                                hintStyle: GoogleFonts.poppins(
                                                  color: dark,
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFFCCCCCC),
                                                  ),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.all(12),
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
                                            style: GoogleFonts.poppins(
                                              color: dark,
                                            ),
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
                                              borderRadius: BorderRadius.circular(
                                                8,
                                              ),
                                            ),
                                          ),
                                          onPressed: () async {
                                            final responseText =
                                                _responseController.text.trim();

                                            if (responseText.isNotEmpty) {
                                              Navigator.pop(context);

                                              try {
                                                final currentUser = FirebaseAuth
                                                    .instance
                                                    .currentUser;
                                                final email = feedback['email'];

                                                final userSnapshot =
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .where(
                                                          'email',
                                                          isEqualTo: email,
                                                        )
                                                        .limit(1)
                                                        .get();

                                                if (userSnapshot.docs.isEmpty) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        "User not found.",
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                final userId =
                                                    userSnapshot.docs.first.id;

                                                final fullMessage =
                                                    "$responseText\n\nIf you have further concerns, feel free to contact us at support@dhvsu.edu.ph or call (045) 123-4567.";

                                                await FirebaseFirestore.instance
                                                    .collection('Notifications')
                                                    .add({
                                                      'userId': userId,
                                                      'email': email,
                                                      'title':
                                                          'Feedback Response',
                                                      'message': fullMessage,
                                                      'timestamp':
                                                          FieldValue.serverTimestamp(),
                                                      'status': 'unread',
                                                      'sentBy':
                                                          currentUser?.email ??
                                                          'super admin',
                                                    });

                                                await FirebaseFirestore.instance
                                                    .collection('Feedbacks')
                                                    .where(
                                                      'message',
                                                      isEqualTo:
                                                          feedback['feedback'],
                                                    )
                                                    .where(
                                                      'email',
                                                      isEqualTo: email,
                                                    )
                                                    .limit(1)
                                                    .get()
                                                    .then((snapshot) {
                                                      if (snapshot
                                                          .docs
                                                          .isNotEmpty) {
                                                        snapshot
                                                            .docs
                                                            .first
                                                            .reference
                                                            .update({
                                                              'status':
                                                                  'reviewed',
                                                            });
                                                      }
                                                    });

                                                await onRefresh();

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Response sent and saved!",
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                    backgroundColor: primarycolor,
                                                    behavior:
                                                        SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                print(
                                                  'Error sending response: $e',
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Failed to send response",
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                    backgroundColor: Colors.red,
                                                    behavior:
                                                        SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
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
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                      ),
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
                              textStyle: const TextStyle(fontSize: 12),
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
                          label: const Text("Archive"),
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
                            textStyle: const TextStyle(fontSize: 12),
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
                    label: const Text("Unarchive"),
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
                      textStyle: const TextStyle(fontSize: 12),
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: widget.color,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 14,
                color: widget.color.withOpacity(0.9),
                fontFamily: 'Poppins',
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
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: dark,
      ),
      decoration: InputDecoration(
        hintText: 'Search user...',
        hintStyle: const TextStyle(color: dark),
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
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: dark,
          ),
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
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: dark,
                    ),
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