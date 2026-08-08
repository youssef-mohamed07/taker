import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/di/providers.dart';
import 'core/database/seeder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a provider container to access providers before runApp
  final container = ProviderContainer();
  final db = container.read(databaseProvider);

  // Run the seeder if database is empty
  final seeder = DatabaseSeeder(db);
  if (await seeder.shouldSeed()) {
    await seeder.seedDatabase();
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: const TagerApp(),
  ));
}
