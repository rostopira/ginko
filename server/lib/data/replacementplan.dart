import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart';
import 'package:models/models.dart';
import 'package:server/config.dart';
import 'package:server/data/unitplan.dart';
import 'package:server/extra/replacementplan.dart';
import 'package:server/notification.dart';
import 'package:server/parsers/replacementplan.dart';
import 'package:server/users.dart';
import 'package:translations/translations_server.dart';

// ignore: avoid_classes_with_only_static_members
/// ReplacementPlanData class
/// handles all replacement plan storing
class ReplacementPlanData {
  // ignore: public_member_api_docs
  static ReplacementPlan replacementPlan;

  // ignore: public_member_api_docs
  static ReplacementPlan previous;

  /// Complete all changes using the unit plan
  static void complete() {
    replacementPlan.replacementPlans =
        replacementPlan.replacementPlans.map((plan) {
      plan.changes = plan.changes
          .map((change) => change
            ..complete(change.getMatchingClasses(
                UnitPlanData.unitPlan.unitPlans[grades.indexOf(plan.grade)])))
          .toList();
      return plan;
    }).toList();
  }

  /// Load all replacement plans
  static Future load() async {
    final plans = [];
    for (var i = 0; i < 2; i++) {
      final dayOne = i == 0;
      plans.add(
        ReplacementPlan(
          replacementPlans: ReplacementPlanParser.extract(
            await ReplacementPlanParser.download(dayOne),
          ),
        ),
      );
    }
    replacementPlan = ReplacementPlanExtra.mergeReplacementPlans(
        plans.cast<ReplacementPlan>());
    UnitPlanData.complete();
    ReplacementPlanData.complete();
    previous ??= replacementPlan;
    if (previous.replacementPlans.isNotEmpty &&
            replacementPlan.replacementPlans.isNotEmpty &&
            previous.replacementPlans[0].replacementPlanDays.isNotEmpty &&
            replacementPlan
                .replacementPlans[0].replacementPlanDays.isNotEmpty &&
            previous.replacementPlans[0].replacementPlanDays[0].date !=
                replacementPlan
                    .replacementPlans[0].replacementPlanDays[0].date ||
        Config.dev) {
      print('Fire notifications!');

      for (final encryptedUsername in Users.encryptedUsernames) {
        final user = Users.getUser(encryptedUsername);
        for (final day in replacementPlan
            .replacementPlans[grades.indexOf(user.grade)].replacementPlanDays) {
          final changes = replacementPlan
              .replacementPlans[grades.indexOf(user.grade)].changes
              .where((change) {
            final block = UnitPlanData
                .unitPlan
                .unitPlans[grades.indexOf(user.grade)]
                .days[day.date.weekday - 1]
                .lessons[change.unit]
                .block;
            final key = Keys.selection(block, isWeekA(day.date));
            final userSelected = user.selection[key];
            final originalSubject = change.getMatchingClasses(
                UnitPlanData.unitPlan.unitPlans[grades.indexOf(user.grade)]);
            return userSelected == originalSubject.identifier;
          }).toList();
          final title =
              // ignore: lines_longer_than_80_chars
              '${ServerTranslations.weekdays(user.language)[day.date.weekday - 1]} ${outputDateFormat.format(day.date)}';
          final lines = [];
          var previousUnit = -1;
          for (final change in changes) {
            if (change.unit != previousUnit) {
              lines.add('<b>${change.unit + 1}. Stunde:</b>');
              previousUnit = change.unit;
            }

            final buffer = StringBuffer();
            if (change.subject != null && change.subject.isNotEmpty) {
              buffer.write(change.subject);
            }
            if (change.teacher != null && change.teacher.isNotEmpty) {
              buffer.write(' ${change.teacher}');
            }
            buffer.write(':');
            if (change.changed.subject != null &&
                change.changed.subject.isNotEmpty) {
              buffer.write(' ${change.changed.subject}');
            }
            if (change.changed.info != null && change.changed.info.isNotEmpty) {
              buffer.write(' ${change.changed.info}');
            }
            if (change.changed.teacher != null &&
                change.changed.teacher.isNotEmpty) {
              buffer.write(' ${change.changed.teacher}');
            }
            if (change.changed.room != null && change.changed.room.isNotEmpty) {
              buffer.write(' ${change.changed.room}');
            }
            lines.add(buffer.toString());
          }
          final bigBody = lines.isEmpty
              ? ServerTranslations.notificationsNoChanges(user.language)
              : lines.join('<br/>');
          final body = changes.isEmpty
              ? ServerTranslations.notificationsNoChanges(user.language)
              : changes.length == 1
                  ? bigBody
                  // ignore: lines_longer_than_80_chars
                  : '${changes.length} ${ServerTranslations.notificationsChanges(user.language)}';
          for (final token in user.tokens) {
            await Notification.send(
              token,
              title,
              body,
              bigBody: changes.length > 1 ? bigBody : null,
              data: {
                Keys.type: Keys.replacementPlan,
              },
            );
          }
        }
      }
      previous = ReplacementPlan.fromJSON(
          json.decode(json.encode(replacementPlan.toJSON())));
    } else {
      print('Nothing changed');
    }
    try {
      for (final replacementPlanForGrade in replacementPlan.replacementPlans) {
        for (final change in replacementPlanForGrade.changes) {
          change.getMatchingClasses(UnitPlanData.unitPlan
              .unitPlans[grades.indexOf(replacementPlanForGrade.grade)]);
        }
      }
    } on Exception catch (e, stacktrace) {
      print(e);
      print(stacktrace);
    }
  }
}

Future main(List<String> arguments) async {
  await setupDateFormats();
  Config.load();
  Config.dev = true;
  await UnitPlanData.load();
  if (arguments.isNotEmpty) {
    var files = [];
    for (final arg in arguments) {
      if (FileSystemEntity.isDirectorySync(arg)) {
        files = files
          ..addAll(Directory(arg)
              .listSync(recursive: true)
              .map((entity) => entity.path)
              .toList());
      } else {
        files.add(arg);
      }
    }
    for (final file in files
        .where((file) => file.split('.').reversed.toList()[0] == 'html')
        .where((file) => File(file).existsSync())
        .toList()) {
      //print(file);
      final replacementPlansForGrade =
          ReplacementPlanParser.extract(parse(File(file).readAsStringSync()));
      for (final replacementPlanForGrade in replacementPlansForGrade) {
        for (final change in replacementPlanForGrade.changes) {
          change.getMatchingClasses(UnitPlanData.unitPlan
              .unitPlans[grades.indexOf(replacementPlanForGrade.grade)]);
        }
      }
    }
  } else {
    await ReplacementPlanData.load();
  }
}
