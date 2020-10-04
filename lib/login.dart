import 'package:fibscli/main.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController _userController = TextEditingController();
  TextEditingController _passController = TextEditingController();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(App.title)),
        body: SizedBox.expand(
          child: Form(
            child: Align(
              alignment: Alignment.center,
              child: Center(
                child: Container(
                  width: 500,
                  child: Column(
                    children: [
                      Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'FIBS Login',
                            style: TextStyle(
                                color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500, fontSize: 36),
                          )),
                      Container(
                        child: TextField(
                          controller: _userController,
                          decoration: InputDecoration(labelText: 'user'),
                        ),
                      ),
                      Divider(),
                      Container(
                        child: TextField(
                          obscureText: true,
                          controller: _passController,
                          decoration: InputDecoration(labelText: 'password'),
                        ),
                      ),
                      Divider(),
                      Container(
                        child: RaisedButton(
                          child: Text('Login'),
                          onPressed: () {
                            final fibs = FibsConnection(App.fibsProxy, App.fibsPort);
                            fibs.login(_userController.text, _passController.text);
                            App.fibs.value = fibs;
                          },
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
