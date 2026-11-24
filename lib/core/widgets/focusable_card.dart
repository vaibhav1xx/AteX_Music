import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'frosted_glass.dart';

/// Focusable card widget optimized for Android TV D-Pad, Arrow keys, and mouse hover.
/// When focused, it displays a high-contrast electric cyan glow and 2px border.
class FocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool autofocus;
  final FocusNode? focusNode;

  const FocusableCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    final isHighlighted = _isFocused || _isHovered;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onShowHoverHighlight: (hovered) => setState(() => _isHovered = hovered),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? 1.025 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: FrostedGlass(
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            margin: widget.margin,
            borderRadius: radius,
            backgroundColor: isHighlighted
                ? AppColors.cardGlassHover
                : AppColors.cardGlass,
            borderColor: _isFocused
                ? AppColors.tvFocusBorder
                : (_isHovered ? AppColors.electricCyan.withAlpha(100) : AppColors.glassBorder),
            borderWidth: _isFocused ? 2.0 : 1.0,
            glow: _isFocused
                ? const BoxShadow(
                    color: AppColors.tvFocusGlow,
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
