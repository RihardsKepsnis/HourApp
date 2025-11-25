import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'login.dart';
import 'profile.dart';
import 'stundas.dart';
import 'kalendars.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('lv_LV', null);
  runApp(const WorkHourTrackerApp());
}

class WorkHourTrackerApp extends StatelessWidget {
  const WorkHourTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF24562B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF24562B),
          secondary: Colors.grey,
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 192, 192, 192),
        appBarTheme: const AppBarTheme(color: Color(0xFF24562B)),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF24562B),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class HomePage extends StatefulWidget {
  final String userRole;
  const HomePage({super.key, required this.userRole});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Map<String, dynamic>> _pages = [
    {'title': 'Sākumlapa', 'widget': const HomePageContent()},
    {
      'title': 'Kalendārs',
      'widget': CalendarPage(selectedDate: DateTime.now()),
    },
    {'title': 'Stundas', 'widget': StundasPage(selectedDate: DateTime.now())},
    {'title': 'Profils', 'widget': const ProfilePage()},
  ];

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
                  padding: EdgeInsets.zero,
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
    return Scaffold(
      appBar:
          _currentIndex != 2
              ? _buildCustomAppBar(_pages[_currentIndex]['title'], screenWidth)
              : null,
      body: Column(
        children: [Expanded(child: _pages[_currentIndex]['widget'])],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF24562B),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Colors.white),
            label: 'Sākumlapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            label: 'Kalendārs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time, color: Colors.white),
            label: 'Stundas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: Colors.white),
            label: 'Profils',
          ),
        ],
      ),
    );
  }
}

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

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});
  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final Color primaryColor = const Color(0xFF24562B);
  String _name = 'Ielādē...';
  bool _isUserDataLoading = true;

  double _monthlyTotalHours = 0.0;
  double _monthlyExpectedHours = 0.0;
  double _monthlyAverageHours = 0.0;
  bool _isMonthlyLoading = true;
  int _sickDaysCount = 0;
  int _workerHolidayCount = 0;

  List<BarChartGroupData> _weeklyBarGroups = [];
  bool _isChartLoading = true;

  late DateTime _selectedMonth;
  late DateTime _selectedWeekStart;

  StreamSubscription<QuerySnapshot>? _monthlySubscription;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1, 12);

    // Set current week start (Monday), keeping time consistent (midday).
    if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) {
      DateTime todayMidday = DateTime(now.year, now.month, now.day, 12);
      _selectedWeekStart = todayMidday.subtract(
        Duration(days: todayMidday.weekday - 1),
      );
    } else {
      DateTime lastDay = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      ).subtract(const Duration(days: 1));
      DateTime lastDayMidday = DateTime(
        lastDay.year,
        lastDay.month,
        lastDay.day,
        12,
      );
      _selectedWeekStart = lastDayMidday.subtract(
        Duration(days: lastDayMidday.weekday - 1),
      );
    }

    _loadUserData().then((_) {
      _fetchWeeklyWorkLogs();
      _subscribeMonthlySummary();
    });
  }

  @override
  void dispose() {
    _monthlySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
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
            _name = doc.get('name') ?? 'Nav norādīts';
            _isUserDataLoading = false;
          });
        } else {
          setState(() {
            _name = 'Nav dati';
            _isUserDataLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _name = 'Kļūda ielādējot datus';
          _isUserDataLoading = false;
        });
      }
    } else {
      setState(() {
        _name = 'Nav lietotāja';
        _isUserDataLoading = false;
      });
    }
  }

  /// WEEKLY DATA
  Future<void> _fetchWeeklyWorkLogs() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Query full days: from Monday 00:00 to Sunday 23:59:59.999
      DateTime monday = _selectedWeekStart;
      DateTime sunday = monday.add(const Duration(days: 6));

      DateTime mondayStart = DateTime(monday.year, monday.month, monday.day, 0);
      DateTime sundayEnd = DateTime(
        sunday.year,
        sunday.month,
        sunday.day,
        23,
        59,
        59,
        999,
      );

      QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('workLogs')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(mondayStart),
              )
              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(sundayEnd))
              .get();

      Map<int, double> weeklyHours = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
      Map<int, List<String>> statusPerDay = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        DateTime logDate = (data['date'] as Timestamp).toDate();
        int weekday = logDate.weekday;

        if (data.containsKey('status') && data['status'] != null) {
          String status = data['status'].toString().toLowerCase().trim();
          if (status == 'slimība' || status == 'atvaļinājums') {
            statusPerDay.putIfAbsent(weekday, () => []).add(status);
          }
        }

        double sumHours = 0.0;

        // New format: entries -> tasks
        if (data.containsKey('entries') && data['entries'] != null) {
          List<dynamic> entries = data['entries'];
          for (var entry in entries) {
            if (entry is Map<String, dynamic> &&
                entry.containsKey('tasks') &&
                entry['tasks'] != null) {
              List<dynamic> tasks = entry['tasks'];
              for (var task in tasks) {
                double hours = 0.0;
                if (task['hours'] is int) {
                  hours = (task['hours'] as int).toDouble();
                } else if (task['hours'] is double) {
                  hours = task['hours'] as double;
                }
                sumHours += hours;
              }
            }
          }
        }
        // Old format: direct tasks[]
        else if (data.containsKey('tasks') && data['tasks'] != null) {
          List<dynamic> tasks = data['tasks'];
          for (var task in tasks) {
            double hours = 0.0;
            if (task['hours'] is int) {
              hours = (task['hours'] as int).toDouble();
            } else if (task['hours'] is double) {
              hours = task['hours'] as double;
            }
            sumHours += hours;
          }
        }

        weeklyHours[weekday] = (weeklyHours[weekday] ?? 0) + sumHours;
      }

      List<BarChartGroupData> groups = [];
      Color getBarColor(double hours) {
        if (hours >= 8) {
          return Colors.green;
        } else if (hours >= 4) {
          return Colors.orange;
        } else {
          return Colors.red;
        }
      }

      for (int i = 1; i <= 7; i++) {
        double hours = weeklyHours[i] ?? 0;
        if (statusPerDay.containsKey(i) && hours < 8) hours = 8;

        Color barColor;
        if (statusPerDay.containsKey(i)) {
          List<String> statuses = statusPerDay[i]!;
          if (statuses.contains("slimība")) {
            barColor = Colors.redAccent;
          } else if (statuses.contains("atvaļinājums")) {
            barColor = Colors.blueAccent;
          } else {
            barColor = getBarColor(hours);
          }
        } else {
          barColor = getBarColor(hours);
        }

        groups.add(
          BarChartGroupData(
            x: i - 1,
            barRods: [
              BarChartRodData(
                y: hours,
                colors: [barColor],
                width: 20,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        );
      }

      setState(() {
        _weeklyBarGroups = groups;
        _isChartLoading = false;
      });
    } catch (e) {
      setState(() {
        _isChartLoading = false;
      });
    }
  }

  void _navigateWeek(int deltaWeeks) {
    DateTime potentialWeek = _selectedWeekStart.add(
      Duration(days: 7 * deltaWeeks),
    );
    if (potentialWeek.month == _selectedMonth.month) {
      setState(() {
        _selectedWeekStart = potentialWeek;
        _isChartLoading = true;
      });
      _fetchWeeklyWorkLogs();
    }
  }

  void _subscribeMonthlySummary() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    DateTime firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
      12,
    );
    DateTime lastDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    ).subtract(const Duration(days: 1));
    lastDayOfMonth = DateTime(
      lastDayOfMonth.year,
      lastDayOfMonth.month,
      lastDayOfMonth.day,
      12,
    );
    _monthlySubscription?.cancel();
    _monthlySubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('workLogs')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth),
        )
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
        .snapshots()
        .listen((snapshot) async {
          double totalWorked = 0.0;
          Map<String, List<String>> statusPerDay = {};
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            DateTime logDate = (data['date'] as Timestamp).toDate();
            String key = DateFormat('yyyy-MM-dd').format(logDate);

            if (data.containsKey('status') && data['status'] != null) {
              String status = data['status'].toString().toLowerCase().trim();
              if (status == 'slimība' || status == 'atvaļinājums') {
                statusPerDay.putIfAbsent(key, () => []).add(status);
              }
            }

            if (data['tasks'] != null) {
              List<dynamic> tasks = data['tasks'] as List<dynamic>;
              for (var task in tasks) {
                double hours =
                    task['hours'] is int
                        ? (task['hours'] as int).toDouble()
                        : task['hours'] as double;
                totalWorked += hours;
              }
            } else if (data.containsKey('entries') && data['entries'] != null) {
              for (var entry in data['entries']) {
                if (entry['tasks'] != null) {
                  for (var task in entry['tasks']) {
                    double hours =
                        task['hours'] is int
                            ? (task['hours'] as int).toDouble()
                            : task['hours'] as double;
                    totalWorked += hours;
                  }
                }
              }
            }
          }

          List<DateTime> holidays = await fetchLatvianHolidays(
            _selectedMonth.year,
          );
          int daysInMonth = lastDayOfMonth.day;
          double expectedHours = 0.0;

          for (int d = 1; d <= daysInMonth; d++) {
            DateTime day = DateTime(
              _selectedMonth.year,
              _selectedMonth.month,
              d,
            );

            bool normallyWorking =
                day.weekday >= DateTime.monday &&
                day.weekday <= DateTime.friday;

            // Special shifted working day example (10.05.2025)
            bool isShiftedWorking =
                (_selectedMonth.year == 2025 &&
                    _selectedMonth.month == 5 &&
                    d == 10);

            bool isWorkingDay = normallyWorking || isShiftedWorking;
            double dayExpected = 0.0;

            if (isWorkingDay) {
              bool isPublicHoliday = holidays.any(
                (holiday) =>
                    holiday.year == day.year &&
                    holiday.month == day.month &&
                    holiday.day == day.day,
              );
              bool workerOff = statusPerDay.containsKey(
                DateFormat('yyyy-MM-dd').format(day),
              );

              if (isPublicHoliday || workerOff) {
                dayExpected = 0.0;
              } else {
                dayExpected = 8.0;

                // Pre-holiday shortened day
                DateTime nextDay = day.add(const Duration(days: 1));

                bool nextNormallyWorking =
                    nextDay.weekday >= DateTime.monday &&
                    nextDay.weekday <= DateTime.friday;

                bool nextShiftedWorking =
                    (nextDay.year == 2025 &&
                        nextDay.month == 5 &&
                        nextDay.day == 10);

                bool nextWorking = nextNormallyWorking || nextShiftedWorking;

                bool nextPublicHoliday = holidays.any(
                  (holiday) =>
                      holiday.year == nextDay.year &&
                      holiday.month == nextDay.month &&
                      holiday.day == nextDay.day,
                );

                bool nextWorkerOff = statusPerDay.containsKey(
                  DateFormat('yyyy-MM-dd').format(nextDay),
                );

                if (nextWorking && nextPublicHoliday && !nextWorkerOff) {
                  dayExpected = 7.0;
                }
              }
            }
            expectedHours += dayExpected;
          }

          double averageHours =
              daysInMonth > 0 ? totalWorked / daysInMonth : 0.0;
          int sickDaysCount = 0;
          int workerHolidayCount = 0;
          statusPerDay.forEach((key, statuses) {
            if (statuses.contains('slimība')) sickDaysCount++;
            if (statuses.contains('atvaļinājums')) workerHolidayCount++;
          });

          setState(() {
            _monthlyTotalHours = totalWorked;
            _monthlyExpectedHours = expectedHours;
            _monthlyAverageHours = averageHours;
            _sickDaysCount = sickDaysCount;
            _workerHolidayCount = workerHolidayCount;
            _isMonthlyLoading = false;
          });
        });
  }

  /// Latvian public holidays:
  /// - Uses Nager API
  /// - Filters to "public" holidays
  /// - Does NOT move weekend holidays to Monday (Latvia does not auto-shift them)
  /// - Skips 8 March if marked as public
  Future<List<DateTime>> fetchLatvianHolidays(int year) async {
    final url = 'https://date.nager.at/api/v3/PublicHolidays/$year/LV';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> holidaysJson = jsonDecode(response.body);
      List<DateTime> holidays = [];

      for (var holiday in holidaysJson) {
        // Keep only real public holidays
        if (holiday["types"] != null && holiday["types"] is List) {
          List<dynamic> types = holiday["types"];
          List<String> lowerTypes =
              types.map((e) => e.toString().toLowerCase()).toList();
          if (!lowerTypes.contains("public")) continue;
        }

        DateTime holidayDate = DateTime.parse(holiday["date"]);

        // Ignore 8 March if provider ever marks it as public.
        if (holidayDate.month == 3 && holidayDate.day == 8) continue;

        // IMPORTANT: do NOT move Saturday/Sunday holidays to Monday.
        // Weekends are already non-working in the monthly calculation.
        holidays.add(
          DateTime(holidayDate.year, holidayDate.month, holidayDate.day),
        );
      }

      // Deduplicate and sort just in case
      holidays = holidays.toSet().toList()..sort((a, b) => a.compareTo(b));

      return holidays;
    } else {
      throw Exception("Failed to fetch holidays");
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (_isUserDataLoading || _isMonthlyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Colors.white.withOpacity(0.9),
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: screenWidth * 0.1,
                    backgroundImage: const NetworkImage(
                      'https://via.placeholder.com/150',
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.05),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.01),
                      const Text(
                        'Sveicināts atpakaļ!',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: screenWidth * 0.03),
          Card(
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Colors.white.withOpacity(0.9),
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nostrādātās stundas',
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left, color: Colors.black),
                        onPressed:
                            _selectedWeekStart
                                        .subtract(const Duration(days: 7))
                                        .month ==
                                    _selectedMonth.month
                                ? () => _navigateWeek(-1)
                                : null,
                      ),
                      Text(
                        "${DateFormat('d.MMM', 'lv_LV').format(_selectedWeekStart)} - ${DateFormat('d.MMM', 'lv_LV').format(_selectedWeekStart.add(const Duration(days: 6)))}",
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_right,
                          color: Colors.black,
                        ),
                        onPressed:
                            _selectedWeekStart
                                        .add(const Duration(days: 7))
                                        .month ==
                                    _selectedMonth.month
                                ? () => _navigateWeek(1)
                                : null,
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  _isChartLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                        height: screenWidth * 0.6,
                        child: BarChart(
                          BarChartData(
                            // Fixed, clean scale from 0 to 24 hours
                            minY: 0,
                            maxY: 24,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipBgColor: Colors.greenAccent,
                                getTooltipItem: (
                                  group,
                                  groupIndex,
                                  rod,
                                  rodIndex,
                                ) {
                                  return BarTooltipItem(
                                    '${rod.y}',
                                    TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: SideTitles(
                                showTitles: true,
                                // 0, 4, 8, 12, 16, 20, 24
                                interval: 4,
                                getTextStyles:
                                    (context, value) => TextStyle(
                                      fontSize: screenWidth * 0.045,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                reservedSize: 40,
                                margin: 10,
                                getTitles: (value) => value.toInt().toString(),
                              ),
                              topTitles: SideTitles(showTitles: false),
                              rightTitles: SideTitles(showTitles: false),
                              bottomTitles: SideTitles(
                                showTitles: true,
                                getTextStyles:
                                    (context, value) => TextStyle(
                                      fontSize: screenWidth * 0.045,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                margin: 10,
                                getTitles: (value) {
                                  switch (value.toInt()) {
                                    case 0:
                                      return 'P';
                                    case 1:
                                      return 'O';
                                    case 2:
                                      return 'T';
                                    case 3:
                                      return 'C';
                                    case 4:
                                      return 'P';
                                    case 5:
                                      return 'S';
                                    case 6:
                                      return 'Sv';
                                    default:
                                      return '';
                                  }
                                },
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            barGroups: _weeklyBarGroups,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          SizedBox(height: screenWidth * 0.03),
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Colors.white.withOpacity(0.9),
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left, color: Colors.black),
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                              1,
                              12,
                            );
                            DateTime newLastDay = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                            ).subtract(const Duration(days: 1));
                            _selectedWeekStart = newLastDay.subtract(
                              Duration(days: newLastDay.weekday - 1),
                            );
                            _isMonthlyLoading = true;
                          });
                          _subscribeMonthlySummary();
                          _fetchWeeklyWorkLogs();
                        },
                      ),
                      Text(
                        DateFormat("LLLL yyyy", "lv_LV").format(_selectedMonth),
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_right,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                              12,
                            );
                            DateTime newLastDay = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                            ).subtract(const Duration(days: 1));
                            _selectedWeekStart = newLastDay.subtract(
                              Duration(days: newLastDay.weekday - 1),
                            );
                            _isMonthlyLoading = true;
                          });
                          _subscribeMonthlySummary();
                          _fetchWeeklyWorkLogs();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  Text(
                    'Kopējās stundas: ${_monthlyTotalHours.toStringAsFixed(1)} / ${_monthlyExpectedHours.toStringAsFixed(0)} h',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.015),
                  Text(
                    'Vidējās stundas/diena: ${_monthlyAverageHours.toStringAsFixed(1)} h',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.015),
                  Text(
                    'Slimības dienas: $_sickDaysCount',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.015),
                  Text(
                    'Atvaļinājuma dienas: $_workerHolidayCount',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      content: SizedBox(
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
                final data = docs[index].data() as Map<String, dynamic>?;
                if (data == null) return const SizedBox();
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
