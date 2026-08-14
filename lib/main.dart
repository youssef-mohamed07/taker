import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/auth/auth_service.dart';
import 'core/di/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a provider container to access providers before runApp
  final container = ProviderContainer();
  appContainer = container;

  // Restore a persisted login session before first frame
  await AuthService.restoreSession(container);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const TagerApp(),
  ));
}
