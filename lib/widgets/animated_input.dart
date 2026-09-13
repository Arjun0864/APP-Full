import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'dart:ui';

class AnimatedInput extends StatefulWidget {
  final String hint;
  final String? label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final TextCapitalization textCapitalization;

  const AnimatedInput({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AnimatedInput> createState() => _AnimatedInputState();
}

class _AnimatedInputState extends State<AnimatedInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<Color?> _borderColorAnimation;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _hasText = widget.controller?.text.isNotEmpty ?? false;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _borderColorAnimation = ColorTween(
      begin: AppColors.cardBorder,
      end: AppColors.primary,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _isFocused = _focusNode.hasFocus);
      if (_focusNode.hasFocus) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });

    widget.controller?.addListener(() {
      if (!mounted) return;
      final hasText = widget.controller!.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                          alpha: 0.25 * _glowAnimation.value),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _borderColorAnimation.value ?? AppColors.cardBorder,
                    width: _isFocused ? 1.5 : 1,
                  ),
                ),
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  maxLines: widget.obscureText ? 1 : widget.maxLines,
                  minLines: 1,
                  validator: widget.validator,
                  onChanged: (v) {
                    widget.onChanged?.call(v);
                    if (!mounted) return;
                    setState(() => _hasText = v.isNotEmpty);
                  },
                  textInputAction: widget.textInputAction,
                  onFieldSubmitted: widget.onFieldSubmitted,
                  textCapitalization: widget.textCapitalization,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: (_isFocused || _hasText) ? null : widget.hint,
                    labelText: widget.label ?? widget.hint,
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    labelStyle: TextStyle(
                      color: _isFocused
                          ? AppColors.primaryLight
                          : AppColors.textMuted,
                      fontSize: _isFocused || _hasText ? 12 : 14,
                    ),
                    floatingLabelStyle: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: widget.suffixIcon,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(
                      widget.prefixIcon != null ? 4 : 16,
                      widget.maxLines > 1 ? 16 : 18,
                      widget.suffixIcon != null ? 4 : 16,
                      widget.maxLines > 1 ? 16 : 14,
                    ),
                    isDense: false,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
