import 'package:app/home.dart';
import 'package:app/loading.dart';
import 'package:app/login.dart';
import 'package:app/utils/static.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_platform/flutter_platform.dart';
import 'package:flutter_platform_storage/flutter_platform_storage.dart';
import 'package:translations/translation_locales_list.dart';
import 'package:translations/translations_app.dart';

Future main() async {
  if (Platform().isDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }

  Static.storage = Storage();
  await Static.storage.init();

  runApp(MaterialApp(
    title: 'Ginko',
    theme: ThemeData(
      brightness: Brightness.light,
      primaryColor: Color(0xFF64A441),
      accentColor: Color(0xFF5BC638),
      fontFamily: 'Roboto',
    ),
    localizationsDelegates: [
      AppTranslationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales:
        LocalesList.locales.map((locale) => Locale(locale)).toList(),
    initialRoute: '/loading',
    routes: <String, WidgetBuilder>{
      '/': (context) => Container(),
      '/loading': (context) => Scaffold(body: Loading()),
      '/login': (context) => Scaffold(body: Login()),
      '/home': (context) => Scaffold(body: Home()),
    },
  ));
}
