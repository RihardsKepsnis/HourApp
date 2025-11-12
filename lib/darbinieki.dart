import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

// Import BottomCurveClipper from sakumlapa.dart.
import 'sakumlapa.dart' show BottomCurveClipper;
import 'WorkerStatisticsPage.dart' hide BottomCurveClipper;
import 'ArchivedWorkersPage.dart' hide BottomCurveClipper;

class DarbiniekiPage extends StatefulWidget {
  const DarbiniekiPage({Key? key}) : super(key: key);

  @override
  _DarbiniekiPageState createState() => _DarbiniekiPageState();
}

class _DarbiniekiPageState extends State<DarbiniekiPage> {
  final Color primaryColor = const Color(0xFF24562B);
  final Color secondaryColor = const Color(0xFFBDBDBD);
  bool isAdmin = false;
  bool isLoading = true;

  // A set to keep track of selected employee IDs.
  final Set<String> _selectedEmployeeIds = {};

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (userDoc.exists && userDoc.get('role') == 'admin') {
        setState(() {
          isAdmin = true;
          isLoading = false;
        });
      } else {
        setState(() {
          isAdmin = false;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isAdmin = false;
        isLoading = false;
      });
    }
  }

  // Toggle select all: if all employees are selected, unselect all.
  // Otherwise, select all.
  void _toggleSelectAll(List<QueryDocumentSnapshot> employees) {
    setState(() {
      if (_selectedEmployeeIds.length == employees.length) {
        _selectedEmployeeIds.clear();
      } else {
        _selectedEmployeeIds.clear();
        for (var emp in employees) {
          _selectedEmployeeIds.add(emp.id);
        }
      }
    });
  }

  // Export CSV for the current month for the selected employees.
  Future<void> _exportSelectedEmployeesCSV() async {
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = DateTime(now.year, now.month + 1, 0);
    int daysCount = endDate.day;

    // Build header rows.
    List<dynamic> headerRow1 = [""];
    List<dynamic> headerRow2 = [""];
    for (int day = 1; day <= daysCount; day++) {
      DateTime currentDate = DateTime(now.year, now.month, day);
      String dateStr =
          "${currentDate.day.toString().padLeft(2, '0')}.${currentDate.month.toString().padLeft(2, '0')}";
      String weekdayStr =
          DateFormat.EEEE("lv_LV").format(currentDate).toLowerCase();
      headerRow1.add(dateStr);
      headerRow2.add(weekdayStr);
    }
    List<List<dynamic>> csvRows = [];
    csvRows.add(headerRow1);
    csvRows.add(headerRow2);

    // For each selected employee, fetch their work logs for the current month.
    for (String empId in _selectedEmployeeIds) {
      // Fetch employee document to get the name.
      DocumentSnapshot empDoc =
          await FirebaseFirestore.instance.collection('users').doc(empId).get();
      String empName =
          empDoc.exists
              ? (empDoc.get('name') ?? 'Nav norādīts')
              : 'Nav norādīts';

      // Query workLogs for current month.
      QuerySnapshot workLogSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(empId)
              .collection('workLogs')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              )
              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
              .get();

      // Build a map with key = day (int) and value = total hours or a status string for that day.
      Map<int, dynamic> dayHoursMap = {};
      for (var doc in workLogSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        Timestamp ts = data['date'];
        DateTime logDate = ts.toDate();
        int dayNumber = logDate.day;
        if (data.containsKey('status')) {
          // Save the status; this will override any hours.
          dayHoursMap[dayNumber] = data['status'];
        } else {
          double totalHours = 0.0;
          if (data['tasks'] != null) {
            List<dynamic> tasks = data['tasks'];
            for (var task in tasks) {
              double hours = 0.0;
              if (task['hours'] is int) {
                hours = (task['hours'] as int).toDouble();
              } else if (task['hours'] is double) {
                hours = task['hours'];
              }
              totalHours += hours;
            }
          }
          if (dayHoursMap.containsKey(dayNumber)) {
            if (dayHoursMap[dayNumber] is double) {
              dayHoursMap[dayNumber] += totalHours;
            }
          } else {
            dayHoursMap[dayNumber] = totalHours;
          }
        }
      }

      // Build the CSV row for this employee.
      List<dynamic> row = [empName];
      for (int day = 1; day <= daysCount; day++) {
        dynamic value = dayHoursMap[day] ?? 0.0;
        String cell;
        if (value is String) {
          String status = value.toLowerCase();
          if (status == "slimība") {
            cell = "Slimības";
          } else if (status == "atvaļinājusm") {
            cell = "Atvaļinājums";
          } else {
            cell = value;
          }
        } else if (value is double) {
          cell = value.toStringAsFixed(1);
        } else {
          cell = "0.0";
        }
        row.add(cell);
      }
      csvRows.add(row);
    }

    // Convert rows to CSV string.
    String csv = const ListToCsvConverter().convert(csvRows);

    // Write CSV to a temporary file.
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/selected_employees_${now.month}_${now.year}.csv';
    final file = File(path);
    await file.writeAsString(csv);

    // Share the CSV file.
    final XFile xfile = XFile(path);
    await Share.shareXFiles([xfile], text: 'Current Month Hours CSV');
  }

  // Helper method to display a floating message.
  void _showMessage(
    String message, {
    Color backgroundColor = const Color(0xFF24562B),
  }) {
    TextStyle textStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: backgroundColor == Colors.red ? Colors.black : Colors.white,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: textStyle),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 50, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Opens a dialog to add a new employee.
  Future<void> _showAddEmployeeDialog() async {
    TextEditingController nameController = TextEditingController();
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();
    bool added = false;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pievienot darbinieku'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Vārds, Uzvārds',
                  ),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'E-pasts'),
                ),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Parole'),
                ),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Atkārtot paroli',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Atcelt',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    emailController.text.isNotEmpty &&
                    passwordController.text.isNotEmpty &&
                    confirmPasswordController.text.isNotEmpty) {
                  if (passwordController.text !=
                      confirmPasswordController.text) {
                    _showMessage(
                      'Paroles nesakrīt!',
                      backgroundColor: primaryColor,
                    );
                  } else {
                    bool success = await _addEmployee(
                      nameController.text,
                      emailController.text,
                      passwordController.text,
                    );
                    if (success) {
                      added = true;
                      Navigator.pop(context);
                    }
                  }
                } else {
                  _showMessage(
                    'Lūdzu, aizpildiet visus laukus!',
                    backgroundColor: primaryColor,
                  );
                }
              },
              child: const Text(
                'Pievienot',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (added) {
      _showMessage('Darbinieks pievienots!', backgroundColor: primaryColor);
    }
  }

  // Adds a new employee by creating a new user in Firebase Authentication
  // and storing extra data in Firestore with default field values.
  Future<bool> _addEmployee(String name, String email, String password) async {
    try {
      // Create new user in Firebase Auth.
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      String uid = userCredential.user!.uid;
      // Set up the Firestore document for the new user.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'accountFrozen': false,
        'archived': false,
        'notificationFrequency': '',
        'notificationsEnabled': true,
        'profilePicture': '',
        'role': 'normal',
      });
      // Optionally, sign out the new user and reauthenticate the admin.
      await FirebaseAuth.instance.signOut();
      return true;
    } catch (e) {
      _showMessage('Error creating user: $e', backgroundColor: Colors.red);
      return false;
    }
  }

  // Archives an employee by updating the 'archived' field to true.
  Future<void> _archiveEmployee(String docId) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archivēt darbinieku'),
          content: const Text('Vai tiešām vēlaties arhivēt šo darbinieku?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Atcelt'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archivēt'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'archived': true,
      });
      _showMessage('Darbinieks arhivēts', backgroundColor: primaryColor);
    }
  }

  // Toggle freezing of an employee's account.
  Future<void> _toggleFreeze(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).update({
      'accountFrozen': !currentStatus,
    });
  }

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
                padding: const EdgeInsets.only(
                  right: 20.0,
                ), // reduce right padding
                child: IconButton(
                  padding: const EdgeInsets.only(
                    left: 0,
                  ), // adjust left padding if needed
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
    );
  }

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
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Access Denied. Admins only.')),
      );
    }
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 192, 192, 192),
      appBar: _buildCustomAppBar('Darbinieki', screenWidth),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton.extended(
              backgroundColor: primaryColor,
              icon: const Icon(Icons.add),
              label: const Text(
                'Pievienot darbinieku',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _showAddEmployeeDialog,
            ),
            FloatingActionButton.extended(
              backgroundColor: primaryColor,
              icon: const Icon(Icons.archive),
              label: const Text(
                'Archivētie darbinieki',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ArchivedWorkersPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final employees = snapshot.data!.docs;
          return Column(
            children: [
              if (_selectedEmployeeIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _toggleSelectAll(employees),
                        child: Text(
                          _selectedEmployeeIds.length == employees.length
                              ? 'Unselect All'
                              : 'Select All',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                      ),
                      ElevatedButton(
                        onPressed:
                            _selectedEmployeeIds.isEmpty
                                ? null
                                : _exportSelectedEmployeesCSV,
                        child: const Text(
                          'Export CSV',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 100,
                  ),
                  itemCount: employees.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data =
                        employees[index].data() as Map<String, dynamic>;
                    final docId = employees[index].id;
                    final name = data['name'] ?? 'Nav norādīts';
                    final email = data['email'] ?? '';
                    final bool frozen = data['accountFrozen'] ?? false;
                    return Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            // Checkbox with a visible border.
                            Checkbox(
                              side: MaterialStateBorderSide.resolveWith(
                                (states) =>
                                    BorderSide(width: 1.5, color: primaryColor),
                              ),
                              activeColor: primaryColor,
                              checkColor: Colors.white,
                              value: _selectedEmployeeIds.contains(docId),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedEmployeeIds.add(docId);
                                  } else {
                                    _selectedEmployeeIds.remove(docId);
                                  }
                                });
                              },
                            ),
                            // Employee Info.
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: screenWidth * 0.045,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      color: secondaryColor,
                                      fontSize: screenWidth * 0.04,
                                    ),
                                  ),
                                  if (frozen)
                                    Text(
                                      'Konts atslēgts',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: screenWidth * 0.04,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Actions Column.
                            Column(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        frozen ? Colors.green : Colors.orange,
                                  ),
                                  onPressed: () {
                                    _toggleFreeze(docId, frozen);
                                  },
                                  child: Text(
                                    frozen ? 'Ieslēgt' : 'Atslēgt',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => WorkerStatisticsPage(
                                              employeeId: docId,
                                              employeeName: name,
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Statistika',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    _archiveEmployee(docId);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -------------------
// NotificationsPopup Widget
// -------------------
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
