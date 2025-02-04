import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:team_maker2/pages/sessions_page.dart';
import 'package:team_maker2/pages/registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _redirecting = false;
  late final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _passwordController = TextEditingController();
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
          Navigator.of(context).pushReplacement(
//            MaterialPageRoute(builder: (context) => const GroupsPage()),
            MaterialPageRoute(builder: (context) => SessionsPage(groupId: null)),
          );
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
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);

    try {
      final res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final session = res.session;
      if (session != null) {
        // Als er een sessie is, ga dan naar de groepenpagina
        if (mounted) {
          _redirecting = true;
          Navigator.of(context).pushReplacement(
            //MaterialPageRoute(builder: (context) => const GroupsPage()),
            MaterialPageRoute(builder: (context) => SessionsPage(groupId: null)),
          );
        }
      } else {
        throw Exception('Aanmelding mislukt');
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
        title: const Text('Login'),
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
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  child: Text(_isLoading ? 'Inloggen...' : 'Inloggen'),
                ),
                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      'Nog geen account? Registreer hier.',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
