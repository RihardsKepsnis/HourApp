import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminEditWorkerHoursPage extends StatefulWidget {
  final String workerId;
  final String workerName;
  final DateTime initialDate;

  const AdminEditWorkerHoursPage({
    Key? key,
    required this.workerId,
    required this.workerName,
    required this.initialDate,
  }) : super(key: key);

  @override
  _AdminEditWorkerHoursPageState createState() =>
      _AdminEditWorkerHoursPageState();
}

class _AdminEditWorkerHoursPageState extends State<AdminEditWorkerHoursPage> {
  bool _isLoading = true;
  late DateTime _selectedDate;
  final Color primaryColor = const Color(0xFF24562B);

  List<Map<String, dynamic>> _entries = [];

  final Map<String, TextEditingController> _controllers = {};

  String? _selectedEntryKey;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _loadWorkerWorkLog();
  }

  Future<void> _loadWorkerWorkLog() async {
    setState(() => _isLoading = true);
    final docId = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.workerId)
              .collection('workLogs')
              .doc(docId)
              .get();

      _entries.clear();
      _controllers.clear();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> rawEntries = data['entries'] ?? [];

        for (var raw in rawEntries) {
          final org = raw['organization'] as String? ?? '';
          final city = raw['city'] as String? ?? '';
          final key = '$org|$city';
          final List<dynamic> tasks = raw['tasks'] ?? [];

          final entry = {
            'organization': org,
            'city': city,
            'tasks': <Map<String, dynamic>>[],
          };
          final tasksList = entry['tasks'] as List<Map<String, dynamic>>;

          for (var t in tasks) {
            final taskName = t['task'] as String? ?? '';
            final hours =
                (t['hours'] is num) ? (t['hours'] as num).toString() : '0';
            tasksList.add({'task': taskName});

            _controllers['$key|$taskName'] = TextEditingController(text: hours);
          }

          _entries.add(entry);
        }

        if (_entries.isNotEmpty) {
          final first = _entries.first;
          _selectedEntryKey = '${first['organization']}|${first['city']}';
        }
      }
    } catch (e) {
      debugPrint('Error loading work log: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// saglabā atjauninātās darba stundas.
  Future<void> _submitUpdatedWorkLog() async {
    final docId = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final updatedEntries =
        _entries.map((entry) {
          final org = entry['organization'] as String;
          final city = entry['city'] as String;
          final key = '$org|$city';

          final tasks = <Map<String, dynamic>>[];
          for (var t in entry['tasks'] as List) {
            final taskName = t['task'] as String;
            final controller = _controllers['$key|$taskName'];
            final hours = double.tryParse(controller?.text ?? '') ?? 0.0;
            tasks.add({'task': taskName, 'hours': hours});
          }

          return {'organization': org, 'city': city, 'tasks': tasks};
        }).toList();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.workerId)
          .collection('workLogs')
          .doc(docId)
          .set({'date': _selectedDate, 'entries': updatedEntries});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stundas par ${DateFormat("dd.MM.yyyy").format(_selectedDate)} ir veiksmīgi atjauninātas!',
          ),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      debugPrint('Error updating work log: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kļūda atjauninot stundas par ${DateFormat("dd.MM.yyyy").format(_selectedDate)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  PreferredSizeWidget _buildCustomAppBar(String title, double width) {
    return PreferredSize(
      preferredSize: Size.fromHeight(width * 0.24),
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
              style: TextStyle(fontSize: width * 0.06, letterSpacing: 1.2),
            ),
            centerTitle: true,
            elevation: 0,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items =
        _entries.map((e) {
          final org = e['organization'];
          final city = e['city'];
          final key = '$org|$city';
          return DropdownMenuItem<String>(
            value: key,
            child: Text('$org – $city'),
          );
        }).toList();

    final selectedEntry = _entries.firstWhere(
      (e) => '${e['organization']}|${e['city']}' == _selectedEntryKey,
      orElse: () => _entries.first,
    );
    final selectedKey =
        '${selectedEntry['organization']}|${selectedEntry['city']}';

    return Scaffold(
      appBar: _buildCustomAppBar('Edit: ${widget.workerName}', screenWidth),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Darba diena: ${DateFormat("dd.MM.yyyy").format(_selectedDate)}',
              style: TextStyle(
                fontSize: screenWidth * 0.05,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            SizedBox(height: screenWidth * 0.04),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedEntryKey,
              items: items,
              onChanged: (val) => setState(() => _selectedEntryKey = val),
            ),
            SizedBox(height: screenWidth * 0.04),
            Expanded(
              child: ListView.separated(
                itemCount: (selectedEntry['tasks'] as List).length,
                separatorBuilder:
                    (_, __) => SizedBox(height: screenWidth * 0.03),
                itemBuilder: (context, idx) {
                  final task = selectedEntry['tasks'][idx];
                  final name = task['task'] as String;
                  final ctrl = _controllers['$selectedKey|$name']!;
                  return Card(
                    color: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                        vertical: screenWidth * 0.03,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Stundas',
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                filled: true,
                                fillColor: primaryColor,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: screenWidth * 0.05),
            Center(
              child: ElevatedButton(
                onPressed: _submitUpdatedWorkLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(
                    vertical: screenWidth * 0.02,
                    horizontal: screenWidth * 0.08,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Atjaunināt stundas',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
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

/// augšējais ieliekums
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
