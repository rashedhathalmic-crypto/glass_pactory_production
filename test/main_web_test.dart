import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/main_web.dart';

void main() {
  testWidgets('standalone web app opens the NC Generator', (tester) async {
    await tester.pumpWidget(const NcGeneratorWebApp());

    expect(find.text('DXF to NC Generator'), findsOneWidget);
    expect(find.text('Upload DXF'), findsOneWidget);
    expect(find.text('Drawing preview'), findsOneWidget);
    expect(find.text('Tool settings'), findsOneWidget);
    expect(find.text('Generate SKG1625 NC'), findsOneWidget);
    expect(find.text('Download NC'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
  });
}
