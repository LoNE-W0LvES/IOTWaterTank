import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'wave_painter.dart';

/// Circular water level indicator with animated wave effect
class CircularWaterLevel extends StatefulWidget {
  final double percentage; // 0.0 to 100.0
  final double size;
  final bool isDarkMode;

  const CircularWaterLevel({
    Key? key,
    required this.percentage,
    this.size = 280,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<CircularWaterLevel> createState() => _CircularWaterLevelState();
}

class _CircularWaterLevelState extends State<CircularWaterLevel>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize wave animation
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_waveController);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Theme-aware colors
    final primaryColor = colorScheme.primary;
    final surfaceColor = widget.isDarkMode
        ? const Color(0xFF1F2937) // dark gray-800
        : const Color(0xFFF9FAFB); // light gray-50
    final borderColor = widget.isDarkMode
        ? const Color(0xFF374151) // dark gray-700
        : const Color(0xFFE5E7EB); // light gray-200

    // Clamp percentage between 0 and 100
    final displayPercentage = widget.percentage.clamp(0.0, 100.0);
    final waterLevel = displayPercentage / 100.0;

    // Add extra space for glow effect (blurRadius + spreadRadius needs room)
    final containerSize = widget.size + 100; // Extra 100px for full glow visibility

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none, // Allow glow to extend beyond bounds
        children: [
          // Outer glow effect (only for dark mode)
          if (widget.isDarkMode)
            Container(
              width: widget.size + 20,
              height: widget.size + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),

          // Main circle with border
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 4,
              ),
              color: surfaceColor,
            ),
          ),

          // Circular progress indicator
          SizedBox(
            width: widget.size - 8,
            height: widget.size - 8,
            child: CircularProgressIndicator(
              value: waterLevel,
              strokeWidth: 8,
              backgroundColor: borderColor.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),

          // Water with wave animation (clipped to circle)
          ClipOval(
            child: SizedBox(
              width: widget.size - 16,
              height: widget.size - 16,
              child: AnimatedBuilder(
                animation: _waveAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavePainter(
                      animationValue: _waveAnimation.value,
                      waterLevel: waterLevel,
                      waveColor: primaryColor.withOpacity(0.4),
                      backgroundColor: Colors.transparent,
                      isDarkMode: widget.isDarkMode,
                    ),
                  );
                },
              ),
            ),
          ),

          // Center text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Percentage
              Text(
                '${displayPercentage.toInt()}%',
                style: textTheme.displayLarge?.copyWith(
                  fontSize: widget.size * 0.22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  shadows: widget.isDarkMode
                      ? [
                          Shadow(
                            color: primaryColor.withOpacity(0.5),
                            blurRadius: 20,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                'CURRENT LEVEL',
                style: textTheme.labelLarge?.copyWith(
                  fontSize: widget.size * 0.04,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
