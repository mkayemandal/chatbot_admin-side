import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/feedbacks.dart';
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
      .map((word) =>
          word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
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

class ChatbotDataPage extends StatefulWidget {
  const ChatbotDataPage({super.key});
  @override
  State<ChatbotDataPage> createState() => _ChatbotDataPageState();
}

class _ChatbotDataPageState extends State<ChatbotDataPage> {
  final TextEditingController _searchController = TextEditingController();
  String firstName = "";
  String lastName = "";
  String? _applicationLogoUrl;
  bool _logoLoaded = false;
  bool _adminInfoLoaded = false;
  bool _chatbotDataLoaded = false;
  bool get _allDataLoaded => _adminInfoLoaded && _chatbotDataLoaded && _logoLoaded;

  List<String> departmentChoices = [];
  Map<String, List<Map<String, dynamic>>> departmentData = {};
  int tabPage = 0;
  int _selectedTabIndex = 0;
  String? selectedLanguage;
  String? searchKeyword;

  @override
  void initState() {
    super.initState();
    _initializePage();
    _searchController.addListener(() {
      setState(() {
        searchKeyword = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _loadAdminInfo(),
      _loadApplicationLogo(),
      _loadChatbotData(),
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
          setState(() {
            firstName = capitalizeEachWord(doc['firstName'] ?? '');
            lastName = capitalizeEachWord(doc['lastName'] ?? '');
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

  Future<void> _loadChatbotData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('CsvData').get();
      final tempDeptMap = <String, List<Map<String, dynamic>>>{};

      for (final doc in snapshot.docs) {
        final departmentName = doc.id;
        final dataList = doc['data'] as List<dynamic>? ?? [];
        tempDeptMap[departmentName] = [];
        for (int i = 0; i < dataList.length; i++) {
          final item = dataList[i];
          if (item is! Map) continue;
          var question =
              item['question']?.toString().replaceAll(r'\n', '\n') ?? '';
          var answer = item['answer']?.toString().replaceAll(r'\n', '\n') ?? '';
          final language = item['language']?.toString();
          question = _stripQuotes(question);
          answer = _stripQuotes(answer);
          if (question.isEmpty || answer.isEmpty) continue;
          tempDeptMap[departmentName]!.add({
            'index': i,
            'question': TextEditingController(text: question),
            'answer': TextEditingController(text: answer),
            'language': language ?? '',
            'department': departmentName,
            'originalDepartment': departmentName,
            'isSaved': true,
          });
        }
      }

      setState(() {
        departmentData = tempDeptMap;
        departmentChoices = tempDeptMap.keys.toList();
        _chatbotDataLoaded = true;
      });
    } catch (e) {
      print('Error loading chatbot data: $e');
      setState(() => _chatbotDataLoaded = true);
    }
  }

  String _stripQuotes(String input) {
    return input.replaceAll(RegExp(r'^"(.*)"$'), r'\1').trim();
  }

  Future<void> _saveDataSet(Map<String, dynamic> dataSet) async {
    final question = (dataSet['question'] as TextEditingController).text.trim();
    final answer = (dataSet['answer'] as TextEditingController).text.trim();
    final language = dataSet['language'] as String;
    final newDepartment = dataSet['department'] as String;
    final index = dataSet['index'] as int?;
    final oldDepartment = dataSet['originalDepartment'] ?? newDepartment;

    if (question.isEmpty || answer.isEmpty || newDepartment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields must be filled.')),
      );
      return;
    }

    try {
      if (newDepartment != oldDepartment) {
        final oldDocRef = FirebaseFirestore.instance.collection('CsvData').doc(oldDepartment);
        final newDocRef = FirebaseFirestore.instance.collection('CsvData').doc(newDepartment);

        final oldDocSnapshot = await oldDocRef.get();
        final newDocSnapshot = await newDocRef.get();

        if (!oldDocSnapshot.exists || !newDocSnapshot.exists) {
          throw Exception('Old or new department does not exist.');
        }

        List<Map<String, dynamic>> oldDataList = List<Map<String, dynamic>>.from(oldDocSnapshot['data']);
        List<Map<String, dynamic>> newDataList = List<Map<String, dynamic>>.from(newDocSnapshot['data']);

        if (index != null && index >= 0 && index < oldDataList.length) {
          oldDataList.removeAt(index);
        }

        final newEntry = {
          'question': question,
          'answer': answer,
          'language': language,
        };

        newDataList.add(newEntry);

        await oldDocRef.set({'data': oldDataList}, SetOptions(merge: true));
        await newDocRef.set({'data': newDataList}, SetOptions(merge: true));

        await logAuditAction(
          action: 'Moved & Edited Chatbot Data',
          description:
              'Moved data from "$oldDepartment" to "$newDepartment". Updated chatbot entry in "$newDepartment" (Lang: $language)',
        );

        setState(() {
          dataSet['isSaved'] = true;
          dataSet['originalDepartment'] = newDepartment;
          dataSet['index'] = newDataList.length - 1;
        });
      } else {
        final docRef = FirebaseFirestore.instance.collection('CsvData').doc(newDepartment);
        final snapshot = await docRef.get();

        if (!snapshot.exists) return;

        final dataList = List<Map<String, dynamic>>.from(snapshot['data']);

        if (index != null && index >= 0 && index < dataList.length) {
          dataList[index] = {
            'question': question,
            'answer': answer,
            'language': language,
          };
        } else {
          dataList.add({
            'question': question,
            'answer': answer,
            'language': language,
          });
        }

        await docRef.set({'data': dataList}, SetOptions(merge: true));

        await logAuditAction(
          action: index == null ? 'Added Chatbot Data' : 'Edited Chatbot Data',
          description: '${index == null ? 'Added' : 'Edited'} chatbot entry in "$newDepartment" (Lang: $language)',
        );

        setState(() {
          dataSet['isSaved'] = true;
          dataSet['index'] = dataList.length - 1;
          dataSet['originalDepartment'] = newDepartment;
        });
      }
    } catch (e) {
      print('Error saving data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save data: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteDataSet(Map<String, dynamic> dataSet) async {
    final department = dataSet['originalDepartment'] ?? dataSet['department'];
    final index = dataSet['index'] as int?;

    if (index == null || department == null || department.isEmpty) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('CsvData').doc(department);
      final snapshot = await docRef.get();

      if (!snapshot.exists) return;

      List<Map<String, dynamic>> dataList = List<Map<String, dynamic>>.from(snapshot['data']);

      if (index < 0 || index >= dataList.length) return;

      final removedEntry = dataList.removeAt(index);

      await docRef.set({'data': dataList}, SetOptions(merge: true));

      await logAuditAction(
        action: 'Deleted Chatbot Data',
        description:
            'Deleted chatbot entry from "$department": "${removedEntry['question']}"',
      );

      setState(() {
        departmentData[department]?.remove(dataSet);
      });
    } catch (e) {
      print('Error deleting dataset: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting data: ${e.toString()}')),
      );
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

    final adminDoc = await FirebaseFirestore.instance.collection('Admin').doc(user.uid).get();
    final superAdminDoc = await FirebaseFirestore.instance.collection('SuperAdmin').doc(user.uid).get();

    if (adminDoc.exists) {
      final firstName = capitalizeEachWord(adminDoc['firstName'] ?? '');
      final lastName = capitalizeEachWord(adminDoc['lastName'] ?? '');
      fullName = '$firstName $lastName'.trim();
    } else if (superAdminDoc.exists) {
      final firstName = capitalizeEachWord(superAdminDoc['firstName'] ?? '');
      final lastName = capitalizeEachWord(superAdminDoc['lastName'] ?? '');
      fullName = '$firstName $lastName'.trim();
    }

    await FirebaseFirestore.instance.collection('AuditLogs').add({
      'performedBy': fullName,
      'email': email,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'description': description,
    });
  }

  @override
  void dispose() {
    for (var deptList in departmentData.values) {
      for (var ds in deptList) {
        (ds['question'] as TextEditingController).dispose();
        (ds['answer'] as TextEditingController).dispose();
      }
    }
    _searchController.dispose();
    super.dispose();
  }

  int get tabsPerPage {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? 3 : 5;
  }
  List<String> get pagedDepartments {
    final start = tabPage * tabsPerPage;
    final end = (start + tabsPerPage).clamp(0, departmentChoices.length);
    return departmentChoices.sublist(start, end);
  }

  List<Map<String, dynamic>> getFilteredData(String department) {
    var list = departmentData[department] ?? [];
    return list.where((item) {
      final question = item['question'].text.toLowerCase();
      final answer = item['answer'].text.toLowerCase();
      final lang = (item['language'] ?? '').toString();
      final matchesKeyword = searchKeyword == null || searchKeyword!.isEmpty
          || question.contains(searchKeyword!)
          || answer.contains(searchKeyword!);
      final matchesLang = selectedLanguage == null || selectedLanguage!.isEmpty
          || lang == selectedLanguage;
      return matchesKeyword && matchesLang;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName';
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

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
        activePage: "Chatbot Data",
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: primarycolordark),
        elevation: 0,
        titleSpacing: 0,
        title: const Row(
          children: [
            SizedBox(width: 12),
            Text(
              "Chatbot Data",
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
          Padding(
            // Ensures maroon section is same width as content
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              margin: const EdgeInsets.only(bottom: 8, top: 16),
              decoration: BoxDecoration(
                color: primarycolordark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  SizedBox(width: 12), 
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Chatbot Data',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          _buildFilterSection(isSmallScreen),
          const SizedBox(height: 8),
          if (pagedDepartments.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No departments available.",
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            )
          else
            _buildTabBarWithArrows(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isSmallScreen) {
    final languageOptions = departmentData.values
        .expand((list) => list.map((e) => e['language']?.toString() ?? ''))
        .where((lang) => lang.isNotEmpty)
        .toSet()
        .toList();

    if (isSmallScreen) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontFamily: 'Poppins', color: dark),
                  decoration: InputDecoration(
                    hintText: 'Search keyword...',
                    hintStyle: const TextStyle(color: dark, fontFamily: 'Poppins'),
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
                      borderSide: const BorderSide(color: secondarycolor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Language',
                    prefixIcon: const Icon(Icons.language, color: primarycolor),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(
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
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: secondarycolor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: primarycolordark, width: 1.5),
                    ),
                  ),
                  value: selectedLanguage,
                  items: languageOptions.map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text(
                        lang,
                        style: const TextStyle(fontFamily: 'Poppins', color: dark),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedLanguage = value;
                    });
                  },
                  style: const TextStyle(fontFamily: 'Poppins', color: dark),
                  iconEnabledColor: secondarycolor,
                  dropdownColor: Colors.white,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        selectedLanguage = null;
                        searchKeyword = null;
                        _searchController.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: primarycolordark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide.none,
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
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontFamily: 'Poppins', color: dark),
                    decoration: InputDecoration(
                      hintText: 'Search keyword...',
                      hintStyle: const TextStyle(color: dark, fontFamily: 'Poppins'),
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
                        borderSide: const BorderSide(color: secondarycolor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Language',
                      prefixIcon: const Icon(Icons.language, color: primarycolor),
                      filled: true,
                      fillColor: Colors.white,
                      labelStyle: const TextStyle(
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
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: secondarycolor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: primarycolordark, width: 1.5),
                      ),
                    ),
                    value: selectedLanguage,
                    items: languageOptions.map((lang) {
                      return DropdownMenuItem(
                        value: lang,
                        child: Text(
                          lang,
                          style: const TextStyle(fontFamily: 'Poppins', color: dark),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLanguage = value;
                      });
                    },
                    style: const TextStyle(fontFamily: 'Poppins', color: dark),
                    iconEnabledColor: secondarycolor,
                    dropdownColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          selectedLanguage = null;
                          searchKeyword = null;
                          _searchController.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: primarycolordark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide.none,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTabBarWithArrows(bool isSmallScreen) {
    final numTabs = tabsPerPage;
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left, color: primarycolordark, size: 30),
                onPressed: tabPage > 0
                    ? () {
                        setState(() {
                          tabPage--;
                          _selectedTabIndex = 0;
                        });
                      }
                    : null,
              ),
              Expanded(
                child: Row(
                  children: List.generate(numTabs, (i) {
                    final deptList = pagedDepartments;
                    final dept = i < deptList.length ? deptList[i] : null;
                    final isActive = i == _selectedTabIndex;
                    return Expanded(
                      child: dept == null
                          ? Container()
                          : GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTabIndex = i;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? primarycolor.withOpacity(0.18)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isActive ? primarycolor : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Center(
                                  child: Text(
                                    dept ?? '',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isActive ? primarycolordark : dark,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    );
                  }),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right, color: primarycolordark, size: 30),
                onPressed: (tabPage + 1) * numTabs < departmentChoices.length
                    ? () {
                        setState(() {
                          tabPage++;
                          _selectedTabIndex = 0;
                        });
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: pagedDepartments.isEmpty
                ? Center(
                    child: Text(
                      "No department data available.",
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                  )
                : _buildDepartmentTab(
                    pagedDepartments[_selectedTabIndex],
                    getFilteredData(pagedDepartments[_selectedTabIndex]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cardSection(
      {required IconData icon,
      required String title,
      required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primarycolordark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: primarycolordark,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentTab(
    String department, List<Map<String, dynamic>> dataSets) {
    String sectionTitle = "${department} Data";
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardSection(
            icon: Icons.question_answer_outlined,
            title: sectionTitle,
            child: Column(
              children: [
                for (var dataSet in dataSets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _DataSetItem(dataSet),
                  ),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        dataSets.add({
                          "question": TextEditingController(),
                          "answer": TextEditingController(),
                          "language": "",
                          "department": department,
                          "originalDepartment": department,
                          "id": "",
                          "isSaved": false,
                        });
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline,
                        color: secondarycolor),
                    label: const Text(
                      "Add Data ",
                      style: TextStyle(
                          color: secondarycolor, fontFamily: 'Poppins'),
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

  Widget _DataSetItem(Map<String, dynamic> DataSet) {
    final question = DataSet['question'] as TextEditingController;
    final answer = DataSet['answer'] as TextEditingController;
    final language = DataSet['language'] as String;
    final department = DataSet['department'] as String;
    final isSaved = DataSet['isSaved'] as bool;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: question,
            readOnly: isSaved,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              color: dark,
            ),
            decoration: InputDecoration(
              labelText: 'Question',
              prefixIcon: const Icon(Icons.question_answer_outlined, color: primarycolor),
              filled: true,
              fillColor: Colors.white,
              labelStyle: const TextStyle(
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
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: answer,
            readOnly: isSaved,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              color: dark,
            ),
            decoration: InputDecoration(
              labelText: 'Answer',
              prefixIcon: const Icon(Icons.text_snippet_outlined, color: primarycolor),
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              labelStyle: const TextStyle(
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
            ),
          ),
          const SizedBox(height: 12),
          isSaved
              ? TextFormField(
                  enabled: false,
                  controller: TextEditingController(text: department),
                  decoration: InputDecoration(
                    labelText: 'Department',
                    prefixIcon: const Icon(Icons.apartment, color: primarycolor),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(
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
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: secondarycolor, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: dark,
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: departmentChoices.contains(DataSet['department']) ? DataSet['department'] : null,
                  hint: const Text(
                    'Choose a Department',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: dark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  dropdownColor: Colors.white,
                  iconEnabledColor: secondarycolor,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: dark,
                    fontWeight: FontWeight.w500,
                  ),
                  items: departmentChoices
                      .toSet()
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: dark,
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        DataSet['department'] = val;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Department',
                    prefixIcon: const Icon(Icons.apartment, color: primarycolor),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(
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
                  ),
                ),
          const SizedBox(height: 12),
          isSaved
              ? TextFormField(
                  enabled: false,
                  controller: TextEditingController(text: language),
                  decoration: InputDecoration(
                    labelText: 'Language',
                    prefixIcon: const Icon(Icons.language, color: primarycolor),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(
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
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: secondarycolor, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: dark,
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: language.isEmpty ? null : language,
                  hint: const Text(
                    'Choose a Language',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: dark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  dropdownColor: Colors.white,
                  iconEnabledColor: secondarycolor,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: dark,
                    fontWeight: FontWeight.w500,
                  ),
                  items: ['English', 'Tagalog', 'Kapampangan']
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: dark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        DataSet['language'] = val;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Language',
                    prefixIcon: const Icon(Icons.language, color: primarycolor),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(
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
                  ),
                ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isSaved)
                IconButton(
                  icon: const Icon(Icons.edit, color: primarycolor),
                  onPressed: () {
                    setState(() {
                      DataSet['isSaved'] = false;
                    });
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () async {
                    final questionText = (DataSet['question'] as TextEditingController).text.trim();
                    final answerText = (DataSet['answer'] as TextEditingController).text.trim();
                    final language = DataSet['language'] as String;
                    final department = DataSet['department'] as String;

                    if (questionText.isEmpty || answerText.isEmpty || language.isEmpty || department.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All fields must be filled before saving.', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    await _saveDataSet(DataSet);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  await _deleteDataSet(DataSet);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  final String? applicationLogoUrl;
  final String activePage;
  const NavigationDrawer(
      {super.key, this.applicationLogoUrl, required this.activePage});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: lightBackground),
            child: Center(
              child: applicationLogoUrl != null &&
                      applicationLogoUrl!.isNotEmpty
                  ? Image.network(
                      applicationLogoUrl!,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset(
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
          _drawerItem(context, Icons.people_outline, "Users Info", () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserinfoPage()),
            );
          }, isActive: activePage == "Users Info"),
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
          _drawerItem(context, Icons.logout, "Logout", () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            );
          }, isLogout: true, isActive: false),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title,
      VoidCallback onTap,
      {bool isLogout = false, required bool isActive}) {
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