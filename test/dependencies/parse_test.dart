import 'package:jb/jb.dart';
import 'package:jb/src/dependencies/parse.dart';
import 'package:test/test.dart';

void main() {
  test('can parse simple JBuild dependency tree', () {
    final results = parseDependencyTree([
      'Dependencies of org.slf4j:slf4j-api:2.0.3 (incl. transitive):',
      '  * no dependencies',
      'Dependencies of org.slf4j:slf4j-simple:2.0.3 (incl. transitive):',
      '  - scope compile',
      '    * org.slf4j:slf4j-api:2.0.3 [compile]',
      '  1 compile dependency listed',
    ]);
    expect(
        results,
        equals([
          ResolvedDependency(
              artifact: 'org.slf4j:slf4j-api:2.0.3',
              spec: defaultSpec,
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [],
              isDirect: true),
          ResolvedDependency(
              artifact: 'org.slf4j:slf4j-simple:2.0.3',
              spec: defaultSpec,
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [
                'org.slf4j:slf4j-api:2.0.3',
              ],
              isDirect: true),
        ]));
  });

  test('can parse bigger JBuild dependency tree', () {
    final results = parseDependencyTree([
      'Dependencies of my-group:my-app:1.0.0 (incl. transitive):',
      '  - scope compile',
      '    * org.slf4j:slf4j-api:2.0.16 [compile]',
      '  1 compile dependency listed',
      '  - scope runtime',
      '    * org.apache.logging.log4j:log4j-core:2.24.3 [runtime]',
      '      * org.apache.logging.log4j:log4j-api:2.24.3 [compile]',
      '    * org.apache.logging.log4j:log4j-slf4j2-impl:2.19.0 [runtime]',
      '      * org.apache.logging.log4j:log4j-api:2.19.0 [compile]',
      '      * org.slf4j:slf4j-api:2.0.0 [compile]',
      '  6 runtime dependencies listed',
      '  The artifact org.apache.logging.log4j:log4j-api is required with more than one version:',
      '    * 2.19.0 (org.apache.logging.log4j:log4j-slf4j2-impl:2.19.0 -> org.apache.logging.log4j:log4j-api:2.19.0)',
      '    * 2.24.3 (org.apache.logging.log4j:log4j-core:2.24.3 -> org.apache.logging.log4j:log4j-api:2.24.3)',
      '  The artifact org.slf4j:slf4j-api is required with more than one version:',
      '    * 2.0.0 (org.apache.logging.log4j:log4j-slf4j2-impl:2.19.0 -> org.slf4j:slf4j-api:2.0.0)',
      '    * 2.0.16 (org.slf4j:slf4j-api:2.0.16)',
    ]);
    expect(
        results,
        equals([
          ResolvedDependency(
              artifact: 'org.slf4j:slf4j-api:2.0.16',
              spec: defaultSpec,
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [],
              isDirect: false),
          ResolvedDependency(
              artifact: 'my-group:my-app:1.0.0',
              spec: defaultSpec,
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [
                'org.slf4j:slf4j-api:2.0.16',
                'org.apache.logging.log4j:log4j-core:2.24.3',
                'org.apache.logging.log4j:log4j-slf4j2-impl:2.19.0',
              ],
              isDirect: true),
          ResolvedDependency(
              artifact: 'org.apache.logging.log4j:log4j-core:2.24.3',
              spec: const DependencySpec(scope: DependencyScope.runtimeOnly),
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [
                'org.apache.logging.log4j:log4j-api:2.24.3',
              ],
              isDirect: false),
          ResolvedDependency(
              artifact: 'org.apache.logging.log4j:log4j-api:2.24.3',
              spec: const DependencySpec(scope: DependencyScope.runtimeOnly),
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [],
              isDirect: false),
          ResolvedDependency(
              artifact: 'org.apache.logging.log4j:log4j-slf4j2-impl:2.19.0',
              spec: const DependencySpec(scope: DependencyScope.runtimeOnly),
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [
                'org.apache.logging.log4j:log4j-api:2.19.0',
                'org.slf4j:slf4j-api:2.0.0',
              ],
              isDirect: false),
          ResolvedDependency(
              artifact: 'org.apache.logging.log4j:log4j-api:2.19.0',
              spec: const DependencySpec(scope: DependencyScope.runtimeOnly),
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [],
              isDirect: false),
          ResolvedDependency(
              artifact: 'org.slf4j:slf4j-api:2.0.0',
              spec: const DependencySpec(scope: DependencyScope.runtimeOnly),
              kind: DependencyKind.maven,
              sha1: '',
              dependencies: [],
              isDirect: false),
        ]));
  });
}
