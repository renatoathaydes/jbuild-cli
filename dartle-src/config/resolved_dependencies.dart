import 'package:schemake/schemake.dart';

import 'jb_config_schema.dart';

const dependencyKind = Enums(EnumValidator('DependencyKind', {
  'localJar',
  'localProject',
  'maven',
}));

const resolvedDependency = Objects('ResolvedDependency', {
  'artifact': Property(Strings()),
  'spec': Property(dependency),
  'sha1': Property(Strings()),
  'kind': Property(dependencyKind),
  'isDirect': Property(Bools()),
  'dependencies': Property(Arrays(Strings())),
});

const resolvedDependencies = Objects('ResolvedDependencies', {
  'dependencies': Property(Arrays(resolvedDependency)),
  'instant': Property(Strings()),
});
