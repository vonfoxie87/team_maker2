import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';  // Import de intl package
import 'groups_page.dart';
import 'settings_page.dart';
import 'new_sessie.dart'; // Nieuwe pagina importeren
import 'session_detail_page.dart'; // Voeg de import van je session detail page toe

// ignore_for_file: avoid_print
final supabase = Supabase.instance.client;

class SessionsPage extends StatefulWidget {
  final int? groupId;
  const SessionsPage({super.key, required this.groupId, required this.toggleTheme});
  final VoidCallback toggleTheme;

  @override
  _SessionsPageState createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  int _selectedIndex = 2;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchSessions();  // Zorg ervoor dat sessies opnieuw worden opgehaald wanneer de pagina wordt geopend
  }

  // Functie om de datum te formatteren naar het gewenste formaat
  String formatDate(String dateString) {
    final DateTime date = DateTime.parse(dateString);
    final DateFormat dateFormat = DateFormat("EEE dd-MM-yyyy - HH:mm", "nl_NL");
    return dateFormat.format(date);
  }

  Future<void> _fetchSessions() async {
    final user = supabase.auth.currentUser;
    final todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day); // Middernacht van vandaag
    if (user == null) return;

    try {
      if (widget.groupId != null) {
        // Haal alleen sessies op die in de toekomst liggen (datum groter dan vandaag)
        final sessionResponse = await supabase
            .from('sessions')
            .select()
            .eq('group_id', widget.groupId!)
            .gte('date', todayMidnight.toIso8601String()) // Filter sessies die na vandaag liggen
            .order('date', ascending: true);

        if (sessionResponse != null) {
          setState(() {
            _sessions = List<Map<String, dynamic>>.from(sessionResponse);
          });
        }
      } else {
        final groupResponse = await supabase
            .from('groups')
            .select()
            .contains('members', [user.id]);
            //.eq('user_id', user.id);

        if (groupResponse != null && groupResponse.isNotEmpty) {
          List<int> groupIds = List<int>.from(groupResponse.map((group) => group['id']));
          List<Map<String, dynamic>> allSessions = [];
          for (int groupId in groupIds) {
            // Haal alleen sessies op die in de toekomst liggen (datum groter dan vandaag)
            final sessionResponse = await supabase
                .from('sessions')
                .select()
                .eq('group_id', groupId)
                .gte('date', todayMidnight.toIso8601String()) // Filter sessies die na vandaag liggen
                .order('date', ascending: true);

            if (sessionResponse != null) {
              allSessions.addAll(List<Map<String, dynamic>>.from(sessionResponse));
            }
          }
          setState(() {
            _sessions = allSessions;
          });
        }
      }

      // Haal de groepsnamen op voor de sessies
      List<Map<String, dynamic>> sessionsWithGroupNames = [];
      for (var session in _sessions) {
        final groupId = session['group_id'];
        final groupResponse = await supabase
            .from('groups')
            .select('name')
            .eq('id', groupId)
            .single();

        session['group_name'] = groupResponse['name'];
        
        // Haal de deelnemers voor de sessie op uit de 'session_participants' tabel
        final participantsResponse = await supabase
            .from('session_participants')
            .select('user_id, status')
            .eq('session_id', session['id']); // Veronderstel dat je de session_id hier kunt gebruiken

        if (participantsResponse != null) {
          session['participants'] = List<Map<String, dynamic>>.from(participantsResponse);
        }

        sessionsWithGroupNames.add(session);
      }

      setState(() {
        _sessions = sessionsWithGroupNames;
      });
    } catch (error) {
      print('Fout bij het ophalen van sessies: $error');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        if (supabase.auth.currentUser == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => GroupsPage(toggleTheme: widget.toggleTheme)),
          );
        }
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => GroupsPage(toggleTheme: widget.toggleTheme)),
        );
        break;
      case 2:
        print("Je bent al op de Sessies pagina");
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SettingsPage(toggleTheme: widget.toggleTheme)),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sessies'),
        automaticallyImplyLeading: false,
        actions: [
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewSessiePage(toggleTheme: widget.toggleTheme),
                    ),
                  );
                },
                icon: Icon(Icons.add),
                label: Text(
                  'Nieuwe sessie',
                ),
              ),
            ],
          ),
      body: Stack(
      children: [
        // Achtergrondafbeelding
        Opacity(
          opacity: 0.05, // Stel de opaciteit in op 50%
          child: Image.asset(
            'assets/Icon-512.png',
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            fit: BoxFit.cover,
          ),
        ),
        Column(
        children: [
          Expanded(
            child: _sessions.isEmpty
                ? Center(child: Text('Geen sessies gevonden.'))
                : ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final groupName = session['group_name'];
                      final attendingCount = session['participants']?.where((participant) => participant['status'] == 'aanwezig').length ?? 0;
                      final isUserPresent = session['participants']?.any((participant) => participant['user_id'] == user?.id && participant['status'] == 'aanwezig') ?? false;

                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.transparent,
                            width: 5.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        margin: EdgeInsets.symmetric(vertical: 2.5),
                        child: ListTile(
                          title: Text('${formatDate(session['date'])}'),
                          subtitle: Text(
                            'Duur: ${session['duration']}\nLocatie: ${session['location']}\nAanwezig: $attendingCount\nJij bent: ${isUserPresent ? 'Aanwezig' : 'Afwezig'}'
                          ),
                          trailing: Text('$groupName', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
                          tileColor: Theme.of(context).brightness == Brightness.dark
                            ? Color.fromRGBO(0, 0, 0, 0.2)
                            : Colors.grey[200],
                          contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                          isThreeLine: true,
                          onTap: () async {
                            bool? isPresent = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SessionDetailPage(session: session, toggleTheme: widget.toggleTheme),
                              ),
                            );
                            if (isPresent != null) {
                              await _fetchSessions();
                            }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ],
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
              icon: Icon(Icons.brightness_6),
              label: Theme.of(context).brightness == Brightness.dark
                ? 'Licht'
                : 'Donker',
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
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[500]
          : Colors.grey[900],
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 0) {
              if (user == null) {
                // Logica voor inloggen als user == null
              } else {
                widget.toggleTheme(); // Als de gebruiker is ingelogd, wissel het thema
              }
            } else {
              _onItemTapped(index); // Andere navigatie-items zoals voorheen
            }
          });      
        },
      ),
    );
  }
}
