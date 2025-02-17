import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'groups_page.dart';
import 'sessions_page.dart';
import 'settings_page.dart';
import 'dart:math';
import 'package:flutter/services.dart';

// ignore_for_file: avoid_print
final supabase = Supabase.instance.client;

class GroupDetailPage extends StatefulWidget {
  final int groupId; // Groep-ID als int
  final VoidCallback toggleTheme;
  const GroupDetailPage({super.key, required this.groupId, required this.toggleTheme});

  @override
  _GroupDetailPageState createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  List<Map<String, dynamic>> _groupUsers = [];
  bool _isLoading = true;
  int _selectedIndex = 1; // Voor navigatie van de BottomNavigationBar
  List<String> admins = []; // Lijst van admin-IDs
  String invitationCode = ''; // Uitnodigingscode voor de groep

  @override
  void initState() {
    super.initState();
    _fetchGroupUsers();
    _fetchInvitationCode(); // Haal uitnodigingscode op bij het laden van de pagina
    _fetchInvitationCode().then((_) {
    if (invitationCode.isEmpty) {
      _generateInvitationCode().then((code) {
        _saveInvitationCode(widget.groupId, code);
        setState(() {
          invitationCode = code;  // Zet de uitnodigingscode in de UI
        });
      });
    }
  });
  }

  // Haal gebruikers op voor de groep
  Future<void> _fetchGroupUsers() async {
    final groupId = widget.groupId;

    try {
      final groupResponse = await supabase
          .from('groups')
          .select('user_id, admins, members')
          .eq('id', groupId)
          .single(); // Haal de groep op met de opgegeven groupId

      final ownerId = groupResponse['user_id'];
      admins = List<String>.from(groupResponse['admins']);
      final members = List<String>.from(groupResponse['members']);

      final allMembers = [ownerId, ...admins, ...members];
      final uniqueMembers = allMembers.toSet().toList();

      List<Map<String, dynamic>> users = [];
      for (var userId in uniqueMembers) {
        final userResponse = await supabase
            .from('users')
            .select('id, username')
            .eq('id', userId)
            .single();

        if (userResponse != null) {
          users.add(userResponse);
        } else {
          // ignore_for_file: avoid_print
          print('User with ID $userId not found.');
        }
      }

      setState(() {
        _groupUsers = users;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching group users: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Genereer een uitnodigingscode
  Future<String> _generateInvitationCode() async {
    final rand = Random();
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrsuvwxzy';
    String code = '';
    for (int i = 0; i < 16; i++) {
      code += characters[rand.nextInt(characters.length)];
    }
    return code;
  }

  // Sla de uitnodigingscode op in de database
  Future<void> _saveInvitationCode(int groupId, String code) async {
    final createdAt = DateTime.now().toIso8601String();
    try {
      await supabase.from('invitations').insert([
        {
          'group_id': groupId,
          'token': code,
          'created_at': createdAt,
        }
      ]).single(); // Gebruik .single() om de insert bewerking uit te voeren zonder execute()

      print('Invitation code saved for group $groupId');
    } catch (e) {
      print('Error generating or saving invitation code: $e');
    }
  }

  // Haal de uitnodigingscode op
  Future<void> _fetchInvitationCode() async {
    final groupId = widget.groupId;

    try {
      final response = await supabase
          .from('invitations')
          .select('token')
          .eq('group_id', groupId)
          .limit(1)
          .single();

      if (response != null && response['token'] != null && response['token']!.isNotEmpty) {
        setState(() {
          invitationCode = response['token'];
        });
      } else {
        // Als de code niet bestaat, genereer een nieuwe code
        final newCode = await _generateInvitationCode();
        await _saveInvitationCode(groupId, newCode);
        setState(() {
          invitationCode = newCode;
        });
        print('Nieuwe uitnodigingscode gegenereerd: $invitationCode');
      }
    } catch (e) {
      print('Error fetching invitation code: $e');
    }
  }

  // Wijzig de rol van een gebruiker (beheerder of gewone gebruiker)
  Future<void> _updateUserRole(String userId, bool isAdmin) async {
    final groupId = widget.groupId;

    try {
      final groupResponse = await supabase
          .from('groups')
          .select('admins')
          .eq('id', groupId)
          .single();

      List<dynamic> admins = List.from(groupResponse['admins']);

      if (isAdmin) {
        if (!admins.contains(userId)) {
          admins.add(userId);
        }
      } else {
        admins.remove(userId);
      }
      await supabase
          .from('groups')
          .update({'admins': admins})
          .eq('id', groupId)
          .select()
          .single(); // Gebruik .single() voor de update

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailPage(groupId: groupId, toggleTheme: widget.toggleTheme),
              ),
            );
      // _fetchGroupUsers();
      
    } catch (error) {
      print('Error updating user role: $error');
    }
  }

  // Verwijder een gebruiker uit de groep
  Future<void> _removeUserFromGroup(String userId) async {
    final groupId = widget.groupId;

    try {
      final groupResponse = await supabase
          .from('groups')
          .select('members')
          .eq('id', groupId)
          .single(); // Haal de groep op met de opgegeven groupId

      if (groupResponse != null) {
        List<dynamic> members = List.from(groupResponse['members']);
        members.remove(userId);

        await supabase
            .from('groups')
            .update({'members': members})
            .eq('id', groupId)
            .select()
            .single(); // Gebruik .single() voor de update

        Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailPage(groupId: groupId, toggleTheme: widget.toggleTheme),
                      ),
                    );
        _fetchGroupUsers();
      }
    } catch (error) {
      print('Error removing user from group: $error');
    }
  }

  // Navigatie voor de BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => GroupsPage(toggleTheme: widget.toggleTheme)),
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => GroupsPage(toggleTheme: widget.toggleTheme)),
          (route) => false,
        );
        break;
      case 2:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SessionsPage(groupId: null, toggleTheme: widget.toggleTheme)),
          (route) => false,
        );
        break;
      case 3:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SettingsPage(toggleTheme: widget.toggleTheme)),
          (route) => false,
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser; // Huidige gebruiker
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Details'),
        automaticallyImplyLeading: false,
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
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Uitnodigingscode weergeven
                      ListTile(
                        title: Text('Uitnodigingscode: ${invitationCode ?? 'Geen code gegenereerd'}'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            if (invitationCode == null || invitationCode.isEmpty) {
                              // Genereer de uitnodigingscode als er nog geen is
                              final code = await _generateInvitationCode();
                              await _saveInvitationCode(widget.groupId, code);
                              setState(() {
                                invitationCode = code;
                              });
                            } else {
                              // Kopieer de code naar het klembord
                              await Clipboard.setData(ClipboardData(text: invitationCode));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Uitnodigingscode gekopieerd naar het klembord!')),
                                );
                              }
                            }
                          },
                          child: Text(invitationCode.isEmpty ? 'Genereer uitnodigingscode' : 'Kopieer'),
                        ),
                      ),
                      // Lijst van groepsleden
                      Expanded(
                        child: ListView.builder(
                          itemCount: _groupUsers.length,
                          itemBuilder: (context, index) {
                            final user = _groupUsers[index];
                            final userId = user['id'];
                            final username = user['username'];

                            bool isAdmin = admins.contains(userId);  // Controleer of de gebruiker een admin is
                            bool isCurrentUser = userId == supabase.auth.currentUser?.id;
                            bool isCurrentUserAdmin = false;

                            // Controleer of de huidige gebruiker een admin is
                            if (supabase.auth.currentUser != null) {
                              isCurrentUserAdmin = admins.contains(supabase.auth.currentUser!.id);
                            }

                            return ListTile(
                              title: Text(
                                username,
                                style: TextStyle(fontWeight: FontWeight.bold), // Maakt de tekst dikgedrukt
                              ),
                              dense: true,
                              subtitle: Text(isAdmin ? 'Beheerder' : 'Gebruiker'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCurrentUserAdmin) ...[
                                    ElevatedButton(
                                      onPressed: () {
                                        _updateUserRole(userId, !isAdmin);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isAdmin == true
                                            ? const Color.fromARGB(255, 190, 175, 41)
                                            : const Color.fromARGB(255, 53, 163, 25),
                                        foregroundColor: Colors.black,
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        minimumSize: Size(30, 30),
                                      ),
                                      child: Text(
                                        isAdmin ? 'Maak gebruiker' : 'Maak beheerder',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text("  "),
                                    ElevatedButton(
                                      onPressed: () {
                                        _removeUserFromGroup(userId);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(255, 151, 10, 10),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        minimumSize: Size(30, 30),
                                      ),
                                      child: Text('Verwijder', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
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
        if (index == 0) {
          if (user == null) {
          } else {
            widget.toggleTheme();
          }
        } else {
          _onItemTapped(index);
        }
        }
      ),
    );
  }
}
