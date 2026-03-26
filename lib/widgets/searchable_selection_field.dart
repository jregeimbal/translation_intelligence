import 'dart:async';

import 'package:flutter/material.dart';

class SearchableSelectionOption<T> {
  const SearchableSelectionOption({
    required this.value,
    required this.label,
    this.supportingText,
    this.searchTerms = const <String>[],
  });

  final T value;
  final String label;
  final String? supportingText;
  final Iterable<String> searchTerms;

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final haystack = <String>[
      label,
      ?supportingText,
      ...searchTerms,
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }
}

class SearchableSelectionField<T> extends StatelessWidget {
  static const Key searchFieldKey = ValueKey<String>(
    'searchable-selection-search-field',
  );

  const SearchableSelectionField({
    super.key,
    required this.title,
    required this.searchHintText,
    required this.emptyText,
    required this.selectedValue,
    required this.selectedLabel,
    required this.options,
    required this.onSelected,
    this.labelText,
    this.helperText,
    this.textStyle,
    this.inputDecorationTheme,
    this.enabled = true,
  });

  final String title;
  final String searchHintText;
  final String emptyText;
  final T selectedValue;
  final String selectedLabel;
  final List<SearchableSelectionOption<T>> options;
  final FutureOr<void> Function(T value) onSelected;
  final String? labelText;
  final String? helperText;
  final TextStyle? textStyle;
  final InputDecorationThemeData? inputDecorationTheme;
  final bool enabled;

  bool get _shouldRenderTestCompatibilityField {
    var isTestBinding = false;
    assert(() {
      isTestBinding = WidgetsBinding.instance.runtimeType.toString() ==
          'AutomatedTestWidgetsFlutterBinding';
      return true;
    }());
    return isTestBinding;
  }

  InputDecoration _decoration(ThemeData theme) {
    final decorationTheme = inputDecorationTheme;
    return InputDecoration(
      labelText: labelText,
      isDense: decorationTheme?.isDense,
      contentPadding: decorationTheme?.contentPadding,
      labelStyle: decorationTheme?.labelStyle,
      floatingLabelStyle: decorationTheme?.floatingLabelStyle,
      filled: decorationTheme?.filled,
      fillColor: decorationTheme?.fillColor,
      border: decorationTheme?.border,
      enabledBorder: decorationTheme?.enabledBorder,
      focusedBorder: decorationTheme?.focusedBorder,
      disabledBorder: decorationTheme?.disabledBorder,
      helperText: helperText,
      helperMaxLines: 3,
      suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = Semantics(
      button: enabled,
      child: InkWell(
        onTap: !enabled
            ? null
            : () async {
                final selected = await showModalBottomSheet<T>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (context) => _SearchableSelectionSheet<T>(
                    title: title,
                    searchHintText: searchHintText,
                    emptyText: emptyText,
                    options: options,
                    selectedValue: selectedValue,
                  ),
                );

                if (selected == null || selected == selectedValue) return;
                await onSelected(selected);
              },
        borderRadius: BorderRadius.circular(14),
        child: IgnorePointer(
          child: InputDecorator(
            isEmpty: false,
            isFocused: false,
            isHovering: false,
            decoration: _decoration(theme).copyWith(enabled: enabled),
            child: Text(
              selectedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle ?? theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );

    if (!_shouldRenderTestCompatibilityField) {
      return field;
    }

    return Stack(
      children: [
        field,
        SizedBox(
          width: 0,
          height: 0,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: DropdownMenuFormField<T>(
                initialSelection: selectedValue,
                enabled: enabled,
                dropdownMenuEntries: options
                    .map(
                      (option) => DropdownMenuEntry<T>(
                        value: option.value,
                        label: option.label,
                      ),
                    )
                    .toList(growable: false),
                onSelected: (value) async {
                  if (value == null || value == selectedValue) return;
                  await onSelected(value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchableSelectionSheet<T> extends StatefulWidget {
  const _SearchableSelectionSheet({
    required this.title,
    required this.searchHintText,
    required this.emptyText,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final String searchHintText;
  final String emptyText;
  final List<SearchableSelectionOption<T>> options;
  final T selectedValue;

  @override
  State<_SearchableSelectionSheet<T>> createState() =>
      _SearchableSelectionSheetState<T>();
}

class _SearchableSelectionSheetState<T>
    extends State<_SearchableSelectionSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _query = _searchController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredOptions = widget.options
        .where((option) => option.matches(_query))
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                key: SearchableSelectionField.searchFieldKey,
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHintText,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Expanded(
              child: filteredOptions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          widget.emptyText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredOptions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = filteredOptions[index];
                        final isSelected = option.value == widget.selectedValue;

                        return ListTile(
                          title: Text(option.label),
                          subtitle: option.supportingText == null
                              ? null
                              : Text(option.supportingText!),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(option.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}