import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/superadmin/userinfo.dart';
import 'package:chatbot/superadmin/auditlogs.dart';
import 'package:chatbot/superadmin/chatlogs.dart';
import 'package:chatbot/superadmin/feedbacks.dart';
import 'package:chatbot/superadmin/settings.dart';
import 'package:chatbot/superadmin/adduser.dart';
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

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({super.key});

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> users = [];
  int totalAdmins = 0;
  int activeAdmins = 0;
  int inactiveAdmins = 0;

  String firstName = "";
  String lastName = "";
  String profilePictureUrl = "assets/images/defaultDP.jpg";

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  bool _adminInfoLoaded = false;
  bool _userDataLoaded = false;

  String get fullName => '$firstName $lastName';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadUserDataList();
    _loadAdminInfo();
    _loadApplicationLogo();
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
      print('Error loading super admin info: $e');
      setState(() => _adminInfoLoaded = true);
    }
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: dark,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: dark,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserDataList() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Admin')
        .orderBy('createdAt', descending: true)
        .get();

    int active = 0;
    int inactive = 0;

    List<Map<String, dynamic>> fetchedUsers = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['createdAt'];
      String formattedDate = '';
      Timestamp? rawTimestamp;

      if (timestamp != null) {
        rawTimestamp = timestamp;
        final date = timestamp.toDate();
        formattedDate = DateFormat('MMMM dd, yyyy').format(date);
      }

      final String email = data['email'] ?? '';
      final String firestoreStatus = (data['status'] ?? 'inactive')
          .toString()
          .toLowerCase();

      // Tally status
      if (firestoreStatus == 'active') {
        active++;
      } else {
        inactive++;
      }

      fetchedUsers.add({
        'name': capitalizeEachWord(data['name'] ?? ''),
        'firstName': capitalizeEachWord(data['firstName'] ?? ''),
        'lastName': capitalizeEachWord(data['lastName'] ?? ''),
        'email': email,
        'username': data['username'] ?? '',
        'position': data['accountType'] ?? '',
        'date': formattedDate,
        'type': firestoreStatus,
        'phonenumber': data['phone'] ?? '',
        'createdAt': rawTimestamp,
        'status': firestoreStatus,
        'uid': doc.id, // add uid for delete
      });
    }

    setState(() {
      users = fetchedUsers
          .where((user) => user['position'].toString().toLowerCase() == 'admin')
          .toList();
      totalAdmins = users.length;
      activeAdmins = active;
      inactiveAdmins = inactive;
      _userDataLoaded = true;
    });
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    final query = _searchController.text.toLowerCase();
    final filter = _selectedFilter.toLowerCase();

    return users.where((item) {
      final name = item['name'].toString().toLowerCase();
      final type = item['type'].toString().toLowerCase();
      final matchesQuery = name.contains(query);
      final matchesFilter =
          filter == 'all' ||
          (filter == 'active' && type == 'active') ||
          (filter == 'inactive' && type == 'inactive');
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Loader screen covers everything until both admin info and user data are loaded
    if (!_adminInfoLoaded || !_userDataLoaded) {
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
          activePage: "Admin Management",
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
                "Admin Management",
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),              
              child: LayoutBuilder(
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
                        title: "Total Admin",
                        value: totalAdmins.toString(),
                        color: primarycolordark,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Active",
                        value: activeAdmins.toString(),
                        color: primarycolor,
                        width: cardWidth,
                      ),
                      StatCard(
                        title: "Inactive",
                        value: inactiveAdmins.toString(),
                        color: primarycolordark,
                        width: cardWidth,
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SearchBar(controller: _searchController),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 150,
                    child: FilterDropdown(
                      selectedFilter: _selectedFilter,
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value ?? 'All';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    height: 48,
                    child: HoverButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddUserPage(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.person_add, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Add User',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      color: secondarycolor,
                      hoverBackground: primarycolordark,
                      textHoverColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 8,
                  ),
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
                                'Date Created',
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
                            flex: 3,
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
            Expanded(
              child: _filteredCustomers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/images/web-search.png",
                            width: 240,
                            height: 240,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "No admin to show.",
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
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final c = _filteredCustomers[index];
                        final fullName = c['name'] ?? '';
                        final joinedDate = c['date'] ?? '';

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            bool isSmallScreen = constraints.maxWidth < 600;
                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 6,
                              ),
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
                                                        color: Colors.white,
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
                                                        Text(
                                                          fullName,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontFamily:
                                                                    'Poppins',
                                                                color: dark,
                                                              ),
                                                        ),
                                                        Text(
                                                          c['email'],
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                fontFamily:
                                                                    'Poppins',
                                                                color: dark,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Date Created: $joinedDate',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontFamily: 'Poppins',
                                                  color: dark,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            final firstName =
                                                                c['firstName'] ??
                                                                '';
                                                            final lastName =
                                                                c['lastName'] ??
                                                                '';
                                                            final fullName =
                                                                '$firstName $lastName'
                                                                    .trim();

                                                            String phoneNumber =
                                                                c['phonenumber'] ??
                                                                '';
                                                            if (phoneNumber
                                                                    .isNotEmpty &&
                                                                !phoneNumber
                                                                    .startsWith(
                                                                      '+63',
                                                                    )) {
                                                              phoneNumber =
                                                                  '+63$phoneNumber';
                                                            }

                                                            return Dialog(
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                              child: Container(
                                                                width: 400,
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      24,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        16,
                                                                      ),
                                                                ),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const CircleAvatar(
                                                                      radius:
                                                                          35,
                                                                      backgroundImage:
                                                                          AssetImage(
                                                                            'assets/images/defaultDP.jpg',
                                                                          ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          12,
                                                                    ),
                                                                    Text(
                                                                      fullName,
                                                                      style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        fontSize:
                                                                            18,
                                                                        fontFamily:
                                                                            'Poppins',
                                                                        color:
                                                                            dark,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 4,
                                                                    ),
                                                                    Text(
                                                                      c['email'] ??
                                                                          '',
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color:
                                                                            dark,
                                                                        fontFamily:
                                                                            'Poppins',
                                                                      ),
                                                                    ),
                                                                    const Divider(
                                                                      height:
                                                                          30,
                                                                    ),
                                                                    _buildProfileRow(
                                                                      "First Name",
                                                                      firstName,
                                                                    ),
                                                                    _buildProfileRow(
                                                                      "Last Name",
                                                                      lastName,
                                                                    ),
                                                                    _buildProfileRow(
                                                                      "Username",
                                                                      c['username'],
                                                                    ),
                                                                    _buildProfileRow(
                                                                      "Mobile Number",
                                                                      phoneNumber
                                                                              .isEmpty
                                                                          ? 'Add number'
                                                                          : phoneNumber,
                                                                    ),
                                                                    _buildProfileRow(
                                                                      "Date Created",
                                                                      c['date'],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
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
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      onPressed: () async {
                                                        final confirmed = await showDialog<bool>(
                                                          context: context,
                                                          builder: (context) => AlertDialog(
                                                            backgroundColor:
                                                                lightBackground,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    14,
                                                                  ),
                                                            ),
                                                            title: const Text(
                                                              'Delete Admin Account?',
                                                              style: TextStyle(
                                                                color:
                                                                    primarycolordark,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontFamily:
                                                                    'Poppins',
                                                              ),
                                                            ),
                                                            content: Text(
                                                              'Are you sure you want to delete admin ${c['name']}? This will permanently remove access to the Admin Management Page.',
                                                              style:
                                                                  const TextStyle(
                                                                    color: dark,
                                                                    fontFamily:
                                                                        'Poppins',
                                                                  ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                      false,
                                                                    ),
                                                                style: TextButton.styleFrom(
                                                                  foregroundColor:
                                                                      primarycolordark,
                                                                  textStyle: const TextStyle(
                                                                    fontFamily:
                                                                        'Poppins',
                                                                  ),
                                                                ),
                                                                child:
                                                                    const Text(
                                                                      'Cancel',
                                                                    ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                      true,
                                                                    ),
                                                                style: TextButton.styleFrom(
                                                                  backgroundColor:
                                                                      primarycolordark,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                  textStyle: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontFamily:
                                                                        'Poppins',
                                                                  ),
                                                                ),
                                                                child: const Text(
                                                                  'Confirm Delete',
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );

                                                        if (confirmed == true) {
                                                          try {
                                                            final email =
                                                                c['email'];
                                                            final uid =
                                                                c['uid'];

                                                            // Delete Firestore document
                                                            final snapshot =
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                      'Admin',
                                                                    )
                                                                    .where(
                                                                      'email',
                                                                      isEqualTo:
                                                                          email,
                                                                    )
                                                                    .limit(1)
                                                                    .get();

                                                            if (snapshot
                                                                .docs
                                                                .isNotEmpty) {
                                                              await snapshot
                                                                  .docs
                                                                  .first
                                                                  .reference
                                                                  .delete();
                                                            }

                                                            // Delete Firebase Auth user (only works if currently authenticated user is same or re-authenticated)
                                                            final user =
                                                                FirebaseAuth
                                                                    .instance
                                                                    .currentUser;

                                                            if (user != null &&
                                                                user.uid ==
                                                                    uid) {
                                                              await user
                                                                  .delete(); // only deletes own account unless you use Admin SDK
                                                            } else {
                                                              print(
                                                                "Cannot delete other users without Admin SDK or secure backend function.",
                                                              );
                                                            }

                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  "Admin ${c['name']} deleted successfully.",
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                                backgroundColor:
                                                                    primarycolor,
                                                                behavior:
                                                                    SnackBarBehavior
                                                                        .floating,
                                                              ),
                                                            );
                                                            _loadUserDataList(); // Refresh
                                                          } catch (e) {
                                                            print(
                                                              "Error deleting user: $e",
                                                            );
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  "Failed to delete admin.",
                                                                ),
                                                                backgroundColor:
                                                                    Colors.red,
                                                                behavior:
                                                                    SnackBarBehavior
                                                                        .floating,
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                      icon: const Icon(
                                                        Icons.delete,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        'Delete',
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            secondarycolor,
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

                                          Align(
                                            alignment: Alignment.topRight,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                top: 4,
                                                right: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: c['status'] == 'active'
                                                    ? Colors.green[100]
                                                    : Colors.red[100],
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                c['status'].toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: c['status'] == 'active'
                                                      ? Colors.green[800]
                                                      : Colors.red[800],
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
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
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      fullName,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: dark,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontFamily: 'Poppins',
                                                      ),
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
                                                c['email'],
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
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: c['status'] == 'active'
                                                      ? Colors.green[100]
                                                      : Colors.red[100],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  c['status']
                                                      .toString()
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color:
                                                        c['status'] == 'active'
                                                        ? Colors.green[800]
                                                        : Colors.red[800],
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) {
                                                          final firstName =
                                                              c['firstName'] ??
                                                              '';
                                                          final lastName =
                                                              c['lastName'] ??
                                                              '';
                                                          final fullName =
                                                              '$firstName $lastName'
                                                                  .trim();

                                                          String phoneNumber =
                                                              c['phonenumber'] ??
                                                              '';
                                                          if (phoneNumber
                                                                  .isNotEmpty &&
                                                              !phoneNumber
                                                                  .startsWith(
                                                                    '+63',
                                                                  )) {
                                                            phoneNumber =
                                                                '+63$phoneNumber';
                                                          }

                                                          return Dialog(
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    16,
                                                                  ),
                                                            ),
                                                            child: Container(
                                                              width: 400,
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    24,
                                                                  ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                    color: Colors
                                                                        .white,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          16,
                                                                        ),
                                                                  ),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const CircleAvatar(
                                                                    radius: 35,
                                                                    backgroundImage:
                                                                        AssetImage(
                                                                          'assets/images/defaultDP.jpg',
                                                                        ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 12,
                                                                  ),
                                                                  Text(
                                                                    fullName,
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          18,
                                                                      fontFamily:
                                                                          'Poppins',
                                                                      color:
                                                                          dark,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  Text(
                                                                    c['email'] ??
                                                                        '',
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color:
                                                                          dark,
                                                                      fontFamily:
                                                                          'Poppins',
                                                                    ),
                                                                  ),
                                                                  const Divider(
                                                                    height: 30,
                                                                  ),
                                                                  _buildProfileRow(
                                                                    "First Name",
                                                                    firstName,
                                                                  ),
                                                                  _buildProfileRow(
                                                                    "Last Name",
                                                                    lastName,
                                                                  ),
                                                                  _buildProfileRow(
                                                                    "Username",
                                                                    c['username'],
                                                                  ),
                                                                  _buildProfileRow(
                                                                    "Mobile Number",
                                                                    phoneNumber
                                                                            .isEmpty
                                                                        ? 'Add number'
                                                                        : phoneNumber,
                                                                  ),
                                                                  _buildProfileRow(
                                                                    "Date Created",
                                                                    c['date'],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
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
                                                            vertical: 12,
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
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      final confirmed = await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          backgroundColor:
                                                              lightBackground,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                          title: const Text(
                                                            'Delete Admin Account?',
                                                            style: TextStyle(
                                                              color:
                                                                  primarycolordark,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontFamily:
                                                                  'Poppins',
                                                            ),
                                                          ),
                                                          content: Text(
                                                            'Are you sure you want to delete admin ${c['name']}? This will permanently remove access to the Admin Management Page.',
                                                            style:
                                                                const TextStyle(
                                                                  color: dark,
                                                                  fontFamily:
                                                                      'Poppins',
                                                                ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    false,
                                                                  ),
                                                              style: TextButton.styleFrom(
                                                                foregroundColor:
                                                                    primarycolordark,
                                                                textStyle:
                                                                    const TextStyle(
                                                                      fontFamily:
                                                                          'Poppins',
                                                                    ),
                                                              ),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    true,
                                                                  ),
                                                              style: TextButton.styleFrom(
                                                                backgroundColor:
                                                                    primarycolordark,
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                textStyle: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontFamily:
                                                                      'Poppins',
                                                                ),
                                                              ),
                                                              child: const Text(
                                                                'Confirm Delete',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );

                                                      if (confirmed == true) {
                                                        try {
                                                          final email =
                                                              c['email'];
                                                          final uid = c['uid'];

                                                          // Delete Firestore document
                                                          final snapshot =
                                                              await FirebaseFirestore
                                                                  .instance
                                                                  .collection(
                                                                    'Admin',
                                                                  )
                                                                  .where(
                                                                    'email',
                                                                    isEqualTo:
                                                                        email,
                                                                  )
                                                                  .limit(1)
                                                                  .get();

                                                          if (snapshot
                                                              .docs
                                                              .isNotEmpty) {
                                                            await snapshot
                                                                .docs
                                                                .first
                                                                .reference
                                                                .delete();
                                                          }

                                                          // Delete Firebase Auth user (only works if currently authenticated user is same or re-authenticated)
                                                          final user =
                                                              FirebaseAuth
                                                                  .instance
                                                                  .currentUser;

                                                          if (user != null &&
                                                              user.uid == uid) {
                                                            await user
                                                                .delete(); // only deletes own account unless you use Admin SDK
                                                          } else {
                                                            print(
                                                              "Cannot delete other users without Admin SDK or secure backend function.",
                                                            );
                                                          }

                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                "Admin ${c['name']} deleted successfully.",
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                              backgroundColor:
                                                                  primarycolor,
                                                              behavior:
                                                                  SnackBarBehavior
                                                                      .floating,
                                                            ),
                                                          );
                                                          _loadUserDataList(); // Refresh
                                                        } catch (e) {
                                                          print(
                                                            "Error deleting user: $e",
                                                          );
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                "Failed to delete admin.",
                                                              ),
                                                              backgroundColor:
                                                                  Colors.red,
                                                              behavior:
                                                                  SnackBarBehavior
                                                                      .floating,
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      size: 16,
                                                    ),
                                                    label: const Text('Delete'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          secondarycolor,
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
                                                            vertical: 12,
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
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeInOut,
        width: widget.width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(isHovered ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.color.withOpacity(isHovered ? 0.54 : 0.31),
            width: 1.5,
          ),
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
  final Widget child;
  final Color color;
  final Color? textHoverColor;
  final Color? hoverBackground;

  const HoverButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.color = primarycolordark,
    this.textHoverColor,
    this.hoverBackground,
  }) : super(key: key);

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isHovered
        ? (widget.hoverBackground ?? widget.color)
        : widget.color;
    final Color? fgColor = isHovered
        ? widget.textHoverColor ??
              (widget.color == Colors.transparent ? null : Colors.white)
        : (widget.color == Colors.transparent ? null : Colors.white);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
            foregroundColor: fgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: widget.onPressed,
          child: widget.child,
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
        hintText: 'Search admin...',
        hintStyle: const TextStyle(color: dark),
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
          style: const TextStyle(fontFamily: 'Poppins', color: dark),
          icon: const Icon(Icons.filter_list, color: primarycolordark),
          items: ['All', 'Active', 'Inactive'].map((filter) {
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

class NavigationDrawer extends StatelessWidget {
  final String? applicationLogoUrl;
  final String activePage; // 👈 NEW: keeps track of which page is active

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
    return _DrawerHoverButton(
      icon: icon,
      title: title,
      onTap: onTap,
      isLogout: isLogout,
      isActive: activePage == title, // 👈 highlight if current page
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
    final bgColor = widget.isActive
        ? primarycolor.withOpacity(0.25) // 👈 active state
        : (isHovered ? primarycolor.withOpacity(0.10) : Colors.transparent);

    final textColor = widget.isLogout
        ? Colors.red
        : (widget.isActive ? primarycolordark : primarycolordark);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Icon(widget.icon, color: textColor),
          title: Text(
            widget.title,
            style: TextStyle(
              color: textColor,
              fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
