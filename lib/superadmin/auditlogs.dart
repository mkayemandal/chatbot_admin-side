import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/userinfo.dart';
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

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  int totalLogs = 0;
  int superAdminLogs = 0;
  int adminLogs = 0;
  List<String> actionChoices = [];
  String? selectedAction;
  String firstName = "";
  String lastName = "";
  String profilePictureUrl = "assets/images/defaultDP.jpg";
  String? selectedUser;
  DateTime? selectedDate;

  bool _adminInfoLoaded = false;
  bool _actionChoicesLoaded = false;
  bool _logsCountLoaded = false;

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  bool get _allDataLoaded =>
      _adminInfoLoaded &&
      _actionChoicesLoaded &&
      _logsCountLoaded &&
      _logoLoaded;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _loadSuperAdminInfo(),
      _loadActionChoices(),
      _countLogs(),
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

  Future<void> _loadActionChoices() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('AuditLogs')
        .get();

    final uniqueActions = snapshot.docs
        .map((doc) => doc['action'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    uniqueActions.sort(); // optional: alphabetize

    setState(() {
      actionChoices = uniqueActions;
      _actionChoicesLoaded = true;
    });
  }

  Future<void> _countLogs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('AuditLogs')
          .get();

      int total = snapshot.docs.length;
      int superAdminCount = 0;
      int adminCount = 0;

      final superAdminsSnapshot = await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .get();
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('Admin')
          .get();

      final superAdminNames = superAdminsSnapshot.docs.map((doc) {
        final fname = capitalizeEachWord(doc['firstName'] ?? '');
        final lname = capitalizeEachWord(doc['lastName'] ?? '');
        return '$fname $lname';
      }).toSet();

      final adminNames = adminsSnapshot.docs.map((doc) {
        final fname = capitalizeEachWord(doc['firstName'] ?? '');
        final lname = capitalizeEachWord(doc['lastName'] ?? '');
        return '$fname $lname';
      }).toSet();

      for (var doc in snapshot.docs) {
        final name = doc['performedBy']?.toString().trim() ?? '';

        if (superAdminNames.contains(name)) {
          superAdminCount++;
        } else if (adminNames.contains(name)) {
          adminCount++;
        }
      }

      setState(() {
        totalLogs = total;
        superAdminLogs = superAdminCount;
        adminLogs = adminCount;
        _logsCountLoaded = true;
      });
    } catch (e) {
      print("Error counting logs: $e");
      setState(() => _logsCountLoaded = true);
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
      print('Error fetching SuperAdmin info: $e');
      setState(() => _adminInfoLoaded = true);
    }
  }

  Future<void> logAuditAction({
    required String action,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String fullName = 'Unknown';
    String email = user.email ?? 'No Email';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final firstName = userDoc['firstName'] ?? '';
        final lastName = userDoc['lastName'] ?? '';
        fullName = '$firstName $lastName'.trim();
      }
    } catch (_) {}

    await FirebaseFirestore.instance.collection('AuditLogs').add({
      'name': fullName,
      'email': email,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'desc': description,
    });
  }

  Stream<List<Map<String, dynamic>>> getAuditLogsStream() {
    return FirebaseFirestore.instance
        .collection('AuditLogs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'name': data['performedBy'] ?? '',
              'email': data['email'] ?? '',
              'action': data['action'] ?? '',
              'timestamp': data['timestamp'] ?? '',
              'desc': data['description'] ?? '',
            };
          }).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName';

    // Loader screen covers everything until all data is loaded
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
        backgroundColor: lightBackground,
        drawer: NavigationDrawer(
          applicationLogoUrl: _applicationLogoUrl,
          activePage: "Audit Logs",
        ),
        appBar: AppBar(
          backgroundColor: lightBackground,
          iconTheme: const IconThemeData(color: primarycolordark),
          elevation: 0,
          titleSpacing: 0,
          title: const Row(
            children: [
              SizedBox(width: 12),
              Text(
                "Audit Logs",
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
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
  builder: (context, constraints) {
    bool isLargeScreen = constraints.maxWidth > 800;

    final statCards = [
      StatCard(
        title: "Total Logs",
        value: "$totalLogs",
        color: primarycolordark,
      ),
      StatCard(
        title: "By Super Admin",
        value: "$superAdminLogs",
        color: primarycolor,
      ),
      StatCard(
        title: "By Admin",
        value: "$adminLogs",
        color: primarycolordark,
      ),
    ];

    if (isLargeScreen) {
      // Horizontal row, each card expands to fill equally
      return Row(
        children: [
          for (int i = 0; i < statCards.length; i++) ...[
            Expanded(child: statCards[i]),
            if (i != statCards.length - 1) const SizedBox(width: 16),
          ],
        ],
      );
    } else {
      // Vertical
      return Column(
        children: [
          for (int i = 0; i < statCards.length; i++) ...[
            SizedBox(width: double.infinity, child: statCards[i]),
            if (i != statCards.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
  },
),
                      const SizedBox(height: 16),
                      _buildFilters(),
                      const SizedBox(height: 16),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: getAuditLogsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return _buildEmptyAuditLogsMessage();
                          }

                          List<Map<String, dynamic>> allLogs = snapshot.data!;

                          List<Map<String, dynamic>>
                          filteredLogs = allLogs.where((log) {
                            final matchesAction =
                                selectedAction == null ||
                                log['action'] == selectedAction;
                            final matchesUser =
                                selectedUser == null ||
                                log['name'] == selectedUser;

                            bool matchesDate = true;
                            if (selectedDate != null) {
                              try {
                                final logDate = (log['timestamp'] as Timestamp)
                                    .toDate();
                                matchesDate =
                                    DateFormat('yyyy-MM-dd').format(logDate) ==
                                    DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(selectedDate!);
                              } catch (_) {
                                matchesDate = false;
                              }
                            }

                            return matchesAction && matchesUser && matchesDate;
                          }).toList();

                          if (filteredLogs.isEmpty) {
                            return _buildEmptyAuditLogsMessage();
                          }

                          return _buildResponsiveTable(
                            constraints.maxWidth,
                            filteredLogs,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAuditLogsMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/web-search.png',
              width: 240,
              height: 240,
            ),
            const SizedBox(height: 16),
            const Text(
              'No audit logs found.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getCardWidth(BoxConstraints constraints) {
    final totalSpacing = 12 * 2;
    final maxWidth = constraints.maxWidth - totalSpacing - 24;
    if (constraints.maxWidth > 1000) {
      return maxWidth / 3;
    } else if (constraints.maxWidth > 600) {
      return maxWidth / 2;
    } else {
      return constraints.maxWidth - 24;
    }
  }

  Widget _buildFilters() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getAuditLogsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final userOptions = snapshot.data!
            .map((log) => log['name']?.toString() ?? '')
            .toSet()
            .toList();

        final isSmallScreen = MediaQuery.of(context).size.width < 800;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildActionDropdown(),
                      const SizedBox(height: 12),
                      _buildUserDropdown(userOptions),
                      const SizedBox(height: 12),
                      _buildDatePicker(),
                      const SizedBox(height: 12),
                      _buildFilterButtons(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildActionDropdown()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildUserDropdown(userOptions)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDatePicker()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildFilterButtons()),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildActionDropdown() {
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<String>(
        decoration: _dropdownDecoration('Select Action'),
        value: selectedAction,
        items: actionChoices.map((action) {
          return DropdownMenuItem(
            value: action,
            child: Text(
              action,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: dark,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) => setState(() => selectedAction = value),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          color: dark,
        ),
        iconEnabledColor: secondarycolor,
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildUserDropdown(List<String> users) {
    final filteredUsers = users.where((u) => u.trim().isNotEmpty).toList();

    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<String>(
        decoration: _dropdownDecoration('Select Users'),
        value: selectedUser != null && filteredUsers.contains(selectedUser)
            ? selectedUser
            : null,
        items: filteredUsers.map((user) {
          return DropdownMenuItem<String>(
            value: user,
            child: Text(
              user,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: dark,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) => setState(() => selectedUser = value),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          color: dark,
        ),
        iconEnabledColor: secondarycolor,
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePicker() {
    return SizedBox(
      height: 48,
      child: InputDecorator(
        decoration: _dropdownDecoration('Select Date', isDate: true),
        child: InkWell(
          onTap: _pickDate,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    selectedDate != null
                        ? DateFormat.yMMMMd().format(selectedDate!)
                        : 'Select Date',
                    style: TextStyle(
                      color: selectedDate != null
                          ? Colors.black
                          : Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          setState(() {
            selectedAction = null;
            selectedUser = null;
            selectedDate = null;
          });
        },
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.hovered)) {
              return primarycolordark;
            }
            return secondarycolor;
          }),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          overlayColor: MaterialStateProperty.all(
            Colors.white.withOpacity(0.08),
          ),
          side: MaterialStateProperty.all(BorderSide.none),
        ),
        child: const Text(
          'Clear Filter',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveTable(
    double maxWidth,
    List<Map<String, dynamic>> filteredLogs,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getAuditLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No audit logs found.'));
        }

        List<Map<String, dynamic>> allLogs = snapshot.data!;

        List<Map<String, dynamic>> filteredLogs = allLogs.where((log) {
          final matchesAction =
              selectedAction == null || log['action'] == selectedAction;
          final matchesUser =
              selectedUser == null || log['name'] == selectedUser;

          bool matchesDate = true;
          if (selectedDate != null) {
            try {
              final logDate = (log['timestamp'] as Timestamp).toDate();
              matchesDate =
                  DateFormat('yyyy-MM-dd').format(logDate) ==
                  DateFormat('yyyy-MM-dd').format(selectedDate!);
            } catch (_) {
              matchesDate = false;
            }
          }

          return matchesAction && matchesUser && matchesDate;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: primarycolordark,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          'Name',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white,
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
                            fontFamily: 'Poppins',
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          'Timestamp',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
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
            const SizedBox(height: 8),
            ...filteredLogs.map((log) {
              return Card(
                color: Colors.white,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: secondarycolor,
                              child: Text(
                                (log['name']?.isNotEmpty ?? false)
                                    ? log['name']![0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log['name'] ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  color: dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            log['email'] ?? '',
                            overflow: TextOverflow.ellipsis,
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
                            log['action'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: dark,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text(
                            log['timestamp'] is Timestamp
                                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(
                                    (log['timestamp'] as Timestamp).toDate(),
                                  )
                                : log['timestamp'].toString(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: dark,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: Text(
                            log['desc'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: dark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  InputDecoration _dropdownDecoration(
    String label, {
    bool isDate = false,
    IconData? icon,
  }) {
    return InputDecoration(
      hintText: isDate ? label : null,
      labelText: isDate ? null : label,
      prefixIcon: icon != null ? Icon(icon, color: secondarycolor) : null,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: dark,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: dark,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: primarycolordark,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.bold,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: secondarycolor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primarycolordark, width: 1.6),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primarycolordark,
              onPrimary: Colors.white,
              onSurface: dark,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primarycolordark,
                textStyle: const TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.31),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.9),
              fontFamily: 'Poppins',
            ),
          ),
        ],
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
      child: AnimatedScale(
        scale: isHovered ? 1.012 : 1.0,
        duration: const Duration(milliseconds: 120),
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
