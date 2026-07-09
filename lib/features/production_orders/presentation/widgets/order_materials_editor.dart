import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/helpers/responsive_helper.dart';
import '../../../../models/order_material.dart';

class OrderMaterialsEditor extends StatefulWidget {
  const OrderMaterialsEditor({
    super.key,
    required this.materials,
    required this.onChanged,
    this.readOnly = false,
  });

  final List<OrderMaterial> materials;
  final ValueChanged<List<OrderMaterial>> onChanged;
  final bool readOnly;

  @override
  State<OrderMaterialsEditor> createState() => _OrderMaterialsEditorState();
}

class _OrderMaterialsEditorState extends State<OrderMaterialsEditor> {
  late List<OrderMaterial> _materials;

  @override
  void initState() {
    super.initState();
    _materials = List<OrderMaterial>.from(widget.materials);
  }

  @override
  void didUpdateWidget(covariant OrderMaterialsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.materials != widget.materials) {
      _materials = List<OrderMaterial>.from(widget.materials);
    }
  }

  void _notify() => widget.onChanged(_materials);

  void _updateMaterial(int index, OrderMaterial material) {
    setState(() => _materials[index] = material);
    _notify();
  }

  void _addMaterial() {
    setState(
      () => _materials.add(
        const OrderMaterial(name: '', quantity: 0, unit: 'pcs'),
      ),
    );
    _notify();
  }

  void _removeMaterial(int index) {
    if (_materials[index].isDefault) return;
    setState(() => _materials.removeAt(index));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveHelper.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _materials.length; i++) ...[
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: _materials[i].name,
                  readOnly: widget.readOnly || _materials[i].isDefault,
                  decoration: const InputDecoration(labelText: 'Material Name'),
                  onChanged: (value) => _updateMaterial(
                    i,
                    _materials[i].copyWith(name: value),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _materials[i].quantity > 0
                            ? '${_materials[i].quantity}'
                            : '',
                        readOnly: widget.readOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration:
                            const InputDecoration(labelText: 'Quantity'),
                        onChanged: (value) => _updateMaterial(
                          i,
                          _materials[i].copyWith(
                            quantity: double.tryParse(value) ?? 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: _materials[i].unit,
                        readOnly: widget.readOnly,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        onChanged: (value) => _updateMaterial(
                          i,
                          _materials[i].copyWith(unit: value),
                        ),
                      ),
                    ),
                    if (!widget.readOnly && !_materials[i].isDefault)
                      IconButton(
                        onPressed: () => _removeMaterial(i),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                  ],
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: _materials[i].name,
                    readOnly: widget.readOnly || _materials[i].isDefault,
                    decoration:
                        const InputDecoration(labelText: 'Material Name'),
                    onChanged: (value) => _updateMaterial(
                      i,
                      _materials[i].copyWith(name: value),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: _materials[i].quantity > 0
                        ? '${_materials[i].quantity}'
                        : '',
                    readOnly: widget.readOnly,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'),
                      ),
                    ],
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    onChanged: (value) => _updateMaterial(
                      i,
                      _materials[i].copyWith(
                        quantity: double.tryParse(value) ?? 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: _materials[i].unit,
                    readOnly: widget.readOnly,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    onChanged: (value) => _updateMaterial(
                      i,
                      _materials[i].copyWith(unit: value),
                    ),
                  ),
                ),
                if (!widget.readOnly && !_materials[i].isDefault)
                  IconButton(
                    onPressed: () => _removeMaterial(i),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
          const SizedBox(height: 12),
        ],
        if (!widget.readOnly)
          OutlinedButton.icon(
            onPressed: _addMaterial,
            icon: const Icon(Icons.add),
            label: const Text('Add Material'),
          ),
      ],
    );
  }
}
