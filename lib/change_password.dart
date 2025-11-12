import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Iliektais, augšējais nav bar
class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 15);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 15,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;

  /// Updates the user's password in Firebase Auth.
  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Optionally, reauthenticate the user here if needed.
        await user.updatePassword(_newPasswordController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password successfully changed!')),
        );

        // Clear the fields.
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        Navigator.pop(context); // Return to previous screen.
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = '';
      if (e.code == 'weak-password') {
        errorMessage = 'The new password is too weak.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please reauthenticate and try again.';
      } else {
        errorMessage = 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Builds the notification icon with an unread count badge.
  Widget _buildNotificationIcon(double size) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return Icon(Icons.notifications, size: size);
    final notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false);
    return StreamBuilder<QuerySnapshot>(
      stream: notificationsRef.snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications, size: size),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      // Custom curved AppBar.
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenWidth * 0.24),
        child: ClipPath(
          clipper: BottomCurveClipper(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF24562B), Color(0xFF1C4F21)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Paroles maiņa'),
              centerTitle: true,
              elevation: 0,
              toolbarHeight: screenWidth * 0.18,
              actions: [
                Padding(
                  padding: EdgeInsets.only(right: screenWidth * 0.05),
                  child: IconButton(
                    icon: _buildNotificationIcon(screenWidth * 0.08),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const NotificationsPopup(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 192, 192, 192),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Current Password Field.
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Esošā parole',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  const SizedBox(height: 20),
                  // New Password Field.
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Jaunā parole',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  const SizedBox(height: 20),
                  // Confirm New Password Field.
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Apstiprināt jauno paroli',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: _changePassword,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 80,
                            vertical: 15,
                          ),
                          backgroundColor: const Color(0xFF24562B),
                        ),
                        child: const Text(
                          'Mainīt paroli',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// NotificationsPopup widget displays new notifications in a pop-up dialog.
class NotificationsPopup extends StatefulWidget {
  const NotificationsPopup({super.key});

  @override
  _NotificationsPopupState createState() => _NotificationsPopupState();
}

class _NotificationsPopupState extends State<NotificationsPopup> {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AlertDialog(
        title: const Text("Paziņojumi"),
        content: const Text("Lietotājs nav pieslēdzies."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Aizvērt"),
          ),
        ],
      );
    }
    final notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications');
    return AlertDialog(
      title: const Text("Paziņojumi"),
      content: Container(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream:
              notificationsRef
                  .where('read', isEqualTo: false)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text("Kļūda ielādējot paziņojumus.");
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Text("Nav jaunu paziņojumu.");
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final title = data['title'] ?? 'Paziņojums';
                final body = data['body'] ?? '';
                return ListTile(
                  title: Text(title),
                  subtitle: Text(body),
                  trailing: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () async {
                      await notificationsRef.doc(docs[index].id).update({
                        'read': true,
                      });
                      setState(() {});
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Aizvērt"),
        ),
      ],
    );
  }
}
