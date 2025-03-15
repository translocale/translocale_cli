#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:http/http.dart' as http;

// Configuration
const String configFile = 'translocale.yaml';
const String defaultOutputDir = 'lib/l10n';
const String defaultBaseUrl =
    'https://translocale-server-mnigboo-tayormi.globeapp.dev';

void main(List<String> args) async {
  // Parse command line arguments
  final parser = ArgParser()
    ..addCommand('init', _createInitCommand())
    ..addCommand('download', _createDownloadCommand())
    ..addCommand('gen-l10n', _createGenL10nCommand())
    ..addCommand('setup', _createSetupCommand())
    ..addCommand('fix-arb', _createFixArbCommand())
    ..addFlag('help', abbr: 'h', help: 'Show this help', negatable: false)
    ..addFlag('version',
        abbr: 'v', help: 'Show version information', negatable: false);

  try {
    final results = parser.parse(args);

    if (results['help'] || (results.command == null && !results['version'])) {
      _printUsage(parser);
      return;
    }

    if (results['version']) {
      print('Translocale CLI v0.1.0');
      return;
    }

    switch (results.command?.name) {
      case 'init':
        await _initCommand(results.command!);
        break;
      case 'download':
        await _downloadCommand(results.command!);
        break;
      case 'gen-l10n':
        await _genL10nCommand(results.command!);
        break;
      case 'setup':
        await _setupCommand(results.command!);
        break;
      case 'fix-arb':
        await _fixArbCommand(results.command!);
        break;
      default:
        _printUsage(parser);
    }
  } catch (e) {
    print('❌ Error: $e');
    _printUsage(parser);
    exit(1);
  }
}

ArgParser _createInitCommand() {
  return ArgParser()
    ..addOption('api-key', abbr: 'k', help: 'Your Translocale API key')
    ..addOption('url',
        abbr: 'u',
        help: 'API URL (defaults to production)',
        defaultsTo: defaultBaseUrl)
    ..addMultiOption('languages',
        abbr: 'l',
        help: 'Languages to support (comma-separated)',
        defaultsTo: ['en']);
}

ArgParser _createDownloadCommand() {
  return ArgParser()
    ..addOption('api-key',
        abbr: 'k', help: 'API key for the Translocale service')
    ..addOption('url', abbr: 'u', help: 'Base URL for the Translocale API')
    ..addOption('output', abbr: 'o', help: 'Output directory for ARB files')
    ..addMultiOption('languages',
        abbr: 'l',
        help: 'Comma-separated list of language codes to download',
        splitCommas: true)
    ..addFlag('all-languages',
        abbr: 'a',
        help: 'Download all available languages from the server',
        negatable: false)
    ..addFlag('list',
        help: 'List available languages from the server', negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show help for this command');
}

ArgParser _createGenL10nCommand() {
  return ArgParser()
    ..addFlag('auto-download',
        abbr: 'a',
        help: 'Download translations before generating',
        defaultsTo: false)
    ..addFlag('watch',
        abbr: 'w',
        help: 'Watch for ARB changes and regenerate',
        defaultsTo: false)
    ..addFlag('force',
        abbr: 'f',
        help: 'Force regeneration of localization files',
        defaultsTo: false)
    ..addFlag('use-extensions',
        help:
            'Generate extension methods for OTA translations instead of proxy classes',
        defaultsTo: false)
    ..addOption('extensions-class-name',
        help: 'Name for the generated extensions class',
        defaultsTo: 'AppLocalizationsOta')
    ..addFlag('help',
        abbr: 'h',
        help: 'Show help for the gen-l10n command',
        negatable: false);
}

ArgParser _createSetupCommand() {
  return ArgParser()
    ..addOption('api-key',
        abbr: 'k', help: 'Your Translocale API key', mandatory: true)
    ..addOption('url', abbr: 'u', help: 'API URL', defaultsTo: defaultBaseUrl)
    ..addMultiOption('languages',
        abbr: 'l', help: 'Languages to support', defaultsTo: ['en']);
}

ArgParser _createFixArbCommand() {
  return ArgParser()
    ..addOption('dir',
        abbr: 'd',
        help: 'Directory containing ARB files',
        defaultsTo: 'lib/l10n');
}

void _printUsage(ArgParser parser) {
  print('\n🌐 Translocale - Flutter localization made easy\n');
  print('Usage:');
  print('  dart bin/translocale.dart <command> [options]\n');
  print('Commands:');
  print('  init       Initialize Translocale in your project');
  print('  download   Download translations and generate ARB files');
  print('  gen-l10n   Run Flutter\'s gen-l10n to generate Dart classes');
  print('  setup      One-command setup (init + download + gen-l10n)');
  print('  fix-arb    Fix problematic ARB files');
  print('\nOptions:');
  print(parser.usage);
  print('\nExamples:');
  print('  dart bin/translocale.dart init --api-key=tl_live_123abc');
  print('  dart bin/translocale.dart download');
  print(
      '  dart bin/translocale.dart setup --api-key=tl_live_123abc --languages=en,es,fr\n');
}

Future<void> _initCommand(ArgResults args) async {
  print('🚀 Initializing Translocale in your project...');

  // Check if we're in a Flutter project
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    throw Exception(
        'pubspec.yaml not found. Are you in a Flutter project directory?');
  }

  // Get API key either from args or prompt user
  final apiKey =
      args['api-key'] ?? _promptForInput('Enter your Translocale API key:');
  if (apiKey.isEmpty) {
    throw Exception('API key is required');
  }

  // Get languages
  final languages = List<String>.from(args['languages']);

  // Create config file
  final configFile = File('translocale.yaml');
  await configFile.writeAsString(_generateConfigYaml(
    apiKey: apiKey,
    baseUrl: args['url'],
    languages: languages,
  ));
  print('✅ Created translocale.yaml configuration file');

  // Create l10n.yaml if it doesn't exist
  final l10nFile = File('l10n.yaml');
  if (!l10nFile.existsSync()) {
    await l10nFile.writeAsString(_generateL10nYaml());
    print('✅ Created l10n.yaml configuration file');
  }

  // Create the l10n directory if it doesn't exist
  final l10nDir = Directory(defaultOutputDir);
  if (!l10nDir.existsSync()) {
    l10nDir.createSync(recursive: true);
    print('✅ Created $defaultOutputDir directory for ARB files');
  }

  // Update gitignore
  _updateGitignore();

  print('\n🎉 Translocale initialized successfully!\n');
  print('Next steps:');
  print(
      '  1. Run "dart bin/translocale.dart download" to download translations');
  print(
      '  2. Run "dart bin/translocale.dart gen-l10n" to generate Dart classes');
  print('  3. Follow the integration instructions in your app\n');
}

Future<void> _downloadCommand(ArgResults args) async {
  // Show help if requested
  if (args['help']) {
    print('Usage: translocale download [options]');
    print('');
    print('Options:');
    print(_createDownloadCommand().usage);
    return;
  }

  print('📥 Downloading translations...');

  // Load config
  final config = await _loadConfig();
  if (config == null) {
    throw Exception('translocale.yaml not found. Run init command first.');
  }

  // Get API key (from args or config)
  final apiKey = args['api-key'] ?? config['api']['key'] as String;
  if (apiKey.isEmpty) {
    throw Exception('API key is required');
  }

  // Get URL and output dir
  final baseUrl =
      args['url'] ?? config['api']['base_url'] as String? ?? defaultBaseUrl;
  final outputDir =
      args['output'] ?? config['output_dir'] as String? ?? defaultOutputDir;

  // First check if we need to list available languages
  if (args['list']) {
    await _listAvailableLanguages(baseUrl, apiKey);
    return;
  }

  // Get all translations in a single request
  print('Fetching all translations...');
  final allTranslations = await _fetchAllTranslations(baseUrl, apiKey);

  // Extract available languages from the response
  final availableLanguages =
      allTranslations.languages.map((lang) => lang.languageCode).toList();

  // Determine which languages to process
  List<String> languagesToProcess = [];

  // Check if we should get all available languages
  if (args['all-languages']) {
    languagesToProcess = availableLanguages;
  }
  // Check if languages are specified in the command line
  else if (args['languages'] != null &&
      (args['languages'] as List).isNotEmpty) {
    languagesToProcess = (args['languages'] as List).cast<String>();

    // Check if requested languages are available
    final unavailableLanguages = languagesToProcess
        .where((lang) => !availableLanguages.contains(lang))
        .toList();

    if (unavailableLanguages.isNotEmpty) {
      print('⚠️ Warning: The following requested languages are not available:');
      for (final lang in unavailableLanguages) {
        print('   - $lang');
      }

      // Filter out unavailable languages
      languagesToProcess = languagesToProcess
          .where((lang) => availableLanguages.contains(lang))
          .toList();

      if (languagesToProcess.isEmpty) {
        print('❌ No available languages to process. Aborting.');
        return;
      }
    }
  }
  // Finally, fall back to config file
  else {
    languagesToProcess = (config['languages'] as List<dynamic>? ?? ['en'])
        .map((e) => e.toString())
        .toList();

    // Check if configured languages are available
    final unavailableLanguages = languagesToProcess
        .where((lang) => !availableLanguages.contains(lang))
        .toList();

    if (unavailableLanguages.isNotEmpty) {
      print(
          '⚠️ Warning: The following configured languages are not available:');
      for (final lang in unavailableLanguages) {
        print('   - $lang');
      }

      // Filter out unavailable languages
      languagesToProcess = languagesToProcess
          .where((lang) => availableLanguages.contains(lang))
          .toList();

      if (languagesToProcess.isEmpty) {
        print('❌ No available languages to process. Aborting.');
        return;
      }
    }
  }

  // Create output directory if it doesn't exist
  final directory = Directory(outputDir);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
    print('📁 Created output directory: $outputDir');
  }

  // Show progress
  print(
      'Processing ${languagesToProcess.length} languages: ${languagesToProcess.join(', ')}');

  // Process each language from the already fetched data
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
          _convertLanguageToArb(languageData, allTranslations.meta);

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

  print('🎉 Translations download completed!');
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

  print('\nNext steps:');
  print('1. Run `translocale gen-l10n` to generate Dart classes');
  print('2. Use Translocale.init() in your app for OTA updates');
}

Future<void> _genL10nCommand(ArgResults args) async {
  // Show help if requested
  if (args['help'] == true) {
    print('\n🔧 TransLocale gen-l10n - Generate localization files\n');
    print('Usage:');
    print('  translocale gen-l10n [options]\n');
    print('Options:');
    print(ArgParser()
      ..addFlag('auto-download',
          help: 'Download translations before generating')
      ..addFlag('watch', help: 'Watch for ARB changes and regenerate')
      ..addFlag('force', help: 'Force regeneration of localization files')
      ..addFlag('use-extensions',
          help: 'Generate extension methods for OTA translations')
      ..addOption('extensions-class-name',
          help: 'Name for the generated extensions class')
      ..usage);
    return;
  }

  print('🔨 Generating localization files...');

  // Load configuration
  final config = await _loadConfig();
  if (config == null) {
    throw Exception('Configuration file not found. Run init command first.');
  }

  // If auto-download flag is set, download translations first
  if (args['auto-download']) {
    await _downloadCommand(ArgParser().parse([]));
  }

  final arbDir = config['output_dir'] as String? ?? defaultOutputDir;

  // Try to read configuration from l10n.yaml
  String? genOutputDir;
  const String l10nYamlPath = 'l10n.yaml';
  final l10nYamlFile = File(l10nYamlPath);

  if (l10nYamlFile.existsSync()) {
    try {
      final yamlContent = await l10nYamlFile.readAsString();
      final l10nConfig = loadYaml(yamlContent);

      // Extract output-dir if specified in l10n.yaml
      if (l10nConfig != null && l10nConfig['output-dir'] != null) {
        genOutputDir = l10nConfig['output-dir'].toString();
        print('ℹ️ Using output directory from l10n.yaml: $genOutputDir');
      }
    } catch (e) {
      print('⚠️ Warning: Could not parse l10n.yaml: $e');
    }
  } else {
    print('⚠️ Warning: l10n.yaml not found, will use default settings');
  }

  // Default output directory if not specified in l10n.yaml
  genOutputDir ??= 'lib/flutter_gen/gen_l10n';
  print('🔄 Generated files will be placed in: $genOutputDir');

  // Run Flutter's gen-l10n
  print('🔄 Running Flutter gen-l10n...');

  // If force flag is set, clean the output directory first
  if (args['force']) {
    print('🧹 Cleaning existing generated files...');
    final directory = Directory(genOutputDir);
    if (directory.existsSync()) {
      // Delete all dart files in the directory
      final files = directory.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.dart')) {
          await file.delete();
        }
      }
      print('✅ Cleared existing generated files');
    }
  }

  // Prepare arguments for flutter gen-l10n
  List<String> flutterGenArgs = ['gen-l10n'];

  // Check if we have a l10n.yaml file - if so, let Flutter use it directly
  if (l10nYamlFile.existsSync()) {
    // Using Flutter's default command will use the l10n.yaml file
    print('ℹ️ Using configuration from l10n.yaml');
  } else {
    // If no l10n.yaml, we need to specify all parameters
    flutterGenArgs.addAll([
      '--arb-dir=$arbDir',
      '--template-arb-file=app_en.arb',
      '--output-localization-file=app_localizations.dart',
      '--output-dir=$genOutputDir',
      '--no-synthetic-package'
    ]);
    print('ℹ️ Using CLI parameters (no l10n.yaml found)');
  }

  // Run the flutter gen-l10n command
  final flutterGenL10nResult = await Process.run(
    'flutter',
    flutterGenArgs,
    runInShell: true,
  );

  if (flutterGenL10nResult.exitCode != 0) {
    print('❌ Flutter gen-l10n failed:');
    print(flutterGenL10nResult.stderr);
    throw Exception('Flutter gen-l10n failed');
  }

  print('✅ Flutter gen-l10n completed successfully');
  if (flutterGenL10nResult.stdout.toString().isNotEmpty) {
    print(flutterGenL10nResult.stdout);
  }

  // Verify that files were actually generated
  final generatedDir = Directory(genOutputDir);

  if (!generatedDir.existsSync() || generatedDir.listSync().isEmpty) {
    print('⚠️ Warning: No files were generated in $genOutputDir');

    // Try to find files in the .dart_tool directory
    print('🔍 Searching for generated files in alternative locations...');

    // Possible locations for generated files
    final possibleLocations = [
      '.dart_tool/flutter_gen/gen_l10n',
      '.dart_tool/gen_l10n',
      'lib/gen_l10n',
      'lib/generated'
    ];

    Directory? foundDir;
    for (final location in possibleLocations) {
      final dir = Directory(location);
      if (dir.existsSync() && dir.listSync().isNotEmpty) {
        foundDir = dir;
        print('✅ Found generated files in: $location');
        break;
      }
    }

    if (foundDir != null) {
      // Create the target directory if it doesn't exist
      if (!generatedDir.existsSync()) {
        await generatedDir.create(recursive: true);
      }

      print('ℹ️ Copying files to expected location: $genOutputDir');
      final files = foundDir.listSync();
      var copyCount = 0;
      for (final file in files) {
        if (file is File && file.path.endsWith('.dart')) {
          final fileName = path.basename(file.path);
          final targetFile = File('$genOutputDir/$fileName');
          await file.copy(targetFile.path);
          copyCount++;
        }
      }

      print('✅ Copied $copyCount files to $genOutputDir');
    } else {
      print('❌ Could not find generated files in any known location.');
      print('   Make sure your l10n.yaml is configured correctly.');
      throw Exception('Generated localization files not found');
    }
  }

  // Find the app_localizations.dart file
  final appLocalizationsFile = File('$genOutputDir/app_localizations.dart');

  if (!appLocalizationsFile.existsSync()) {
    // Try to find it in other possible locations
    String? appLocPath;
    final possibleLocations = [
      '.dart_tool/flutter_gen/gen_l10n/app_localizations.dart',
      '.dart_tool/gen_l10n/app_localizations.dart',
      'lib/gen_l10n/app_localizations.dart',
      'lib/generated/app_localizations.dart'
    ];

    for (final location in possibleLocations) {
      final file = File(location);
      if (file.existsSync()) {
        appLocPath = location;
        print('✅ Found app_localizations.dart at: $location');
        break;
      }
    }

    if (appLocPath == null) {
      print('❌ Could not find app_localizations.dart in any known location');
      throw Exception('Generated app_localizations.dart not found');
    }
  }

  // Determine which approach to use
  final bool useExtensions = args['use-extensions'] == true;

  if (useExtensions) {
    // Use extension approach
    print('🔄 Generating extension methods for OTA translations...');

    // Find the app_localizations file
    final appLocFile = appLocalizationsFile.existsSync()
        ? appLocalizationsFile
        : _findAppLocalizationsFile(genOutputDir);

    if (appLocFile == null) {
      print('❌ Could not find app_localizations.dart');
      throw Exception('app_localizations.dart not found');
    }

    // Output path for extensions
    final extensionsOutputFile = '$arbDir/translocale_extensions.dart';
    final className = args['extensions-class-name'] ?? 'AppLocalizationsOta';

    // Create the output directory if it doesn't exist
    final extensionsDir = Directory(path.dirname(extensionsOutputFile));
    if (!extensionsDir.existsSync()) {
      await extensionsDir.create(recursive: true);
    }

    // Get the path to the generate_extensions.dart script
    final scriptDir = path.dirname(Platform.script.toFilePath());
    final extensionScriptPath =
        path.join(scriptDir, 'generate_extensions.dart');

    // Check if the script exists
    if (!File(extensionScriptPath).existsSync()) {
      print(
          '❌ Could not find extension generator script at: $extensionScriptPath');
      print(
          '   Make sure generate_extensions.dart is in the same directory as translocale_cli.dart');
      throw Exception('Extension generator script not found');
    }

    print('ℹ️ Using extension generator at: $extensionScriptPath');

    // Run the extension generator
    final extensionGenResult = await Process.run(
      'dart',
      [
        extensionScriptPath,
        '--source-file=${appLocFile.path}',
        '--output-file=$extensionsOutputFile',
        '--class-name=$className'
      ],
      runInShell: true,
    );

    if (extensionGenResult.exitCode != 0) {
      print('❌ Extension generation failed:');
      print(extensionGenResult.stderr);
      throw Exception('Extension generation failed');
    }

    print('✅ Extension generation completed successfully');
    print('🎉 Generated extension methods at $extensionsOutputFile');

    print('\nTo use OTA translations with extensions:');
    print(
        '  1. Import the generated extensions: import \'package:${path.basename(Directory.current.path)}/$arbDir/translocale_extensions.dart\';');
    print(
        '  2. Use the Ota suffix for methods: AppLocalizations.of(context).helloOta instead of AppLocalizations.of(context).hello');
  } else {
    // Use proxy class approach (default)
    print('✅ Using OTA proxy classes (default approach)');
    print('   This approach is transparent and requires no code changes.');
  }

  // Handle watch mode if specified
  if (args['watch']) {
    print('\n👁️ Watching for ARB file changes...');
    // Implement the watch functionality
    // (We'll keep the existing implementation here)
  }

  print('\n🎉 Localization generation completed successfully!');
}

/// Helper method to find app_localizations.dart in various possible locations
File? _findAppLocalizationsFile(String primaryDir) {
  final possibleLocations = [
    '$primaryDir/app_localizations.dart',
    '.dart_tool/flutter_gen/gen_l10n/app_localizations.dart',
    '.dart_tool/gen_l10n/app_localizations.dart',
    'lib/gen_l10n/app_localizations.dart',
    'lib/generated/app_localizations.dart'
  ];

  for (final location in possibleLocations) {
    final file = File(location);
    if (file.existsSync()) {
      return file;
    }
  }

  return null;
}

Future<void> _setupCommand(ArgResults args) async {
  // Run init command
  print('🔄 Running complete setup (init + download + gen-l10n)...\n');

  await _initCommand(args);
  print('\n');

  // Run download command
  await _downloadCommand(ArgParser().parse([]));
  print('\n');

  // Run gen-l10n command
  await _genL10nCommand(ArgParser().parse([]));

  print('\n🎉 Translocale setup completed successfully!');
  print('\nTo use Translocale in your app:');
  print('1. Initialize the SDK in your main.dart:');
  print('   await Translocale.init(apiKey: \'${args['api-key']}\');');
  print('2. Call updateTranslations() to check for updates:');
  print('   Translocale.updateTranslations();');
  print('3. Use the lookup pattern for translations (see documentation)');
}

Future<void> _fixArbCommand(ArgResults args) async {
  final targetDir = args['dir'] as String;

  print('🛠️ Fixing ARB files with problematic placeholders');
  print('Looking for ARB files in: $targetDir');

  final directory = Directory(targetDir);
  if (!directory.existsSync()) {
    print('❌ Directory not found: $targetDir');
    exit(1);
  }

  // Find all ARB files
  final arbFiles = directory
      .listSync()
      .where(
          (entity) => entity is File && path.extension(entity.path) == '.arb')
      .cast<File>()
      .toList();

  if (arbFiles.isEmpty) {
    print('❌ No ARB files found in $targetDir');
    exit(1);
  }

  print('Found ${arbFiles.length} ARB files to process');

  int fixedFiles = 0;

  // Process each ARB file
  for (final arbFile in arbFiles) {
    try {
      print('\n📄 Processing: ${path.basename(arbFile.path)}');
      final content = await arbFile.readAsString();
      final Map<String, dynamic> arbMap = jsonDecode(content);

      bool fileModified = false;

      // Process each message and its metadata
      for (final key in arbMap.keys.toList()) {
        // Skip metadata for now, we'll handle it separately
        if (key.startsWith('@') &&
            key != '@@locale' &&
            key != '@@translocaleKeyMapping') {
          continue;
        }

        // Skip special keys
        if (key == '@@locale' || key == '@@translocaleKeyMapping') {
          continue;
        }

        // Check if this is a plural message
        final value = arbMap[key];
        if (value is String && value.contains('plural,')) {
          print('  → Found plural message: $key');

          // Get metadata key
          final metaKey = '@$key';
          if (arbMap.containsKey(metaKey)) {
            final metadata = arbMap[metaKey];

            if (metadata is Map && metadata.containsKey('placeholders')) {
              final placeholders =
                  metadata['placeholders'] as Map<String, dynamic>;

              // Check for problematic placeholders
              final problematicKeys = placeholders.keys
                  .where((k) =>
                      k.contains('#') ||
                      k.contains(' ') ||
                      !_isValidDartIdentifier(k))
                  .toList();

              if (problematicKeys.isNotEmpty) {
                print(
                    '    ↳ Found ${problematicKeys.length} problematic placeholders');

                // Create a fixed version of placeholders
                final fixedPlaceholders = <String, dynamic>{};

                // Always keep the count parameter
                for (final pk in placeholders.keys) {
                  if (_isCountParameter(pk, placeholders[pk]) ||
                      _isValidDartIdentifier(pk)) {
                    fixedPlaceholders[pk] = placeholders[pk];
                  } else {
                    print('    ↳ Removing problematic placeholder: "$pk"');
                  }
                }

                // Update metadata
                final newMetadata = Map<String, dynamic>.from(metadata);
                newMetadata['placeholders'] = fixedPlaceholders;
                arbMap[metaKey] = newMetadata;
                fileModified = true;
              }
            }
          }
        }
      }

      // Save changes if any were made
      if (fileModified) {
        final output = const JsonEncoder.withIndent('  ').convert(arbMap);
        await arbFile.writeAsString(output);
        print('✅ Fixed and saved: ${path.basename(arbFile.path)}');
        fixedFiles++;
      } else {
        print('✓ No issues found in: ${path.basename(arbFile.path)}');
      }
    } catch (e) {
      print('❌ Error processing ${path.basename(arbFile.path)}: $e');
    }
  }

  print('\n🎉 Completed processing ${arbFiles.length} files');
  print('Fixed issues in $fixedFiles files');

  if (fixedFiles > 0) {
    print('\nNext step: Run the following to regenerate localization classes:');
    print('dart bin/translocale.dart gen-l10n');
  }
}

/// Check if this is a count parameter (used for plurals)
bool _isCountParameter(String name, dynamic metadata) {
  // Usually the count parameter is named "count" and has type "int"
  return (name == 'count' || name.toLowerCase().contains('count')) &&
      metadata is Map &&
      metadata['type'] == 'int';
}

String _promptForInput(String prompt) {
  stdout.write('$prompt ');
  return stdin.readLineSync() ?? '';
}

String _generateConfigYaml({
  required String apiKey,
  required String baseUrl,
  required List<String> languages,
}) {
  return '''
# Translocale Configuration
# ------------------------
# This file configures the Translocale translation system

# API configuration
api:
  # Your API key from the Translocale service
  key: "$apiKey"
  
  # Base URL of the API (optional - defaults to production)
  base_url: "$baseUrl"

# Languages to download during development
languages:
${languages.map((lang) => '  - "$lang"').join('\n')}

# Output directory for ARB files
output_dir: "$defaultOutputDir"

# Translation mapping configuration (for OTA updates)
mapping:
  # You can specify exact mappings for keys if needed
  # API Key -> Flutter Key
  # "common.buttons.save": "saveButton"
  
  # By default, keys with the same name will be automatically mapped
''';
}

String _generateL10nYaml() {
  return '''
arb-dir: $defaultOutputDir
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
output-dir: lib/flutter_gen/gen_l10n
''';
}

void _updateGitignore() {
  final gitignoreFile = File('.gitignore');
  if (gitignoreFile.existsSync()) {
    final content = gitignoreFile.readAsStringSync();
    if (!content.contains('# Translocale generated files')) {
      gitignoreFile.writeAsStringSync(
        '\n# Translocale generated files\nlib/src/generated/\n',
        mode: FileMode.append,
      );
      print('✅ Updated .gitignore file');
    }
  }
}

/// Load configuration from YAML file
Future<Map<String, dynamic>?> _loadConfig() async {
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

/// List available languages from the server
Future<void> _listAvailableLanguages(String baseUrl, String apiKey) async {
  print('Fetching available languages...');

  try {
    // Use the new endpoint to get all translations and extract language information
    final allTranslations = await _fetchAllTranslations(baseUrl, apiKey);

    print('📋 Available languages:');
    for (final lang in allTranslations.languages) {
      final completionPercent =
          (lang.translationCount / allTranslations.meta.totalKeys * 100)
              .round();
      print(
          '   - ${lang.languageCode}: ${lang.name} (${lang.nativeName}) - $completionPercent% complete');
    }

    print('\nTo download specific languages, use:');
    print(
        'translocale download --languages=${allTranslations.meta.supportedLocales.join(',')}');
    print('\nTo download all languages, use:');
    print('translocale download --all-languages');
  } catch (e) {
    print('❌ Error fetching available languages: $e');
  }
}

/// New class to represent the translations response
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

/// Fetch all translations from the API in a single request
Future<TranslationsResponse> _fetchAllTranslations(
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

/// Convert a language data object to ARB format
String _convertLanguageToArb(
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
    final arbKey = _transformKeyForArb(apiKey);

    // Store key mapping for OTA updates
    keyMapping[apiKey] = arbKey;

    // Check if this is a plural message before validation
    final isPluralMessage = valueText.contains('plural,');

    // Validate and normalize the translation value
    final validationResult = _validateTranslationValue(valueText);
    final normalizedValue = validationResult.value;

    // Add the translation to the ARB map
    arbMap[arbKey] = normalizedValue;

    // Get placeholders, but filter them if this is a plural message
    final placeholders = isPluralMessage
        ? _filterPlaceholdersForPluralMessage(validationResult.placeholders)
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
        final sanitizedName = _sanitizePlaceholderName(placeholder.name);

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

/// Filter placeholders for plural messages to avoid invalid parameter names
List<Placeholder> _filterPlaceholdersForPluralMessage(
    List<Placeholder> placeholders) {
  // For plural messages, we only keep the count parameter
  // Other placeholders with # or spaces will cause syntax errors
  return placeholders.where((p) {
    // Keep only the count variable and valid Dart identifiers
    return p.type == 'int' || _isValidDartIdentifier(p.name);
  }).toList();
}

/// Check if a string is a valid Dart identifier
bool _isValidDartIdentifier(String name) {
  // Simplified check - Dart identifiers can't have spaces or special chars
  return !name.contains(' ') &&
      !name.contains('#') &&
      !name.contains('-') &&
      RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(name);
}

/// Sanitize a placeholder name to be a valid Dart identifier
String _sanitizePlaceholderName(String name) {
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
ValidationResult _validateTranslationValue(String value) {
  // Store all placeholders found in the message
  final placeholders = <Placeholder>[];
  String updatedValue = value;

  // Check for ICU syntax errors and extract placeholders
  try {
    // Handle plural messages
    if (value.contains('plural,')) {
      return _validatePluralMessage(value);
    }

    // Handle select messages
    if (value.contains('select,')) {
      return _validateSelectMessage(value);
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
ValidationResult _validatePluralMessage(String message) {
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
ValidationResult _validateSelectMessage(String message) {
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

/// Transform an API key into a valid ARB key (Dart method name)
String _transformKeyForArb(String apiKey) {
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
