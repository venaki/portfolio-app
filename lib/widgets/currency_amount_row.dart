import 'package:flutter/material.dart';

/// Keep the original baseline alignment when both amounts fit; wrap only when
/// the available width cannot show the complete numbers on one line.
class CurrencyAmountRow extends StatelessWidget {
  const CurrencyAmountRow({
    super.key,
    required this.primary,
    required this.secondary,
    required this.primaryStyle,
    required this.secondaryStyle,
    required this.spacing,
  });
  final String primary, secondary;
  final TextStyle primaryStyle, secondaryStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      double width(String value, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(
            text: value,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final measured = painter.width;
        painter.dispose();
        return measured;
      }

      final primaryWidth = width(primary, primaryStyle);
      final secondaryWidth = width(secondary, secondaryStyle);
      final primaryText = Text(primary, style: primaryStyle);
      final secondaryText = Text(secondary, style: secondaryStyle);
      if (primaryWidth + secondaryWidth + spacing <= constraints.maxWidth) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            primaryText,
            SizedBox(width: spacing),
            secondaryText,
          ],
        );
      }
      Widget fit(Widget text, double measured) =>
          measured <= constraints.maxWidth
          ? text
          : SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: text,
              ),
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fit(primaryText, primaryWidth),
          const SizedBox(height: 4),
          fit(secondaryText, secondaryWidth),
        ],
      );
    },
  );
}
