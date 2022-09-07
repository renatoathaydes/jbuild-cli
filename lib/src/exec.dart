import 'dart:io';

import 'package:dartle/dartle.dart';

import 'config.dart' show logger, jbuildLogNameEnvVar;

Future<int> execJBuildCli(String name, List<String> commandArgs,
    {required String workingDir}) {
  if (Platform.executable == 'dart') {
    commandArgs = [Platform.script.path, ...commandArgs];
  }
  logger.fine(
      () => 'Executing [$name]: ${Platform.resolvedExecutable} $commandArgs');
  return exec(Process.start(Platform.resolvedExecutable, commandArgs,
      runInShell: true,
      workingDirectory: workingDir,
      environment: {jbuildLogNameEnvVar: name}));
}

Future<int> execJBuild(File jbuildJar, List<String> preArgs, String command,
    List<String> commandArgs) {
  return execJava([
    '-jar',
    jbuildJar.path,
    '-q',
    ...preArgs,
    command,
    ...commandArgs,
  ]);
}

Future<int> execJava(List<String> args) {
  logger.fine(() => 'Executing java $args');
  return exec(Process.start('java', args, runInShell: true));
}
