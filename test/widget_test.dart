import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteeb/core/day.dart';
import 'package:tarteeb/core/format.dart';
import 'package:tarteeb/core/money.dart';
import 'package:tarteeb/core/strings.dart';
import 'package:tarteeb/ui/theme.dart';

void main() {
  testWidgets('completion circle toggles only through its own tap target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AppCard(
            onTap: () {},
            child: Row(children: [
              CompletionCircle(done: false, color: Colors.blue, semanticLabel: 'done', onTap: () => taps++),
              const Expanded(child: Text('مهمة')),
            ]),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(CompletionCircle));
    await tester.pump();
    expect(taps, 1);
    await tester.tap(find.text('مهمة'));
    await tester.pump();
    expect(taps, 1);
  });

  test('Arabic and English strings and formats', () {
    S.setLanguage('ar');
    expect(tr.tabTasks, 'المهام');
    expect(formatDayShort(const Day(2024, 10, 14), today: const Day(2024, 1, 1)), '14 أكتوبر');
    expect(formatMoney(123450, 'SAR', arabic: true), '\u20661,234.50\u2069 ر.س');
    S.setLanguage('en');
    expect(tr.tabTasks, 'Tasks');
    expect(formatDayShort(const Day(2024, 10, 14), today: const Day(2024, 1, 1)), 'Oct 14');
    expect(formatMoney(123450, 'SAR', arabic: false), 'SAR \u20661,234.50\u2069');
    S.setLanguage('ar');
  });
}
