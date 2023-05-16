import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

String getTextDirection(Map<String, dynamic> config, String locale) {
  if ((config['rtl'] as List<dynamic>).contains(locale)) return 'rtl';
  if ((config['ltr'] as List<dynamic>).contains(locale)) return 'ltr';
  return '';
}

String escapeStringFromJson(String input) {
  input = input.replaceAll("\\{", "{");
  input = input.replaceAll("\\}", "}");
  input = input.replaceAll("\\", "\\\\");
  input = input.replaceAll('"', '\\"');
  input = input.replaceAll("\$", "\\\$");
  input = input.replaceAll("\n", "\\n");
  input = input.replaceAll("\r", "");
  return input;
}

String getVariablesFromStringAndEscapeIt(String input, List<String> variables) {
  final exp = RegExp(r"(?<!\\)(\{([_A-Za-z]\w*)\})");
  var matches = exp.allMatches(input);
  variables.addAll(matches.map((e) => e.group(2)!));

  String dollarSubstitute = ".i18n_json_dollar_sign.";
  int indexOffset = 0;
  matches.forEach((e) {
    int startIndex = e.start + indexOffset;

    if (e.group(0)!.startsWith('{', 1)) {
      startIndex++;
    }
    input = input.substring(0, startIndex) +
        dollarSubstitute +
        input.substring(startIndex);
    indexOffset += dollarSubstitute.length;
  });
  input = escapeStringFromJson(input);
  input = input.replaceAll(dollarSubstitute, '\$');
  return input;
}

class TranslationEntry {
  TranslationEntry(this.type, this.name, dynamic entry) {
    variables = [];
    if (entry is String)
      entries = [getVariablesFromStringAndEscapeIt(entry, variables)];
    else
      entries = [entry];
    isArrayType = false;
  }

  TranslationEntry.array(this.type, this.name, this.entries) {
    isArrayType = true;
  }

  TranslationEntry.gender(this.name, this.decendants) {
    variables = collectVariables(["gender"], decendants.values).toList();
    isGender = true;
  }

  TranslationEntry.plural(this.name, this.decendants) {
    variables = collectVariables(["count"], decendants.values).toList();
    isPlural = true;
  }

  static Set<String> collectVariables(
      List<String> variables, Iterable<TranslationEntry> decendants) {
    Set<String> output = Set.from(variables);
    decendants.forEach((entry) {
      if (entry.isGender || entry.isPlural) {
        output = output.union(collectVariables([], entry.decendants.values));
      } else {
        output = output.union(Set.from(entry.variables));
      }
    });
    return output;
  }

  String comment() {
    if (isPlural || isGender) {
      return "/// it's complex";
    } else {
      if (isArrayType) {
        if (type == "List<String>") {
          return "/// ${entries.map((e) => '"' + e + '"').toList()}";
        } else
          return "/// $entries";
      }
      if (type == "String") {
        return "/// \"${entries[0]}\"";
      } else {
        return "/// ${entries[0]}";
      }
    }
  }

  String getPluralGenderCode(TranslationEntry? entry) {
    if (entry == null) {
      return "return null;";
    }
    if (entry.isGender) {
      return "if (gender == 'male'){${getPluralGenderCode(entry.decendants['male'])}} else if (gender == 'female'){${getPluralGenderCode(entry.decendants['female'])}} else {${getPluralGenderCode(entry.decendants['other'])}}";
    } else if (entry.isPlural) {
      return "if (count == 0){${getPluralGenderCode(entry.decendants['zero'])}} else if (count == 1){${getPluralGenderCode(entry.decendants['one'])}} else {${getPluralGenderCode(entry.decendants['other'])}}";
    } else {
      return "return \"${entry.entries[0]}\";";
    }
  }

  @override
  String toString() {
    if (isPlural || isGender) {
      String argumentsString = '';
      if (variables.contains('count')) {
        argumentsString += 'int count';
      }
      if (variables.contains('gender')) {
        if (argumentsString.isNotEmpty) {
          argumentsString += ', ';
        }
        argumentsString += 'String gender';
      }
      argumentsString = variables.fold(
          argumentsString,
          (previousValue, element) =>
              (element != 'count' && element != 'gender')
                  ? previousValue + ", String " + element
                  : previousValue);
      return "String $name($argumentsString){${getPluralGenderCode(this)}}";
    } else {
      if (isArrayType) {
        if (type == "List<String>") {
          return "$type get $name => ${entries.map((e) => '"' + e + '"').toList()};";
        } else
          return "$type get $name => $entries;";
      }
      if (variables.isEmpty) {
        if (type == "String") {
          return "$type get $name => \"${entries[0]}\";";
        } else {
          return "$type get $name => ${entries[0]};";
        }
      } else
        return "$type $name(${variables.skip(1).fold("String " + variables[0], (previousValue, element) => previousValue + ", String " + element)}) => \"${entries[0]}\";";
    }
  }

  late bool isArrayType;
  bool isPlural = false;
  bool isGender = false;
  late Map<String, TranslationEntry> decendants; //used only for gender & plural
  late String type;
  String name;
  late List<dynamic> entries; // the single or array of translations
  late List<String>
      variables; // the optional variables... cannot be used in array mode.
}

extension StringCapitalizeExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

TranslationEntry? buildPluralEntry(
  Map<String, dynamic> content,
  String prefix,
  bool alreadyGender,
) {
  final pluralKeys = ["zero", "one", "other"];
  Map<String, TranslationEntry> decendants = {};
  pluralKeys.forEach((pluralKey) {
    if (content.containsKey(pluralKey)) {
      if (!alreadyGender &&
          (content[pluralKey] is Map<String, dynamic>) &&
          (content[pluralKey] as Map<String, dynamic>)
              .containsKey("__gender") &&
          (content[pluralKey] as Map<String, dynamic>)["__gender"]
              is Map<String, dynamic>) {
        var genderEntry =
            buildGenderEntry(content[pluralKey]["__gender"], prefix, true);
        if (genderEntry != null) decendants[pluralKey] = genderEntry;
      } else if (content[pluralKey] is String) {
        decendants[pluralKey] =
            TranslationEntry("String", pluralKey, content[pluralKey]);
      }
    }
  });
  if (decendants.isNotEmpty) {
    return TranslationEntry.plural(prefix, decendants);
  }
  return null;
}

TranslationEntry? buildGenderEntry(
  Map<String, dynamic> content,
  String prefix,
  bool alreadyPlural,
) {
  final genderKeys = ["male", "female", "other"];
  Map<String, TranslationEntry> decendants = {};
  genderKeys.forEach((genderKey) {
    if (content.containsKey(genderKey)) {
      if (!alreadyPlural &&
          (content[genderKey] is Map<String, dynamic>) &&
          (content[genderKey] as Map<String, dynamic>)
              .containsKey("__plural") &&
          (content[genderKey] as Map<String, dynamic>)["__plural"]
              is Map<String, dynamic>) {
        var pluralEntry =
            buildPluralEntry(content[genderKey]["__plural"], prefix, true);
        if (pluralEntry != null) decendants[genderKey] = pluralEntry;
      } else if (content[genderKey] is String) {
        decendants[genderKey] =
            TranslationEntry("String", genderKey, content[genderKey]);
      }
    }
  });
  if (decendants.isNotEmpty) {
    return TranslationEntry.gender(prefix, decendants);
  }
  return null;
}

void buildTranslationEntriesArray(Map<String, dynamic> content, String prefix,
    Map<String, TranslationEntry> translationsList) {
  final var_name_validator = RegExp(r"^[_A-Za-z]\w*$");
  content.forEach((key, value) {
    if (var_name_validator.firstMatch(key) == null) {
      //atempt to fix key strings
      key = key.replaceAll(RegExp(r"\W"), "_");
      if (RegExp(r"^\d").firstMatch(key) != null) {
        key = '_' + key;
      }
    }
    if (key == "__plural" &&
        (value is Map<String, dynamic>) &&
        prefix.isNotEmpty) {
      var pluralEntry = buildPluralEntry(value, prefix, false);
      if (pluralEntry != null) {
        translationsList[prefix] = pluralEntry;
      }
    } else if (key == "__gender" &&
        (value is Map<String, dynamic>) &&
        prefix.isNotEmpty) {
      var genderEntry = buildGenderEntry(value, prefix, false);
      if (genderEntry != null) {
        translationsList[prefix] = genderEntry;
      }
    } else {
      if (prefix.isNotEmpty) {
        key = key.capitalize();
      }
      key = prefix + key;
      if (value is Map<String, dynamic>) {
        buildTranslationEntriesArray(value, key, translationsList);
      } else if (value is List<dynamic>) {
        if (value.every((element) => element is String)) {
          translationsList[key] = TranslationEntry.array('List<String>', key,
              value.map((e) => escapeStringFromJson(e)).toList());
        } else if (value.every((element) => element is int)) {
          translationsList[key] =
              TranslationEntry.array('List<int>', key, value);
        } else if (value.every((element) => element is double)) {
          translationsList[key] =
              TranslationEntry.array('List<double>', key, value);
        } else if (value.every((element) => element is bool)) {
          translationsList[key] =
              TranslationEntry.array('List<bool>', key, value);
        }
      } else if (value is String) {
        translationsList[key] = TranslationEntry('String', key, value);
      } else if (value is int) {
        translationsList[key] = TranslationEntry('int', key, value);
      } else if (value is double) {
        translationsList[key] = TranslationEntry('double', key, value);
      } else if (value is bool) {
        translationsList[key] = TranslationEntry('bool', key, value);
      }
    }
  });
}

bool testSdkVersionForNullSafety(String version) {
  final exp1 = RegExp(r"^\^(\d+).(\d+).(\d+)(?:-\d+)?$");
  final exp2 = RegExp(r"^>=(\d+).(\d+).(\d+)(?:-\d+)? <(\d+).(\d+).(\d+)$");
  var match = exp1.firstMatch(version);
  if (match != null) {
    var vlist = [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
    if (vlist[0] > 2) return true;
    if (vlist[0] < 2) return false;
    return (vlist[1] >= 12);
  } else if ((match = exp2.firstMatch(version)) != null) {
    var vlist1 = [
      int.parse(match!.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
    /*var vlist2 = [
      int.parse(match.group(4)),
      int.parse(match.group(5)),
      int.parse(match.group(6)),
    ];*/
    if (vlist1[0] > 2) return true;
    if (vlist1[0] < 2) return false;
    return (vlist1[1] >= 12);
  }
  return false;
}

Future<bool> getProjectNullSafety() async {
  var contents = await File('pubspec.yaml').readAsString();
  return testSdkVersionForNullSafety(loadYaml(contents)['environment']['sdk']);
}

Future<Map<String, dynamic>> getConfigFile() async {
  return readJsonFile('i18nconfig.json');
}

Future<Map<String, dynamic>> readJsonFile(String path) async {
  var contents = await File(path).readAsString();
  return jsonDecode(contents);
}

Future<dynamic> readYamlFile(String path) async {
  var contents = await File(path).readAsString();
  return loadYaml(contents);
}

dynamic convertYamlNode(dynamic input) {
  if (input is YamlNode) {
    if (input is YamlMap) {
      return input
          .map((key, value) => MapEntry(key as String, convertYamlNode(value)));
    } else if (input is YamlList) {
      return input.map((value) => convertYamlNode(value)).toList();
    } else if (input is YamlScalar) {
      return input.value;
    }
  }
  return input;
}
