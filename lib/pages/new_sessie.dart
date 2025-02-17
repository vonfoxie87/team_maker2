import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:team_maker2/pages/sessions_page.dart';

// ignore_for_file: avoid_print
final supabase = Supabase.instance.client;

class NewSessiePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const NewSessiePage({super.key, required this.toggleTheme});

  @override
  _NewSessiePageState createState() => _NewSessiePageState();
}

class _NewSessiePageState extends State<NewSessiePage> {
  final _formKey = GlobalKey<FormState>();
  String _duration = '2 uur';
  String _location = '';
  int _maxParticipants = 16;
  int? _selectedGroupId; // Opslaan van de geselecteerde groep
  List<Map<String, dynamic>> _groups = []; // Lijst om groepen op te slaan
  DateTime _selectedDate = DateTime.now(); // Huidige datum als standaard
  TimeOfDay _selectedTime = TimeOfDay(hour: 9, minute: 0); // Standaard tijd is 09:00

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _fetchGroups(); // Haal de groepen van de gebruiker op bij het laden van de pagina

    // Initialiseer notificaties
    final AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Haal de groepen op waar de gebruiker lid van is
  Future<void> _fetchGroups() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('groups')
          .select()
          .contains('members', [user.id]);
          //.eq('user_id', user.id);

      if (response != null) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(response);
          if (_groups.isNotEmpty) {
            _selectedGroupId = _groups[0]['id']; // Standaard de eerste groep selecteren
          }
        });
      }
    } catch (error) {
      print('Fout bij het ophalen van groepen: $error');
    }
  }

  // Functie om de sessie aan te maken
  Future<void> _createSessie() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        if (_selectedGroupId == null) {
          // Controleer of een groep is geselecteerd
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kies een groep voor de sessie.')),
            );
          }
          return;
        }

        // Combineer de datum en tijd
        final DateTime selectedDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        // Sessie invoegen in de database
        final response = await supabase.from('sessions').insert({
          'group_id': _selectedGroupId,
          'date': selectedDateTime.toIso8601String(),
          'duration': _duration,
          'max_participants': _maxParticipants,
          'location': _location,
        });

        // Navigeren terug naar de sessiespagina
        if (mounted) {
          Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SessionsPage(groupId: null, toggleTheme: widget.toggleTheme),
                      ),
                    );
        }
        
        // Succesbericht tonen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sessie succesvol aangemaakt!')),
          );
        }

        // Toon de notificatie zodra de sessie succesvol is aangemaakt
        await _showSessionStartedNotification();
      } catch (error) {
        // Toon een foutmelding als er iets misgaat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij het aanmaken van sessie: $error')),
        );
      }
    }
  }

  // Functie om de notificatie te tonen
  Future<void> _showSessionStartedNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'session_channel', // Channel ID
      'Session Notifications', // Channel name
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Nieuwe sessie gestart!',
      'Er is een nieuwe sessie gestart in je groep.',
      notificationDetails,
      payload: 'Sessie details of andere informatie hier',
    );
  }

  // Functie om de datum te selecteren via een DatePicker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: Locale('nl', 'NL'), // Zet de locale op Nederlands
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Functie om de tijd te selecteren via een TimePicker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nieuwe Sessie'),
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Dropdown voor het kiezen van de groep
                  DropdownButtonFormField<int>(
                    value: _selectedGroupId,
                    decoration: InputDecoration(labelText: 'Kies een Groep'),
                    items: _groups.map((group) {
                      return DropdownMenuItem<int>(
                        value: group['id'],
                        child: Text(group['name'] ?? 'Groep zonder naam'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGroupId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Kies een groep';
                      }
                      return null;
                    },
                  ),
                  // Datumveld voor het kiezen van de datum
                  TextFormField(
                    controller: TextEditingController(
                      text: DateFormat('d MMMM yyyy', 'nl_NL').format(_selectedDate),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Datum',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () => _selectDate(context), // Datumpicker aanroepen
                      ),
                    ),
                    readOnly: true, // Zorgt ervoor dat het veld alleen-lezen is
                  ),
                  // Tijdveld voor het kiezen van de tijd
                  TextFormField(
                    controller: TextEditingController(
                      text: _selectedTime.format(context), // Zet de geselecteerde tijd in het veld
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tijd',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.access_time),
                        onPressed: () => _selectTime(context), // TimePicker aanroepen
                      ),
                    ),
                    readOnly: true, // Zorgt ervoor dat het veld alleen-lezen is
                  ),
                  TextFormField(
                    initialValue: _duration,
                    decoration: InputDecoration(labelText: 'Duur'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vul de duur van de sessie in';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _duration = value!;
                    },
                  ),
                  TextFormField(
                    initialValue: _location,
                    decoration: InputDecoration(labelText: 'Locatie'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vul de locatie in';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _location = value!;
                    },
                  ),
                  TextFormField(
                    initialValue: _maxParticipants.toString(),
                    decoration: InputDecoration(labelText: 'Max deelnemers'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vul het aantal deelnemers in';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _maxParticipants = int.parse(value!);
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _createSessie,
                    child: Text('Sessie Aanmaken'),
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