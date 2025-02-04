import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessions_page.dart';
import 'settings_page.dart';
import 'groups_page.dart';

final supabase = Supabase.instance.client;

class SessionDetailPage extends StatefulWidget {
  final Map<String, dynamic> session;
  const SessionDetailPage({super.key, required this.session});

  @override
  _SessionDetailPageState createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  List<Map<String, dynamic>> _groupUsers = [];
  Map<String, String> _userAttendance = {};
  bool _isLoading = true;
  int _selectedIndex = 0;
  List<String> _ownerId = [];
  List<String> _admins = [];

  @override
  void initState() {
    super.initState();
    _fetchGroupUsers();
  }

  Future<void> _fetchGroupUsers() async {
    final user = supabase.auth.currentUser;
    final groupId = widget.session['group_id'];

    if (user == null) return;

    try {
      final groupResponse = await supabase
          .from('groups')
          .select('members, admins')
          .eq('id', groupId)
          .single();
      setState(() {
        _ownerId = List<String>.from(groupResponse['members']);
        _admins = List<String>.from(groupResponse['admins']);
      });

      final allMembers = [..._ownerId, ..._admins];
      final uniqueMembers = allMembers.toSet().toList();

      List<Map<String, dynamic>> users = [];
      for (var userId in uniqueMembers) {
        String validUserId = userId.toString();

        final userResponse = await supabase
            .from('users')
            .select('id, username')
            .eq('id', validUserId)
            .single();

        if (userResponse != null) {
          users.add(userResponse);
        } else {
          print('Gebruiker met ID $validUserId niet gevonden.');
        }
      }

      setState(() {
        _groupUsers = users;
        _isLoading = false;
      });

      _fetchAttendanceStatus();
    } catch (error) {
      print('Fout bij het ophalen van gebruikers: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAttendanceStatus() async {
    final sessionId = widget.session['id'];

    try {
      final attendanceResponse = await supabase
          .from('session_participants')
          .select('user_id, status')
          .eq('session_id', sessionId);

      final attendanceMap = <String, String>{};
      for (var attendance in attendanceResponse) {
        attendanceMap[attendance['user_id']] = attendance['status'];
      }

      setState(() {
        _userAttendance = attendanceMap;
      });
    } catch (error) {
      print('Fout bij het ophalen van aanwezigheid: $error');
    }
  }

  Future<void> _deleteSession() async {
    final sessionId = widget.session['id'];

    try {
      await supabase.from('sessions').delete().eq('id', sessionId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SessionsPage(groupId: null),
        ),
      );
    } catch (error) {
      print('Fout bij het verwijderen van de sessie: $error');
    }
  }

  Future<void> _updateAttendance(String userId, String status) async {
    final sessionId = widget.session['id'];

    try {
      await supabase.from('session_participants').upsert({
        'session_id': sessionId,
        'user_id': userId,
        'status': status,
      });

      setState(() {
        _userAttendance[userId] = status;
      });
    } catch (error) {
      print('Fout bij het bijwerken van aanwezigheid: $error');
    }
  }

  Future<void> _deleteAttendance(String userId, String status) async {
    final sessionId = widget.session['id'];

    try {
      await supabase.from('session_participants').delete().eq('user_id', userId).eq('session_id', sessionId);

      setState(() {
        _userAttendance[userId] = status;
      });
    } catch (error) {
      print('Fout bij het bijwerken van aanwezigheid: $error');
    }
  }

  Future<void> _updateSession(Map<String, dynamic> updates) async {
    final sessionId = widget.session['id'];

    try {
      await supabase.from('sessions').update(updates).eq('id', sessionId);

      setState(() {
        widget.session.addAll(updates);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessie succesvol aangepast!')),
      );
    } catch (error) {
      print('Fout bij het updaten van de sessie: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fout bij het aanpassen van de sessie')),
      );
    }
  }

  Future<void> _showEditSessionDialog() async {
    final TextEditingController groupIdController = TextEditingController(text: widget.session['group_id']?.toString() ?? '');
    final TextEditingController dateController = TextEditingController(text: widget.session['date'] ?? '');
    final TextEditingController durationController = TextEditingController(text: widget.session['duration']?.toString() ?? '');
    final TextEditingController maxParticipantsController = TextEditingController(text: widget.session['max_participants']?.toString() ?? '');
    final TextEditingController locationController = TextEditingController(text: widget.session['location'] ?? '');

    DateTime? selectedDateTime = DateTime.tryParse(widget.session['date'] ?? '');

    final user = supabase.auth.currentUser;
    if (_ownerId.contains(user?.id) || _admins.contains(user?.id)) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Sessie Aanpassen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Datum en Tijd'),
                    onTap: () async {
                      selectedDateTime = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selectedDateTime != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime!),
                        );
                        if (time != null) {
                          selectedDateTime = DateTime(
                            selectedDateTime!.year,
                            selectedDateTime!.month,
                            selectedDateTime!.day,
                            time.hour,
                            time.minute,
                          );
                          dateController.text = selectedDateTime!.toIso8601String();
                        }
                      }
                    },
                  ),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(labelText: 'Duur (minuten)'),
                    keyboardType: TextInputType.text,
                  ),
                  TextField(
                    controller: maxParticipantsController,
                    decoration: const InputDecoration(labelText: 'Max deelnemers'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Locatie'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Annuleren'),
              ),
              TextButton(
                onPressed: () async {
                  await _updateSession({
                    'group_id': groupIdController.text,
                    'date': selectedDateTime?.toIso8601String(),
                    'duration':durationController.text,
                    'max_participants': int.tryParse(maxParticipantsController.text),
                    'location': locationController.text,
                  });
                  Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SessionsPage(groupId: null),
                        ),
                      );
                  // Navigator.of(context).pop();
                },
                child: const Text('Opslaan'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('Sessie Details'),
        automaticallyImplyLeading: false,
        
        actions: [
          if (_admins.contains(user?.id ?? ''))
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Bevestig verwijdering'),
                      content: Text('Weet je zeker dat je deze sessie wilt verwijderen?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(), // Sluit de popup
                          child: Text('Annuleren'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Sluit de popup
                            _deleteSession(); // Voer de verwijderactie uit
                          },
                          child: Text('Verwijderen', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.delete),
              label: const Text('Verwijder sessie'),
            ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _groupUsers.length,
              itemBuilder: (context, index) {
                final user = _groupUsers[index];
                final userId = user['id'];
                final username = user['username'];
                final attendance = _userAttendance[userId] ?? 'afwezig';

                return ListTile(
                  title: Text(
                    username,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  dense: true,
                  //visualDensity: VisualDensity(vertical: -4),
                  subtitle: Text('Status: $attendance'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _updateAttendance(userId, 'aanwezig'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: attendance == 'aanwezig' ? Colors.green : Colors.white,
                          foregroundColor: attendance == 'aanwezig' ? Colors.white : Colors.black,
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          minimumSize: Size(30, 30),
                        ),
                        child: const Text(
                          'Aanwezig',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _deleteAttendance(userId, 'afwezig'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: attendance == 'afwezig' ? Colors.red : Colors.white,
                          foregroundColor: attendance == 'afwezig' ? Colors.white : Colors.black,
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          minimumSize: Size(30, 30),
                        ),
                        child: const Text(
                          'Afwezig',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          if (user == null)
            const BottomNavigationBarItem(
              icon: Icon(Icons.login),
              label: 'Inloggen',
            )
          else
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: user.userMetadata?['username'] ?? 'Profiel',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Groepen',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Sessies',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Instellingen',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => GroupsPage()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => GroupsPage()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SessionsPage(groupId: null)),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
              break;
            default:
              break;
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showEditSessionDialog,
        child: const Icon(Icons.edit),
      ),
    );
  }
}

