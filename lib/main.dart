import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'role.dart';
import 'screens/home_screen.dart';
import 'screens/owner_home_screen.dart';
import 'screens/team_leader_home_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';

export 'role.dart' show userRole;

/// Formats a timestamp as 'YYYY-MM-DD HH:mm:ss' in local time.
String formatTimestamp(DateTime t) {
  String p2(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${p2(t.month)}-${p2(t.day)} '
      '${p2(t.hour)}:${p2(t.minute)}:${p2(t.second)}';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yprnwybpteelfhcorwib.supabase.co',
    publishableKey: 'sb_publishable_zzeNiixC5aau8lhM8GtU6g_6GdDRPex',
  );
  // The Owner's Command Center is a thin client: it never opens the local Isar
  // database, never runs the offline sync worker and needs no daily site
  // reminder, so the whole field-staff startup chain is skipped for that role.
  if (userRole != 'owner') {
    await DatabaseService.init();
    await SyncService.init(); // background push on reconnect + initial pull
    await NotificationService.init(); // daily 07:00 local reminder
  }
  runApp(const HydraApp());
}

class HydraApp extends StatelessWidget {
  const HydraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hydra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: switch (userRole) {
        // Owner: the thin-client "Site Command" map + decision sheet.
        'owner' => const OwnerHomeScreen(),
        // Team Leader: the Chef de Chantier dashboard.
        'team_leader' => const TeamLeaderHomeScreen(),
        // Subcontractor (and anything else): the capture screen.
        _ => const HomeScreen(),
      },
    );
  }
}
