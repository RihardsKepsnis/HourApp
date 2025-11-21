import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings.dart';
import 'statistics.dart';
import 'change_password.dart';
import 'darbinieki.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = 'Ielādē...';
  String _role = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (doc.exists) {
          setState(() {
            _name = doc.get('name') ?? 'Nav norādīts';
            _role = doc.get('role') ?? '';
            _isLoading = false;
          });
        } else {
          setState(() {
            _name = 'Nav dati';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _name = 'Nav lietotāja';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _name = 'Kļūda ielādējot datus';
        _isLoading = false;
      });
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: screenWidth * 0.1),
          CircleAvatar(
            radius: screenWidth * 0.2,
            backgroundImage: const NetworkImage(
              'https://via.placeholder.com/150',
            ),
          ),
          SizedBox(height: screenWidth * 0.05),
          // Lietotāja vārds
          Text(
            _name,
            style: TextStyle(
              color: const Color.fromARGB(255, 0, 0, 0),
              fontSize: screenWidth * 0.07,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          // Lietotāja e-pasts
          Text(
            FirebaseAuth.instance.currentUser?.email ?? '',
            style: TextStyle(
              color: Colors.black54,
              fontSize: screenWidth * 0.045,
            ),
          ),
          SizedBox(height: screenWidth * 0.08),
          // sarakts ar izvēlēm
          ListTile(
            leading: Icon(Icons.settings, color: const Color(0xFF24562B)),
            title: const Text(
              'Iestatījumi',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.black54,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          const Divider(color: Colors.black),
          ListTile(
            leading: Icon(Icons.bar_chart, color: const Color(0xFF24562B)),
            title: const Text(
              'Statistika',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.black54,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsPage()),
              );
            },
          ),
          const Divider(color: Colors.black),
          ListTile(
            leading: Icon(Icons.lock, color: const Color(0xFF24562B)),
            title: const Text(
              'Mainīt Paroli',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.black54,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          const Divider(color: Colors.black),
          if (_role == 'admin')
            ListTile(
              leading: Icon(Icons.group, color: const Color(0xFF24562B)),
              title: const Text(
                'Darbinieki',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.black54,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DarbiniekiPage(),
                  ),
                );
              },
            ),
          if (_role == 'admin') const Divider(color: Colors.black),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: const Color.fromARGB(255, 240, 16, 16),
            ),
            title: const Text(
              'Izrakstīties',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 240, 16, 16),
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text(
                        'Vai tiešām vēlaties izrakstīties?',
                        style: TextStyle(color: Colors.white),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Atcelt',
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.pushReplacementNamed(context, '/');
                          },
                          child: const Text(
                            'Izrakstīties',
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 248, 248),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}
