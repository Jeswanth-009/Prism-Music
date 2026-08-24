import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/services/settings_service.dart';

void showCountrySelectionSheet(BuildContext context, SettingsService settingsService, VoidCallback onRegionChanged) {
  final theme = Theme.of(context);
  final searchController = TextEditingController();
  List<CountryInfo> filteredCountries = List.from(supportedCountries);

  showShadSheet(
    context: context,
    side: ShadSheetSide.bottom,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return ShadSheet(
            title: Row(
              children: [
                const Icon(LucideIcons.globe, size: 24),
                const SizedBox(width: 12),
                const Text('Select Your Country'),
              ],
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ShadInput(
                      controller: searchController,
                      placeholder: const Text('Search countries...'),
                      leading: const Icon(LucideIcons.search, size: 18),
                      onChanged: (value) {
                        setModalState(() {
                          if (value.isEmpty) {
                            filteredCountries = List.from(supportedCountries);
                          } else {
                            filteredCountries = supportedCountries
                                .where((c) =>
                                    c.name.toLowerCase().contains(value.toLowerCase()) ||
                                    c.code.toLowerCase().contains(value.toLowerCase()))
                                .toList();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCountries.length,
                      itemBuilder: (context, index) {
                        final country = filteredCountries[index];
                        final isSelected = country.code == settingsService.countryCode;

                        return ShadButton.ghost(
                          width: double.infinity,
                          onPressed: () async {
                            await settingsService.setCountryCode(country.code);
                            if (!context.mounted) return;
                            Navigator.pop(sheetContext);
                            onRegionChanged();
                            if (context.mounted) {
                              ShadToaster.of(context).show(
                                ShadToast(
                                  title: Text('Region set to ${country.name} ${country.flag}'),
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Text(country.flag, style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      country.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? theme.colorScheme.primary : null,
                                      ),
                                    ),
                                    Text(
                                      country.code,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  LucideIcons.circleCheck,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
