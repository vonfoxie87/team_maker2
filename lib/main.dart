import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:team_maker2/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://hwptvjnzhqzzbdtaixqb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3cHR2am56aHF6emJkdGFpeHFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzczODI3NTMsImV4cCI6MjA1Mjk1ODc1M30.OgUXWuYSq1UyfD_FrioQjF1Dpd6kE2cZokrOIriZkQQ',
    );
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Fout bij Supabase-initialisatie: $e');
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

  @override
  void initState() {
    super.initState();

    // Initialiseer notificaties
    final AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
    );

    // Hier stel je de notificaties in zonder de onSelectNotification
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Toon een testmelding als de app start
    showSessionStartedNotification();
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
      title: 'Team maker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Zet de locale en zorg ervoor dat de lokale gegevens worden geladen.
      locale: Locale('nl', 'NL'),
      supportedLocales: [
        Locale('nl', 'NL'), // Nederlands als ondersteunde taal
        Locale('en', 'US'), // Engels als backup
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginPage(),
    );
  }
}
