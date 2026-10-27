import 'package:flutter/material.dart';

import '../constants.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pass = TextEditingController();
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  void _enter() {
    final p = _pass.text.trim();
    if (p == readerPassword) {
      _open(isDeveloper: false);
    } else if (p == developerPassword) {
      _open(isDeveloper: true);
    } else {
      setState(() => _error = 'كلمة المرور غير صحيحة');
    }
  }

  void _open({required bool isDeveloper}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(isDeveloper: isDeveloper)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: const Color(0xff1b1d2b),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 72, color: Color(0xffb7a9ff)),
                    const SizedBox(height: 14),
                    const Text(appName, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('دروسك وملخصاتك في مكان واحد'),
                    const SizedBox(height: 26),
                    TextField(
                      controller: _pass,
                      obscureText: _hide,
                      onSubmitted: (_) => _enter(),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        errorText: _error,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _enter,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('دخول'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
