// ignore_for_file: use_build_context_synchronously
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessions_page.dart';
import 'settings_page.dart';
import 'groups_detail_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({Key? key, this.onGroupIdUpdate}) : super(key: key);
  final Function(int?)? onGroupIdUpdate;

  @override
  _GroupsPageState createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late Future<List<Map<String, dynamic>>> _groupsFuture;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _fetchGroups();
  }

  // Aangepaste functie om groepen op te halen waarin de gebruiker lid of admin is
  Future<List<Map<String, dynamic>>> _fetchGroups() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      return [];
    }

    try {
      // Haal alle groepen op
      final data = await supabase
          .from('groups')
          .select('*');

      // Filter groepen waar de gebruiker in de admins of members lijst zit
      final userGroups = data.where((group) {
        final admins = List<String>.from(group['admins']);
        final members = List<String>.from(group['members']);

        // Kijk of de gebruiker in de admins of members lijst zit
        return admins.contains(userId) || members.contains(userId);
      }).toList();

      // Filter de groepen zodat de gebruiker niet zowel admin als member is
      final uniqueGroups = userGroups.map((group) {
        final members = List<String>.from(group['members']);
        final admins = List<String>.from(group['admins']);

        List<String> newMembers = List<String>.from(admins);
        newMembers.addAll(members);
        newMembers = newMembers.toSet().toList();

        return {
          ...group,
          'members': newMembers, // Bijgewerkte lijst van members
        };
      }).toList();
      return uniqueGroups;
    } catch (error) {
      throw Exception('Fout bij het ophalen van groepen: $error');
    }
  }


  void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  final user = Supabase.instance.client.auth.currentUser; // Verkrijg de huidige gebruiker

  switch (index) {
    case 0:
      // Maak de knop zichtbaar, maar blokkeer de actie als de gebruiker al is ingelogd
      if (user == null) { // Alleen als er geen gebruiker is
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => GroupsPage()),
          (route) => false,
        );
      }
      break;
      case 1:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => GroupsPage()),
          (route) => false,
        );
        break;
      case 2:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SessionsPage(groupId: null)),
          (route) => false,
        );
        break;
      case 3:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SettingsPage()),
          (route) => false,
        );
        break;
      default:
        break;
    }
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nieuwe groep maken'),
        content: TextField(
          controller: _groupNameController,
          decoration: InputDecoration(labelText: 'Groepsnaam'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_groupNameController.text.isNotEmpty) {
                final supabase = Supabase.instance.client;

                try {
                  // Probeer de groep aan te maken in de database
                  await supabase.from('groups').insert({
                    'name': _groupNameController.text,
                    'user_id': supabase.auth.currentUser!.id,
                    'admins': [supabase.auth.currentUser!.id],
                    'members': [supabase.auth.currentUser!.id],
                  });

                  // Bijwerken van de groepen na het aanmaken van de groep
                  setState(() {
                    _groupsFuture = _fetchGroups();
                  });

                  // Het formulier leegmaken
                  _groupNameController.clear();

                  // De dialoog sluiten
                  if (mounted) {
                    Navigator.of(context).pop();
                  }

                  // Controleer of de widget nog gemonteerd is voordat we de SnackBar tonen
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Groep succesvol aangemaakt!')),
                    );
                  }
                } catch (error) {
                  // Controleer ook of de widget gemonteerd is bij het weergeven van de foutmelding
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fout bij het aanmaken van de groep: $error')),
                    );
                  }
                }

              }
            },
            child: Text('Verzenden'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deelnemen aan een groep'),
        content: TextField(
          controller: _inviteCodeController,
          decoration: InputDecoration(labelText: 'Uitnodigingscode'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_inviteCodeController.text.isNotEmpty) {
                final supabase = Supabase.instance.client;
                final inviteCode = _inviteCodeController.text;

                try {
                  // Haal de uitnodiging op uit de database
                  final invitation = await supabase
                      .from('invitations')
                      .select('*')
                      .eq('token', inviteCode)
                      .maybeSingle();

                  // Controleer of de uitnodiging geldig is
                  if (invitation == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ongeldige code.')),
                      );
                    }
                    return;
                  }

                  final groupId = invitation['group_id'];
                  // Haal de groep op
                  final group = await supabase
                      .from('groups')
                      .select('members')
                      .eq('id', groupId)
                      .maybeSingle();

                  // Controleer of de groep bestaat
                  if (group == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Groep niet gevonden.')),
                      );
                    }
                    return;
                  }

                  final List<dynamic> members = group['members'] ?? [];
                  // Controleer of de gebruiker al lid is
                  if (!members.contains(supabase.auth.currentUser!.id)) {
                    members.add(supabase.auth.currentUser!.id);

                    try {
                      // Werk de groepsleden bij
                      final response = await supabase
                          .from('groups')
                          .update({'members': members})
                          .eq('id', groupId);

                      print(response);
                    } catch (e) {
                      print('Update failed: $e');
                    }

                    // Werk de lijst met groepen bij
                    setState(() {
                      _groupsFuture = _fetchGroups();
                    });

                    // Leeg het invoerveld en sluit de dialoog
                    _inviteCodeController.clear();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                    
                    // Toon een succesbericht
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Succesvol lid geworden van de groep!')),
                      );
                    }
                  } else {
                    // Als de gebruiker al lid is
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Je bent al lid van deze groep.')),
                      );
                    }
                  }
                } catch (error) {
                  // Toon een foutmelding bij een fout in het proces
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fout bij het lid worden: $error')),
                    );
                  }
                }
              }
            },
            child: Text('Verzenden'),
          ),
        ],
      ),
    );
  }
  Future<int> _getMemberCount(String groupId) async {
    final response = await Supabase.instance.client
        .from('groups')
        .select('admins, members')
        .eq('id', groupId)
        .single();  // Haal een enkel record op in plaats van een lijst

    if (response != null) {
      final members = List<String>.from(response['members']);
      final admins = List<String>.from(response['admins']);

      // Tel het aantal unieke leden (admins + members)
      final totalMembers = (members.toSet().union(admins.toSet())).length;
      return totalMembers;
    }
    return 0;  // Als er geen data is, geef 0 terug
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Groepen'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: _showCreateGroupDialog,
            icon: Icon(Icons.add),
            label: Text('Nieuwe groep'),
          )
        ],
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.05, // Stel de opaciteit in op 50%
            child: Image.asset(
              'assets/Icon-512.png',
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<List<Map<String, dynamic>>>( // Haal de groepen op
              future: _groupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Fout bij het ophalen van gegevens'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Geen groepen gevonden.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    var group = snapshot.data![index];

                    return FutureBuilder<int>(  // Gebruik FutureBuilder om het aantal leden op te halen
                      future: _getMemberCount(group['id'].toString()),  // Convertie naar string voor database-query
                      builder: (context, countSnapshot) {
                        if (countSnapshot.connectionState == ConnectionState.waiting) {
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
                              title: Text(group['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Laden...'),  // Toon laadbericht
                              tileColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                              isThreeLine: true,
                            ),
                          );
                        }

                        if (countSnapshot.hasError) {
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
                              title: Text(group['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Fout bij het ophalen van leden'),  // Toon foutmelding
                              tileColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                              isThreeLine: true,
                            ),
                          );
                        }

                        final groupCount = countSnapshot.data ?? 0;  // Gebruik 0 als er geen data is
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
                            title: Text(group['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$groupCount leden'),  // Toon het aantal leden
                            tileColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                            isThreeLine: true,
                            onTap: () {
                              final groupId = group['id'];  // Hier hoef je niet meer te converteren
                              widget.onGroupIdUpdate?.call(groupId);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupDetailPage(groupId: groupId),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showJoinGroupDialog,
        label: Text('Uitnodigingscode'),
        icon: Icon(Icons.add),
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
        onTap: _onItemTapped,
      ),
    );
  }
}
