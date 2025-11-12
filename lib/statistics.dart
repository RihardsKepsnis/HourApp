import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late DateTime selectedEndDate;
  late DateTime selectedStartDate;
  bool _isLoading = true;

  double _totalHours = 0.0;
  double _averageHours = 0.0;
  List<Map<String, dynamic>> _topTasks = [];
  Map<String, double> _orgHours = {};
  Map<String, double> _cityHours = {};
  String _userName = 'Ielādē...';

  final Color primaryColor = const Color(0xFF24562B);
  final Color secondaryColor = const Color(0xFFBDBDBD);

  @override
  void initState() {
    super.initState();
    selectedEndDate = DateTime.now();
    selectedStartDate = selectedEndDate.subtract(const Duration(days: 6));
    _loadUserData().then((_) => _fetchStatistics());
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
        setState(() {
          _userName =
              doc.exists ? (doc.get('name') ?? 'Nav norādīts') : 'Nav dati';
        });
      } else {
        setState(() => _userName = 'Nav lietotāja');
      }
    } catch (e) {
      setState(() => _userName = 'Kļūda ielādējot datus');
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchStatistics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final uid = user.uid;

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('workLogs')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(selectedStartDate),
              )
              .where(
                'date',
                isLessThanOrEqualTo: Timestamp.fromDate(selectedEndDate),
              )
              .get();

      double totalHours = 0.0;
      final Map<String, double> taskTotals = {};
      final Map<String, double> orgTotals = {};
      final Map<String, double> cityTotals = {};

      for (var wsDoc in snapshot.docs) {
        final data = wsDoc.data(); // no cast needed
        final entries = (data['entries'] as List<dynamic>?);
        if (entries != null) {
          for (var entry in entries) {
            final org = entry['organization'] as String? ?? 'Cits';
            final city = entry['city'] as String? ?? 'Cits';
            final tasks = (entry['tasks'] as List<dynamic>?);
            double entryHours = 0.0;

            if (tasks != null) {
              for (var t in tasks) {
                double h = 0.0;
                if (t['hours'] is int) {
                  h = (t['hours'] as int).toDouble();
                } else if (t['hours'] is double) {
                  h = t['hours'] as double;
                }
                entryHours += h;
                totalHours += h;

                final taskName = t['task'] as String? ?? 'Unknown';
                taskTotals[taskName] = (taskTotals[taskName] ?? 0) + h;
              }
            }

            orgTotals[org] = (orgTotals[org] ?? 0) + entryHours;
            cityTotals[city] = (cityTotals[city] ?? 0) + entryHours;
          }
        }
      }

      final daysCount =
          selectedEndDate.difference(selectedStartDate).inDays + 1;
      final averageHours = daysCount > 0 ? totalHours / daysCount : 0.0;

      final topTasks =
          taskTotals.entries
              .map((e) => {'task': e.key, 'hours': e.value})
              .toList()
            ..sort(
              (a, b) => (b['hours'] as double).compareTo(a['hours'] as double),
            );
      if (topTasks.length > 5) topTasks.removeRange(5, topTasks.length);

      setState(() {
        _totalHours = totalHours;
        _averageHours = averageHours;
        _topTasks = topTasks;
        _orgHours = orgTotals;
        _cityHours = cityTotals;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching statistics: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildNotificationIcon(double size) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Icon(Icons.notifications, size: size);
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false);
    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
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

  PreferredSizeWidget _buildCustomAppBar(double sw) {
    return PreferredSize(
      preferredSize: Size.fromHeight(sw * 0.24),
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
              'Statistika',
              style: TextStyle(fontSize: sw * 0.06, letterSpacing: 1.2),
            ),
            centerTitle: true,
            elevation: 0,
            toolbarHeight: sw * 0.18,
            actions: [
              Padding(
                padding: EdgeInsets.only(right: sw * 0.05),
                child: GestureDetector(
                  onTap:
                      () => showDialog(
                        context: context,
                        builder: (_) => const NotificationsPopup(),
                      ),
                  child: _buildNotificationIcon(sw * 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _makeSections(
    Map<String, double> dataMap,
    double total,
  ) {
    final colors = Colors.primaries;
    int i = 0;
    return dataMap.entries.map((e) {
      final color = colors[i++ % colors.length];
      return PieChartSectionData(
        value: e.value,
        color: color,
        radius: 80,
        title: '',
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, double> dataMap, double total) {
    final colors = Colors.primaries;
    int i = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          dataMap.entries.map((e) {
            final color = colors[i++ % colors.length];
            final percent = total > 0 ? e.value / total * 100 : 0.0; // now used
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 16, height: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key)),
                  Text(
                    '${e.value.toStringAsFixed(1)}h (${percent.toStringAsFixed(1)}%)',
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 192, 192, 192),
      appBar: _buildCustomAppBar(sw),
      body: Padding(
        padding: EdgeInsets.all(sw * 0.05),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistika: $_userName',
                        style: TextStyle(
                          fontSize: sw * 0.055,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: sw * 0.05),

                      // Date range display & picker
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'No: ${DateFormat('dd.MM.yyyy').format(selectedStartDate)}',
                              style: TextStyle(
                                fontSize: sw * 0.05,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Līdz: ${DateFormat('dd.MM.yyyy').format(selectedEndDate)}',
                              style: TextStyle(
                                fontSize: sw * 0.05,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: sw * 0.03),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2025, 1, 1),
                              lastDate: DateTime(2025, 12, 31),
                              initialDateRange: DateTimeRange(
                                start: selectedStartDate,
                                end: selectedEndDate,
                              ),
                              builder:
                                  (ctx, child) => Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: ColorScheme.dark(
                                        primary: primaryColor,
                                        secondary: secondaryColor,
                                      ),
                                    ),
                                    child: child!,
                                  ),
                            );
                            if (range != null) {
                              setState(() {
                                selectedStartDate = range.start;
                                selectedEndDate = range.end;
                                _isLoading = true;
                              });
                              await _fetchStatistics();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Izvēlēties datumu no–līdz',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: sw * 0.05),

                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Kopējās stundas',
                              value: _totalHours.toStringAsFixed(1),
                              color: primaryColor,
                              widthFactor: sw,
                            ),
                          ),
                          SizedBox(width: sw * 0.03),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Vidēji stundas/dienā',
                              value: _averageHours.toStringAsFixed(1),
                              color: primaryColor,
                              widthFactor: sw,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: sw * 0.04),

                      if (_orgHours.isNotEmpty) ...[
                        Text(
                          'Stundas pa organizācijām',
                          style: TextStyle(
                            fontSize: sw * 0.05,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: sw * 0.02),
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final total = _totalHours;
                            final chart = AspectRatio(
                              aspectRatio: 1,
                              child: PieChart(
                                PieChartData(
                                  sections: _makeSections(_orgHours, total),
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 30,
                                ),
                              ),
                            );
                            final legend = SingleChildScrollView(
                              child: _buildLegend(_orgHours, total),
                            );
                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [chart, SizedBox(height: 12), legend],
                              );
                            } else {
                              return Row(
                                children: [
                                  Expanded(flex: 2, child: chart),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 3, child: legend),
                                ],
                              );
                            }
                          },
                        ),
                        SizedBox(height: sw * 0.04),
                      ],

                      if (_cityHours.isNotEmpty) ...[
                        Text(
                          'Stundas pa pilsētām',
                          style: TextStyle(
                            fontSize: sw * 0.05,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: sw * 0.02),
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final total = _totalHours;
                            final chart = AspectRatio(
                              aspectRatio: 1,
                              child: PieChart(
                                PieChartData(
                                  sections: _makeSections(_cityHours, total),
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 30,
                                ),
                              ),
                            );
                            final legend = SingleChildScrollView(
                              child: _buildLegend(_cityHours, total),
                            );
                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [chart, SizedBox(height: 12), legend],
                              );
                            } else {
                              return Row(
                                children: [
                                  Expanded(flex: 2, child: chart),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 3, child: legend),
                                ],
                              );
                            }
                          },
                        ),
                        SizedBox(height: sw * 0.04),
                      ],

                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(sw * 0.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top 5 uzdevumi',
                                style: TextStyle(
                                  fontSize: sw * 0.045,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: sw * 0.02),
                              ..._topTasks.map((t) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: sw * 0.01,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t['task'] as String,
                                          style: TextStyle(
                                            fontSize: sw * 0.045,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${(t['hours'] as double).toStringAsFixed(1)} h',
                                        style: TextStyle(
                                          fontSize: sw * 0.045,
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value;
  final Color color;
  final double widthFactor;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.widthFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(widthFactor * 0.04),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: widthFactor * 0.045,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: widthFactor * 0.02),
            Text(
              value,
              style: TextStyle(
                fontSize: widthFactor * 0.065,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
  bool shouldReclip(CustomClipper<Path> old) => false;
}

class NotificationsPopup extends StatelessWidget {
  const NotificationsPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true);
    return AlertDialog(
      title: const Text("Paziņojumi"),
      content: Container(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream: ref.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text("Kļūda ielādējot paziņojumus.");
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Text("Nav jaunu paziņojumu.");
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final data = docs[i].data()! as Map<String, dynamic>;
                final ts = data['timestamp'] as Timestamp?;
                final date = ts?.toDate() ?? DateTime.now();
                return ListTile(
                  title: Text(data['title'] ?? 'Paziņojums'),
                  subtitle: Text(data['body'] ?? ''),
                  trailing: Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(date),
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
