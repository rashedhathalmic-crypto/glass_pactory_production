part of 'image_to_dxf_screen.dart';

extension _ImageToDxfEditor on _ImageToDxfScreenState {
  Widget _valueEditor() {
    final analysis = _analysis!;
    final width = analysis.sourceImageWidth;
    final height = analysis.sourceImageHeight;
    final aspectRatio = width > 0 && height > 0 ? width / height : 1.4;
    final adding = _manualMode != _ManualValueMode.none;
    final linearCount = _readings.where((reading) => reading.isLinear).length;
    final angleCount = _readings.where((reading) => reading.isAngle).length;
    final chamferCount = _readings.where((reading) => reading.isChamfer).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'أبعاد: $linearCount • زوايا: $angleCount • شنفر: $chamferCount',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            _modeButton(
              mode: _ManualValueMode.horizontal,
              icon: Icons.swap_horiz,
              label: 'إضافة بُعد أفقي',
            ),
            _modeButton(
              mode: _ManualValueMode.vertical,
              icon: Icons.swap_vert,
              label: 'إضافة بُعد رأسي',
            ),
            _modeButton(
              mode: _ManualValueMode.angle,
              icon: Icons.change_history_outlined,
              label: 'إضافة زاوية °',
            ),
            _modeButton(
              mode: _ManualValueMode.chamfer,
              icon: Icons.cut,
              label: 'إضافة شنفر mm',
            ),
            if (adding)
              Text(
                _manualInstruction(),
                style: const TextStyle(
                  color: AppColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'اضغط الزر ثم اضغط مكان القيمة أو الركن داخل الرسم. الزاوية تغيّر شكل الركن، والشنفر يقطع الركن بالقيمة المدخلة على الضلعين.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: adding
                            ? (details) => _addManualValue(details, constraints)
                            : null,
                        child: Image.memory(
                          _previewBytes!,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                      ...List<Widget>.generate(
                        math.min(_readings.length, _valueControllers.length),
                        (index) => _valueField(
                          index,
                          _readings[index],
                          _valueControllers[index],
                          constraints,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeButton({
    required _ManualValueMode mode,
    required IconData icon,
    required String label,
  }) {
    final selected = _manualMode == mode;
    return OutlinedButton.icon(
      onPressed: () => _setManualMode(mode),
      icon: Icon(icon),
      label: Text(label),
      style: selected
          ? OutlinedButton.styleFrom(
              backgroundColor: AppColors.darkBlue.withValues(alpha: .09),
            )
          : null,
    );
  }

  String _manualInstruction() {
    return switch (_manualMode) {
      _ManualValueMode.angle => 'اضغط على الركن الذي تريد تحديد زاويته.',
      _ManualValueMode.chamfer => 'اضغط على الركن الذي تريد إضافة الشنفر له.',
      _ => 'اضغط على مكان رقم البُعد داخل الرسم.',
    };
  }

  Widget _valueField(
    int index,
    ImageDimensionReading reading,
    TextEditingController controller,
    BoxConstraints constraints,
  ) {
    final vertical = reading.isLinear && reading.vertical;
    final editorWidth = vertical ? 48.0 : 118.0;
    final editorHeight = vertical ? 118.0 : 48.0;
    final left = (reading.x * constraints.maxWidth - editorWidth / 2)
        .clamp(0.0, math.max(0.0, constraints.maxWidth - editorWidth))
        .toDouble();
    final top = (reading.y * constraints.maxHeight - editorHeight / 2)
        .clamp(0.0, math.max(0.0, constraints.maxHeight - editorHeight))
        .toDouble();

    final fill = reading.isAngle
        ? const Color(0xFFFFF7ED)
        : reading.isChamfer
            ? const Color(0xFFF0FDF4)
            : Colors.white;
    final suffix = reading.isAngle ? '°' : 'mm';
    final hint = reading.isAngle
        ? 'الزاوية'
        : reading.isChamfer
            ? 'الشنفر'
            : 'القيمة';

    Widget field = SizedBox(
      width: 110,
      height: 42,
      child: TextField(
        controller: controller,
        autofocus: controller.text.isEmpty,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          suffixText: suffix,
          hintText: hint,
          fillColor: fill.withValues(alpha: .97),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          border: const OutlineInputBorder(),
        ),
      ),
    );
    if (vertical) field = RotatedBox(quarterTurns: 3, child: field);

    return Positioned(
      left: left,
      top: top,
      width: editorWidth,
      height: editorHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Center(child: field)),
          Positioned(
            top: -5,
            right: -5,
            child: Material(
              color: AppColors.error,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _removeValue(index),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
