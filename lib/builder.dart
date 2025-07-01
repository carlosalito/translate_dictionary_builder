import 'package:build/build.dart';
import 'package:flutter_translate/translate_annotation.dart';
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';

class TranslateDictionaryGenerator extends Generator {
  final BuilderOptions options;
  TranslateDictionaryGenerator(this.options);

  String _toPascalCase(String key) {
    final List<String> parts = key.split(RegExp(r'[_\-.]'));
    return parts.map((String part) => part[0].toUpperCase() + part.substring(1)).join('');
  }

  String _toCamelCase(String key) {
    final List<String> parts = key.split('.');
    for (int i = 1; i < parts.length; i++) {
      parts[i] = parts[i][0].toUpperCase() + parts[i].substring(1);
    }
    return parts.join('');
  }

  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final String yamlRelativePath = options.config['yaml_path'] as String? ?? 'assets/i18n/pt_Br.yaml';

    final AssetId yamlAssetId = AssetId(buildStep.inputId.package, yamlRelativePath);

    if (!await buildStep.canRead(yamlAssetId)) {
      log.warning(
        'Arquivo YAML não encontrado no caminho esperado para o pacote ${buildStep.inputId.package}: ${yamlAssetId.uri}',
      );
      return ''; // Retorna uma string vazia, pois não há dicionário para gerar.
    }

    const TypeChecker typeChecker = TypeChecker.fromRuntime(GenerateTranslateDictionary);
    final Iterable<AnnotatedElement> annotatedClasses = library.annotatedWith(typeChecker);

    if (annotatedClasses.isEmpty) {
      return '';
    }

    final String yamlString = await buildStep.readAsString(yamlAssetId);
    final dynamic yamlMap = loadYaml(yamlString);

    final Object className = annotatedClasses.first.annotation.read('className').literalValue ?? 'TranslateDict';
    final List<String> classDefinitions = <String>[]; // Lista para armazenar as definições de classes aninhadas.

    final String rootClass = _generateClasses(yamlMap, classDefinitions, rootClassName: className.toString());

    return '''
class $className {
  $rootClass
}

${classDefinitions.join('\n')}
''';
  }

  String _generateClasses(
    dynamic data,
    List<String> classDefinitions, {
    String parentKey = '',
    String rootClassName = 'TranslateDict',
  }) {
    final List<String> lines = <String>[];

    if (data is Map) {
      for (final dynamic key in data.keys) {
        final String fullKey = parentKey.isEmpty ? key : '$parentKey.$key';
        final String camelCaseKey = _toCamelCase(key);
        final String className = _toPascalCase('${rootClassName}_$key');

        if (data[key] is Map) {
          final String subClassContent = _generateClasses(
            data[key],
            classDefinitions,
            parentKey: fullKey,
            rootClassName: className,
          );
          classDefinitions.add('class $className { $subClassContent }');
          lines.add('$className get $camelCaseKey => $className();');
        } else {
          lines.add('String get $camelCaseKey => \'$fullKey\';');
        }
      }
    }

    if (data is String) {
      lines.add('String get $parentKey => \'$parentKey\';');
    }

    return lines.join('\n  ');
  }
}

Builder translateDictionaryBuilder(BuilderOptions options) {
  return SharedPartBuilder(<Generator>[TranslateDictionaryGenerator(options)], 'translate_dictionary');
}
