import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'AdminEditWorkerHoursPage.dart'; // Import your editing screen

/// Custom Clipper for a curved AppBar.
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

/// This page displays monthly summary statistics for a worker and allows exporting a CSV.
class WorkerStatisticsPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const WorkerStatisticsPage({
    Key? key,
    required this.employeeId,
    required this.employeeName,
  }) : super(key: key);

  @override
  _WorkerStatisticsPageState createState() => _WorkerStatisticsPageState();
}

class _WorkerStatisticsPageState extends State<WorkerStatisticsPage> {
  bool _isLoading = true;
  double _totalHours = 0.0;
  double _averageHours = 0.0;
  List<Map<String, dynamic>> _dailyStats = [];
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final Color primaryColor = const Color(0xFF24562B);
  final Color secondaryColor = const Color(0xFFBDBDBD);

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    setState(() {
      _isLoading = true;
      _dailyStats.clear();
      _totalHours = 0.0;
    });
    try {
      // Determine the first and last day of the selected month.
      DateTime startDate = DateTime(_selectedYear, _selectedMonth, 1);
      DateTime endDate = DateTime(_selectedYear, _selectedMonth + 1, 0);
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.employeeId)
              .collection('workLogs')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              )
              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
              .get();

      double totalHours = 0.0;
      // Map to hold data grouped by date string.
      Map<String, Map<String, dynamic>> dailyData = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        Timestamp ts = data['date'];
        DateTime logDate = ts.toDate();
        String dateStr = DateFormat('dd.MM.yyyy').format(logDate);
        // If status (like sick or holiday) set at top-level, record and skip hours.
        if (data.containsKey("status") &&
            ((data["status"] as String).toLowerCase() == "slimība" ||
                (data["status"] as String).toLowerCase() == "atvaļinājums")) {
          dailyData[dateStr] = {
            'status': (data['status'] as String).toLowerCase(),
          };
        } else {
          // Sum hours across all organization/city entries.
          List<dynamic> entries = data['entries'] as List<dynamic>? ?? [];
          double dayHours = 0.0;
          List<dynamic> tasks = [];
          for (var entry in entries) {
            List<dynamic> entryTasks = entry['tasks'] as List<dynamic>? ?? [];
            for (var task in entryTasks) {
              double hours = 0.0;
              if (task['hours'] is int) {
                hours = (task['hours'] as int).toDouble();
              } else if (task['hours'] is double) {
                hours = task['hours'] as double;
              }
              dayHours += hours;
              // Preserve the task map for CSV export if needed.
              tasks.add(task);
            }
          }
          // If a status was already recorded, skip overriding it.
          if (dailyData.containsKey(dateStr) &&
              dailyData[dateStr]!.containsKey('status')) {
            // do nothing; status takes precedence
          } else {
            dailyData[dateStr] = {'hours': dayHours, 'tasks': tasks};
            totalHours += dayHours;
          }
        }
      }
      int daysCount = endDate.day;
      double average = daysCount > 0 ? totalHours / daysCount : 0.0;
      List<Map<String, dynamic>> dailyStats = [];
      // Prepare daily stats for each day in the month.
      for (int d = 1; d <= daysCount; d++) {
        DateTime day = DateTime(_selectedYear, _selectedMonth, d);
        String dayStr = DateFormat('dd.MM.yyyy').format(day);
        if (dailyData.containsKey(dayStr) &&
            dailyData[dayStr]!.containsKey('status')) {
          dailyStats.add({
            'date': dayStr,
            'status': dailyData[dayStr]!['status'],
          });
        } else {
          double hours =
              dailyData.containsKey(dayStr)
                  ? (dailyData[dayStr]!['hours'] as double)
                  : 0.0;
          List<dynamic> tasks =
              dailyData.containsKey(dayStr)
                  ? dailyData[dayStr]!['tasks'] as List<dynamic>
                  : [];
          dailyStats.add({'date': dayStr, 'hours': hours, 'tasks': tasks});
        }
      }
      setState(() {
        _totalHours = totalHours;
        _averageHours = average;
        _dailyStats = dailyStats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching worker statistics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<DropdownMenuItem<int>> _buildYearDropdownItems() {
    List<int> years = [];
    int currentYear = DateTime.now().year;
    for (int y = 2020; y <= currentYear + 1; y++) {
      years.add(y);
    }
    return years.map((year) {
      return DropdownMenuItem<int>(value: year, child: Text(year.toString()));
    }).toList();
  }

  List<DropdownMenuItem<int>> _buildMonthDropdownItems() {
    List<int> months = List.generate(12, (index) => index + 1);
    return months.map((month) {
      return DropdownMenuItem<int>(
        value: month,
        child: Text(DateFormat.MMMM('lv_LV').format(DateTime(0, month))),
      );
    }).toList();
  }

  /// Build a custom curved AppBar with a notification icon.
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
                padding: const EdgeInsets.only(right: 20.0),
                child: IconButton(
                  padding: const EdgeInsets.only(left: 0),
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

  /// Helper method to build a notification icon with an unread count badge.
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

  /// Export CSV: generate a CSV summary of the month with detailed daily tasks and an overall summary.
  Future<void> _exportCSV() async {
    List<List<dynamic>> rows = [];
    // CSV header.
    rows.add(['Date', 'Task', 'Hours']);
    // For each day, output each task or the status.
    for (var dayStat in _dailyStats) {
      String date = dayStat['date'];
      if (dayStat.containsKey('status')) {
        rows.add([
          date,
          dayStat['status'] == 'slimība' ? 'Slimības' : 'Atvaļinājums',
          '',
        ]);
      } else {
        List<dynamic> tasks = dayStat['tasks'];
        if (tasks.isNotEmpty) {
          for (var task in tasks) {
            rows.add([date, task['task'], task['hours'].toString()]);
          }
        } else {
          rows.add([date, 'No Tasks', '0']);
        }
      }
    }
    // Overall summary rows.
    rows.add([]);
    rows.add(['Overall Total Hours', _totalHours.toStringAsFixed(1)]);
    rows.add(['Overall Average Hours/Day', _averageHours.toStringAsFixed(1)]);
    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    String workerName = widget.employeeName.toLowerCase().replaceAll(' ', '_');
    final path = '${directory.path}/${workerName}_menesiskopsavilkums.csv';
    final file = File(path);
    await file.writeAsString(csv);
    final XFile xfile = XFile(path);
    await Share.shareXFiles([xfile], text: 'Monthly Summary CSV');
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (_isLoading) {
      return Scaffold(
        appBar: _buildCustomAppBar(
          'Statistika: ${widget.employeeName}',
          screenWidth,
        ),
        backgroundColor: const Color.fromARGB(255, 192, 192, 192),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: _buildCustomAppBar(
        'Statistika: ${widget.employeeName}',
        screenWidth,
      ),
      backgroundColor: const Color.fromARGB(255, 192, 192, 192),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          children: [
            // Dropdowns for Year and Month.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<int>(
                  value: _selectedYear,
                  items: _buildYearDropdownItems(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedYear = value;
                      });
                      _fetchStatistics();
                    }
                  },
                  dropdownColor: Colors.white,
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.045,
                  ),
                ),
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: _buildMonthDropdownItems(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedMonth = value;
                      });
                      _fetchStatistics();
                    }
                  },
                  dropdownColor: Colors.white,
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.045,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenWidth * 0.03),
            // Summary using Wrap.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 10,
              children: [
                Text(
                  'Total Hours: ${_totalHours.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  'Average Hours/Day: ${_averageHours.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenWidth * 0.03),
            // Export CSV button.
            Center(
              child: ElevatedButton.icon(
                onPressed: _exportCSV,
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  'Export CSV',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
            // Daily stats list with tap-to-edit.
            Expanded(
              child: ListView.builder(
                itemCount: _dailyStats.length,
                itemBuilder: (context, index) {
                  final dayStat = _dailyStats[index];
                  // Decide what to display on the right side.
                  String displayText;
                  if (dayStat.containsKey('status')) {
                    displayText =
                        dayStat['status'] == 'slimība'
                            ? 'Slimības'
                            : 'Atvaļinājums';
                  } else {
                    displayText = '${dayStat['hours'].toStringAsFixed(1)} h';
                  }
                  return InkWell(
                    onTap: () {
                      DateTime parsedDate = DateFormat(
                        'dd.MM.yyyy',
                      ).parse(dayStat['date']);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => AdminEditWorkerHoursPage(
                                workerId: widget.employeeId,
                                workerName: widget.employeeName,
                                initialDate: parsedDate,
                              ),
                        ),
                      );
                    },
                    child: Card(
                      color: primaryColor,
                      child: Padding(
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dayStat['date'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.045,
                              ),
                            ),
                            Text(
                              displayText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.045,
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// NotificationsPopup widget displays unread notifications.
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
        .collection('notifications')
        .where('read', isEqualTo: false);

    return AlertDialog(
      title: const Text("Paziņojumi"),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream:
              notificationsRef
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
                final timestamp = data['timestamp'] as Timestamp?;
                final date =
                    timestamp != null ? timestamp.toDate() : DateTime.now();
                final formattedDate = DateFormat(
                  'dd.MM.yyyy HH:mm',
                ).format(date);
                return ListTile(
                  title: Text(title),
                  subtitle: Text(body),
                  trailing: Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 12),
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
