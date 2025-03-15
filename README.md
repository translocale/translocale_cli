# TransLocale CLI

A command-line tool for the TransLocale localization system, making Flutter app localization easier and more powerful.

## Installation

```bash
dart pub global activate -sgit https://github.com/translocale/translocale_cli.git
```

## Usage

```bash
translocale [command] [options]
```

Available commands:

- `init` - Initialize TransLocale in your project
- `download` - Download translations from TransLocale server
- `gen-l10n` - Generate Flutter localization files
- `setup` - One-command setup (init + download + gen-l10n)
- `fix-arb` - Fix ARB files with common issues

## Command Details

### Initialize (`init`)

Initialize TransLocale in your Flutter project.

```bash
translocale init [options]
```

Options:
- `--api-key, -k` - Your TransLocale API key
- `--url, -u` - API URL (defaults to production)
- `--languages, -l` - Languages to support (comma-separated, defaults to 'en')

The `init` command creates the following files:
- `translocale.yaml` - Configuration file for your TransLocale settings
- `l10n.yaml` - Flutter configuration file for gen-l10n (if it doesn't exist)
- Creates the l10n directory for ARB files

Example `translocale.yaml` file:
```yaml
# API configuration
api:
  key: "your_api_key"
  base_url: "https://api.translocale.io"

# Languages to download during development
languages:
  - "en"
  - "es"
  - "fr"

# Output directory for ARB files
output_dir: "lib/l10n"

# Translation mapping configuration (for OTA updates)
mapping:
  # Optional key mappings if needed
  # "common.buttons.save": "saveButton"
```

### Download Translations (`download`)

Download translations from TransLocale server and generate ARB files.

```bash
translocale download [options]
```

Options:
- `--api-key, -k` - API key for the TransLocale service
- `--url, -u` - Base URL for the TransLocale API
- `--output, -o` - Output directory for ARB files
- `--languages, -l` - Comma-separated list of language codes to download
- `--all-languages, -a` - Download all available languages from the server
- `--list` - List available languages from the server
- `--help, -h` - Show help for this command

*Note: If options are not specified, values from the `translocale.yaml` file will be used.*

### Generate Localizations (`gen-l10n`)

Generate Flutter localization files from ARB files.

```bash
translocale gen-l10n [options]
```

Options:
- `--auto-download, -a` - Download translations before generating
- `--watch, -w` - Watch for ARB changes and regenerate
- `--force, -f` - Force regeneration of localization files
- `--use-extensions` - Generate extension methods for OTA translations
- `--extensions-class-name` - Name for the generated extensions class (default: AppLocalizationsOta)
- `--help, -h` - Show help for this command

*Note: This command uses the output directory specified in `translocale.yaml` or `l10n.yaml` to find ARB files.*

### One-Command Setup (`setup`)

Perform complete setup in one command (init + download + gen-l10n).

```bash
translocale setup [options]
```

Options:
- `--api-key, -k` - Your TransLocale API key (required)
- `--url, -u` - API URL (defaults to production)
- `--languages, -l` - Languages to support (defaults to 'en')

### Fix ARB Files (`fix-arb`)

Fix problematic ARB files with common issues.

```bash
translocale fix-arb [options]
```

Options:
- `--dir, -d` - Directory containing ARB files (defaults to 'lib/l10n')

## OTA Translation Approaches

TransLocale supports two approaches for Over-The-Air (OTA) translations:

### 1. Proxy Class Approach (Default)

This approach uses proxy classes that automatically handle OTA translations. It requires no code changes in your app - your existing localization code will automatically use OTA translations when available.

```bash
translocale gen-l10n
```

### 2. Extension Method Approach

This approach generates extension methods with an `Ota` suffix, giving you explicit control over when to use OTA translations vs. build-time translations.

```bash
translocale gen-l10n --use-extensions
```

Then in your code:

```dart
// Import the generated extensions
import 'package:your_app/l10n/translocale_extensions.dart';

// Use standard method for build-time translations
Text(AppLocalizations.of(context).hello)

// Use Ota method for OTA translations with the same API
Text(AppLocalizations.of(context).helloOta)
```

## Flutter SDK Integration

After generating localization files, integrate TransLocale in your Flutter app:

```dart
// Initialize TransLocale
await TransLocale.initialize(
  apiKey: 'your_api_key',
  // supportedLocales is optional - if not provided, 
  // it will be detected automatically from ARB files
);

// In your MaterialApp, use the TransLocale wrapper
return MaterialApp(
  localizationsDelegates: TransLocale.wrapDelegates([
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ]),
  supportedLocales: TransLocale.supportedLocales,
  // ...rest of your app configuration
);
```

## Configuration Files

TransLocale uses two main configuration files:

### translocale.yaml

This is the main configuration file for the TransLocale CLI tool, created by the `init` command. It stores:

- API configuration (key, base URL)
- Languages to download during development
- Output directory for ARB files
- Optional translation mappings for OTA updates

All CLI commands will look for this file in the project root and use its values as defaults.

### l10n.yaml

This is Flutter's standard configuration file for localization, which controls:

- ARB files directory location
- Template ARB file name
- Output localization file name
- Nullable getter settings
- Output directory for generated Dart files

The TransLocale CLI will create this file if it doesn't exist, but you can modify it to customize Flutter's localization generation.

## License

MIT
