#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

// Configuration
const String configFile = 'translocale.yaml';
const String defaultOutputDir = 'lib/l10n';
const String defaultBaseUrl = 'http://localhost:8081';

Future<void> main(List<String> args) async {
  print('🌐 Translocale: Downloading translations for development...');

  // Parse command line args
  final bool downloadAllLanguages =
      args.contains('--all-languages') || args.contains('-a');
  final bool listLanguages = args.contains('--list');

  // Load configuration
  final config = await loadConfig();
  if (config == null) {
    print(
        '❌ Configuration file not found. Run `dart bin/initialize.dart` first.');
    exit(1);
  }

  final apiKey = config['api']['key'] as String;
  final baseUrl = config['api']['base_url'] as String? ?? defaultBaseUrl;
  final configuredLanguages = config['languages'] as List<dynamic>? ?? ['en'];
  final outputDir = config['output_dir'] as String? ?? defaultOutputDir;

  // Create output directory if it doesn't exist
  final directory = Directory(outputDir);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
    print('📁 Created output directory: $outputDir');
  }

  try {
    // Fetch all translations in a single request
    print('📥 Fetching all translations...');
    final allTranslations = await fetchAllTranslations(baseUrl, apiKey);

    // Get available languages from the response
    final availableLanguages =
        allTranslations.languages.map((lang) => lang.languageCode).toList();

    // If user just wants to list available languages
    if (listLanguages) {
      print('📋 Available languages:');
      for (final lang in allTranslations.languages) {
        final completionPercent =
            (lang.translationCount / allTranslations.meta.totalKeys * 100)
                .round();
        print(
            '   - ${lang.languageCode}: ${lang.name} (${lang.nativeName}) - $completionPercent% complete');
      }
      print('\nTo download all available languages, use:');
      print('dart bin/download_translations.dart --all-languages');
      return;
    }

    // Determine which languages to process based on command line args and config
    List<String> languagesToProcess;

    if (downloadAllLanguages) {
      // If --all-languages flag is provided, download all available languages
      languagesToProcess = availableLanguages;
      print('🌍 Downloading all available languages...');
    } else {
      // Otherwise only download languages specified in config
      languagesToProcess = configuredLanguages
          .map((e) => e.toString())
          .where((lang) => availableLanguages.contains(lang))
          .toList();

      // Warn about unavailable languages
      final unavailableLanguages = configuredLanguages
          .map((e) => e.toString())
          .where((lang) => !availableLanguages.contains(lang))
          .toList();

      if (unavailableLanguages.isNotEmpty) {
        print('⚠️ Warning: The following languages are not available:');
        for (final lang in unavailableLanguages) {
          print('   - $lang');
        }
      }
    }

    // Process each language
    print(
        'Processing ${languagesToProcess.length} languages: ${languagesToProcess.join(', ')}');

    int completed = 0;
    int failed = 0;

    for (final languageCode in languagesToProcess) {
      try {
        print('📄 Processing translations for language: $languageCode');

        // Find the language data in our allTranslations
        final languageData = allTranslations.languages.firstWhere(
          (lang) => lang.languageCode == languageCode,
          orElse: () => throw Exception('Language not found in response'),
        );

        // Convert to ARB format
        final arbContent =
            convertLanguageToArb(languageData, allTranslations.meta);

        // Write to ARB file
        final arbFile = File(path.join(outputDir, 'app_$languageCode.arb'));
        await arbFile.writeAsString(arbContent);

        print('✅ Generated ARB file: ${arbFile.path}');
        completed++;
      } catch (e) {
        print('❌ Error processing translations for $languageCode: $e');
        failed++;
      }
    }

    // If translations contain fallbacks, create a l10n_fallbacks.json file
    if (allTranslations.meta.fallbacks.isNotEmpty) {
      try {
        final fallbacksFile = File(path.join(outputDir, 'l10n_fallbacks.json'));
        await fallbacksFile.writeAsString(const JsonEncoder.withIndent('  ')
            .convert(allTranslations.meta.fallbacks));
        print('✅ Generated fallbacks file: ${fallbacksFile.path}');
      } catch (e) {
        print('⚠️ Warning: Failed to create fallbacks file: $e');
      }
    }

    print('🎉 Translation download completed!');
    print('   Languages processed: ${languagesToProcess.length}');
    print('   Successfully downloaded: $completed');
    if (failed > 0) {
      print('   Failed: $failed');
    }

    // Print information about the translations
    print('\nℹ️ Translation Information:');
    print('   Total keys: ${allTranslations.meta.totalKeys}');
    print('   Total translations: ${allTranslations.meta.totalTranslations}');
    print('   Version: ${allTranslations.meta.version}');
    print('   Last modified: ${allTranslations.meta.lastModified}');
    print(
        '   Available languages: ${allTranslations.meta.supportedLocales.join(', ')}');
  } catch (e) {
    print('❌ Error downloading translations: $e');
    exit(1);
  }

  print('\nNext steps:');
  print('1. Run Flutter gen-l10n to generate Dart classes');
  print('2. Use Translocale.init() in your app for OTA updates');

  if (args.isEmpty) {
    // Show the help message for users who didn't provide any args
    print('\nTip: To download all available languages, run:');
    print('dart bin/download_translations.dart --all-languages');
    print('\nTo list available languages:');
    print('dart bin/download_translations.dart --list');
  }
}

/// Fetch all translations from the API in a single request
Future<TranslationsResponse> fetchAllTranslations(
    String baseUrl, String apiKey) async {
  final uri = Uri.parse('$baseUrl/api/v1/public/translations');

  final response = await http.get(
    uri,
    headers: {
      'X-API-Key': apiKey,
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
        'API request failed with status ${response.statusCode}: ${response.body}');
  }

  final Map<String, dynamic> responseData = jsonDecode(response.body);
  return TranslationsResponse.fromJson(responseData);
}

/// Class to represent the translations response
class TranslationsResponse {
  final List<LanguageData> languages;
  final TranslationMetadata meta;

  TranslationsResponse({required this.languages, required this.meta});

  factory TranslationsResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List)
        .map((langData) => LanguageData.fromJson(langData))
        .toList();

    final meta = TranslationMetadata.fromJson(json['meta']);

    return TranslationsResponse(languages: data, meta: meta);
  }
}

/// Class to represent language data
class LanguageData {
  final String languageCode;
  final String name;
  final String nativeName;
  final bool isRtl;
  final int translationCount;
  final Map<String, String> translations;

  LanguageData({
    required this.languageCode,
    required this.name,
    required this.nativeName,
    required this.isRtl,
    required this.translationCount,
    required this.translations,
  });

  factory LanguageData.fromJson(Map<String, dynamic> json) {
    final translationsMap = (json['translations'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value.toString()));

    return LanguageData(
      languageCode: json['languageCode'],
      name: json['name'],
      nativeName: json['nativeName'],
      isRtl: json['isRtl'] ?? false,
      translationCount: json['translationCount'] ?? 0,
      translations: translationsMap,
    );
  }
}

/// Class to represent translation metadata
class TranslationMetadata {
  final int totalKeys;
  final int totalTranslations;
  final int languageCount;
  final String format;
  final String version;
  final String lastModified;
  final List<String> supportedLocales;
  final Map<String, String> fallbacks;
  final Map<String, dynamic> project;

  TranslationMetadata({
    required this.totalKeys,
    required this.totalTranslations,
    required this.languageCount,
    required this.format,
    required this.version,
    required this.lastModified,
    required this.supportedLocales,
    required this.fallbacks,
    required this.project,
  });

  factory TranslationMetadata.fromJson(Map<String, dynamic> json) {
    final supportedLocales =
        (json['supportedLocales'] as List).map((e) => e.toString()).toList();

    final fallbacks = (json['fallbacks'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value.toString()));

    return TranslationMetadata(
      totalKeys: json['totalKeys'] ?? 0,
      totalTranslations: json['totalTranslations'] ?? 0,
      languageCount: json['languageCount'] ?? 0,
      format: json['format'] ?? 'json',
      version: json['version'] ?? '',
      lastModified: json['lastModified'] ?? '',
      supportedLocales: supportedLocales,
      fallbacks: fallbacks,
      project: json['project'] ?? {},
    );
  }
}

/// Convert a language data object to ARB format
String convertLanguageToArb(
    LanguageData languageData, TranslationMetadata meta) {
  final Map<String, dynamic> arbMap = {
    '@@locale': languageData.languageCode,
  };

  // Add metadata about the language
  arbMap['@@languageName'] = languageData.name;
  arbMap['@@nativeName'] = languageData.nativeName;
  if (languageData.isRtl) {
    arbMap['@@isRtl'] = true;
  }

  // Get the key mapping for OTA updates
  final keyMapping = <String, String>{};

  // Process each translation
  for (final entry in languageData.translations.entries) {
    final apiKey = entry.key;
    final valueText = entry.value;

    // Transform the API key into a valid Dart identifier (camelCase)
    final arbKey = transformKeyForArb(apiKey);

    // Store key mapping for OTA updates
    keyMapping[apiKey] = arbKey;

    // Check if this is a plural message before validation
    final isPluralMessage = valueText.contains('plural,');

    // Validate and normalize the translation value
    final validationResult = validateTranslationValue(valueText);
    final normalizedValue = validationResult.value;

    // Add the translation to the ARB map
    arbMap[arbKey] = normalizedValue;

    // Get placeholders, but filter them if this is a plural message
    final placeholders = isPluralMessage
        ? filterPlaceholdersForPluralMessage(validationResult.placeholders)
        : validationResult.placeholders;

    // Create metadata for this translation
    final metadataMap = <String, dynamic>{
      'description': 'Auto-generated from Translocale key: $apiKey',
    };

    // Add placeholders if any were found
    if (placeholders.isNotEmpty) {
      metadataMap['placeholders'] = <String, dynamic>{};
      for (final placeholder in placeholders) {
        // Sanitize placeholder name to ensure it's a valid Dart identifier
        final sanitizedName = sanitizePlaceholderName(placeholder.name);

        metadataMap['placeholders'][sanitizedName] = {
          'type': placeholder.type,
          'example': placeholder.example,
        };

        // Add format info for known special types
        if (placeholder.format != null) {
          metadataMap['placeholders'][sanitizedName]['format'] =
              placeholder.format;
        }
      }
    }

    // Add the metadata to the ARB map
    arbMap['@$arbKey'] = metadataMap;
  }

  // Add metadata about the key mapping for OTA updates
  arbMap['@@translocaleKeyMapping'] = jsonEncode(keyMapping);

  // Add version information
  arbMap['@@version'] = meta.version;
  arbMap['@@lastModified'] = meta.lastModified;

  return const JsonEncoder.withIndent('  ').convert(arbMap);
}

/// Transform an API key into a valid ARB key (Dart method name)
String transformKeyForArb(String apiKey) {
  // Split by dots to handle nested keys
  final parts = apiKey.split('.');

  // Process each part to ensure it's a valid Dart identifier
  for (var i = 0; i < parts.length; i++) {
    var part = parts[i];

    // Remove invalid characters
    part = part.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

    // Ensure it doesn't start with a number
    if (part.startsWith(RegExp(r'[0-9]'))) {
      part = '_$part';
    }

    parts[i] = part;
  }

  // Join with underscores if there are multiple parts
  String result = parts.join('_');

  // Convert to camelCase if it has multiple parts
  if (parts.length > 1) {
    result = result.split('_').asMap().entries.map((entry) {
      final word = entry.value;
      if (entry.key == 0) {
        // First word stays lowercase
        return word.toLowerCase();
      } else if (word.isNotEmpty) {
        // Other words get capitalized
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      } else {
        return '';
      }
    }).join('');
  }

  return result;
}

/// Filter placeholders for plural messages to avoid invalid parameter names
List<Placeholder> filterPlaceholdersForPluralMessage(
    List<Placeholder> placeholders) {
  // For plural messages, we only keep the count parameter
  // Other placeholders with # or spaces will cause syntax errors
  return placeholders.where((p) {
    // Keep only the count variable and valid Dart identifiers
    return p.type == 'int' || isValidDartIdentifier(p.name);
  }).toList();
}

/// Check if a string is a valid Dart identifier
bool isValidDartIdentifier(String name) {
  // Simplified check - Dart identifiers can't have spaces or special chars
  return !name.contains(' ') &&
      !name.contains('#') &&
      !name.contains('-') &&
      RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(name);
}

/// Sanitize a placeholder name to be a valid Dart identifier
String sanitizePlaceholderName(String name) {
  // Replace spaces and special characters with underscores
  String sanitized = name.replaceAll(RegExp(r'[^\w$]'), '_');

  // Ensure it starts with a letter or underscore
  if (RegExp(r'^[0-9]').hasMatch(sanitized)) {
    sanitized = '_$sanitized';
  }

  // Handle empty name edge case
  if (sanitized.isEmpty) {
    sanitized = 'param';
  }

  return sanitized;
}

/// Represents a placeholder in a translation message
class Placeholder {
  final String name;
  final String type;
  final String example;
  final String? format;

  Placeholder({
    required this.name,
    required this.type,
    required this.example,
    this.format,
  });
}

/// Result of validating a translation value
class ValidationResult {
  final String value;
  final List<Placeholder> placeholders;

  ValidationResult(this.value, this.placeholders);
}

/// Validate and normalize a translation value, extracting placeholders
ValidationResult validateTranslationValue(String value) {
  // Store all placeholders found in the message
  final placeholders = <Placeholder>[];
  String updatedValue = value;

  // Check for ICU syntax errors and extract placeholders
  try {
    // Handle plural messages
    if (value.contains('plural,')) {
      return validatePluralMessage(value);
    }

    // Handle select messages
    if (value.contains('select,')) {
      return validateSelectMessage(value);
    }

    // Handle simple parameter replacements
    final paramMatches = RegExp(r'\{([^{}]+?)\}').allMatches(value);
    for (final match in paramMatches) {
      final param = match.group(1)!.trim();

      // Skip complex expressions (they are likely part of other ICU formats)
      if (param.contains(',')) continue;

      // Add as a placeholder
      placeholders.add(Placeholder(
        name: param,
        type: 'String',
        example: param,
      ));
    }
  } catch (e) {
    print('Warning: Error validating message: $e');
    print('Original message: $value');
    // Return the original value if we can't properly validate
    return ValidationResult(value, placeholders);
  }

  return ValidationResult(updatedValue, placeholders);
}

/// Validate a plural message and extract placeholders
ValidationResult validatePluralMessage(String message) {
  final placeholders = <Placeholder>[];

  // Try to extract the plural variable name
  final pluralMatch = RegExp(r'\{([^,]+),\s*plural,').firstMatch(message);
  if (pluralMatch != null) {
    final pluralVar = pluralMatch.group(1)!.trim();

    // Add the plural variable as a special placeholder
    placeholders.add(Placeholder(
      name: pluralVar,
      type: 'int',
      example: '42',
      format: 'compact',
    ));

    // Check if the message has a proper 'other' case
    final otherCaseCheck = RegExp(r'other\s*\{[^}]*\}').hasMatch(message);
    if (!otherCaseCheck) {
      // Try to create a more valid form with an 'other' case
      try {
        // Extract existing plural cases
        final pluralFormatMatch =
            RegExp(r'\{([^,]+),\s*plural,\s*([^}]+)\}').firstMatch(message);
        if (pluralFormatMatch != null) {
          final varName = pluralFormatMatch.group(1)!.trim();
          final existingCases = pluralFormatMatch.group(2)!.trim();

          // Add a generic 'other' case
          final withOtherCase =
              '{$varName, plural, $existingCases other{$varName}}';

          // Replace the original plural format with our corrected version
          final correctedMessage =
              message.substring(0, pluralFormatMatch.start) +
                  withOtherCase +
                  message.substring(pluralFormatMatch.end);

          // Return with the fixed message
          return ValidationResult(correctedMessage, placeholders);
        }
      } catch (e) {
        print('Warning: Failed to fix missing other case: $e');
      }
    }
  }

  // Look for other simple parameters in the message
  final paramMatches = RegExp(r'\{([^{},]+)\}').allMatches(message);
  for (final match in paramMatches) {
    final param = match.group(1)!.trim();

    // Skip the plural variable we already added
    if (pluralMatch != null && param == pluralMatch.group(1)!.trim()) continue;
    // Skip complex expressions (they are likely part of other ICU formats)
    if (param.contains(',')) continue;

    // Add as a regular placeholder
    placeholders.add(Placeholder(
      name: param,
      type: 'String',
      example: param,
    ));
  }

  return ValidationResult(message, placeholders);
}

/// Validate a select message and extract placeholders
ValidationResult validateSelectMessage(String message) {
  final placeholders = <Placeholder>[];

  // Try to extract the select variable name
  final selectMatch = RegExp(r'\{([^,]+),\s*select,').firstMatch(message);
  if (selectMatch != null) {
    final selectVar = selectMatch.group(1)!.trim();

    // Add the select variable as a special placeholder
    placeholders.add(Placeholder(
      name: selectVar,
      type: 'String',
      example: selectVar,
    ));

    // Check if the message has a proper 'other' case
    final otherCaseCheck = RegExp(r'other\s*\{[^}]*\}').hasMatch(message);
    if (!otherCaseCheck) {
      // Try to create a more valid form with an 'other' case
      try {
        // Extract existing select cases
        final selectFormatMatch =
            RegExp(r'\{([^,]+),\s*select,\s*([^}]+)\}').firstMatch(message);
        if (selectFormatMatch != null) {
          final varName = selectFormatMatch.group(1)!.trim();
          final existingCases = selectFormatMatch.group(2)!.trim();

          // Add a generic 'other' case
          final withOtherCase =
              '{$varName, select, $existingCases other{Default}}';

          // Replace the original select format with our corrected version
          final correctedMessage =
              message.substring(0, selectFormatMatch.start) +
                  withOtherCase +
                  message.substring(selectFormatMatch.end);

          // Return with the fixed message
          return ValidationResult(correctedMessage, placeholders);
        }
      } catch (e) {
        print('Warning: Failed to fix missing other case: $e');
      }
    }
  }

  // Look for other simple parameters in the message
  final paramMatches = RegExp(r'\{([^{},]+)\}').allMatches(message);
  for (final match in paramMatches) {
    final param = match.group(1)!.trim();

    // Skip the select variable we already added
    if (selectMatch != null && param == selectMatch.group(1)!.trim()) continue;
    // Skip complex expressions (they are likely part of other ICU formats)
    if (param.contains(',')) continue;

    // Add as a regular placeholder
    placeholders.add(Placeholder(
      name: param,
      type: 'String',
      example: param,
    ));
  }

  return ValidationResult(message, placeholders);
}

/// Load configuration from YAML file
Future<Map<String, dynamic>?> loadConfig() async {
  final file = File(configFile);
  if (!file.existsSync()) {
    return null;
  }

  final yamlString = await file.readAsString();
  final yamlMap = loadYaml(yamlString);

  // Convert YamlMap to regular Map
  return _convertYamlToMap(yamlMap);
}

/// Convert YamlMap to regular Map recursively
Map<String, dynamic> _convertYamlToMap(dynamic yaml) {
  final result = <String, dynamic>{};

  if (yaml is YamlMap) {
    for (final entry in yaml.entries) {
      if (entry.value is YamlMap) {
        result[entry.key.toString()] = _convertYamlToMap(entry.value);
      } else if (entry.value is YamlList) {
        result[entry.key.toString()] = _convertYamlList(entry.value);
      } else {
        result[entry.key.toString()] = entry.value;
      }
    }
  }

  return result;
}

/// Convert YamlList to regular List recursively
List<dynamic> _convertYamlList(YamlList yamlList) {
  return yamlList.map((item) {
    if (item is YamlMap) {
      return _convertYamlToMap(item);
    } else if (item is YamlList) {
      return _convertYamlList(item);
    } else {
      return item;
    }
  }).toList();
}
