import 'package:flutter/material.dart';

/// A reusable widget that paints a ruled notebook-style background
/// with a vertical margin line, adapting to the app theme.
class NotebookPaper extends StatelessWidget {
  final Widget child;
  final double lineThickness;
  final double marginOffset;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? lineColor;
  final Color? marginColor;
  // If provided, the painter will compute precise line height and baseline
  // from this text style to align horizontal rules exactly with text lines.
  final TextStyle? referenceTextStyle;
  // Optional override for MediaQuery.textScaleFactor when computing metrics.
  final double? textScaleFactor;
  // Manual fine adjustment in logical pixels if needed (+down / -up).
  final double baselineShift;
  // Fallback line height if no referenceTextStyle is given.
  final double fallbackLineHeight;

  const NotebookPaper({
    super.key,
    required this.child,
    this.lineThickness = 1,
    this.marginOffset = 56,
    this.padding,
    this.backgroundColor,
    this.lineColor,
    this.marginColor,
    this.referenceTextStyle,
    this.textScaleFactor,
    this.baselineShift = 0,
    this.fallbackLineHeight = 28,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surface;
    final lines = lineColor ?? theme.colorScheme.secondary.withOpacity(0.18);
    final margin = marginColor ?? theme.colorScheme.secondary.withOpacity(0.9);

    // Compute precise line height and baseline from text style if available
    final scale = textScaleFactor ?? MediaQuery.textScaleFactorOf(context);
    double lineHeight;
    double baseline;
    if (referenceTextStyle != null) {
      final tp = TextPainter(
        text: TextSpan(text: 'A', style: referenceTextStyle),
        textDirection: TextDirection.ltr,
        textScaleFactor: scale,
        maxLines: 1,
      )..layout();
      final metrics = tp.computeLineMetrics();
      if (metrics.isNotEmpty) {
        lineHeight = metrics.first.height;
        baseline = metrics.first.baseline;
      } else {
        lineHeight = tp.preferredLineHeight;
        baseline = lineHeight * 0.8; // reasonable fallback
      }
    } else {
      lineHeight = fallbackLineHeight;
      baseline = fallbackLineHeight * 0.8;
    }

    // Default padding leaves room for the margin line on the left
    final resolvedPadding = padding ?? EdgeInsets.fromLTRB(marginOffset + 16, 16, 16, 16);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: CustomPaint(
          painter: _NotebookPainter(
            lineHeight: lineHeight,
            firstLineY: (resolvedPadding as EdgeInsets).top + baseline + baselineShift,
            lineThickness: lineThickness,
            lineColor: lines,
            marginColor: margin,
            marginOffset: marginOffset,
          ),
          child: Padding(
            padding: resolvedPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NotebookPainter extends CustomPainter {
  final double lineHeight;
  final double firstLineY;
  final double lineThickness;
  final double marginOffset;
  final Color lineColor;
  final Color marginColor;

  _NotebookPainter({
    required this.lineHeight,
    required this.firstLineY,
    required this.lineThickness,
    required this.marginOffset,
    required this.lineColor,
    required this.marginColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineThickness;
    final marginPaint = Paint()
      ..color = marginColor
      ..strokeWidth = lineThickness * 1.4;

    // Horizontal ruled lines aligned to text baseline
    double y = firstLineY;
    while (y <= size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      y += lineHeight;
    }

    // Vertical margin line
    canvas.drawLine(Offset(marginOffset, 0), Offset(marginOffset, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant _NotebookPainter oldDelegate) {
    return oldDelegate.lineHeight != lineHeight ||
        oldDelegate.firstLineY != firstLineY ||
        oldDelegate.lineThickness != lineThickness ||
        oldDelegate.marginOffset != marginOffset ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.marginColor != marginColor;
  }
}
