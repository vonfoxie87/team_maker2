import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:team_maker2/pages/groups_page.dart';
import 'package:team_maker2/pages/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isLoading = false;
  bool _redirecting = false;
  late final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _passwordController = TextEditingController();
  late final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  late StreamSubscription<AuthState> _authStateSubscription;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Luister naar veranderingen in de authenticatiestatus
    _authStateSubscription = supabase.auth.onAuthStateChange.listen(
      (data) {
        if (_redirecting) return;
        final session = data.session;
        if (session != null) {
          _redirecting = true;
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const GroupsPage()),
            );
          }
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text,           // email
        password: _passwordController.text,     // wachtwoord
        data: {
          'username': _usernameController.text,  // gebruikersnaam
          'dob': _dobController.text,            // geboortedatum
        },
        emailRedirectTo: 'team_maker2://login',
      );

      final User? user = res.user;  // Verkrijg de gebruiker

      if (user != null) {
        // Voeg gebruiker toe aan de tabel `public.users`
        await Supabase.instance.client.from('users').insert({
          'id': user.id,
          'email': user.email,
          'username': _usernameController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registratie succesvol!')),
          );
          _redirecting = true;
          Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
        }
      } else {
        throw Exception('Registratie mislukt');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registratie'),
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
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Wachtwoord'),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Gebruikersnaam'),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      child: Text(_isLoading ? 'Registreren...' : 'Registreren'),
                    ),
                  ],
                ),
              ),
              // Toevoegen van een login link onderaan
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: const Text('Al een account? Log hier in'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}