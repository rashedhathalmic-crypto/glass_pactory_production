import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/helpers/open_url_helper.dart';
import '../../../../core/helpers/image_picker_helper.dart';
import '../../../../core/helpers/responsive_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../models/department_workflow_data.dart';
import '../../../../models/app_user.dart';
import '../../../../models/enums/delivery_status.dart';
import '../../../../models/enums/department.dart';
import '../../../../models/enums/inspection_status.dart';
import '../../../../models/enums/order_status.dart';
import '../../../../models/production_order.dart';
import '../../../../providers/workflow_provider.dart';
import '../../../../utils/exceptions/exceptions.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_context.dart';
import '../../../../utils/extensions/extensions.dart';
import '../../../../widgets/widgets.dart';
import 'label_print_dialog.dart';

class DepartmentWorkflowPanel extends ConsumerStatefulWidget {
  const DepartmentWorkflowPanel({
    super.key,
    required this.order,
    required this.user,
  });

  final ProductionOrder order;
  final AppUser user;

  @override
  ConsumerState<DepartmentWorkflowPanel> createState() =>
      _DepartmentWorkflowPanelState();
}

class _DepartmentWorkflowPanelState
    extends ConsumerState<DepartmentWorkflowPanel> {
  late final TextEditingController _inputQtyController;
  late final TextEditingController _passQtyController;
  late final TextEditingController _rejectQtyController;
  late final TextEditingController _rejectReasonController;
  late final TextEditingController _signatureController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final workflow = widget.order.workflowFor(widget.order.currentDepartment);
    _inputQtyController = TextEditingController(
      text: workflow.inputQty > 0 ? '${workflow.inputQty}' : '',
    );
    _passQtyController = TextEditingController(
      text: workflow.passQty > 0 ? '${workflow.passQty}' : '',
    );
    _rejectQtyController = TextEditingController(
      text: workflow.rejectQty > 0 ? '${workflow.rejectQty}' : '',
    );
    _rejectReasonController = TextEditingController(
      text: workflow.rejectReasons.join(', '),
    );
    _signatureController = TextEditingController(
      text: workflow.digitalSignature,
    );
    _notesController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant DepartmentWorkflowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.currentDepartment != widget.order.currentDepartment) {
      final workflow = widget.order.workflowFor(widget.order.currentDepartment);
      _inputQtyController.text =
          workflow.inputQty > 0 ? '${workflow.inputQty}' : '';
      _passQtyController.text =
          workflow.passQty > 0 ? '${workflow.passQty}' : '';
      _rejectQtyController.text =
          workflow.rejectQty > 0 ? '${workflow.rejectQty}' : '';
      _rejectReasonController.text = workflow.rejectReasons.join(', ');
      _signatureController.text = workflow.digitalSignature;
    }
  }

  @override
  void dispose() {
    _inputQtyController.dispose();
    _passQtyController.dispose();
    _rejectQtyController.dispose();
    _rejectReasonController.dispose();
    _signatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final user = widget.user;
    final dept = order.currentDepartment;
    final workflow = order.workflowFor(dept);
    final ctx = PermissionContext(order: order, department: dept);
    final canManageProduction = user.hasPermission(
      AppPermission.stopResumeOrders,
      context: ctx,
    );
    final isTerminal =
        order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled;

    if (isTerminal && dept != Department.finishedDelivery) {
      return const SizedBox.shrink();
    }

    return AppCard(
      title: '${dept.label} Workflow',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusBanner(order: order, workflow: workflow),
          const SizedBox(height: 16),
          if (!isTerminal) ...[
            _buildWorkControls(order, workflow),
            const SizedBox(height: 16),
            if (dept == Department.glassProcessing)
              _buildDrawingLinks(order),
            if (dept == Department.glassProcessing &&
                (order.pdfUrl.isNotEmpty || order.dxfUrl.isNotEmpty))
              const SizedBox(height: 16),
            _buildNotesSection(order),
            const SizedBox(height: 16),
            if (_hasQuantityFields(dept)) ...[
              _buildQuantitySection(dept),
              const SizedBox(height: 16),
            ],
            if (dept == Department.assemblyAutoclave) ...[
              _buildAssemblySection(order, workflow),
              const SizedBox(height: 16),
            ],
            if (dept == Department.quality) ...[
              _buildQualitySection(order, workflow),
              const SizedBox(height: 16),
            ],
            if (dept == Department.finishedDelivery)
              _buildFinishedSection(order, workflow),
          ] else
            _buildCompletedFinishedSection(order, workflow),
          if (canManageProduction && !isTerminal) ...[
            const Divider(height: 32),
            _buildManagementActions(order),
          ],
          if (order.reworkOrderIds.isNotEmpty) ...[
            const Divider(height: 32),
            _buildReworkLinks(order),
          ],
        ],
      ),
    );
  }

  bool _hasQuantityFields(Department dept) {
    return dept == Department.assemblyAutoclave ||
        dept == Department.quality;
  }

  Widget _buildStatusBanner({
    required ProductionOrder order,
    required DepartmentWorkflowData workflow,
  }) {
    final dept = order.currentDepartment;
    String statusText;
    StatusTone tone;

    if (order.status == OrderStatus.onHold) {
      statusText = 'Order On Hold';
      tone = StatusTone.warning;
    } else if (workflow.paused) {
      statusText = 'Work Paused';
      tone = StatusTone.warning;
    } else if (workflow.workStarted) {
      statusText = 'Work In Progress';
      tone = StatusTone.info;
    } else {
      statusText = 'Not Started';
      tone = StatusTone.neutral;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusChip(label: statusText, tone: tone),
        if (dept == Department.finishedDelivery)
          StatusChip(
            label: workflow.deliveryStatus.label,
            tone: StatusTone.info,
          ),
        if (order.orderType.name == 'rework')
          const StatusChip(label: 'Rework', tone: StatusTone.warning),
      ],
    );
  }

  Widget _buildWorkControls(
    ProductionOrder order,
    DepartmentWorkflowData workflow,
  ) {
    final workflowService = ref.read(workflowServiceProvider);
    final dept = order.currentDepartment;
    final needsStartWork = dept != Department.finishedDelivery;
    final ctx = PermissionContext(order: order, department: dept);
    final canStart =
        widget.user.hasPermission(AppPermission.startWork, context: ctx);
    final canPause =
        widget.user.hasPermission(AppPermission.pauseWork, context: ctx);
    final canResume =
        widget.user.hasPermission(AppPermission.resumeWork, context: ctx);
    final canTransfer =
        widget.user.hasPermission(AppPermission.transferOrders, context: ctx);
    final canSaveProgress = dept == Department.quality
        ? widget.user.hasPermission(
            AppPermission.passRejectInspection,
            context: ctx,
          )
        : widget.user.hasPermission(
            AppPermission.finishDepartment,
            context: ctx,
          );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (needsStartWork && !workflow.workStarted && canStart)
          ElevatedButton.icon(
            onPressed: () => _run(() => workflowService.startWork(
                  order: order,
                  performer: widget.user,
                )),
            icon: const Icon(AppIcons.play, size: 18),
            label: const Text('Start Work'),
          ),
        if (needsStartWork && workflow.workStarted && !workflow.paused && canPause)
          OutlinedButton.icon(
            onPressed: () => _run(() => workflowService.pauseWork(
                  order: order,
                  performer: widget.user,
                )),
            icon: const Icon(AppIcons.pause, size: 18),
            label: const Text('Pause'),
          ),
        if (needsStartWork && workflow.paused && canResume)
          ElevatedButton.icon(
            onPressed: () => _run(() => workflowService.resumeWork(
                  order: order,
                  performer: widget.user,
                )),
            icon: const Icon(AppIcons.play, size: 18),
            label: const Text('Resume'),
          ),
        if (_hasQuantityFields(dept) && workflow.workStarted && !workflow.paused && canSaveProgress)
          OutlinedButton.icon(
            onPressed: () => _saveProgress(order),
            icon: const Icon(AppIcons.save, size: 18),
            label: Text(
              dept == Department.quality ? 'Save Inspection' : 'Save Progress',
            ),
          ),
        if (dept != Department.finishedDelivery &&
            workflow.workStarted &&
            !workflow.paused &&
            canTransfer)
          ElevatedButton.icon(
            onPressed: () => _transfer(order),
            icon: const Icon(AppIcons.arrowForward, size: 18),
            label: Text(_transferLabel(dept)),
          ),
      ],
    );
  }

  String _transferLabel(Department dept) {
    return switch (dept) {
      Department.glassProcessing => 'Transfer to Grinding & Washing',
      Department.grindingWashing => 'Transfer to Assembly & Autoclave',
      Department.assemblyAutoclave => 'Transfer to Quality',
      Department.quality => 'Transfer to Finished & Delivery',
      Department.finishedDelivery => 'Finish Order',
    };
  }

  Widget _buildDrawingLinks(ProductionOrder order) {
    if (order.pdfUrl.isEmpty && order.dxfUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (order.pdfUrl.isNotEmpty)
          TextButton.icon(
            onPressed: () => openExternalUrl(order.pdfUrl),
            icon: const Icon(AppIcons.download, size: 18),
            label: const Text('Open PDF Drawing'),
          ),
        if (order.dxfUrl.isNotEmpty)
          TextButton.icon(
            onPressed: () => openExternalUrl(order.dxfUrl),
            icon: const Icon(AppIcons.download, size: 18),
            label: const Text('Open DXF Drawing'),
          ),
      ],
    );
  }

  Widget _buildNotesSection(ProductionOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Department Notes',
            hintText: 'Add notes for this department...',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: () {
              if (_notesController.text.trim().isEmpty) return;
              _run(() => ref.read(workflowServiceProvider).addDepartmentNotes(
                    order: order,
                    performer: widget.user,
                    notes: _notesController.text.trim(),
                  ));
              _notesController.clear();
            },
            child: const Text('Save Notes'),
          ),
        ),
        if (order.workflowFor(order.currentDepartment).notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            order.workflowFor(order.currentDepartment).notes,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantitySection(Department dept) {
    final isCompact = ResponsiveHelper.isMobile(context);

    Widget field({
      required TextEditingController controller,
      required String label,
    }) {
      return TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      );
    }

    final quantityFields = <Widget>[
      if (dept == Department.assemblyAutoclave)
        field(controller: _inputQtyController, label: 'Input Qty (Optional)'),
      field(
        controller: _passQtyController,
        label: dept == Department.assemblyAutoclave
            ? 'Pass Qty (Optional)'
            : 'Pass Qty',
      ),
      field(
        controller: _rejectQtyController,
        label: dept == Department.assemblyAutoclave
            ? 'Reject Qty (Optional)'
            : 'Reject Qty',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dept == Department.quality
              ? 'Final Inspection'
              : 'Production Quantities (Optional)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (isCompact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < quantityFields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                quantityFields[i],
              ],
            ],
          )
        else
          Row(
            children: [
              for (var i = 0; i < quantityFields.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: quantityFields[i]),
              ],
            ],
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _rejectReasonController,
          decoration: InputDecoration(
            labelText: dept == Department.assemblyAutoclave
                ? 'Reject Reasons (Optional)'
                : 'Reject Reasons',
            hintText: 'Comma-separated reasons',
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildAssemblySection(
    ProductionOrder order,
    DepartmentWorkflowData workflow,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inspection (Optional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Inspection, quantities, and photos are optional before transfer.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        if (order.inspectionStatus != InspectionStatus.notStarted)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: StatusChip(
              label: order.inspectionStatus.label,
              tone: order.inspectionStatus == InspectionStatus.passed
                  ? StatusTone.success
                  : order.inspectionStatus == InspectionStatus.failed
                      ? StatusTone.error
                      : StatusTone.warning,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (order.inspectionStatus == InspectionStatus.notStarted)
              OutlinedButton(
                onPressed: () => _run(() => ref
                    .read(workflowServiceProvider)
                    .startInspection(order: order, performer: widget.user)),
                child: const Text('Start Inspection'),
              ),
            if (order.inspectionStatus == InspectionStatus.pending) ...[
              ElevatedButton(
                onPressed: () => _run(() => ref
                    .read(workflowServiceProvider)
                    .completeInspection(
                      order: order,
                      performer: widget.user,
                      passed: true,
                    )),
                child: const Text('Pass Inspection'),
              ),
              OutlinedButton(
                onPressed: () => _showFailInspectionDialog(order),
                child: const Text('Fail Inspection'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: () => _uploadPhotos(order, isFinal: false),
              icon: const Icon(AppIcons.upload, size: 18),
              label: const Text('Upload Inspection Photos (Optional)'),
            ),
          ],
        ),
        if (workflow.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PhotoGallery(urls: workflow.photoUrls),
        ],
      ],
    );
  }

  Widget _buildQualitySection(
    ProductionOrder order,
    DepartmentWorkflowData workflow,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quality Approval',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _uploadPhotos(order, isFinal: true),
          icon: const Icon(AppIcons.upload, size: 18),
          label: const Text('Upload Final Photos'),
        ),
        if (workflow.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PhotoGallery(urls: workflow.photoUrls),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _signatureController,
          decoration: const InputDecoration(
            labelText: 'Digital Signature (Full Name)',
          ),
        ),
        const SizedBox(height: 8),
        if (workflow.approvedAt != null)
          Text(
            'Approved by ${workflow.approvedBy} on ${workflow.approvedAt}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: workflow.approvedAt != null
              ? null
              : () => _run(() => ref.read(workflowServiceProvider).approveQuality(
                    order: order,
                    performer: widget.user,
                    digitalSignature: _signatureController.text,
                  )),
          child: const Text('Quality Approval'),
        ),
      ],
    );
  }

  Widget _buildFinishedSection(
    ProductionOrder order,
    DepartmentWorkflowData workflow,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Finished & Delivery',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showLabelDialog(order, printQr: false),
              icon: const Icon(AppIcons.print, size: 18),
              label: const Text('Print Label'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showLabelDialog(order, printQr: true),
              icon: const Icon(AppIcons.qr, size: 18),
              label: const Text('Print QR'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<DeliveryStatus>(
          isExpanded: true,
          initialValue: workflow.deliveryStatus,
          decoration: const InputDecoration(labelText: 'Delivery Status'),
          items: DeliveryStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (status) {
            if (status == null) return;
            _run(() => ref.read(workflowServiceProvider).updateDeliveryStatus(
                  order: order,
                  performer: widget.user,
                  status: status,
                ));
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: workflow.customerConfirmed
              ? null
              : () => _run(() => ref
                  .read(workflowServiceProvider)
                  .confirmCustomerDelivery(
                    order: order,
                    performer: widget.user,
                  )),
          child: const Text('Customer Delivery Confirmation'),
        ),
        if (workflow.customerConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Confirmed at ${workflow.customerConfirmedAt}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.success,
              ),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: workflow.customerConfirmed
              ? () => _run(() => ref.read(workflowServiceProvider).finishOrder(
                    order: order,
                    performer: widget.user,
                  ))
              : null,
          icon: const Icon(AppIcons.check, size: 18),
          label: const Text('Finish Order'),
        ),
      ],
    );
  }

  Widget _buildCompletedFinishedSection(
    ProductionOrder order,
    DepartmentWorkflowData workflow,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Summary',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text('Status: ${workflow.deliveryStatus.label}'),
        Text('Customer Confirmed: ${workflow.customerConfirmed ? 'Yes' : 'No'}'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showLabelDialog(order, printQr: false),
              icon: const Icon(AppIcons.print, size: 18),
              label: const Text('Print Label'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showLabelDialog(order, printQr: true),
              icon: const Icon(AppIcons.qr, size: 18),
              label: const Text('Print QR'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManagementActions(ProductionOrder order) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (order.status == OrderStatus.inProgress)
          OutlinedButton(
            onPressed: () => _showHoldDialog(order),
            child: const Text('Place On Hold'),
          ),
        if (order.status == OrderStatus.onHold)
          ElevatedButton(
            onPressed: () => _run(() => ref
                .read(workflowServiceProvider)
                .resumeProduction(order: order, performer: widget.user)),
            child: const Text('Resume Production'),
          ),
        OutlinedButton(
          onPressed: () => _showCancelDialog(order),
          child: const Text('Cancel Order'),
        ),
      ],
    );
  }

  Widget _buildReworkLinks(ProductionOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rework Orders',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          '${order.reworkOrderIds.length} rework order(s) created',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _saveProgress(ProductionOrder order) async {
    final passQty = int.tryParse(_passQtyController.text) ?? 0;
    final rejectQty = int.tryParse(_rejectQtyController.text) ?? 0;
    final inputQty = order.currentDepartment == Department.assemblyAutoclave
        ? int.tryParse(_inputQtyController.text) ?? 0
        : passQty + rejectQty;
    final reasons = _rejectReasonController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    await _run(() => ref.read(workflowServiceProvider).saveProgress(
          order: order,
          performer: widget.user,
          inputQty: inputQty,
          passQty: passQty,
          rejectQty: rejectQty,
          rejectReasons: reasons,
        ));
  }

  Future<void> _transfer(ProductionOrder order) async {
    await _run(() => ref.read(workflowServiceProvider).transferToNextDepartment(
          order: order,
          performer: widget.user,
        ));
  }

  Future<void> _uploadPhotos(ProductionOrder order, {required bool isFinal}) async {
    final files = await pickImages();
    if (files.isEmpty) return;

    await _run(() => ref.read(workflowServiceProvider).uploadDepartmentPhotos(
          order: order,
          performer: widget.user,
          files: files
              .map(
                (f) => (
                  fileName: f.fileName,
                  bytes: f.bytes,
                  contentType: f.contentType,
                ),
              )
              .toList(),
          isFinalInspection: isFinal,
        ));
  }

  Future<void> _showLabelDialog(ProductionOrder order, {required bool printQr}) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => LabelPrintDialog(order: order, showQr: printQr),
    );
    if (!printQr) {
      await _run(() => ref.read(workflowServiceProvider).recordLabelPrinted(
            order: order,
            performer: widget.user,
          ));
    }
  }

  void _showFailInspectionDialog(ProductionOrder order) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fail Inspection'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _run(() => ref.read(workflowServiceProvider).completeInspection(
                    order: order,
                    performer: widget.user,
                    passed: false,
                    notes: notesController.text,
                  ));
            },
            child: const Text('Confirm Fail'),
          ),
        ],
      ),
    );
  }

  void _showHoldDialog(ProductionOrder order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place On Hold'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _run(() => ref.read(workflowServiceProvider).setOnHold(
                    order: order,
                    performer: widget.user,
                    reason: reasonController.text.trim(),
                  ));
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(ProductionOrder order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _run(() => ref.read(workflowServiceProvider).cancelOrder(
                    order: order,
                    performer: widget.user,
                    reason: reasonController.text.trim(),
                  ));
            },
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) context.showAppSnackBar('Action completed');
    } on AppException catch (e) {
      if (mounted) context.showAppSnackBar(e.message, isError: true);
    }
  }
}

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              urls[index],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 80,
                height: 80,
                color: AppColors.lightGray,
                child: const Icon(AppIcons.image),
              ),
            ),
          );
        },
      ),
    );
  }
}
