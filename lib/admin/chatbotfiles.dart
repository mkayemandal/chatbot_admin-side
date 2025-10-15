import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chatbot/admin/chatlogs.dart';
import 'package:chatbot/admin/feedbacks.dart';
import 'package:chatbot/admin/chatbotdata.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/admin/profile.dart';
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

class ChatbotFilesPage extends StatefulWidget {
  const ChatbotFilesPage({super.key});

  @override
  State<ChatbotFilesPage> createState() => _ChatbotFilesPageState();
}

class _ChatbotFilesPageState extends State<ChatbotFilesPage> {
  String firstName = '';
  String lastName = '';
  String email = '';
  String gender = '';
  String userType = '';
  String birthday = '';
  String staffID = '';
  String searchQuery = '';

  // For Application Logo
  String? _applicationLogoUrl;
  bool _logoLoaded = false;

  bool _adminInfoLoaded = false;

  @override
  void initState() {
    super.initState();
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
            .collection('Admin')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            firstName = capitalizeEachWord(data['firstName'] ?? '');
            lastName = capitalizeEachWord(data['lastName'] ?? '');
            email = data['email'] ?? '';
            gender = capitalizeEachWord(data['gender'] ?? '');
            userType = capitalizeEachWord(data['userType'] ?? 'Admin');
            birthday = data['birthday'] ?? '';
            staffID = data['id']?.toString() ?? '';
            _adminInfoLoaded = true;
          });
        } else {
          setState(() => _adminInfoLoaded = true);
        }
      } else {
        setState(() => _adminInfoLoaded = true);
      }
    } catch (e) {
      print('Error fetching Admin info: $e');
      setState(() => _adminInfoLoaded = true);
    }
  }

  Future<void> logAuditAction({
    required String action,
    required String description,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      String fullName = 'Unknown';
      String email = user.email ?? 'No Email';

      final adminDoc = await FirebaseFirestore.instance.collection('Admin').doc(uid).get();
      final superAdminDoc = await FirebaseFirestore.instance.collection('SuperAdmin').doc(uid).get();

      if (adminDoc.exists) {
        final data = adminDoc.data()!;
        fullName = '${capitalizeEachWord(data['firstName'] ?? '')} ${capitalizeEachWord(data['lastName'] ?? '')}';
      } else if (superAdminDoc.exists) {
        final data = superAdminDoc.data()!;
        fullName = '${capitalizeEachWord(data['firstName'] ?? '')} ${capitalizeEachWord(data['lastName'] ?? '')}';
      }

      await FirebaseFirestore.instance.collection('AuditLogs').add({
        'performedBy': fullName,
        'email': email,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
      });
    } catch (e) {
      print('Audit log failed: $e');
    }
  }

  Future<void> deleteCSV(BuildContext context, String fileName, String docId, String csvDocId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final csvDataDocRef = firestore.collection('CsvData').doc(csvDocId);
      final uploadedFileDocRef = firestore.collection('UploadedFiles').doc(docId);

      batch.delete(csvDataDocRef);
      batch.delete(uploadedFileDocRef);

      await batch.commit();

      await logAuditAction(
        action: 'Delete CSV File',
        description: 'Deleted CSV file "$fileName".',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'CSV file deleted successfully.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error deleting CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete CSV: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName';
    // Loader screen covers everything until _adminInfoLoaded
    if (!_adminInfoLoaded) {
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
        activePage: "Chatbot Files",
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: primarycolordark),
        elevation: 0,
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            "Chatbot Files",
            style: TextStyle(
              color: primarycolordark,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
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
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              UploadBox(logAuditAction: logAuditAction),
              const SizedBox(height: 30),
              FileTableCard(
                searchQuery: searchQuery,
                onSearchChanged: (value) => setState(() => searchQuery = value),
                onDeleteCSV: (fileName, docId, csvDocId) {
                  deleteCSV(context, fileName, docId, csvDocId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UploadBox extends StatefulWidget {
  final Future<void> Function({required String action, required String description}) logAuditAction;

  const UploadBox({super.key, required this.logAuditAction});

  @override
  State<UploadBox> createState() => _UploadBoxState();
}

class _UploadBoxState extends State<UploadBox> {
  String status = '';
  bool isUploading = false;
  String uploaderName = '';
  String uploaderEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUploaderInfo();
  }

  Future<void> _loadUploaderInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('Admin')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          uploaderName =
            '${capitalizeEachWord(data['firstName'] ?? '')} ${capitalizeEachWord(data['lastName'] ?? '')}';
          uploaderEmail = data['email'] ?? '';
        });
      }
    }
  }

  Future<void> uploadCSV() async {
    setState(() {
      isUploading = true;
      status = 'Uploading CSV...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() {
          status = 'No file selected.';
          isUploading = false;
        });
        return;
      }

      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      final baseName = fileName.split('.').first;

      // ---- DUPLICATE CHECK: Prevent uploading if fileName already exists ----
      final existing = await FirebaseFirestore.instance
          .collection('UploadedFiles')
          .where('fileName', isEqualTo: fileName)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() {
          status = 'A file named "$fileName" already exists. Please delete it first or rename your file.';
          isUploading = false;
        });
        return;
      }
      // ---- END DUPLICATE CHECK ----

      final csvString = utf8.decode(fileBytes);
      final csvTable = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (csvTable.isEmpty || csvTable.length < 2) {
        setState(() {
          status = 'CSV is empty or missing data rows.';
          isUploading = false;
        });
        return;
      }

      final headers = csvTable.first.map((e) => e.toString().toLowerCase()).toList();
      final questionIndex = headers.indexWhere((h) => h.trim() == 'question');
      final answerIndex = headers.indexWhere((h) => h.trim() == 'answer');
      final languageIndex = headers.indexWhere((h) => h.trim() == 'language' || h.trim() == 'category');

      if (questionIndex == -1 || answerIndex == -1) {
        throw Exception('CSV must contain "question" and "answer" columns.');
      }

      final dataList = <Map<String, dynamic>>[];

      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length <= answerIndex) continue;

        final question = row[questionIndex].toString().trim().replaceAll('\\n', '\n');
        final answer = row[answerIndex].toString().trim().replaceAll('\\n', '\n');
        final language = (languageIndex != -1 && languageIndex < row.length)
            ? row[languageIndex].toString().trim()
            : '';

        if (question.isNotEmpty && answer.isNotEmpty) {
          dataList.add({
            'question': question,
            'answer': answer,
            'language': language,
          });
        }
      }

      if (dataList.isEmpty) {
        setState(() {
          status = 'CSV has no valid entries.';
          isUploading = false;
        });
        return;
      }

      // Save the chatbot data to CsvData collection
      await FirebaseFirestore.instance.collection('CsvData').doc(baseName).set({
        'fileName': fileName,
        'data': dataList,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      // Save metadata in UploadedFiles collection
      await FirebaseFirestore.instance.collection('UploadedFiles').add({
        'fileName': fileName,
        'fileSize': '${(fileBytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
        'timestamp': FieldValue.serverTimestamp(),
        'uploaderName': uploaderName,
        'uploaderEmail': uploaderEmail,
        'csvDocId': baseName,
      });

      // Audit log entry
      await widget.logAuditAction(
        action: 'Add CSV Files',
        description: 'Uploaded CSV "$fileName" with ${dataList.length} entries.',
      );

      setState(() {
        status = '${dataList.length} entries uploaded from "$fileName".';
        isUploading = false;
      });
    } catch (e) {
      print('Upload error: $e');
      setState(() {
        status = 'Upload failed: ${e.toString()}';
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : uploadCSV,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: secondarycolor, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 48, color: secondarycolor),
            const SizedBox(height: 12),
            RichText(
              text: const TextSpan(
                text: 'Click here ',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: secondarycolor),
                children: [
                  TextSpan(
                    text: 'to upload your file or drag.',
                    style: TextStyle(
                        fontWeight: FontWeight.normal, color: dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Supported Format: CSV only (Max 10MB)',
              style: TextStyle(color: dark, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              status,
              style: const TextStyle(fontSize: 14, color: dark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FileTableCard extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final void Function(String fileName, String docId, String csvDocId) onDeleteCSV;

  const FileTableCard({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onDeleteCSV,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 700;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('UploadedFiles')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final files = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final fileName = data['fileName']?.toLowerCase() ?? '';
              final uploaderName = data['uploaderName']?.toLowerCase() ?? '';
              return fileName.contains(searchQuery.toLowerCase()) ||
                  uploaderName.contains(searchQuery.toLowerCase());
            }).toList();

            // Card container with header and table, but only the table content changes
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primarycolordark,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    spreadRadius: 2,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header and Search Row
                  isSmallScreen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "Attached Files",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: primarycolordark),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: secondarycolor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${files.length} Total",
                                    style: TextStyle(
                                      color: secondarycolor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Only CSV files are allowed. Manage your uploaded files here.",
                              style: TextStyle(fontSize: 13, color: dark),
                            ),
                            const SizedBox(height: 12),
                            _buildSearchBar(fullWidth: true),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        "Attached Files",
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: primarycolordark),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: secondarycolor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "${files.length} Total",
                                          style: TextStyle(
                                            color: secondarycolor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Only CSV files are allowed. Manage your uploaded files here.",
                                    style: TextStyle(fontSize: 13, color: dark),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildSearchBar(),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),
                  // Table Header for desktop
                  if (!isSmallScreen)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: primarycolordark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text("File Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Expanded(child: Text("File Size", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Expanded(child: Text("Uploaded At", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text("Uploaded By", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Expanded(child: Text("Actions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  if (!isSmallScreen) const SizedBox(height: 12),
                  // Table/List content
                  files.isEmpty
                      // === EMPTY STATE ===
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 40 : 60),
                          child: Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  "assets/images/web-search.png",
                                  width: 140,
                                  height: 140,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "No files to show.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'Poppins',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      // === END EMPTY STATE PART ===
                      : Column(
                          children: files.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final fileName = data['fileName'] ?? 'Unnamed.csv';
                            final fileSize = data['fileSize'] ?? 'N/A';
                            final uploaderName = data['uploaderName'] ?? 'Unknown';
                            final uploaderEmail = data['uploaderEmail'] ?? '';
                            final timestamp = data['timestamp'] as Timestamp?;
                            final formattedDate = timestamp != null
                                ? DateFormat.yMMMMd().format(timestamp.toDate())
                                : 'Unknown';
                            final csvDocId = data['csvDocId'] ?? fileName.split('.').first;

                            if (isSmallScreen) {
                              // Card for mobile
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // File Name
                                      Row(
                                        children: [
                                          const Icon(Icons.insert_drive_file, color: secondarycolor, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              fileName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: dark,
                                                fontFamily: 'Poppins',
                                                fontSize: 16,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _infoRow("File Size", fileSize),
                                      _infoRow("Uploaded At", formattedDate),
                                      // Uploaded By & Email + Delete button AT THE BOTTOM
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Uploaded by:",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: dark,
                                                fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: secondarycolor,
                                                child: Text(
                                                  uploaderName.isNotEmpty
                                                      ? uploaderName[0].toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    uploaderName,
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        color: dark),
                                                  ),
                                                  Text(
                                                    uploaderEmail,
                                                    style: const TextStyle(
                                                        color: dark, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Container(
                                                width: 35,
                                                height: 35,
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                                  tooltip: 'Delete file',
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        backgroundColor: lightBackground,
                                                        title: const Text(
                                                          'Delete Confirmation',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: primarycolordark,
                                                          ),
                                                        ),
                                                        content: Text(
                                                          'Are you sure you want to delete the CSV file "$fileName"? This action cannot be undone.',
                                                          style: const TextStyle(
                                                            fontFamily: 'Poppins',
                                                            color: dark,
                                                          ),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.of(context).pop(),
                                                            child: const Text(
                                                              'Cancel',
                                                              style: TextStyle(color: primarycolordark),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            style: TextButton.styleFrom(
                                                              backgroundColor: Colors.red,
                                                              fixedSize: const Size(80, 35),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                            ),
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                              onDeleteCSV(fileName, doc.id, csvDocId);
                                                            },
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              // Table row for desktop
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.insert_drive_file,
                                              color: secondarycolor),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              fileName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: dark,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        fileSize,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: dark,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: dark,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: secondarycolor,
                                            child: Text(
                                              uploaderName.isNotEmpty
                                                  ? uploaderName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(uploaderName,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: primarycolordark)),
                                              Text(uploaderEmail,
                                                  style: const TextStyle(
                                                      color: dark, fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 35,
                                            height: 35,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                              tooltip: 'Delete file',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    backgroundColor: lightBackground,
                                                    title: const Text(
                                                      'Delete Confirmation',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: primarycolordark,
                                                      ),
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to delete the CSV file "$fileName"? This action cannot be undone.',
                                                      style: const TextStyle(
                                                        fontFamily: 'Poppins',
                                                        color: dark,
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.of(context).pop(),
                                                        child: const Text(
                                                          'Cancel',
                                                          style: TextStyle(color: primarycolordark),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        style: TextButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          fixedSize: const Size(80, 35),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                        ),
                                                        onPressed: () {
                                                          Navigator.of(context).pop();
                                                          onDeleteCSV(fileName, doc.id, csvDocId);
                                                        },
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
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
                                  ],
                                ),
                              );
                            }
                          }).toList(),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar({bool fullWidth = false}) {
    return Container(
      height: 42,
      width: fullWidth ? double.infinity : 280,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: lightBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primarycolordark),
      ),
      alignment: Alignment.center,
      child: TextField(
        onChanged: onSearchChanged,
        style: const TextStyle(
          fontSize: 14,
          color: dark,
          fontFamily: 'Poppins',
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, size: 18, color: primarycolor),
          hintText: "Search by file name or uploader...",
          hintStyle: TextStyle(fontSize: 14, color: dark, fontFamily: 'Poppins'),
          contentPadding: EdgeInsets.symmetric(vertical: 10),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 1),
      child: Row(
        children: [
          Text("$label: ",
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: dark, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: dark,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
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