import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// A utility script to fix ARB files with problematic placeholders
/// Particularly useful for plural messages that have invalid placeholder names
void main(List<String> args) async {
  print('🛠️ ARB Placeholder Fixer');
  print(
      'This tool fixes ARB files with problematic placeholders that cause errors in generated code');

  // Determine target directory
  final targetDir = args.isNotEmpty ? args[0] : 'lib/l10n';
  print('\nLooking for ARB files in: $targetDir');

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

/// Check if a string is a valid Dart identifier
bool _isValidDartIdentifier(String name) {
  return !name.contains(' ') &&
      !name.contains('#') &&
      !name.contains('-') &&
      RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(name);
}

/// Check if this is a count parameter (used for plurals)
bool _isCountParameter(String name, Map<String, dynamic> metadata) {
  // Usually the count parameter is named "count" and has type "int"
  return (name == 'count' || name.toLowerCase().contains('count')) &&
      metadata['type'] == 'int';
}
