import 'package:flutter/material.dart';
import '../domain/glass_cutting_planner.dart';

class GlassCuttingScreen extends StatelessWidget {
  const GlassCuttingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Glass Cutting V2', style: TextStyle(fontSize: 24)),
          SizedBox(height: 12),
          Text('Experimental geometry preview. Tool diameter: 8 mm.'),
          Text('NC export is disabled pending machine validation.'),
        ],
      ),
    );
  }
}
