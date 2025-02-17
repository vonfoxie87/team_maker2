import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'groups_page.dart';
import 'sessions_page.dart';
import 'package:team_maker2/pages/login_page.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const SettingsPage({super.key, required this.toggleTheme});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedIndex = 3; // De instellingenpagina is standaard geselecteerd
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final user = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();

    // Vul de controllers met de huidige gebruikersgegevens
    if (user != null) {
      _usernameController.text = user?.userMetadata?['username'] ?? '';
      _emailController.text = user?.email ?? '';
    }

    // Haal de groepen op bij het laden van de pagina
    _fetchUserGroups();
  }

  Future<void> _updateProfile() async {
    try {
      final newUsername = _usernameController.text.trim();
      final newEmail = _emailController.text.trim();

      if (newUsername.isEmpty || newEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gebruikersnaam en e-mail mogen niet leeg zijn.')),
        );
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('users') 
            .update({
              'username': newUsername,
              'email': newEmail,
            })
            .eq('id', userId);

        // Werk de lokale gebruikersgegevens bij
        // Bijwerken van de 'currentUser' zonder response
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            email: newEmail, // Nieuwe e-mail
            data: {'username': newUsername}, // Nieuwe gebruikersnaam
          ),
        );

        // Werk de UI bij
        setState(() {
          _usernameController.text = newUsername;
          _emailController.text = newEmail;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profiel succesvol bijgewerkt.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: Gebruiker niet gevonden.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: $e')),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigeren naar de juiste pagina afhankelijk van de geselecteerde index
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

  void _editGroupName(BuildContext context, dynamic groupId, String oldName) {
    final TextEditingController groupNameController = TextEditingController();
    groupNameController.text = oldName;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bewerk groepsnaam'),
          content: TextField(
            controller: groupNameController,
            decoration: InputDecoration(
              labelText: 'Nieuwe groepsnaam',
              hintText: 'Voer de nieuwe naam in',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Sluit de popup
              },
              child: Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = groupNameController.text.trim();
                if (newName.isNotEmpty) {
                  try {
                    // Update de groepsnaam in de database
                    await Supabase.instance.client
                        .from('groups')
                        .update({'name': newName})
                        .eq('id', groupId);

                    setState(() {
                      _fetchUserGroups(); // Vernieuw de lijst met groepen
                    });
                    Navigator.of(context).pop(); // Sluit de popup
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Groepsnaam bijgewerkt.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fout bij bewerken: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Naam mag niet leeg zijn.')),
                  );
                }
              },
              child: Text('Opslaan'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteGroup(BuildContext context, dynamic groupId, String groupName) {
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Groep verwijderen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Typ de groepsnaam in om te bevestigen:'),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: 'Groepsnaam',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Sluit de popup
              },
              child: Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (confirmController.text.trim() == groupName) {
                  try {
                    await Supabase.instance.client
                        .from('invitations')
                        .delete()
                        .eq('id', groupId);

                    // Verwijder de groep uit de database
                    await Supabase.instance.client
                        .from('groups')
                        .delete()
                        .eq('id', groupId);

                    setState(() {
                      _fetchUserGroups(); // Vernieuw de lijst met groepen
                    });
                    Navigator.of(context).pop(); // Sluit de popup
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Groep verwijderd.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fout bij verwijderen: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Groepsnaam komt niet overeen.')),
                  );
                }
              },
              child: Text('Verwijderen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Log de gebruiker uit via Supabase
      await Supabase.instance.client.auth.signOut();

      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage(toggleTheme: widget.toggleTheme)),
          (route) => false,);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij uitloggen: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserGroups() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        return [];
      }

      final data = await supabase
          .from('groups')
          .select('*')
          .contains('admins', [userId]);

      return List<Map<String, dynamic>>.from(data);
    } catch (error) {
      throw Exception('Fout bij het ophalen van groepen: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Instellingen'),
      actions: [
        TextButton.icon(
          onPressed: () {
            _logout(context);
          },
          icon: Icon(Icons.logout),
          label: Text('Uitloggen'),
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
        // Hoofdinhoud boven de afbeelding
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profiel',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'Gebruikersnaam'),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'E-mail'),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _updateProfile, // Voeg profiel update functionaliteit toe
                  child: Text('Bijwerken'),
                ),
                SizedBox(height: 40),
                Text(
                  'Jouw Groepen',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>( 
                  future: _fetchUserGroups(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Fout bij het ophalen van gegevens'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('Je hebt geen groepen.'));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        var group = snapshot.data![index];
                        return ListTile(
                          title: Text(group['name']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _editGroupName(context, group['id'], group['name']);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _confirmDeleteGroup(context, group['id'], group['name']);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
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
