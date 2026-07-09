import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/enums/department.dart';
import 'assembly_autoclave_department_illustration.dart';
import 'finished_delivery_department_illustration.dart';
import 'glass_processing_department_illustration.dart';
import 'grinding_washing_department_illustration.dart';
import 'quality_department_illustration.dart';

/// Renders the correct industrial illustration for each department.
class DepartmentIllustration extends StatelessWidget {
  const DepartmentIllustration({
    super.key,
    required this.department,
    this.height = GlassProcessingDepartmentIllustration.preferredHeight,
  });

  final Department department;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: switch (department) {
        Department.glassProcessing =>
          const GlassProcessingDepartmentIllustration(),
        Department.grindingWashing =>
          const GrindingWashingDepartmentIllustration(),
        Department.assemblyAutoclave =>
          const AssemblyAutoclaveDepartmentIllustration(),
        Department.quality => const QualityDepartmentIllustration(),
        Department.finishedDelivery =>
          const FinishedDeliveryDepartmentIllustration(),
      },
    );
  }
}

/// Hero illustration for department detail headers.
class DepartmentHeroIllustration extends StatelessWidget {
  const DepartmentHeroIllustration({super.key, required this.department});

  final Department department;

  static const double height =
      GlassProcessingDepartmentIllustration.preferredHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: DepartmentIllustration(department: department, height: height),
    );
  }
}

/// Compact illustration for department cards.
class DepartmentCardIllustration extends StatelessWidget {
  const DepartmentCardIllustration({super.key, required this.department});

  final Department department;

  static const double height = 100;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: DepartmentIllustration(department: department, height: height),
    );
  }
}
