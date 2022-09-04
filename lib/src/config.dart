import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jbuild_cli/src/utils.dart';
import 'package:logging/logging.dart' as log;
import 'package:path/path.dart' as p;

import 'utils.dart';

part 'config.freezed.dart';

final logger = log.Logger('jbuild');

class JBuildFiles {
  final File jbuildJar;
  final File configFile;
  final Directory tempDir = Directory('.jbuild-cache/tmp');

  JBuildFiles(this.jbuildJar, this.configFile);
}

JBuildConfiguration configFromJson(dynamic json) {
  if (json is Map) {
    final map = asJsonMap(json);
    return JBuildConfiguration.fromMap(map);
  } else {
    throw DartleException(
        message: 'Expecting jbuild configuration to be a Map, '
            'but it is ${json?.runtimeType}');
  }
}

@freezed
class JBuildConfiguration with _$JBuildConfiguration {
  const JBuildConfiguration._();

  const factory JBuildConfiguration({
    required Set<String> sourceDirs,
    required CompileOutput output,
    required Set<String> resourceDirs,
    required String mainClass,
    required List<String> javacArgs,
    required Set<String> repositories,
    required Map<String, DependencySpec> dependencies,
    required Set<String> exclusions,
    required String compileLibsDir,
    required String runtimeLibsDir,
    required String testLibsDir,
  }) = _Config;

  static JBuildConfiguration fromMap(Map<String, Object?> map) {
    return JBuildConfiguration(
      sourceDirs: _stringIterableValue(map, 'source-dirs', const {}).toSet(),
      output: _compileOutputValue(map, 'output-dir', 'output-jar') ??
          _defaultOutputValue(),
      resourceDirs:
          _stringIterableValue(map, 'resource-dirs', const {}).toSet(),
      mainClass: _stringValue(map, 'main-class', ''),
      javacArgs: _stringIterableValue(map, 'javac-args', const [])
          .toList(growable: false),
      dependencies: _dependencies(map, 'dependencies', const {}),
      repositories: _stringIterableValue(map, 'repositories', const {}).toSet(),
      exclusions:
          _stringIterableValue(map, 'exclusion-patterns', const {}).toSet(),
      compileLibsDir: _stringValue(map, 'compile-libs-dir', 'compile-libs'),
      runtimeLibsDir: _stringValue(map, 'runtime-libs-dir', 'runtime-libs'),
      testLibsDir: _stringValue(map, 'test-libs-dir', 'test-libs'),
    );
  }

  List<String> preArgs() {
    if (repositories.isNotEmpty) {
      return repositories.expand((r) => ['-r', r]).toList();
    }
    return const [];
  }

  List<String> compileArgs(List<SubProject> subProjects) {
    final result = <String>[];
    result.addAll(sourceDirs);
    final classpath = subProjects
        .map((p) => p.when(
            project: (i1, i2, out) => out,
            jar: (j) => CompileOutput.jar(j.path)))
        .followedBy([
      CompileOutput.dir(compileLibsDir),
    ]);
    for (final cp in classpath) {
      result.addAll(['-cp', cp.when(dir: (d) => d, jar: (j) => j)]);
    }
    output.when(
        dir: (d) => result.addAll(['-d', d]),
        jar: (j) => result.addAll(['-j', j]));
    for (final r in resourceDirs) {
      result.addAll(['-r', r]);
    }
    if (mainClass.isNotEmpty) {
      result.addAll(['-m', mainClass]);
    }
    if (javacArgs.isNotEmpty) {
      result.add('--');
      result.addAll(javacArgs);
    }
    return result;
  }

  List<String> installArgsForCompilation() {
    final result = ['-s', 'compile', '-d', compileLibsDir];
    for (final exclude in exclusions) {
      result.add('--exclusion');
      result.add(exclude);
    }
    dependencies.forEach((dependency, spec) {
      if (spec.scope.includedInCompilation() && spec.path == null) {
        result.add(dependency);
      }
    });
    return result;
  }

  List<String> installArgsForRuntime() {
    final result = ['-t', '-d', runtimeLibsDir];
    for (final exclude in exclusions) {
      result.add('--exclusion');
      result.add(exclude);
    }
    dependencies.forEach((dependency, spec) {
      if (spec.scope.includedAtRuntime() && spec.path == null) {
        result.add(dependency);
      }
    });
    return result;
  }
}

@freezed
class CompileOutput with _$CompileOutput {
  const factory CompileOutput.dir(String directory) = Dir;

  const factory CompileOutput.jar(String jar) = Jar;
}

enum DependencyScope {
  all,
  compileOnly,
  runtimeOnly;

  bool includedInCompilation() {
    return this != DependencyScope.runtimeOnly;
  }

  bool includedAtRuntime() {
    return this != DependencyScope.compileOnly;
  }
}

@freezed
class DependencySpec with _$DependencySpec {
  const DependencySpec._();

  static const DependencySpec defaultSpec =
      DependencySpec(transitive: true, scope: DependencyScope.all);

  const factory DependencySpec({
    required bool transitive,
    required DependencyScope scope,
    String? path,
  }) = _DependencySpec;

  static DependencySpec fromMap(Map<String, Object?> map) {
    if (map.keys.any(const {'transitive', 'scope'}.contains.not)) {
      throw DartleException(
          message: 'invalid dependency definition, '
              'only "transitive" and "scope" fields can be set: $map');
    }
    return DependencySpec(
        transitive: _boolValue(map, 'transitive', true),
        scope: _scopeValue(map, 'scope', DependencyScope.all),
        path: _optionalStringValue(map, 'path'));
  }

  Future<PathDependency>? toPathDependency() {
    final thisPath = path;
    if (thisPath == null) return null;
    return FileSystemEntity.isFile(thisPath).then((isFile) => isFile
        ? PathDependency.jar(this, thisPath)
        : PathDependency.jbuildProject(this, thisPath));
  }
}

@freezed
class PathDependency with _$PathDependency {
  const factory PathDependency.jar(DependencySpec spec, String path) =
      JarDependency;

  const factory PathDependency.jbuildProject(DependencySpec spec, String path) =
      ProjectDependency;
}

@freezed
class SubProject with _$SubProject {
  const factory SubProject.project(
      Task compileTask, Task testTask, CompileOutput output) = SubProjectOutput;

  const factory SubProject.jar(File jar) = SubProjectJar;
}

bool _boolValue(Map<String, Object?> map, String key, bool defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is bool) {
    return value;
  }
  if (value is String) {
    if (const {'true', 'True', 'yes', 'Yes'}.contains(value)) {
      return true;
    }
    if (const {'false', 'False', 'no', 'No'}.contains(value)) {
      return false;
    }
  }
  throw DartleException(
      message: "expecting a boolean value for '$key', but got '$value'.");
}

String _stringValue(Map<String, Object?> map, String key, String defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is String) {
    return value;
  }
  throw DartleException(
      message: "expecting a String value for '$key', but got '$value'.");
}

String? _optionalStringValue(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is String) {
    return value;
  }
  throw DartleException(
      message: "expecting a String value for '$key', but got '$value'.");
}

DependencyScope _scopeValue(
    Map<String, Object?> map, String key, DependencyScope defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is String) {
    return DependencyScope.values
        .firstWhere((enumValue) => enumValue.name == value, orElse: () {
      throw DartleException(
          message: "expecting one of ${DependencyScope.values} for '$key', "
              "but got '$value'.");
    });
  }
  throw DartleException(
      message: "expecting a String value for '$key', "
          "but got '$value'.");
}

Iterable<String> _stringIterableValue(
    Map<String, Object?> map, String key, Iterable<String> defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is Iterable) {
    // value is not even an Iterable!!!
    return value.map((e) {
      if (e == null || e is Iterable || e is Map) {
        throw DartleException(
            message: "expecting a list of String values for '$key', "
                "but got '$e'.");
      }
      return e.toString();
    });
  }
  if (value is String) {
    return {value};
  }
  throw DartleException(
      message: "expecting a list of String values for '$key', "
          "but got '$value'.");
}

CompileOutput? _compileOutputValue(
    Map<String, Object?> map, String dirKey, String jarKey) {
  final dir = map[dirKey];
  final jar = map[jarKey];
  if (dir == null && jar == null) {
    return null;
  }
  if (dir != null) {
    if (dir is String) {
      return CompileOutput.dir(dir);
    }
    throw DartleException(
        message: "expecting a String value for '$dirKey', "
            "but got '$dir'.");
  }
  if (jar is String) {
    return CompileOutput.jar(jar);
  }
  throw DartleException(
      message: "expecting a String value for '$jarKey', "
          "but got '$jar'.");
}

const dependenciesSyntaxHelp = '''
Use the following syntax to declare dependencies:

  dependencies:
    - first:dep:1.0
    - another:dep:2.0:
        transitive: false  # true (at runtime) by default
        scope: runtimeOnly # or compileOnly or all
''';

Map<String, DependencySpec> _dependencies(Map<String, Object?> map, String key,
    Map<String, DependencySpec> defaultValue) {
  final value = map[key];
  if (value == null) return defaultValue;
  if (value is List) {
    final map = <String, DependencySpec>{};
    for (final entry in value) {
      if (entry is String) {
        map[entry] = DependencySpec.defaultSpec;
      } else if (entry is Map) {
        _addMapDependencyTo(map, entry);
      } else {
        throw DartleException(
            message: 'bad dependency declaration, '
                "expected String or Map value, got '$entry'.\n"
                "$dependenciesSyntaxHelp");
      }
    }
    return map;
  }
  throw DartleException(
      message: "'$key' should be a List.\n"
          "$dependenciesSyntaxHelp");
}

void _addMapDependencyTo(Map<String, DependencySpec> map, Map entry) {
  if (entry.length != 1) {
    throw DartleException(
        message: "bad dependency declaration: '$entry'.\n"
            '$dependenciesSyntaxHelp');
  }
  final dep = entry.entries.first;
  map[dep.key as String] = _dependencySpec(dep.value);
}

DependencySpec _dependencySpec(value) {
  if (value == null) {
    return DependencySpec.defaultSpec;
  }
  if (value is Map) {
    return DependencySpec.fromMap(asJsonMap(value));
  }
  throw DartleException(
      message: "bad dependency attributes declaration: '$value'.\n"
          "$dependenciesSyntaxHelp");
}

CompileOutput _defaultOutputValue() {
  return CompileOutput.jar('${p.basename(Directory.current.path)}.jar');
}
