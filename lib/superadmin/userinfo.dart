import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
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
          child: Row(
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

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  List<Map<String, dynamic>> users = [];
  late AnimationController _controller;

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
          style: const TextStyle(
            fontFamily: 'Poppins',
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

  void _recoverAccount(Map user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user['email'])
          .limit(1)
          .get();

      if (userDoc.docs.isNotEmpty) {
        await userDoc.docs.first.reference.update({'blocked': false});

        await FirebaseFirestore.instance.collection('Notifications').add({
          'email': user['email'],
          'message':
              'Your account has been recovered and access has been restored.',
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
        title: const Text(
          'Block User?',
          style: TextStyle(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        content: Text(
          'Are you sure you want to block ${user['name']}? This will restrict their access due to violations.',
          style: const TextStyle(color: dark, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: primarycolordark,
              textStyle: const TextStyle(fontFamily: 'Poppins'),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser(user);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            child: const Text('Confirm Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(Map<String, dynamic> user) async {
    try {
      final userEmail = user['email'];
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docId = snapshot.docs.first.id;
        await FirebaseFirestore.instance.collection('users').doc(docId).update({
          'blocked': true,
        });

        await FirebaseFirestore.instance.collection('Notifications').add({
          'email': userEmail,
          'message': 'Your account has been blocked due to violations.',
          'status': 'unread',
          'title': 'Notice',
          'timestamp': Timestamp.now(),
        });

        await _loadUserDataList();

        if (mounted) {
          showCustomSnackBar(context, 'User has been blocked.');
        }
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

  void _showRecoverConfirmation(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Recover User Account?',
          style: TextStyle(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        content: Text(
          'Are you sure you want to recover the account for ${user['name']}? Access will be restored.',
          style: const TextStyle(color: dark, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: primarycolordark,
              textStyle: const TextStyle(fontFamily: 'Poppins'),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _recoverAccount(user);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            child: const Text('Confirm Recover'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWarningNotification(Map<String, dynamic> user) async {
    try {
      final userEmail = user['email'];
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docId = snapshot.docs.first.id;

        await FirebaseFirestore.instance.collection('Notifications').add({
          'userId': docId,
          'email': userEmail,
          'title': 'Warning',
          'message': 'You will be blocked if you continue using foul language.',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'unread',
          'sentBy': FirebaseAuth.instance.currentUser?.email ?? 'Super Admin',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Warning notification sent.",
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: primarycolor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        showCustomSnackBar(context, 'User not found in database.');
      }
    } catch (e) {
      print('Error sending warning notification: $e');
      showCustomSnackBar(context, 'Failed to send warning notification.');
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
            // The following line fetches and updates the profilePictureUrl if it exists
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

          return {
            'name': capitalizeEachWord(data['name'] ?? ''),
            'email': data['email'] ?? '',
            'username': data['username'] ?? '',
            'position': data['studentType'] ?? 'Prospective',
            'date': formattedDate,
            'foulWords': data['strikes'] ?? 0,
            'blocked': data['blocked'] ?? false,
            'phoneNumber': data['phoneNumber'] ?? null,
          };
        }).toList(),
      );

      setState(() {
        users = fetchedUsers;
        _userDataLoaded = true;
      });
    } catch (e) {
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: dark,
            ),
          ),
          Flexible(
            child: Text(
              value?.toString() ?? 'N/A',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', color: textdark),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  color: dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                c['email'] ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  color: textdark,
                  fontFamily: 'Poppins',
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

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
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
          title: const Row(
            children: [
              SizedBox(width: 12),
              Text(
                "Users Info",
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
                        title: "Total User",
                        value: totalusersCount.toString(),
                        color: primarycolordark,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Registered Users",
                        value: users.length.toString(),
                        color: primarycolor,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Guest Users",
                        value: guestUsers.length.toString(),
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
                        children: const [
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: EdgeInsets.only(left: 40),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Joined',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Foul Words Count',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Action',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
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
                          const Text(
                            "No user to show.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontFamily: 'Poppins',
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
                                                      style: const TextStyle(
                                                        color: white,
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
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontFamily:
                                                                      'Poppins',
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
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                fontFamily:
                                                                    'Poppins',
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
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: textdark,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Foul Words: ${c['foulWords'] ?? 0}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: textdark,
                                                  fontFamily: 'Poppins',
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
                                                      label: const Text('View'),
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
                                                        textStyle:
                                                            const TextStyle(
                                                              fontFamily:
                                                                  'Poppins',
                                                            ),
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
                                                            label: const Text(
                                                              'Recover',
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
                                                              textStyle:
                                                                  const TextStyle(
                                                                    fontFamily:
                                                                        'Poppins',
                                                                  ),
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
                                                            label: const Text(
                                                              'Warning',
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
                                                              textStyle:
                                                                  const TextStyle(
                                                                    fontFamily:
                                                                        'Poppins',
                                                                  ),
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
                                                        label: const Text(
                                                          'Block',
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
                                                          textStyle:
                                                              const TextStyle(
                                                                fontFamily:
                                                                    'Poppins',
                                                              ),
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
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontFamily: 'Poppins',
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          fullName,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                color: dark,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontFamily:
                                                                    'Poppins',
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
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
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
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
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
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  String _maskEmail(String email) {
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
      style: const TextStyle(fontFamily: 'Poppins', color: dark),
      decoration: InputDecoration(
        hintText: 'Search user...',
        hintStyle: const TextStyle(color: textdark),
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
          style: const TextStyle(fontFamily: 'Poppins', color: dark),
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
                    style: const TextStyle(fontFamily: 'Poppins', color: dark),
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
                ? primarycolor.withOpacity(0.25) // Active highlight
                : (isHovered
                      ? primarycolor.withOpacity(0.10) // Hover highlight
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
              style: TextStyle(
                color: widget.isActive
                    ? primarycolordark
                    : (widget.isLogout ? Colors.red : primarycolordark),
                fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w600,
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
  final String activePage; // holds current active page name

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
              child:
                  applicationLogoUrl != null && applicationLogoUrl!.isNotEmpty
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
              MaterialPageRoute(
                builder: (_) => const SuperAdminDashboardPage(),
              ),
            );
          }),
          _drawerItem(context, Icons.people_outline, "Users Info", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserinfoPage()),
            );
          }),
          _drawerItem(context, Icons.chat_outlined, "Chat Logs", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatsPage()),
            );
          }),
          _drawerItem(context, Icons.feedback_outlined, "Feedbacks", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbacksPage()),
            );
          }),
          _drawerItem(
            context,
            Icons.admin_panel_settings_outlined,
            "Admin Management",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminManagementPage()),
              );
            },
          ),
          _drawerItem(context, Icons.receipt_long_outlined, "Audit Logs", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuditLogsPage()),
            );
          }),
          _drawerItem(context, Icons.settings_outlined, "Settings", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SystemSettingsPage()),
            );
          }),
          const Spacer(),
          _drawerItem(context, Icons.logout, "Logout", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            );
          }, isLogout: true),
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
