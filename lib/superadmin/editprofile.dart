import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'profile.dart';

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
      .map((word) =>
          word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
      .join(' ');
}

class EditAdminProfilePage extends StatefulWidget {
  @override
  _EditAdminProfilePageState createState() => _EditAdminProfilePageState();
}

class _EditAdminProfilePageState extends State<EditAdminProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthdayController = TextEditingController();
  String gender = 'Female';
  bool _adminInfoLoaded = false;
  String? _profileImageUrl;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadSuperAdminInfo();
  }

  Future<void> _loadSuperAdminInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _firstNameController.text =
              capitalizeEachWord(data['firstName'] ?? '');
          _lastNameController.text = capitalizeEachWord(data['lastName'] ?? '');
          _birthdayController.text = data['birthday'] ?? '';
          gender = data['gender'] ?? 'Female';
          _profileImageUrl = data['profilePicture'];
          _adminInfoLoaded = true;
        });
      } else {
        setState(() => _adminInfoLoaded = true);
      }
    } else {
      setState(() => _adminInfoLoaded = true);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (picked == null) return;

    const cloudName = "dvfwzl6gp";
    const uploadPreset = "university_logo_preset";
    final uploadUrl =
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    try {
      var request = http.MultipartRequest('POST', uploadUrl)
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: picked.name),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', picked.path));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final resData = await response.stream.bytesToString();
        final jsonData = json.decode(resData);
        final imageUrl = jsonData['secure_url'];

        setState(() {
          _profileImageUrl = imageUrl;
        });

        _showFloatingSnackBar(
          message: 'Image uploaded! Click Save Changes to apply.',
          background: primarycolor,
          textColor: Colors.black,
        );
      } else {
        throw Exception('Upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      _showFloatingSnackBar(
        message: 'Error: $e',
        background: Colors.redAccent,
      );
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('SuperAdmin').doc(user.uid).update({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'gender': gender,
        'userType': 'Super Admin',
        'profilePicture': _profileImageUrl ?? '',
      });
    }
  }

  void _showFloatingSnackBar({
    required String message,
    Color background = primarycolor,
    Color textColor = Colors.white,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: textColor),
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _selectDate() async {
    FocusScope.of(context).unfocus();

    await Future.delayed(const Duration(milliseconds: 50));

    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 25));
    final parsed = _parseDateFromString(_birthdayController.text);
    if (parsed != null) {
      initialDate = parsed;
    }

    final now = DateTime.now();
    if (initialDate.isAfter(now)) initialDate = now;

    DateTime? pickedDate;
    try {
      pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1900),
        lastDate: now,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: primarycolordark,
                onPrimary: Colors.white,
                onSurface: dark,
              ),
            ),
            child: child!,
          );
        },
      );
    } catch (err, stack) {
      debugPrint('showDatePicker failed with error: $err\n$stack');
      try {
        pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(1900),
          lastDate: now,
        );
      } catch (err2, stack2) {
        debugPrint('Fallback showDatePicker also failed: $err2\n$stack2');
        pickedDate = null;
      }
    }

    if (!mounted) return;

    if (pickedDate != null) {
      setState(() {
        _birthdayController.text = DateFormat('MM/dd/yyyy').format(pickedDate!);
      });
    }
  }

  DateTime? _parseDateFromString(String? input) {
    if (input == null || input.trim().isEmpty) return null;

    final cleaned = input.trim();

    // Try multiple known formats
    for (final format in [
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
    ]) {
      try {
        return DateFormat(format).parseStrict(cleaned);
      } catch (_) {}
    }

    try {
      return DateTime.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        iconTheme: const IconThemeData(color: primarycolordark),
        backgroundColor: lightBackground,
        elevation: 1,
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: lightBackground,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (_profileImageUrl != null
                                      ? NetworkImage(_profileImageUrl!)
                                      : const AssetImage('assets/default_avatar.png'))
                                      as ImageProvider,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: primarycolor,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.camera_alt, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Update Your Information",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primarycolordark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField("First Name", _firstNameController),
                      _buildTextField("Last Name", _lastNameController),
                      _buildBirthdayField("Birthday", _birthdayController),
                      _buildDropdown(
                        "Gender",
                        gender,
                        ["Female", "Male", "Other"],
                        (value) {
                          if (value != null) setState(() => gender = value);
                        },
                        iconItems: {
                          "Female": Icons.female,
                          "Male": Icons.male,
                          "Other": Icons.transgender,
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            await _saveProfile();
                            if (context.mounted) {
                              _showFloatingSnackBar(
                                message: "Profile successfully updated",
                                background: primarycolor,
                                textColor: Colors.black,
                              );
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminProfilePage(
                                    updatedProfileUrl: _profileImageUrl,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: Text("Save Changes", style: GoogleFonts.poppins()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primarycolordark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
        decoration: _inputDecoration(label),
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildBirthdayField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: _selectDate,
        style: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
        decoration: _inputDecoration(label).copyWith(
          suffixIcon: const Icon(Icons.calendar_today, color: primarycolordark),
        ),
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Please select your birthday' : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: GoogleFonts.poppins(color: dark, fontWeight: FontWeight.w500),
      floatingLabelStyle:
          GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.bold),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: secondarycolor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primarycolordark, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
      errorStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: Colors.redAccent,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDropdown(String label, String currentValue, List<String> options,
      ValueChanged<String?> onChanged,
      {Map<String, IconData>? iconItems}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        onChanged: onChanged,
        decoration: _inputDecoration(label),
        icon: const Icon(Icons.arrow_drop_down, color: primarycolordark),
        dropdownColor: lightBackground,
        style: GoogleFonts.poppins(color: dark),
        items: options.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Row(
              children: [
                if (iconItems != null && iconItems.containsKey(type))
                  Icon(iconItems[type], size: 20, color: primarycolordark),
                const SizedBox(width: 8),
                Text(type, style: GoogleFonts.poppins()),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}