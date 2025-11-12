import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Custom Clipper for the curved AppBar shape.
class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height - 15,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Main page for entering and submitting work hours.
class StundasPage extends StatefulWidget {
  final DateTime selectedDate;
  const StundasPage({required this.selectedDate});

  @override
  _StundasPageState createState() => _StundasPageState();
}

class _StundasPageState extends State<StundasPage> {
  final Color primaryColor = const Color(0xFF24562B);
  final Color formBackground = const Color.fromARGB(255, 192, 192, 192);

  static const Map<String, List<String>> _defaultOrganizationCities = {
    "BPC": ["Riga", "Jelgava", "Liepāja"],
    "LDZB": ["Riga", "Daugavpils"],
    "DZB": ["Riga", "Ventspils"],
    "Other": ["Riga"],
  };
  Map<String, List<String>> _organizationCities = Map.from(
    _defaultOrganizationCities,
  );

  final Map<String, Color> _organizationColors = {
    "BPC": Colors.blue,
    "LDZB": Colors.orange,
    "DZB": Colors.purple,
    "Other": Colors.teal,
  };

  String _selectedOrganization = "BPC";
  String _selectedCity = "Riga";

  List<Map<String, dynamic>> _commonPresetTasks = [];
  List<Map<String, dynamic>> _currentTasks = [];

  /// Stores saved entries for this date, keyed by "org|city"
  Map<String, Map<String, dynamic>> _savedEntriesMap = {};

  /// Clipboard: stores entire day's entries (all org|city) when copying
  Map<String, Map<String, dynamic>> _clipboardEntriesMap = {};

  String? _specialStatus;
  bool _isLoading = true;
  bool _isEditing = true;
  bool _hasEntriesForDate = false;

  @override
  void initState() {
    super.initState();
    _initForDate();
  }

  @override
  void didUpdateWidget(covariant StundasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _initForDate();
    }
  }

  void _initForDate() {
    setState(() {
      _isLoading = true;
      _hasEntriesForDate = false;
      _isEditing = true;
      _specialStatus = null;
      _savedEntriesMap.clear();
      _currentTasks.clear();
    });

    _loadOrganizationCities().then((_) async {
      await _loadCommonPresetTasks();
      await _loadUserHiddenTasks();
      _currentTasks = _copyTasks(_commonPresetTasks);
      await _loadSubmittedWorkLog();
      setState(() {
        if (_savedEntriesMap.isNotEmpty) {
          _hasEntriesForDate = true;
          _isEditing = false;
        }
        _populateCurrentEntry();
        _isLoading = false;
      });
    });
  }

  Future<void> _loadOrganizationCities() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null && data['organizationCities'] != null) {
        final raw = Map<String, dynamic>.from(data['organizationCities']);
        _organizationCities = raw.map(
          (org, cities) => MapEntry(org, List<String>.from(cities)),
        );
      }
    } catch (_) {}
    if (!_organizationCities.containsKey(_selectedOrganization)) {
      _selectedOrganization = _organizationCities.keys.first;
    }
    if (!_organizationCities[_selectedOrganization]!.contains(_selectedCity)) {
      _selectedCity = _organizationCities[_selectedOrganization]!.first;
    }
  }

  Future<void> _saveOrganizationCities() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'organizationCities': _organizationCities,
    });
  }

  Future<void> _loadCommonPresetTasks() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('presetTasks').get();
      _commonPresetTasks =
          snap.docs.map((doc) {
            final data = doc.data();
            final defaultHours = (data['defaultHours'] ?? "").toString();
            return {
              'task': data['task'] ?? '',
              'time': defaultHours,
              'controller': TextEditingController(text: defaultHours),
              'manual': defaultHours.isEmpty,
              'selected': false,
              'submitted': false,
              'hidden': false,
            };
          }).toList();
    } catch (_) {}
  }

  Future<void> _loadUserHiddenTasks() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final hiddenList = List<String>.from(doc.data()?['hiddenTasks'] ?? []);
        for (var t in _commonPresetTasks) {
          if (hiddenList.contains(t['task'])) t['hidden'] = true;
        }
      }
    } catch (_) {}
  }

  Future<void> _updateUserHiddenTasks() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final hidden =
        _currentTasks
            .where((t) => t['hidden'] == true)
            .map((t) => t['task'] as String)
            .toList();
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'hiddenTasks': hidden,
    });
  }

  void _hideTask(Map<String, dynamic> t) {
    setState(() => t['hidden'] = true);
    _updateUserHiddenTasks();
  }

  void _unhideTask(Map<String, dynamic> t) {
    setState(() => t['hidden'] = false);
    _updateUserHiddenTasks();
  }

  List<Map<String, dynamic>> _copyTasks(List<Map<String, dynamic>> src) =>
      src
          .map(
            (t) => {
              'task': t['task'],
              'time': t['time'],
              'controller': TextEditingController(
                text: (t['controller'] as TextEditingController).text,
              ),
              'manual': t['manual'],
              'selected': t['selected'],
              'submitted': false,
              'hidden': t['hidden'],
            },
          )
          .toList();

  Future<void> _loadSubmittedWorkLog() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('workLogs')
            .doc(id)
            .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _specialStatus = data['status'];
    final entries = data['entries'] as List<dynamic>? ?? [];
    for (var e in entries) {
      final entry = Map<String, dynamic>.from(e as Map<String, dynamic>);
      final key = "${entry['organization']}|${entry['city']}";
      _savedEntriesMap[key] = entry;
    }
  }

  void _populateCurrentEntry() {
    final key = "$_selectedOrganization|$_selectedCity";
    if (!_savedEntriesMap.containsKey(key)) return;
    final saved = _savedEntriesMap[key]!['tasks'] as List<dynamic>;
    for (var t in _currentTasks) {
      try {
        final m = saved.firstWhere((e) => e['task'] == t['task']);
        (t['controller'] as TextEditingController).text = m['hours'].toString();
        t['hidden'] = m['hidden'] ?? false;
      } catch (_) {}
    }
  }

  Future<void> _onSelectionChanged() async {
    setState(() {
      _isLoading = true;
      _currentTasks = _copyTasks(_commonPresetTasks);
    });
    _populateCurrentEntry();
    setState(() => _isLoading = false);
  }

  double _computeTotalHours() {
    return _currentTasks.fold<double>(0, (sum, t) {
      if (t['hidden'] == true) return sum;
      if (t['manual'] == false && t['selected'] != true) return sum;
      final h =
          double.tryParse((t['controller'] as TextEditingController).text) ??
          0.0;
      return sum + h;
    });
  }

  double _computeTotalCombinedHours() {
    double total = 0.0;
    final key = "$_selectedOrganization|$_selectedCity";
    _savedEntriesMap.forEach((k, e) {
      if (k != key) {
        for (var t in e['tasks'] as List<dynamic>) {
          total += double.tryParse(t['hours'].toString()) ?? 0.0;
        }
      }
    });
    if (_isEditing) {
      total += _computeTotalHours();
    } else if (_savedEntriesMap.containsKey(key)) {
      for (var t in _savedEntriesMap[key]!['tasks'] as List<dynamic>) {
        total += double.tryParse(t['hours'].toString()) ?? 0.0;
      }
    }
    return total;
  }

  void _saveCurrentEntry() {
    final tot = _computeTotalHours();
    if (tot <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Lūdzu ievadiet stundas vismaz vienam uzdevumam!',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final key = "$_selectedOrganization|$_selectedCity";
    final tasks =
        _currentTasks
            .where((t) {
              if (t['hidden'] == true) return false;
              final h =
                  double.tryParse(
                    (t['controller'] as TextEditingController).text,
                  ) ??
                  0.0;
              if (t['manual'] == false && t['selected'] != true) return false;
              return h > 0;
            })
            .map(
              (t) => {
                'task': t['task'],
                'hours':
                    double.tryParse(
                      (t['controller'] as TextEditingController).text,
                    ) ??
                    0.0,
                'hidden': t['hidden'] ?? false,
              },
            )
            .toList();
    _savedEntriesMap[key] = {
      'organization': _selectedOrganization,
      'city': _selectedCity,
      'tasks': tasks,
    };
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ieraksts saglabāts! Saglābie uzdevumi: ${tasks.length}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
      ),
    );
  }

  int _getSavedTasksCount() => _savedEntriesMap.values.fold(
    0,
    (sum, e) => sum + (e['tasks'] as List).length,
  );

  Future<void> _submitEntries() async {
    if (_computeTotalHours() > 0) _saveCurrentEntry();
    if (_savedEntriesMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Nav saglabātu ierakstu, ko iesniegt!',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final combined = _computeTotalCombinedHours();
    if (combined > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kopējais stundas skaits dienā nevar pārsniegt 24 stundas (${combined.toStringAsFixed(1)}).',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final entries =
        _savedEntriesMap.entries.map((e) {
          final v = e.value;
          return {
            'organization': v['organization'],
            'city': v['city'],
            'tasks': v['tasks'],
          };
        }).toList();
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workLogs')
          .doc(id)
          .set({
            'date': widget.selectedDate,
            'entries': entries,
            if (_specialStatus != null) 'status': _specialStatus,
          });
      await _loadSubmittedWorkLog();
      setState(() {
        _hasEntriesForDate = true;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Darba stundas par ${DateFormat("d. MMMM", "lv_LV").format(widget.selectedDate)} ir veiksmīgi iesniegtas!',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: primaryColor,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Kļūda iesniedzot darba stundas!',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showAddTaskDialog() async {
    if (!_isEditing) return;
    final tCtrl = TextEditingController();
    final hCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text("Pievienot uzdevumu"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tCtrl,
                  decoration: const InputDecoration(
                    labelText: "Uzdevuma nosaukums",
                  ),
                ),
                TextField(
                  controller: hCtrl,
                  decoration: const InputDecoration(labelText: "Stundas"),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("Atcelt"),
              ),
              ElevatedButton(
                onPressed: () {
                  final n = tCtrl.text.trim();
                  final h = hCtrl.text.trim();
                  if (n.isNotEmpty && h.isNotEmpty) {
                    setState(() {
                      _currentTasks.add({
                        'task': n,
                        'time': h,
                        'controller': TextEditingController(text: h),
                        'manual': true,
                        'selected': false,
                        'submitted': false,
                        'hidden': false,
                      });
                    });
                    Navigator.pop(c);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "Lūdzu ievadiet gan uzdevuma nosaukumu, gan stundas.",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text("Pievienot"),
              ),
            ],
          ),
    );
  }

  /// Copy entire day's entries (all org|city) from a given date into clipboard
  Future<void> _copyDayEntries(DateTime fromDate) async {
    if (!_isEditing) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = DateFormat('yyyy-MM-dd').format(fromDate);
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('workLogs')
            .doc(id)
            .get();
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nav ierakstu datumam ${DateFormat.yMd().format(fromDate)}!',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final data = doc.data()!;
    final entries = List<dynamic>.from(data['entries'] as List<dynamic>? ?? []);
    _clipboardEntriesMap.clear();
    for (var e in entries) {
      final entry = Map<String, dynamic>.from(e as Map<String, dynamic>);
      final key = "${entry['organization']}|${entry['city']}";
      final tasks =
          (entry['tasks'] as List<dynamic>).map((t) {
            return {
              'task': t['task'],
              'hours': t['hours'],
              'hidden': t['hidden'] ?? false,
            };
          }).toList();
      _clipboardEntriesMap[key] = {
        'organization': entry['organization'],
        'city': entry['city'],
        'tasks': tasks,
      };
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Nokopēti ieraksti ${_clipboardEntriesMap.length} organizācijām/pilsētām!',
        ),
        backgroundColor: primaryColor,
      ),
    );
  }

  /// Paste entire clipboard entries into today's local entries map
  void _pasteDayEntries() {
    if (!_isEditing) return;
    if (_clipboardEntriesMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nav nokopētu ierakstu!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    // Deep clone into savedEntries
    final Map<String, Map<String, dynamic>> clone = {};
    _clipboardEntriesMap.forEach((k, v) {
      final tasks =
          (v['tasks'] as List<dynamic>).map((t) {
            return {
              'task': t['task'],
              'hours': t['hours'],
              'hidden': t['hidden'],
            };
          }).toList();
      clone[k] = {
        'organization': v['organization'],
        'city': v['city'],
        'tasks': tasks,
      };
    });
    _savedEntriesMap = clone;
    _populateCurrentEntry();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ielīmēti ieraksti ${_savedEntriesMap.length} organizācijām/pilsētām!',
        ),
        backgroundColor: primaryColor,
      ),
    );
  }

  void _showHiddenTasksMenu() {
    if (!_isEditing) return;
    final hidden = _currentTasks.where((t) => t['hidden'] == true).toList();
    showModalBottomSheet(
      context: context,
      builder: (c) {
        if (hidden.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text("Nav paslēptu uzdevumu.")),
          );
        }
        return ListView.separated(
          itemCount: hidden.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (c, i) {
            final t = hidden[i];
            return ListTile(
              title: Text(t['task']),
              trailing: IconButton(
                icon: Icon(Icons.visibility, color: primaryColor),
                onPressed: () {
                  _unhideTask(t);
                  Navigator.pop(c);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrganizationDropdown() {
    return DropdownButton<String>(
      value: _selectedOrganization,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black),
      onChanged:
          _isEditing
              ? (newOrg) async {
                if (newOrg == "ADD_ORG") {
                  await _showAddOrganizationDialog();
                } else if (newOrg == "DELETE_ORG") {
                  await _deleteOrganization();
                } else {
                  setState(() {
                    _selectedOrganization = newOrg!;
                    _selectedCity = _organizationCities[newOrg]!.first;
                  });
                  await _onSelectionChanged();
                }
              }
              : null,
      items: [
        ..._organizationCities.keys.map((org) {
          return DropdownMenuItem<String>(
            value: org,
            child: Text(org, style: const TextStyle(color: Colors.black)),
          );
        }),
        DropdownMenuItem<String>(
          value: "ADD_ORG",
          child: Row(
            children: const [
              Icon(Icons.add, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "Pievienot organizāciju",
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
        DropdownMenuItem<String>(
          value: "DELETE_ORG",
          child: Row(
            children: const [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text("Dzēst organizāciju", style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddOrganizationDialog() async {
    final ctrl = TextEditingController();
    final newOrg = await showDialog<String>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text("Pievienot organizāciju"),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: "Organizācijas nosaukums",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("Atcelt"),
              ),
              ElevatedButton(
                onPressed: () {
                  final n = ctrl.text.trim();
                  Navigator.pop(c, n.isEmpty ? null : n);
                },
                child: const Text("Pievienot"),
              ),
            ],
          ),
    );
    if (newOrg == null) return;
    final newCity = await _showAddCityDialog();
    if (newCity == null) return;
    setState(() {
      _organizationCities[newOrg] = [newCity];
      _selectedOrganization = newOrg;
      _selectedCity = newCity;
    });
    await _saveOrganizationCities();
    await _onSelectionChanged();
  }

  Future<void> _deleteOrganization() async {
    if (_organizationCities.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jābūt vismaz vienai organizācijai!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text("Dzēst organizāciju"),
            content: Text(
              "Vai tiešām vēlaties dzēst organizāciju '$_selectedOrganization'?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Atcelt"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text("Dzēst"),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    setState(() {
      _organizationCities.remove(_selectedOrganization);
      _selectedOrganization = _organizationCities.keys.first;
      _selectedCity = _organizationCities[_selectedOrganization]!.first;
    });
    await _saveOrganizationCities();
    await _onSelectionChanged();
  }

  Widget _buildCityDropdown() {
    final cities = _organizationCities[_selectedOrganization]!;
    return DropdownButton<String>(
      value: _selectedCity.isEmpty ? null : _selectedCity,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black),
      onChanged:
          _isEditing
              ? (newCity) async {
                if (newCity == "ADD_CITY") {
                  final c = await _showAddCityDialog();
                  if (c != null) {
                    setState(() {
                      _organizationCities[_selectedOrganization]!.add(c);
                      _selectedCity = c;
                    });
                    await _saveOrganizationCities();
                    await _onSelectionChanged();
                  }
                } else if (newCity == "DELETE_CITY") {
                  await _deleteCity();
                } else {
                  setState(() => _selectedCity = newCity!);
                  await _onSelectionChanged();
                }
              }
              : null,
      items: [
        ...cities.map((city) {
          return DropdownMenuItem<String>(
            value: city,
            child: Text(city, style: const TextStyle(color: Colors.black)),
          );
        }),
        DropdownMenuItem<String>(
          value: "ADD_CITY",
          child: Row(
            children: const [
              Icon(Icons.add, color: Colors.green),
              SizedBox(width: 8),
              Text("Pievienot pilsētu", style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
        DropdownMenuItem<String>(
          value: "DELETE_CITY",
          child: Row(
            children: const [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text("Dzēst pilsētu", style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _showAddCityDialog() async {
    final ctrl = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text("Pievienot pilsētu"),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: "Pilsētas nosaukums",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("Atcelt"),
              ),
              ElevatedButton(
                onPressed: () {
                  final n = ctrl.text.trim();
                  Navigator.pop(c, n.isEmpty ? null : n);
                },
                child: const Text("Pievienot"),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteCity() async {
    final cities = _organizationCities[_selectedOrganization]!;
    if (cities.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jābūt vismaz vienai pilsētai!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text("Dzēst pilsētu"),
            content: Text(
              "Vai tiešām vēlaties dzēst pilsētu '$_selectedCity' no '$_selectedOrganization'?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Atcelt"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text("Dzēst"),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    setState(() {
      _organizationCities[_selectedOrganization]!.remove(_selectedCity);
      final list = _organizationCities[_selectedOrganization]!;
      _selectedCity = list.isNotEmpty ? list.first : '';
    });
    await _saveOrganizationCities();
    await _onSelectionChanged();
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
        final count = snap.data?.docs.length ?? 0;
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

  Widget _buildOtherButton() {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (!_isEditing) return;
        setState(() {
          _specialStatus = v;
          for (var t in _currentTasks) {
            (t['controller'] as TextEditingController).text = "0";
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              v == "atvaļinājums"
                  ? "Atvaļinājuma režīms aktivizēts"
                  : "Slimības režīms aktivizēts",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: primaryColor,
          ),
        );
      },
      itemBuilder:
          (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: "atvaļinājums",
              child: Text("Atvaļinājums"),
            ),
            PopupMenuItem<String>(value: "slimība", child: Text("Slimība")),
          ],
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.more_vert, color: Colors.white),
            SizedBox(width: 4),
            Text("Cits", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final visibleTasks =
        _currentTasks.where((t) => t['hidden'] != true).toList();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenWidth * 0.277),
        child: ClipPath(
          clipper: BottomCurveClipper(),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _organizationColors[_selectedOrganization] ?? primaryColor,
                  Colors.black87,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: AppBar(
              backgroundColor: Colors.transparent,
              title: Text(
                DateFormat("d. MMMM", "lv_LV").format(widget.selectedDate),
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
                  child: IconButton(
                    icon: _buildNotificationIcon(screenWidth * 0.08),
                    onPressed:
                        () => showDialog(
                          context: context,
                          builder: (_) => const NotificationsPopup(),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: formBackground,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: EdgeInsets.all(screenWidth * 0.05),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildOrganizationDropdown()),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(child: _buildCityDropdown()),
                        ],
                      ),
                      SizedBox(height: screenWidth * 0.03),
                      Text(
                        'Kopējās ievadītās stundas: ${_computeTotalCombinedHours().toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.03),
                      Wrap(
                        spacing: screenWidth * 0.03,
                        runSpacing: screenWidth * 0.02,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                _isEditing
                                    ? () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: widget.selectedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (d != null) {
                                        await _copyDayEntries(d);
                                      }
                                    }
                                    : null,
                            icon: const Icon(Icons.copy, color: Colors.white),
                            label: const Text(
                              'Kopēt',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isEditing ? _pasteDayEntries : null,
                            icon: const Icon(Icons.paste, color: Colors.white),
                            label: const Text(
                              'Ielīmēt',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                          ),
                          _buildOtherButton(),
                        ],
                      ),
                      SizedBox(height: screenWidth * 0.03),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isEditing ? _showAddTaskDialog : null,
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                "Pievienot uzdevumu",
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isEditing ? _showHiddenTasksMenu : null,
                              icon: const Icon(
                                Icons.visibility,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Paslēptie uzdevumi",
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenWidth * 0.03),
                      Text(
                        'Saglābie uzdevumi: ${_getSavedTasksCount()}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.03),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isEditing ? _saveCurrentEntry : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                              ),
                              child: const Text(
                                "Saglabāt ierakstu",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isEditing ? _submitEntries : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                              ),
                              child: const Text(
                                "Iesniegt ierakstus",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_isEditing && _hasEntriesForDate) ...[
                        SizedBox(height: screenWidth * 0.03),
                        Center(
                          child: ElevatedButton(
                            onPressed: () => setState(() => _isEditing = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                            child: const Text(
                              "Rediģēt stundas",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: screenWidth * 0.03),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleTasks.length,
                        separatorBuilder:
                            (_, __) => SizedBox(height: screenWidth * 0.02),
                        itemBuilder: (context, idx) {
                          final t = visibleTasks[idx];
                          return Card(
                            color: formBackground,
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
                                  if (t['manual'] == false)
                                    Checkbox(
                                      value: t['selected'],
                                      activeColor: primaryColor,
                                      checkColor: Colors.white,
                                      onChanged:
                                          _isEditing
                                              ? (val) {
                                                setState(() {
                                                  t['selected'] = val!;
                                                  if (!val) {
                                                    (t['controller']
                                                            as TextEditingController)
                                                        .text = "0";
                                                  }
                                                });
                                              }
                                              : null,
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_red_eye,
                                      color: primaryColor,
                                    ),
                                    onPressed:
                                        _isEditing ? () => _hideTask(t) : null,
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      t['task'],
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Ilgums: ${t['time']} hrs',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: t['controller'],
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      enabled:
                                          _isEditing &&
                                          _specialStatus == null &&
                                          (t['manual'] == true ||
                                              (t['manual'] == false &&
                                                  t['selected'] == true)),
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Stundas',
                                        labelStyle: const TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        filled: true,
                                        fillColor: formBackground,
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

/// Popup to show unread notifications.
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
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final title = data['title'] ?? 'Paziņojums';
                final body = data['body'] ?? '';
                return ListTile(
                  title: Text(title),
                  subtitle: Text(body),
                  trailing: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () async {
                      await notificationsRef.doc(docs[i].id).update({
                        'read': true,
                      });
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
