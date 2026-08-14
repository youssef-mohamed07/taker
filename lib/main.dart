import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a provider container to access providers before runApp
  final container = ProviderContainer();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const TagerApp(),
  ));
}
