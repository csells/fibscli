import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController _userController = TextEditingController();
  TextEditingController _passController = TextEditingController();
  var _shouldAutologin = false;

  @override
  void initState() {
    super.initState();
    if (App.prefs.value == null)
      App.prefs.addListener(_autologin);
    else
      _autologin();
  }

  void _autologin() {
    App.prefs.removeListener(_autologin);

    final prefs = App.prefs.value;
    final autologin = prefs.getBool('autologin') ?? false;
    if (!autologin) return;

    final user = prefs.getString('user');
    final pass = prefs.getString('pass'); // TODO: obscure this
    if (user == null || pass == null) return;

    App.fibs.login(user: user, pass: pass);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(App.title)),
        body: ValueListenableBuilder<SharedPreferences>(
          valueListenable: App.prefs,
          builder: (context, prefs, child) => prefs == null
              ? CircularProgressIndicator()
              : SizedBox.expand(
                  child: Form(
                    child: Align(
                      alignment: Alignment.center,
                      child: Center(
                        child: Container(
                          width: 500,
                          child: Column(
                            children: [
                              SizedBox(height: 20),
                              Text(
                                'FIBS Login',
                                style: TextStyle(
                                    color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500, fontSize: 36),
                              ),
                              SizedBox(height: 20),
                              TextField(
                                controller: _userController,
                                decoration: InputDecoration(labelText: 'user'),
                              ),
                              SizedBox(height: 20),
                              TextField(
                                obscureText: true,
                                controller: _passController,
                                decoration: InputDecoration(labelText: 'password'),
                              ),
                              SizedBox(height: 20),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _shouldAutologin,
                                    onChanged: (checked) => setState(() => _shouldAutologin = checked),
                                  ),
                                  Text('Remember user name and password'),
                                ],
                              ),
                              SizedBox(height: 20),
                              RaisedButton(
                                child: Text('Login'),
                                onPressed: () {
                                  final user = _userController.text;
                                  final pass = _passController.text;
                                  if (user.isEmpty || pass.isEmpty) return;

                                  if (_shouldAutologin) {
                                    prefs.setBool('autologin', true);
                                    prefs.setString('user', user);
                                    prefs.setString('pass', pass);
                                  }

                                  App.fibs.login(user: user, pass: pass);
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
