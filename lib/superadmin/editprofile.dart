import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
      .map((word) => word.isNotEmpty
          ? '${word[0].toUpperCase()}${word.substring(1)}'
          : '')
      .join(' ');
}

class EditAdminProfilePage extends StatefulWidget {
  @override
  _EditAdminProfilePageState createState() =>
      _EditAdminProfilePageState();
}

class _EditAdminProfilePageState
    extends State<EditAdminProfilePage> {
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
          _firstNameController.text = capitalizeEachWord(data['firstName'] ?? '');
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
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

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
        request.files.add(
          await http.MultipartFile.fromPath('file', picked.path),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final resData = await response.stream.bytesToString();
        final jsonData = json.decode(resData);
        final imageUrl = jsonData['secure_url'];

        setState(() {
          _profileImageUrl = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded! Click Save Changes to apply.'),
            backgroundColor: primarycolor,
          ),
        );
      } else {
        throw Exception('Upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .doc(user.uid)
          .update({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'gender': gender,
        'userType': 'Super Admin',
        'profilePicture': _profileImageUrl ?? '',
      });
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
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
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
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Update Your Information",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primarycolordark,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField("First Name", _firstNameController),
                      _buildTextField("Last Name", _lastNameController),
                      _buildTextField("Birthday", _birthdayController),
                      _buildDropdown(
                        "Gender",
                        gender,
                        ["Female", "Male", "Other"],
                        (value) {
                          if (value != null) {
                            setState(() => gender = value);
                          }
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Profile successfully updated"),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: primarycolor,
                                ),
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
                        label: const Text("Save Changes"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primarycolordark,
                          foregroundColor: Colors.white,
                          textStyle:
                              const TextStyle(fontFamily: 'Poppins'),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontFamily: 'Poppins',
          color: dark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: dark, fontWeight: FontWeight.w500),
          floatingLabelStyle: const TextStyle(
            color: primarycolordark,
            fontWeight: FontWeight.bold,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: secondarycolor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: primarycolordark, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.6),
          ),
          errorStyle: const TextStyle(
            fontSize: 12,
            fontFamily: 'Poppins',
            color: Colors.redAccent,
            fontWeight: FontWeight.w500,
          ),
        ),
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged, {
    Map<String, IconData>? iconItems,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Poppins', color: dark),
          filled: true,
          fillColor: lightBackground,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: primarycolordark),
        dropdownColor: lightBackground,
        style: const TextStyle(fontFamily: 'Poppins', color: dark),
        items: options.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Row(
              children: [
                if (iconItems != null && iconItems.containsKey(type))
                  Icon(iconItems[type], size: 20, color: primarycolordark),
                const SizedBox(width: 8),
                Text(type),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}