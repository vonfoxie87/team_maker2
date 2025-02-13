import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:team_maker2/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String sbUrl = String.fromEnvironment('SB_URL', defaultValue: '');
  const String sbKey = String.fromEnvironment('SB_KEY', defaultValue: '');

  if (sbUrl.isEmpty || sbKey.isEmpty) {
    debugPrint('❌ Supabase URL of Key ontbreekt! Controleer je dart-define instellingen.');
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

  @override
  void initState() {
    super.initState();

    // Initialiseer notificaties
    final AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
