import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/widgets/searchable_selection_field.dart';

import 'test_app.dart';

void main() {
  testWidgets(
    'SearchableSelectionField filters results and updates the selection',
    (tester) async {
      var selectedValue = 'en';

      await pumpTestApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SearchableSelectionField<String>(
                key: const ValueKey<String>('language-field'),
                title: 'Source',
                searchHintText: 'Search languages',
                emptyText: 'No matching languages',
                selectedValue: selectedValue,
                selectedLabel: switch (selectedValue) {
                  'en' => 'English',
                  'es' => 'Spanish',
                  _ => selectedValue,
                },
                labelText: 'Source',
                inputDecorationTheme: const InputDecorationThemeData(
                  filled: true,
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(),
                ),
                options: const [
                  SearchableSelectionOption<String>(
                    value: 'en',
                    label: 'English',
                    supportingText: 'en',
                    searchTerms: ['english'],
                  ),
                  SearchableSelectionOption<String>(
                    value: 'es',
                    label: 'Spanish',
                    supportingText: 'es',
                    searchTerms: ['spanish'],
                  ),
                ],
                onSelected: (value) {
                  setState(() {
                    selectedValue = value;
                  });
                },
              ),
            );
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('language-field')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'zzz',
      );
      await tester.pumpAndSettle();

      expect(find.text('No matching languages'), findsOneWidget);

      await tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'spa',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Spanish'),
        ),
      );
      await tester.pumpAndSettle();

      expect(selectedValue, 'es');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('language-field')),
          matching: find.text('Spanish'),
        ),
        findsWidgets,
      );
    },
  );
}
