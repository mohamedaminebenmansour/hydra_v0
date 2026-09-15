import 'package:flutter/material.dart';

/// A bold circular back button used on every detail / creation screen.
class BackButtonCircle extends StatelessWidget {
  const BackButtonCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.arrow_back, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
