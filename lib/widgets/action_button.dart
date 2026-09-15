import 'package:flutter/material.dart';

/// A single giant, full-width action button: an 80px icon centered in the
/// surface and the label pinned to the very bottom edge, with a soft drop
/// shadow so the button reads as a physical, tactile key.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The margin creates the seam that lets the drop shadow show between
      // the three stacked buttons (flush siblings would hide each other's).
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            // Icon stays in the true geometric center; the label is pinned to
            // the bottom edge, near the border.
            fit: StackFit.expand,
            children: [
              Center(child: Icon(icon, size: 80, color: iconColor)),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: iconColor,
                    ),
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
