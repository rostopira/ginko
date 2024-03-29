import 'package:app/utils/data.dart';
import 'package:app/utils/svg/svg.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:translations/translations_app.dart';

/// Login class
/// describes the login widget
class Login extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => LoginState();
}

/// LoginState class
/// describes the state of the login widget
class LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _focus = FocusNode();
  bool _credentialsCorrect = true;
  String _grade = grades[0];
  String _language;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCheckingForm = false;
  bool _validInputs = true;

  Future _checkForm([a]) async {
    setState(() {
      _isCheckingForm = true;
      _validInputs = _formKey.currentState.validate();
    });
    if (_validInputs) {
      Data.user = User(
        username: _usernameController.text,
        password: _passwordController.text,
        grade: UserValue('grade', _grade),
        language: UserValue('language', _language),
        selection: [],
        tokens: [],
      );
      await Data.load().then((code) {
        setState(() {
          _credentialsCorrect = code != ErrorCode.wrongCredentials;
          _isCheckingForm = false;
        });
        switch (code) {
          case ErrorCode.none:
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacementNamed('/home');
            break;
          case ErrorCode.offline:
            Scaffold.of(context).showSnackBar(SnackBar(
              content: Text(AppTranslations.of(context).loginFailed),
            ));
            break;
          case ErrorCode.wrongCredentials:
            _formKey.currentState.validate();
            _passwordController.clear();
            break;
        }
      });
    } else {
      setState(() {
        _isCheckingForm = false;
      });
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((a) {
      _language = AppTranslations.of(context).locale.languageCode;
    });
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Scaffold(
          body: ListView(
            padding: EdgeInsets.all(10),
            children: <Widget>[
              Container(
                height: 125,
                margin: EdgeInsets.only(bottom: 5),
                child: SvgPicture.asset('images/logo_green.svg'),
              ),
              Center(
                child: Text(
                  AppTranslations.of(context).appName,
                  style: TextStyle(fontSize: 25),
                ),
              ),
              Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    DropdownButtonFormField(
                      items: grades
                          .map((value) => DropdownMenuItem<String>(
                                value: value,
                                child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width - 100,
                                  child: Text(value),
                                ),
                              ))
                          .toList(),
                      value: _grade,
                      onChanged: (grade) {
                        setState(() {
                          _grade = grade;
                        });
                      },
                    ),
                    // Username input
                    TextFormField(
                      controller: _usernameController,
                      // ignore: missing_return
                      validator: (value) {
                        if (value.isEmpty) {
                          return AppTranslations.of(context)
                              .loginUserNameRequired;
                        }
                      },
                      decoration: InputDecoration(
                          hintText: AppTranslations.of(context).loginUsername),
                      onFieldSubmitted: (value) {
                        FocusScope.of(context).requestFocus(_focus);
                      },
                    ),
                    // Password input
                    TextFormField(
                      controller: _passwordController,
                      // ignore: missing_return
                      validator: (value) {
                        if (value.isEmpty) {
                          return AppTranslations.of(context)
                              .loginPasswordRequired;
                        }
                      },
                      decoration: InputDecoration(
                          hintText: AppTranslations.of(context).loginPassword),
                      onFieldSubmitted: _checkForm,
                      obscureText: true,
                      focusNode: _focus,
                    ),
                    // Login button
                    Container(
                      margin: EdgeInsets.only(top: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: RaisedButton(
                          color: Theme.of(context).accentColor,
                          onPressed: _checkForm,
                          child: !_isCheckingForm
                              ? Text(AppTranslations.of(context).loginSubmit)
                              : SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                    strokeWidth: 2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (!_credentialsCorrect && _validInputs)
                      Container(
                        margin: EdgeInsets.only(top: 10),
                        width: double.infinity,
                        child: Text(
                          AppTranslations.of(context).loginCredentialsWrong,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
