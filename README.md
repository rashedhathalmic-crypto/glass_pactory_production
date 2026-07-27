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

## Browser-based CNC NC generator

The production web application includes a responsive NC generator at
`/nc-generator`. It supports profiles `129-122-03-210`, `129-122-03-102`, and
`129-122-03-211`, generates the complete program locally in the browser, and
lets operators preview, copy, or download the result. Excel and a desktop
installation are not required.

Run the application for web development with:

```bash
flutter run -d chrome
```

The Python generator remains as a tested reference engine and command-line
option for automation:

```bash
glass-cnc-nc-cli 129-122-03-211 --tool-diameter 94.4 --tool-width 24.3 -o program.nc
```

`WorkbookEngine` is retained only for inspecting worksheets and formula dependencies.
