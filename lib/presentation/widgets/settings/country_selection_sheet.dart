import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../prism/prism_sheet.dart';

void showCountrySelectionSheet(
  BuildContext context,
  SettingsService settingsService,
  VoidCallback onRegionChanged,
) {
  final searchController = TextEditingController();
  List<CountryInfo> filteredCountries = List.from(supportedCountries);

  showPrismSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Text(
                  'Select your country',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search countries…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHigh
                          .withValues(alpha: .55),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        if (value.isEmpty) {
                          filteredCountries =
                              List.from(supportedCountries);
                        } else {
                          filteredCountries = supportedCountries
                              .where(
                                (c) =>
                                    c.name
                                        .toLowerCase()
                                        .contains(value.toLowerCase()) ||
                                    c.code
                                        .toLowerCase()
                                        .contains(value.toLowerCase()),
                              )
                              .toList();
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      final isSelected =
                          country.code == settingsService.countryCode;

                      return ListTile(
                        leading: Text(
                          country.flag,
                          style: const TextStyle(fontSize: 26),
                        ),
                        title: Text(
                          country.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        subtitle: Text(country.code),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () async {
                          await settingsService.setCountryCode(country.code);
                          if (!context.mounted) return;
                          Navigator.pop(sheetContext);
                          onRegionChanged();
                          if (context.mounted) {
                            showPrismToast(
                              context,
                              'Region set to ${country.name} ${country.flag}',
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
