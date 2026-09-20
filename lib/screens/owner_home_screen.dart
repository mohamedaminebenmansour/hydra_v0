import 'package:flutter/material.dart';

import 'owner_map_screen.dart';
import 'owner_reports_list_screen.dart';

// ---------------------------------------------------------------------------
// The Owner's landing dashboard: "Site Command".
//
// The owner is a thin client over Supabase; this screen holds no data of its
// own - it is just the two giant doors into his tools: the site map and the
// reports list. Everything data-shaped lives behind those doors.
// ---------------------------------------------------------------------------

/// The Owner's landing screen: two giant buttons into the site map and the
/// reports list.
///
/// [onOpenMap] / [onOpenList] default to pushing the real screens; tests
/// inject recorders so navigation is assertable without building a live map.
class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key, this.onOpenMap, this.onOpenList});

  /// Opens the site map (defaults to pushing [OwnerMapScreen]).
  final VoidCallback? onOpenMap;

  /// Opens the reports list (defaults to pushing [OwnerReportsListScreen]).
  final VoidCallback? onOpenList;

  /// One giant door: a full-width solid button with a big icon and its label.
  Widget _door({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 104,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Site Command')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _door(
                label: 'VIEW SITE MAP',
                color: Colors.green,
                icon: Icons.map_outlined,
                onPressed:
                    onOpenMap ??
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OwnerMapScreen(),
                      ),
                    ),
              ),
              const SizedBox(height: 24),
              _door(
                label: 'VIEW REPORTS LIST',
                color: Colors.blue,
                icon: Icons.list_alt,
                onPressed:
                    onOpenList ??
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OwnerReportsListScreen(),
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
