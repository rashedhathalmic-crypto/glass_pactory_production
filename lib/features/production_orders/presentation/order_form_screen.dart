import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/default_materials.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/helpers/polygon_area_helper.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../core/helpers/validators.dart';
import '../../../models/enums/order_priority.dart';
import '../../../models/order_history_entry.dart';
import '../../../models/enums/history_action.dart';
import '../../../models/order_material.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/production_order_provider.dart';
import '../../../core/helpers/picked_file.dart';
import '../../../providers/workflow_provider.dart';
import '../../../utils/exceptions/exceptions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../utils/extensions/extensions.dart';
import '../../../widgets/widgets.dart';
import 'widgets/order_materials_editor.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _projectController = TextEditingController();
  final _glassTypeController = TextEditingController();
  final _drawingNumberController = TextEditingController();
  final _thicknessController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _sideLengthControllers = [];

  OrderPriority _priority = OrderPriority.normal;
  DateTime? _dueDate;
  int _polygonSides = 4;
  List<OrderMaterial> _materials = DefaultMaterials.initialList();
  PickedFile? _pdfFile;
  PickedFile? _dxfFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resetSideLengthControllers();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _projectController.dispose();
    _glassTypeController.dispose();
    _drawingNumberController.dispose();
    _thicknessController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    for (final controller in _sideLengthControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetSideLengthControllers() {
    for (final controller in _sideLengthControllers) {
      controller.dispose();
    }
    _sideLengthControllers
      ..clear()
      ..addAll(
        List.generate(_polygonSides, (_) => TextEditingController()),
      );
  }

  double get _calculatedAreaSqM {
    final lengths = _sideLengthControllers
        .map((c) => double.tryParse(c.text) ?? 0)
        .toList();
    return PolygonAreaHelper.calculateAreaSqM(
      sides: _polygonSides,
      sideLengthsMm: lengths,
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _pickPdf() async {
    final files = await pickFiles(extensions: const ['pdf']);
    if (files.isEmpty) return;
    if (mounted) setState(() => _pdfFile = files.first);
  }

  Future<void> _pickDxf() async {
    final files = await pickFiles(extensions: const ['dxf']);
    if (files.isEmpty) return;
    if (mounted) setState(() => _dxfFile = files.first);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final sideLengths = _sideLengthControllers
          .map((c) => double.tryParse(c.text) ?? 0)
          .toList();

      final repo = ref.read(productionOrderRepositoryProvider);
      var order = await repo.createOrder(
        customerName: _customerController.text,
        projectName: _projectController.text,
        glassType: _glassTypeController.text,
        drawingNumber: _drawingNumberController.text,
        thicknessMm: double.parse(_thicknessController.text),
        quantity: int.parse(_quantityController.text),
        polygonSides: _polygonSides,
        polygonSideLengthsMm: sideLengths,
        createdBy: user.uid,
        description: _descriptionController.text,
        priority: _priority,
        dueDate: _dueDate,
        materials: _materials,
      );

      final workflow = ref.read(workflowServiceProvider);
      if (_pdfFile != null) {
        await workflow.uploadOrderDocument(
          order: order,
          performer: user,
          file: _pdfFile!,
          documentType: 'pdf',
        );
      }
      if (_dxfFile != null) {
        order = await repo.getOrder(order.id) ?? order;
        await workflow.uploadOrderDocument(
          order: order,
          performer: user,
          file: _dxfFile!,
          documentType: 'dxf',
        );
      }

      await ref.read(historyServiceProvider).logEntry(
            OrderHistoryEntry(
              id: '',
              orderId: order.id,
              action: HistoryAction.created,
              performedBy: user.uid,
              performedByName: user.displayName,
              notes: 'Production order ${order.orderNumber} created',
              timestamp: DateTime.now(),
            ),
          );

      if (mounted) {
        context.showAppSnackBar('Order ${order.orderNumber} created');
        context.pop();
      }
    } on AppException catch (e) {
      if (mounted) context.showAppSnackBar(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Production Order'),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    title: 'Order Details',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _customerController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                          ),
                          validator: (v) => Validators.required(
                            v,
                            fieldName: 'Customer name',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _projectController,
                          decoration: const InputDecoration(
                            labelText: 'Project Name',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _glassTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Glass Type',
                          ),
                          validator: (v) =>
                              Validators.required(v, fieldName: 'Glass type'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _drawingNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Drawing Number',
                          ),
                          validator: (v) => Validators.required(
                            v,
                            fieldName: 'Drawing number',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _thicknessController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Thickness (mm)',
                                ),
                                validator: (v) => Validators.positiveDouble(
                                  v,
                                  fieldName: 'Thickness',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                ),
                                validator: Validators.positiveInt,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                isExpanded: true,
                                initialValue: _polygonSides,
                                decoration: const InputDecoration(
                                  labelText: 'Polygon Sides',
                                ),
                                items: List.generate(10, (i) => i + 3)
                                    .map(
                                      (sides) => DropdownMenuItem(
                                        value: sides,
                                        child: Text('$sides sides'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _polygonSides = value;
                                          _resetSideLengthControllers();
                                        });
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Calculated Area',
                                ),
                                child: Text(
                                  '${_calculatedAreaSqM.toStringAsFixed(2)} m²',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < _sideLengthControllers.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: _sideLengthControllers[i],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Side ${i + 1} Length (mm)',
                              ),
                              validator: (v) => Validators.positiveDouble(
                                v,
                                fieldName: 'Side ${i + 1} length',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (ResponsiveHelper.isMobile(context))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _pickPdf,
                                icon: const Icon(AppIcons.upload, size: 18),
                                label: Text(
                                  _pdfFile == null
                                      ? 'Upload PDF'
                                      : _pdfFile!.fileName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _pickDxf,
                                icon: const Icon(AppIcons.upload, size: 18),
                                label: Text(
                                  _dxfFile == null
                                      ? 'Upload DXF'
                                      : _dxfFile!.fileName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _pickPdf,
                                  icon: const Icon(AppIcons.upload, size: 18),
                                  label: Text(
                                    _pdfFile == null
                                        ? 'Upload PDF'
                                        : _pdfFile!.fileName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _pickDxf,
                                  icon: const Icon(AppIcons.upload, size: 18),
                                  label: Text(
                                    _dxfFile == null
                                        ? 'Upload DXF'
                                        : _dxfFile!.fileName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<OrderPriority>(
                          isExpanded: true,
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                          ),
                          items: OrderPriority.values
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.label),
                                ),
                              )
                              .toList(),
                          onChanged: _isLoading
                              ? null
                              : (v) => setState(() => _priority = v!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description / Notes',
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _pickDueDate,
                          icon: const Icon(AppIcons.calendar, size: 18),
                          label: Text(
                            _dueDate == null
                                ? 'Set Due Date'
                                : 'Due: ${_dueDate!.toLocal().toString().split(' ').first}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    title: 'Materials',
                    child: OrderMaterialsEditor(
                      materials: _materials,
                      onChanged: (materials) =>
                          setState(() => _materials = materials),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Order'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
