// The entry point for the command-line tool to generate Translocale files

import 'dart:io';

void main(List<String> args) async {
  print('Running Translocale generator...');

  // Run the build_runner to generate the proxy classes
  final buildRunner = await Process.run(
    'dart',
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    runInShell: true,
  );

  if (buildRunner.exitCode != 0) {
    print('Error running build_runner:');
    print(buildRunner.stderr);
    exit(1);
  }

  print(buildRunner.stdout);
  print('Translocale generation completed successfully!');
}
