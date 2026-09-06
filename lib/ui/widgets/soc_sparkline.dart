import 'package:flutter/material.dart';

/// Minimal SOC sparkline — no chart package, just a CustomPainter.
class SocSparkline extends StatelessWidget {
  const SocSparkline({super.key, required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox(
        height: 72,
        child: Center(child: Text('Not enough SOC history yet')),
      );
    }

    return SizedBox(
      height: 72,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          values: values,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 0.01 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
