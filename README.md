# glass_pactory_production

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Native CNC NC generator

NC programs are generated directly in Python; Excel is not required at runtime.
The three workbook profiles are supported:
`129-122-03-210`, `129-122-03-102`, and `129-122-03-211`.

```bash
glass-cnc-nc-cli 129-122-03-211 --tool-diameter 94.4 --tool-width 24.3 -o program.nc
```

`WorkbookEngine` is retained only for inspecting worksheets and formula dependencies.
