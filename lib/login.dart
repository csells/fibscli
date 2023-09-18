import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool? _shouldAutologin = false;

  @override
  void initState() {
    super.initState();
    if (App.prefs.value == null) {
      App.prefs.addListener(_autologin);
    } else {
      unawaited(_autologin());
    }
  }

  Future<void> _autologin() async {
    App.prefs.removeListener(_autologin);

    final prefs = App.prefs.value!;
    final autologin = prefs.getBool('autologin') ?? false;
    if (!autologin) return;

    final user = prefs.getString('user');
    final pass = prefs.getString('pass'); // TODO: obscure this
    if (user == null || pass == null) return;

    await _login(user, pass);
  }

  Future<bool> _login(String user, String pass) async {
    dev.log('_login($user)');

    try {
      await App.fibs.login(user: user, pass: pass);
      return true;
    } on Exception catch (ex) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unable to login to FIBS'),
            content: Text(ex.toString()),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }

      return false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(App.title)),
        body: ValueListenableBuilder<SharedPreferences?>(
          valueListenable: App.prefs,
          builder: (context, prefs, child) => prefs == null
              ? const CircularProgressIndicator()
              : SizedBox.expand(
                  child: Form(
                    child: Align(
                      alignment: Alignment.center,
                      child: Center(
                        child: SizedBox(
                          width: 500,
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                'FIBS Login',
                                style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 36),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _userController,
                                decoration:
                                    const InputDecoration(labelText: 'user'),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                obscureText: true,
                                controller: _passController,
                                decoration: const InputDecoration(
                                    labelText: 'password'),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _shouldAutologin,
                                    onChanged: (checked) => setState(
                                        () => _shouldAutologin = checked),
                                  ),
                                  const Text('Remember user name and password'),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                child: const Text('Login'),
                                onPressed: () async {
                                  final user = _userController.text;
                                  final pass = _passController.text;
                                  if (user.isEmpty || pass.isEmpty) return;
                                  if (await _login(user, pass)) {
                                    await prefs.setBool(
                                        'autologin', _shouldAutologin!);
                                    await prefs.setString('user', user);
                                    await prefs.setString('pass', pass);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      );
}
