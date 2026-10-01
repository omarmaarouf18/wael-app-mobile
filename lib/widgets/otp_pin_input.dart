import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Keeps only digits, maps Arabic-Indic (U+0660..0669) and Persian
/// (U+06F0..06F9) digits to ASCII, and truncates to [length]. An Arabic
/// keyboard therefore produces a code the backend accepts.
class OtpDigitsFormatter extends TextInputFormatter {
  const OtpDigitsFormatter(this.length);

  final int length;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (final r in newValue.text.runes) {
      if (r >= 0x30 && r <= 0x39) {
        buffer.writeCharCode(r);
      } else if (r >= 0x660 && r <= 0x669) {
        buffer.writeCharCode(r - 0x660 + 0x30);
      } else if (r >= 0x6F0 && r <= 0x6F9) {
        buffer.writeCharCode(r - 0x6F0 + 0x30);
      }
    }
    var text = buffer.toString();
    if (text.length > length) text = text.substring(0, length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// One box per digit, backed by a single invisible text field so paste, SMS
/// autofill (`oneTimeCode`) and backspace behave natively. The boxes are
/// always laid out left to right, also in Arabic: a code is read as digits.
class OtpPinInput extends StatefulWidget {
  const OtpPinInput({
    super.key,
    this.length = 6,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
    this.autofocus = false,
    this.enabled = true,
    this.hasError = false,
  });

  final int length;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  /// Called once the last digit is entered.
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final bool enabled;
  final bool hasError;

  @override
  State<OtpPinInput> createState() => _OtpPinInputState();
}

class _OtpPinInputState extends State<OtpPinInput> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  Color _borderFor(int index, String code) {
    if (widget.hasError) return AppColors.danger;
    final current = code.length < widget.length
        ? code.length
        : widget.length - 1;
    if (_focusNode.hasFocus && index == current) return AppColors.crimson;
    return AppColors.prominentBorder;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = _controller.text;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        label: l10n.verificationCode,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                widget.length * 56.0 + (widget.length - 1) * AppSpacing.spaceSm,
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.spaceSm),
                    Expanded(
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppRadius.radiusLg,
                          border: Border.all(
                            color: _borderFor(i, code),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          i < code.length ? code[i] : '',
                          style: AppTypography.headlineMd(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [OtpDigitsFormatter(widget.length)],
                    autocorrect: false,
                    enableSuggestions: false,
                    enableInteractiveSelection: false,
                    showCursor: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: _onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
