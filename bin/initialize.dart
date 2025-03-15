import 'dart:io';

/// A script to initialize the Translocale OTA system in a Flutter project
void main(List<String> args) async {
  print('Initializing Translocale system...');

  // Check if a pubspec.yaml file exists (to verify we are in a Flutter project)
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print(
        'Error: pubspec.yaml not found. Are you in a Flutter project directory?');
    exit(1);
  }

  // Create a translocale.yaml configuration file
  final configFile = File('translocale.yaml');
  await configFile.writeAsString('''
# Translocale Configuration
# ------------------------
# This file configures the Translocale translation system

# API configuration
api:
  # Your API key from the Translocale service
  key: "YOUR_API_KEY_HERE"
  
  # Base URL of the API (optional - defaults to production)
  base_url: "http://localhost:8081"

# Languages to download during development
languages:
  - "en"
  - "es"
  - "fr"
  - "de"

# Output directory for ARB files
output_dir: "lib/l10n"

# Translation mapping configuration (for OTA updates)
mapping:
  # You can specify exact mappings for keys if needed
  # API Key -> Flutter Key
  # "common.buttons.save": "saveButton"
  
  # By default, keys with the same name will be automatically mapped
''');

  // Check if we should update the build.yaml file
  final buildYamlFile = File('build.yaml');
  if (!buildYamlFile.existsSync()) {
    await buildYamlFile.writeAsString('''
targets:
  \$default:
    builders:
      translocale|intl_builder:
        enabled: true
      translocale|gen_l10n_builder:
        enabled: true
''');
  } else {
    print(
        'Note: build.yaml already exists. You may need to manually configure it for Translocale.');
  }

  // Create l10n.yaml for Flutter gen_l10n configuration
  final l10nYamlFile = File('l10n.yaml');
  if (!l10nYamlFile.existsSync()) {
    await l10nYamlFile.writeAsString('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
output-dir: lib/flutter_gen/gen_l10n
''');
    print('Created l10n.yaml for Flutter gen_l10n configuration.');
  } else {
    print('Note: l10n.yaml already exists.');
  }

  // Update gitignore to exclude generated files
  final gitignoreFile = File('.gitignore');
  if (gitignoreFile.existsSync()) {
    final gitignoreContent = await gitignoreFile.readAsString();
    if (!gitignoreContent.contains('# Translocale generated files')) {
      await gitignoreFile.writeAsString('''
# Translocale generated files
lib/src/generated/
''', mode: FileMode.append);
    }
  }

  // Create the l10n directory if it doesn't exist
  final l10nDir = Directory('lib/l10n');
  if (!l10nDir.existsSync()) {
    l10nDir.createSync(recursive: true);
    print('Created lib/l10n directory for ARB files.');
  }

  print('Translocale system initialized successfully!');
  print('');
  print('Next steps:');
  print('1. Update the API key in translocale.yaml');
  print('2. Run "dart bin/translocale.dart download" to download translations');
  print(
      '3. Run "dart bin/translocale.dart gen-l10n" to generate localization classes');
  print('4. Add Translocale.init() to your app for OTA updates');
  print('');
  print('Important notes:');
  print(
      '• If you encounter errors in generated code (especially with plural messages),');
  print(
      '  run "dart bin/translocale.dart download" with the latest version of the CLI.');
  print(
      '• For plural messages, the CLI automatically sanitizes placeholder names to ensure');
  print('  they are valid Dart identifiers.');
  print(
      '• Review the generated ARB files to ensure placeholder metadata is correct.');
  print('');
  print(
      'For more information, visit: https://github.com/yourusername/translocale');
}
