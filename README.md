# i18n_json

## Introduction

An alternative dart code generator for the vs-code plugin "vscode-flutter-i18n-json",
written in dart.
This project is not a full replacement of the original plugin, it is only a replacement of the code generator, because the original code generator had many bugs and many missing features.
This project in not a vs-code plugin, rather it is a simple cli to convert the json files into one dart class.
In order to use it, add it to dev dependencies in pubspec.yaml:

```yaml
dev_dependencies:
  i18n_json: ^1.0.0
```

and generate i18n.dart by running the command

```bash
flutter pub run i18n_json
```

## Features

- Full compatibility with the vscode plugin.
- Auto-detection of "Sound Null Safety" of your project.
- Ability to add comments (through YAML, see notes below)
- Experimental Gender & Plural (see notes below)

## Notes

This cli support both YAML and JSON locale files. This was made in effort to allow adding comments in your locale files, since JSON doesn't support comments but YAML does.
In order to use comments in locale files, rename the file endings to ".yaml", so this tool could detect it. If you have both endings (.yaml & .json), the .yaml will be loaded.

To add Plural or Gender, make it like:

```json
    "sentItems":
        {
         "__gender":{
            "male": {"__plural":
                {
                    "zero": "he sent you no {item}s",
                    "one": "he sent you one {item}",
                    "other": "he sent you {count} {item}s"
                }},
            "female": {"__plural":
                {
                    "zero": "she sent you no {item}s",
                    "one": "she sent you one {item}",
                    "other": "she sent you {count} {item}s"

                }},
            "other": {"__plural":
                {
                    "zero": "they sent you no {item}s",
                    "one": "they sent you one {item}",
                    "other": "they sent you {count} {item}s"

                }},
            },
        }
```

This will generate the following code:

```dart
String sentItems(int count, String gender, String item){if (gender == 'male'){if (count == 0){return "he sent you no ${item}s";} else if (count == 1){return "he sent you one ${item}";} else {return "he sent you ${count} ${item}s";}} else if (gender == 'female'){if (count == 0){return "she sent you no ${item}s";} else if (count == 1){return "she sent you one ${item}";} else {return "she sent you ${count} ${item}s";}} else {if (count == 0){return "they sent you no ${item}s";} else if (count == 1){return "they sent you one ${item}";} else {return "they sent you ${count} ${item}s";}}}
```

Note that "count" variable is automatically added in Plural, and "gender" variable is automatically added in Gender.
