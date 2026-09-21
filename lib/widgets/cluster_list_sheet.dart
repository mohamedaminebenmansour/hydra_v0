import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// The 'Cluster List' popup.
//
// When several reports share (almost) the same GPS coordinates they collapse
// into one cluster bubble, and the plugin's zoom-on-tick can never separate
// them. So cluster taps are handled manually: the map passes every child
// marker's report here, newest first, and this sheet lists them — the user
// picks one and the full report view opens.
// ---------------------------------------------------------------------------

/// Opens the Cluster List popup for a tapped map cluster.
///
/// [items] must already be sorted newest-first by the caller. [tileBuilder]
/// renders one row (thumbnail, type, timestamp, TL/Owner badges). Tapping a
/// row closes the sheet first and then runs [onItemTap] with the map screen's
/// own context, so the opened detail/decision sheet stacks on the map, not
/// inside this popup.
Future<void> showClusterListSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required Widget Function(BuildContext context, T item) tileBuilder,
  required Future<void> Function(T item) onItemTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _ClusterListSheet<T>(
      title: title,
      items: items,
      tileBuilder: tileBuilder,
      onItemTap: onItemTap,
    ),
  );
}

/// Tap handler for one Cluster List row: closes the popup, then opens the
/// item's full report view. [open] must not use [context] (it is the row's,
/// inside a popped route) — callers capture their own screen context.
Future<void> openClusterListItem(
  BuildContext context,
  Future<void> Function() open,
) async {
  Navigator.of(context).pop();
  await open();
}

/// The 50%-height popup itself: handle, title, then a scrollable list of the
/// cluster's reports. [mainAxisSize.min] + [Expanded] keep the layout inside
/// the fixed height so the list scrolls instead of overflowing.
class _ClusterListSheet<T> extends StatelessWidget {
  const _ClusterListSheet({
    required this.title,
    required this.items,
    required this.tileBuilder,
    required this.onItemTap,
  });

  final String title;
  final List<T> items;
  final Widget Function(BuildContext, T) tileBuilder;
  final Future<void> Function(T) onItemTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle.
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  tileBuilder(context, items[index]),
            ),
          ),
        ],
      ),
    );
  }
}