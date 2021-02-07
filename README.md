# i18n_json

## Introduction

An alternative dart code generator for the vs-code plugin "vscode-flutter-i18n-json",
written in in dart.
This project cannot yet completely replace the specified plugin, but is a workaround to deal with code generation bugs in original plugin.
This project in not a vs-code plugin, rather it is a simple cli to convert the json files into one dart class.
In order to use it, add it to dev dependencies in pubspec.yaml:

```yaml
dev_dependencies:
  i18n_json:
    git: https://github.com/gnudles/dart_i18n_generator
```

and generate i18n.dart by running the command

```bash
flutter pub run i18n_json:generate
```

## Notes

This cli support both YAML and JSON locale files. This was made in effort to allow adding comments in your locale files, since JSON doesn't support comments but YAML does.
In order to use comments in locale files, rename the file endings to ".yaml", so this tool could detect it. If you have both endings (.yaml & .json), the .yaml will be loaded.
