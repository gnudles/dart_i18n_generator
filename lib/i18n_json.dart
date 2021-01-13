import 'dart:async';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

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
  variables.addAll(matches.map((e) => e.group(2)));

  String dollarSubstitute = ".i18n_json_dollar_sign.";
  int indexOffset = 0;
  matches.forEach((e) {
    int startIndex = e.start + indexOffset;

    if (e.group(0).startsWith('{', 1)) {
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
  String comment() {
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

  @override
  String toString() {
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

  bool isArrayType;
  String type;
  String name;
  List<dynamic> entries; // the single or array of translations
  List<String>
      variables; // the optional variables... cannot be used in array mode.
}

void buildTranslationEntriesArray(Map<String, dynamic> content, String prefix,
    List<TranslationEntry> translationsList) {
  content.forEach((key, value) {
    key = prefix + key;
    if (value is Map<String, dynamic>) {
      buildTranslationEntriesArray(value, key, translationsList);
    } else if (value is List<dynamic>) {
      if (value.every((element) => element is String)) {
        translationsList.add(TranslationEntry.array('List<String>', key,
            value.map((e) => escapeStringFromJson(e)).toList()));
      } else if (value.every((element) => element is int)) {
        translationsList.add(TranslationEntry.array('List<int>', key, value));
      } else if (value.every((element) => element is double)) {
        translationsList
            .add(TranslationEntry.array('List<double>', key, value));
      }
    } else if (value is String) {
      translationsList.add(TranslationEntry('String', key, value));
    } else if (value is int) {
      translationsList.add(TranslationEntry('int', key, value));
    } else if (value is double) {
      translationsList.add(TranslationEntry('double', key, value));
    }
  });
}

bool testSdkVersionForNullSafety(String version) {
  final exp1 = RegExp(r"^\^(\d+).(\d+).(\d+)(?:-\d+)?$");
  final exp2 = RegExp(r"^>=(\d+).(\d+).(\d+)(?:-\d+)? <(\d+).(\d+).(\d+)$");
  var match = exp1.firstMatch(version);
  if (match != null) {
    var vlist = [
      int.parse(match.group(1)),
      int.parse(match.group(2)),
      int.parse(match.group(3)),
    ];
    if (vlist[0] > 2) return true;
    if (vlist[0] < 2) return false;
    return (vlist[1] >= 12);
  } else if ((match = exp2.firstMatch(version)) != null) {
    var vlist1 = [
      int.parse(match.group(1)),
      int.parse(match.group(2)),
      int.parse(match.group(3)),
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
