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
`/nc-generator`. Upload a DXF containing LINE, ARC, CIRCLE, POLYLINE, or
LWPOLYLINE geometry, preview it, configure tooling and feeds, and generate NC
locally in the browser. The generator does not upload drawings or depend on
predefined workbook profiles.

The CAM core is split into geometry analysis, native line/arc offsetting,
inside-first toolpath planning, an SKG1625 machine profile, and NC serialization.
Each closed contour receives configurable rough offsets, an optional
semi-finish allowance pass, and a dedicated finish pass. Inter-contour moves
use absolute (`G90`) coordinates while contour cutting uses incremental
(`G91`) coordinates and configurable lead-in, lead-out, and Z oscillation.

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
