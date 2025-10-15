import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/admin/dashboard.dart';
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
      _fetchChatData(),
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
      print('Error loading super admin info: $e');
      setState(() => _adminInfoLoaded = true);
    }
  }

  Future<void> _fetchChatData() async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      List<Map<String, dynamic>> loadedChats = [];

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

          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('conversations')
              .doc(convoDoc.id)
              .collection('messages')
              .orderBy('timestamp')
              .get();

          final messages = messagesSnapshot.docs.map((msgDoc) {
            final msgData = msgDoc.data();
            return {
              'role': msgData['role'] ?? '',
              'text': msgData['text'],
              'timestamp': msgData['timestamp'],
            };
          }).toList();

          if (messages.isNotEmpty) {
            final titleText =
                convoData['title'] ?? messages.last['text'] ?? '';
            final lastTimestamp =
                convoData['lastTimestamp'] ?? messages.last['timestamp'];

            loadedChats.add({
              'user': userName,
              'title': titleText,
              'timestamp':
                  _formatTimestamp((lastTimestamp as Timestamp).toDate()),
              'rawTimestamp': lastTimestamp as Timestamp, 
              'messages': messages,
            });
          }
        }
      }

      loadedChats.sort((a, b) {
        Timestamp aTimestamp = a['rawTimestamp'];
        Timestamp bTimestamp = b['rawTimestamp'];
        return bTimestamp.compareTo(aTimestamp);
      });

      setState(() {
        allChats = loadedChats;
        chatData = loadedChats;
        _chatDataLoaded = true;
      });
    } catch (e) {
      print("Error fetching chat data: $e");
      setState(() => _chatDataLoaded = true);
    }
  }

  void _applySearchFilter(String keyword) {
    final filtered = allChats.where((chat) {
      final name = chat['user'].toString().toLowerCase();
      return name.contains(keyword.toLowerCase());
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

    return Scaffold(
      backgroundColor: lightBackground,
      drawer: NavigationDrawer(
        applicationLogoUrl: _applicationLogoUrl,
        activePage: "Chat Logs",
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
                "Chat Logs",
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
                      double cardWidth =
                          (constraints.maxWidth - totalSpacing) / columns;
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
                              return dt.year == now.year &&
                                  dt.month == now.month &&
                                  dt.day == now.day;
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
                        child: SearchBar(
                          controller: _searchController,
                          onChanged: _applySearchFilter,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilterDropdown(
                        selectedFilter: _selectedFilter,
                        onChanged: (value) {
                          if (value != null) {
                            _applyFilter(value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: chatData.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/web-search.png',
                                  width: 240,
                                  height: 240,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  "No chats to show.",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: secondarycolor,
                              child: Text(
                                chat['user'].toString().substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            title: Text(
                              chat['user'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: primarycolordark,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                chat['title'],
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  chat['timestamp'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: primarycolor,
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatHistoryPage(
                                    user: chat['user'],
                                    messages: List<Map<String, dynamic>>.from(
                                        chat['messages']),
                                  ),
                                ),
                              );
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

  const ChatHistoryPage({
    super.key,
    required this.user,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        title: Text(
          user,
          style: const TextStyle(
            color: primarycolordark,
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: primarycolordark),
        elevation: 1,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final role = message['role'] ?? '';
          final isUser = role.toLowerCase() == 'user';

          final timestamp = message['timestamp'];
          final displayTime = timestamp is Timestamp
              ? _formatTimestamp(timestamp.toDate())
              : timestamp.toString();

          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? primarycolordark.withOpacity(0.95)
                        : primarycolor.withOpacity(0.9),    
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isUser ? 12 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 12),
                    ),
                  ),
                  child: Text(
                    message['text'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Poppins',
                      color: isUser ? Colors.white : Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    displayTime,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontFamily: 'Poppins',
                    ),
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
        scale: isHovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const SearchBar({
    super.key,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
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
    const List<String> filters = ['All', 'Today', 'This Week', 'This Month'];

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
          items: filters.map((filter) {
            return DropdownMenuItem<String>(
              value: filter,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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