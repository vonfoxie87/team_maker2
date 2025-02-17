import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:team_maker2/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Laad .env als deze lokaal bestaat
  bool isLocal = false;
  try {
    await dotenv.load();
    isLocal = dotenv.env.isNotEmpty;
  } catch (e) {
    debugPrint('Geen .env bestand gevonden, overschakelen naar dart-define');
  }

  // Gebruik .env als het lokaal is, anders dart-define
  final String sbUrl = isLocal
      ? dotenv.env['SB_URL'] ?? ''
      : const String.fromEnvironment('SB_URL', defaultValue: '');

  final String sbKey = isLocal
      ? dotenv.env['SB_KEY'] ?? ''
      : const String.fromEnvironment('SB_KEY', defaultValue: '');

  if (sbUrl.isEmpty || sbKey.isEmpty) {
    debugPrint('❌ Supabase URL of Key ontbreekt! Controleer je .env bestand of dart-define instellingen.');
    return;
  }

  try {
    await Supabase.initialize(
      url: sbUrl,
      anonKey: sbKey,
    );
    runApp(const MyApp());
  } catch (e) {
    debugPrint('❌ Fout bij Supabase-initialisatie: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  ThemeMode _themeMode = ThemeMode.light; // Standaard licht thema

  @override
  void initState() {
    super.initState();
    _loadTheme(); // Laad opgeslagen thema-instelling
  }

  // Laad de opgeslagen thema-instelling
  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDarkMode = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  // Wissel tussen licht en donker en sla op
  Future<void> _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDark = _themeMode == ThemeMode.dark;
    setState(() {
      _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    });
    await prefs.setBool('isDarkMode', !isDark);
  }

  // Functie om een melding te tonen
  Future<void> showSessionStartedNotification() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check of de notificatie al eerder is verzonden
    bool? notificationSent = prefs.getBool('sessionNotificationSent') ?? false;

    if (!notificationSent) {
      // Stuur de notificatie
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'session_channel', 
        'Session Notifications', 
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

      // Markeer als verzonden
      await prefs.setBool('sessionNotificationSent', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Team Maker',
      theme: ThemeData.light(),  // Licht thema
      darkTheme: ThemeData.dark(), // Donker thema
      themeMode: _themeMode,  // Dynamisch wisselen

      locale: Locale('nl', 'NL'),
      supportedLocales: [
        Locale('nl', 'NL'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginPage(toggleTheme: _toggleTheme), // Geef toggle functie door
    );
  }
}
