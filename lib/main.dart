import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/nc_generator/presentation/image_to_dxf_screen.dart';
import 'features/nc_generator/presentation/nc_generator_screen.dart';
import 'features/nc_generator/presentation/pdf_to_dxf_screen.dart';

void main() {
  runApp(const NcGeneratorApp());
}

class NcGeneratorApp extends StatelessWidget {
  const NcGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glass CNC Tools',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.precision_manufacturing),
                text: 'DXF → NC Grinding',
              ),
              Tab(
                icon: Icon(Icons.image_outlined),
                text: 'Image → Editable DXF',
              ),
              Tab(
                icon: Icon(Icons.picture_as_pdf),
                text: 'PDF → DXF 2D',
              ),
            ],
          ),
          body: TabBarView(
            children: [
              NcGeneratorScreen(),
              ImageToDxfScreen(),
              PdfToDxfScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
