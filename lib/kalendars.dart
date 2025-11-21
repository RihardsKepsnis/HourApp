import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'stundas.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class CalendarPage extends StatefulWidget {
  final DateTime selectedDate;

  const CalendarPage({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  final Color primaryColor = const Color(0xFF24562B);

  late int _selectedYear;
  late int _selectedMonth;
  // Brīvdienu saraksts
  List<DateTime> _publicHolidays = [];

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDate;
    _selectedDay = widget.selectedDate;
    _selectedYear = widget.selectedDate.year;
    _selectedMonth = widget.selectedDate.month;
    _fetchPublicHolidays();
  }

  Future<void> _fetchPublicHolidays() async {
    try {
      List<DateTime> holidays = await fetchLatvianHolidays(_selectedYear);
      setState(() {
        _publicHolidays = holidays;
      });
    } catch (e) {
      print("Error fetching public holidays: $e");
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Iegūst brīvdienas no api
  Future<List<DateTime>> fetchLatvianHolidays(int year) async {
    final url = 'https://date.nager.at/api/v3/PublicHolidays/$year/LV';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> holidaysJson = jsonDecode(response.body);
      List<DateTime> holidays = [];
      for (var holiday in holidaysJson) {
        if (holiday["types"] != null && holiday["types"] is List) {
          List<dynamic> types = holiday["types"];
          List<String> lowerTypes =
              types.map((e) => e.toString().toLowerCase()).toList();
          if (!lowerTypes.contains("public")) continue;
        }
        DateTime holidayDate = DateTime.parse(holiday["date"]);
        String? localName = holiday["localName"];
        bool isMatesDiena =
            localName != null &&
            localName.toString().toLowerCase() == "mātes diena";
        if (!isMatesDiena) {
          if (holidayDate.weekday == DateTime.saturday) {
            holidays.add(holidayDate.add(const Duration(days: 2)));
          } else if (holidayDate.weekday == DateTime.sunday) {
            holidays.add(holidayDate.add(const Duration(days: 1)));
          }
        }
        holidays.add(holidayDate);
      }
      return holidays;
    } else {
      throw Exception("Failed to fetch holidays");
    }
  }

  Map<DateTime, double> _buildHoursMap(QuerySnapshot snapshot) {
    Map<DateTime, double> hoursMap = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] != null) {
        DateTime logDate = (data['date'] as Timestamp).toDate();
        DateTime normalized = _normalizeDate(logDate);
        double dayHours = 0.0;
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
                dayHours += hours;
              }
            }
          }
        } else if (data.containsKey('tasks') && data['tasks'] != null) {
          List<dynamic> tasks = data['tasks'];
          for (var task in tasks) {
            double hours = 0.0;
            if (task['hours'] is int) {
              hours = (task['hours'] as int).toDouble();
            } else if (task['hours'] is double) {
              hours = task['hours'] as double;
            }
            dayHours += hours;
          }
        }
        if (dayHours > 0) {
          hoursMap[normalized] = (hoursMap[normalized] ?? 0) + dayHours;
        }
      }
    }
    return hoursMap;
  }

  Map<DateTime, String> _buildStatusMap(QuerySnapshot snapshot) {
    Map<DateTime, String> statusMap = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] != null && data.containsKey('status')) {
        String status = data['status'];
        if (status == "slimība" || status == "atvaļinājums") {
          DateTime logDate = (data['date'] as Timestamp).toDate();
          DateTime normalized = _normalizeDate(logDate);
          statusMap[normalized] = status;
        }
      }
    }
    return statusMap;
  }

  Widget _buildDayCell(
    DateTime day,
    Map<DateTime, double> hoursMap,
    Map<DateTime, String> statusMap,
  ) {
    DateTime normalized = _normalizeDate(day);
    double? hours = hoursMap[normalized];
    String? status = statusMap[normalized];

    bool isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    bool isHoliday = _publicHolidays.any(
      (holiday) => _normalizeDate(holiday) == normalized,
    );
    bool isWeekendOrHoliday = isWeekend || isHoliday;

    Color cellColor;
    if (status != null) {
      if (status == "slimība") {
        cellColor = Colors.redAccent;
      } else if (status == "atvaļinājums") {
        cellColor = Colors.blueAccent;
      } else {
        cellColor = Colors.transparent;
      }
    } else {
      cellColor =
          isWeekendOrHoliday ? Colors.red.withOpacity(0.3) : Colors.transparent;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: cellColor),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: isWeekendOrHoliday ? Colors.red : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (status != null)
          status == "slimība"
              ? const Icon(
                Icons.sentiment_dissatisfied,
                color: Colors.black,
                size: 16,
              )
              : status == "atvaļinājums"
              ? const Icon(
                Icons.airplanemode_active,
                color: Colors.black,
                size: 16,
              )
              : Container()
        else if (hours != null && cellColor == Colors.transparent)
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: TextStyle(
              color: isWeekendOrHoliday ? Colors.red : primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedCell(
    DateTime day,
    Map<DateTime, double> hoursMap,
    Map<DateTime, String> statusMap,
  ) {
    DateTime normalized = _normalizeDate(day);
    bool isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    bool isHoliday = _publicHolidays.any(
      (holiday) => _normalizeDate(holiday) == normalized,
    );
    bool isWeekendOrHoliday = isWeekend || isHoliday;
    double? hours = hoursMap[normalized];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.7),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        if (hours != null) ...[
          const SizedBox(height: 4),
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: TextStyle(
              color: isWeekendOrHoliday ? Colors.red : primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: Colors.black, size: 30),
              onPressed: () {
                setState(() {
                  if (_selectedMonth == 1) {
                    _selectedMonth = 12;
                    _selectedYear--;
                  } else {
                    _selectedMonth--;
                  }
                  _focusedDay = DateTime(_selectedYear, _selectedMonth, 1);
                  _selectedDay = _focusedDay;
                  _fetchPublicHolidays();
                });
              },
            ),
            Text(
              DateFormat("MMMM yyyy", "lv_LV").format(_focusedDay),
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: Colors.black, size: 30),
              onPressed: () {
                setState(() {
                  if (_selectedMonth == 12) {
                    _selectedMonth = 1;
                    _selectedYear++;
                  } else {
                    _selectedMonth++;
                  }
                  _focusedDay = DateTime(_selectedYear, _selectedMonth, 1);
                  _selectedDay = _focusedDay;
                  _fetchPublicHolidays();
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButton<int>(
              value: _selectedMonth,
              items: List.generate(12, (index) {
                int month = index + 1;
                return DropdownMenuItem<int>(
                  value: month,
                  child: Text(
                    DateFormat.MMMM('lv_LV').format(DateTime(0, month)),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedMonth = val;
                    _focusedDay = DateTime(_selectedYear, _selectedMonth, 1);
                    _selectedDay = _focusedDay;
                  });
                }
              },
              dropdownColor: Colors.white,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 20),
            DropdownButton<int>(
              value: _selectedYear,
              items: List.generate(10, (index) {
                int currentYear = DateTime.now().year;
                int startYear = currentYear - 5;
                int year = startYear + index;
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text(
                    year.toString(),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedYear = val;
                    _focusedDay = DateTime(_selectedYear, _selectedMonth, 1);
                    _selectedDay = _focusedDay;
                    _fetchPublicHolidays();
                  });
                }
              },
              dropdownColor: Colors.white,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String uid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 192, 192, 192),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('workLogs')
                .snapshots(),
        builder: (context, snapshot) {
          Map<DateTime, double> hoursMap = {};
          Map<DateTime, String> statusMap = {};
          if (snapshot.hasData) {
            hoursMap = _buildHoursMap(snapshot.data!);
            statusMap = _buildStatusMap(snapshot.data!);
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Card(
                    color: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildCustomHeader(),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: TableCalendar(
                            firstDay: DateTime.utc(2000, 1, 1),
                            lastDay: DateTime.utc(2100, 12, 31),
                            focusedDay: _focusedDay,
                            rowHeight: 80,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            selectedDayPredicate:
                                (day) => isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              _focusedDay = focusedDay;
                            },
                            headerVisible: false,
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) {
                                return _buildDayCell(day, hoursMap, statusMap);
                              },
                              todayBuilder: (context, day, focusedDay) {
                                if (isSameDay(day, _selectedDay)) {
                                  return _buildSelectedCell(
                                    day,
                                    hoursMap,
                                    statusMap,
                                  );
                                } else {
                                  return _buildDayCell(
                                    day,
                                    hoursMap,
                                    statusMap,
                                  );
                                }
                              },
                              selectedBuilder: (context, day, focusedDay) {
                                return _buildSelectedCell(
                                  day,
                                  hoursMap,
                                  statusMap,
                                );
                              },
                            ),
                            calendarStyle: CalendarStyle(
                              todayDecoration: const BoxDecoration(),
                              selectedDecoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              defaultTextStyle: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              weekendTextStyle: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                              outsideTextStyle: TextStyle(
                                color: Colors.black.withOpacity(0.5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            daysOfWeekStyle: DaysOfWeekStyle(
                              weekdayStyle: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              weekendStyle: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_selectedDay != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Card(
                      color: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Izvēlētais datums: ${DateFormat("yyyy \'gada.\' d MMMM", "lv_LV").format(_selectedDay!)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => StundasPage(
                                          selectedDate: _selectedDay!,
                                        ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: const Text(
                                'Rediģēt darba stundas',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
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
