// lib/settings.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import notification service.
import 'notification_service.dart';
// Import the DateTimeComponents enum from flutter_local_notifications.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
// Import BottomCurveClipper from sakumlapa.dart.
import 'sakumlapa.dart' show BottomCurveClipper;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = false;
  String _notificationFrequency =
      'Daily'; // Options: 'Daily', 'Every 2 days', 'Weekly'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load existing settings from Firestore.
  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (doc.exists) {
          setState(() {
            _notificationsEnabled = doc.get('notificationsEnabled') ?? false;
            _notificationFrequency =
                doc.get('notificationFrequency') ?? 'Daily';
          });
        }
      } catch (e) {
        print('Error loading settings: $e');
      }
    }
  }

  // Save the settings to Firestore and update local notifications.
  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'notificationsEnabled': _notificationsEnabled,
              'notificationFrequency': _notificationFrequency,
            });
        // After saving settings, update the local notifications.
        await _updateNotifications();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Iestatījumi saglabāti!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neizdevās saglabāt iestatījumus')),
        );
        print('Error saving settings: $e');
      }
    }
  }

  /// Cancels any previously scheduled notifications and schedules a new one based on the chosen frequency.
  /// Also checks if the user has submitted today's work log.
  Future<void> _updateNotifications() async {
    // Cancel any existing notifications.
    await NotificationService.flutterLocalNotificationsPlugin.cancelAll();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if the user has submitted today's work hours.
    final String todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    DocumentSnapshot todayLog =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('workLogs')
            .doc(todayDocId)
            .get();

    // If a work log exists for today, do not schedule a notification.
    if (todayLog.exists) {
      print("Work log for today exists; no notification scheduled.");
      return;
    }

    // If notifications are disabled, do nothing.
    if (!_notificationsEnabled) return;

    DateTime now = DateTime.now();
    // Set baseTime to 6:00 PM local time.
    DateTime baseTime = DateTime(now.year, now.month, now.day, 18);
    DateTime scheduledTime;
    if (now.isAfter(baseTime)) {
      scheduledTime = baseTime.add(const Duration(days: 1));
    } else {
      scheduledTime = baseTime;
    }

    DateTimeComponents? matchComponents;
    if (_notificationFrequency == 'Daily') {
      matchComponents = DateTimeComponents.time;
    } else if (_notificationFrequency == 'Every 2 days') {
      scheduledTime = baseTime.add(const Duration(days: 2));
      matchComponents = null;
    } else if (_notificationFrequency == 'Weekly') {
      scheduledTime = baseTime.add(const Duration(days: 7));
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    } else {
      // Default to daily.
      matchComponents = DateTimeComponents.time;
    }

    print(
      "Updating notifications: scheduled for $scheduledTime with frequency $_notificationFrequency",
    );
    await NotificationService.scheduleNotification(
      id: 0,
      title: 'Atgādinājums',
      body: 'Nepalaid garām pieteikt savas darba stundas!',
      scheduledNotificationDateTime: scheduledTime,
      matchDateTimeComponents: matchComponents,
    );

    // Check if the notifications subcollection is empty (i.e. first notification).
    QuerySnapshot notifSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .limit(1)
            .get();
    if (notifSnapshot.docs.isEmpty) {
      // Automatically create the notifications subcollection with the first notification document.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
            'title': 'Atgādinājums',
            'body': 'Nepalaid garām pieteikt savas darba stundas!',
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
    }
  }

  /// Builds the notification icon with badge.
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

  // Custom curved AppBar.
  PreferredSizeWidget _buildCustomAppBar(String title, double screenWidth) {
    return PreferredSize(
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
            title: Text(
              title,
              style: TextStyle(
                fontSize: screenWidth * 0.06,
                letterSpacing: 1.2,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            toolbarHeight: screenWidth * 0.18,
            actions: [
              Padding(
                padding: EdgeInsets.only(right: screenWidth * 0.05),
                child: _buildNotificationIcon(screenWidth * 0.08),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 192, 192, 192),
      appBar: _buildCustomAppBar('Iestatījumi', screenWidth),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle for notifications.
            Text(
              'Ieslēgt paziņojumus:',
              style: TextStyle(
                fontSize: screenWidth * 0.05,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Ieslēgt paziņojumus',
                style: TextStyle(color: Colors.black),
              ),
              value: _notificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              activeColor: const Color(0xFF24562B),
            ),
            SizedBox(height: screenWidth * 0.05),
            // Dropdown for notification frequency.
            Text(
              'Paziņojumu biežums:',
              style: TextStyle(
                fontSize: screenWidth * 0.05,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            DropdownButton<String>(
              value: _notificationFrequency,
              onChanged: (String? newValue) {
                setState(() {
                  _notificationFrequency = newValue!;
                });
              },
              dropdownColor: Colors.white,
              style: TextStyle(color: Colors.black),
              items:
                  <String>[
                    'Daily',
                    'Every 2 days',
                    'Weekly',
                  ].map<DropdownMenuItem<String>>((String value) {
                    String displayText;
                    switch (value) {
                      case 'Daily':
                        displayText = 'Katru dienu';
                        break;
                      case 'Every 2 days':
                        displayText = 'Ik pēc 2 dienām';
                        break;
                      case 'Weekly':
                        displayText = 'Reizi nedēļā';
                        break;
                      default:
                        displayText = value;
                    }
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(displayText),
                    );
                  }).toList(),
            ),
            SizedBox(height: screenWidth * 0.05),
            // Save Settings Button.
            Center(
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(screenWidth * 0.8, 50),
                  backgroundColor: const Color(0xFF24562B),
                ),
                child: const Text(
                  'Saglabāt iestatījumus',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
