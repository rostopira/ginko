import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:models/models.dart';
import 'package:server/config.dart';
import 'package:server/data/cafetoria.dart';
import 'package:server/data/calendar.dart';
import 'package:server/data/replacementplan.dart';
import 'package:server/data/teachers.dart';
import 'package:server/data/unitplan.dart';
import 'package:server/notification.dart';
import 'package:server/users.dart';

Future main() async {
  await _setup();
  print('Running in ${Config.dev ? 'development' : 'production'} mode');
  final port = int.parse((Platform.environment['PORT'] == ''
          ? null
          : Platform.environment['PORT']) ??
      '8000');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Listening on *:$port');

  await for (final request in server) {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', '*');
    if (request.uri.path == '/' && request.method == 'GET') {
      final queryParams = request.uri.queryParameters;
      if (queryParams[Keys.user] == 'null' || queryParams[Keys.user] == null) {
        request.response.statusCode = 401;
        request.response.write('401 Unauthorized');
      } else {
        final user = User.fromJSON(json.decode(queryParams[Keys.user]));
        if (Users.encryptedUsernames.contains(user.username) &&
            Users.getUser(user.username).encryptedPassword == user.password) {
          Users.updateLanguage(user.username, user.language);
          Users.updateSelection(user.username, user.selection);
          Users.updateTokens(user.username, user.tokens);
          // ignore: omit_local_variable_types
          final Map<String, dynamic> data = {
            'status': 'ok',
            Keys.user: Users.getUser(user.username).toJSON(),
          };
          for (final key in queryParams.keys.where((key) => key != Keys.user)) {
            try {
              final value = int.parse(queryParams[key]);
              if (key == Keys.unitPlan) {
                if (value <
                    UnitPlanData.unitPlan.unitPlans
                        .where((unitPlan) => unitPlan.grade == user.grade.value)
                        .toList()[0]
                        .timeStamp) {
                  data[key] = UnitPlanData.unitPlan.unitPlans
                      .where((unitPlan) => unitPlan.grade == user.grade.value)
                      .toList()[0]
                      .toJSON();
                }
              } else if (key == Keys.calendar) {
                if (value < CalendarData.calendar.timeStamp) {
                  data[key] = CalendarData.calendar.toJSON();
                }
              } else if (key == Keys.cafetoria) {
                if (value < CafetoriaData.cafetoria.timeStamp) {
                  data[key] = CafetoriaData.cafetoria.toJSON();
                }
              } else if (key == Keys.replacementPlan) {
                if (value <
                    ReplacementPlanData.replacementPlan.replacementPlans
                        .where((replacementPlan) =>
                            replacementPlan.grade == user.grade.value)
                        .toList()[0]
                        .timeStamp) {
                  data[key] = ReplacementPlanData
                      .replacementPlan.replacementPlans
                      .where((replacementPlan) =>
                          replacementPlan.grade == user.grade.value)
                      .toList()[0]
                      .toJSON();
                }
              } else if (key == Keys.teachers) {
                if (value < TeachersData.teachers.timeStamp) {
                  data[key] = TeachersData.teachers.toJSON();
                }
              } else {
                print('$key: $value');
              }
              // ignore: unused_catch_clause, empty_catches
            } on Exception catch (e, stacktrace) {
              print(e);
              print(stacktrace.toString());
            }
          }
          request.response.headers.contentType =
              ContentType('application', 'json', charset: 'utf-8');
          request.response.write(json.encode(data));
        } else {
          request.response.statusCode = 401;
          request.response.write('401 Unauthorized');
        }
      }
    } else {
      request.response.statusCode = 404;
      request.response.write('404 Not Found');
    }
    await request.response.close();
  }
}

Future _setup() async {
  await setupDateFormats();
  Config.load();
  print('Config loaded');
  Users.load();
  print('Users loaded');
  await _deleteOldTokens();
  await TeachersData.load();
  print('Teachers loaded');
  await UnitPlanData.load();
  print('Unit plan loaded');
  await CalendarData.load();
  print('Calendar loaded');
  await CafetoriaData.load();
  print('Cafetoria loaded');
  await ReplacementPlanData.load();
  print('Replacement plan loaded');
  Timer.periodic(Duration(minutes: 1), (a) async {
    await ReplacementPlanData.load();
    print('Replacement plan reloaded');
  });
}

Future _deleteOldTokens() async {
  for (final encryptedUsername in Users.encryptedUsernames) {
    final user = Users.getUser(encryptedUsername);

    final unregisteredTokens = [];
    for (final token in user.tokens) {
      final tokenRegistered = await Notification.checkToken(token);
      if (!tokenRegistered) {
        unregisteredTokens.add(token);
      }
    }
    for (final unregisteredToken in unregisteredTokens) {
      Users.removeToken(user.encryptedUsername, unregisteredToken);
    }
  }
}
