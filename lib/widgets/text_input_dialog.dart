import 'package:flutter/material.dart';

import 'app_dialog.dart';

/// Hiển thị popup nhập văn bản theo cùng style với dialog xác nhận.
///
/// Trả về `null` khi người dùng hủy và trả về nội dung đã nhập khi xác nhận.
/// Mặc định kết quả được trim và không chấp nhận chuỗi rỗng.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? message,
  String? labelText,
  String? hintText,
  String confirmLabel = 'Lưu',
  String cancelLabel = 'Hủy',
  String emptyErrorText = 'Vui lòng nhập thông tin.',
  IconData icon = Icons.edit_outlined,
  int? maxLength,
  int minLines = 1,
  int? maxLines = 1,
  double maxWidth = 400,
  bool allowEmpty = false,
  bool trimResult = true,
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.sentences,
}) {
  assert(minLines > 0);
  assert(maxLines == null || maxLines >= minLines);

  final accentColor = Theme.of(context).colorScheme.primary;

  return showAppDialog<String>(
    context,
    builder: (dialogContext) => _TextInputDialogCard(
      title: title,
      initialValue: initialValue,
      message: message,
      labelText: labelText,
      hintText: hintText,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      emptyErrorText: emptyErrorText,
      icon: icon,
      accentColor: accentColor,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      maxWidth: maxWidth,
      allowEmpty: allowEmpty,
      trimResult: trimResult,
      keyboardType:
          keyboardType ??
          (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
      textCapitalization: textCapitalization,
    ),
  );
}

class _TextInputDialogCard extends StatefulWidget {
  const _TextInputDialogCard({
    required this.title,
    required this.initialValue,
    required this.message,
    required this.labelText,
    required this.hintText,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.emptyErrorText,
    required this.icon,
    required this.accentColor,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
    required this.maxWidth,
    required this.allowEmpty,
    required this.trimResult,
    required this.keyboardType,
    required this.textCapitalization,
  });

  final String title;
  final String initialValue;
  final String? message;
  final String? labelText;
  final String? hintText;
  final String confirmLabel;
  final String cancelLabel;
  final String emptyErrorText;
  final IconData icon;
  final Color accentColor;
  final int? maxLength;
  final int minLines;
  final int? maxLines;
  final double maxWidth;
  final bool allowEmpty;
  final bool trimResult;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  @override
  State<_TextInputDialogCard> createState() => _TextInputDialogCardState();
}

class _TextInputDialogCardState extends State<_TextInputDialogCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final value = widget.trimResult
        ? _controller.text.trim()
        : _controller.text;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSingleLine = widget.maxLines == 1;

    return AppDialogCard(
      title: widget.title,
      icon: widget.icon,
      accentColor: widget.accentColor,
      maxWidth: widget.maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message != null) ...[
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
          ],
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              autofocus: true,
              maxLength: widget.maxLength,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              textInputAction: isSingleLine
                  ? TextInputAction.done
                  : TextInputAction.newline,
              onFieldSubmitted: isSingleLine ? (_) => _submit() : null,
              validator: (rawValue) {
                final value = widget.trimResult
                    ? (rawValue ?? '').trim()
                    : (rawValue ?? '');
                if (!widget.allowEmpty && value.isEmpty) {
                  return widget.emptyErrorText;
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                alignLabelWithHint: !isSingleLine,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: widget.accentColor, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppDialogActionButton(
            label: widget.confirmLabel,
            backgroundColor: widget.accentColor,
            onPressed: _submit,
          ),
          const SizedBox(height: 10),
          AppDialogActionButton(
            label: widget.cancelLabel,
            backgroundColor: appDialogCancelColor,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
